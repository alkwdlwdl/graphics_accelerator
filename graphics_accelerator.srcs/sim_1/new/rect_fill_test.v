`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.10.2026 00:08:18
// Design Name: 
// Module Name: rect_fill_test
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module rect_fill_test();

localparam xres = 32;
localparam yres = 16;
localparam color = 8;
localparam bitres = $clog2(xres) + 1;
localparam wpr = xres/2;
localparam addr_w = $clog2(yres*wpr);

reg clk = 0;
always #5 clk = ~clk;
reg rst = 1;

reg start = 0;
reg [bitres-1:0] x_start,y_start,w,h;
reg [color-1:0] color_in;
wire fb_we;
wire [addr_w-1:0] fb_addr;
wire [2*color-1:0] fb_data;
wire [1:0] fb_mask;
reg fb_ready = 1;
wire fin;

rect_fill #(.xres(xres),.yres(yres),.color(color)) r1(
    .clk(clk),.rst(rst),.start(start),.x_start(x_start),.y_start(y_start),.w(w),.h(h),.color_in(color_in),
    .fb_we(fb_we),.fb_addr(fb_addr),.fb_data(fb_data),.fb_mask(fb_mask),.fb_ready(fb_ready),.fin(fin)
    );

reg [2*color-1:0] mem [0:wpr*yres-1];
reg [2*color-1:0] tmp;

//framebuffer just for this testbench
always @(posedge clk) begin
    if(fb_we && fb_ready) begin
        if(fb_addr >= wpr*yres)
            $display("address out of range");
        else begin
            tmp = mem[fb_addr];
            if(fb_mask[0])
                tmp[color-1:0] = fb_data[color-1:0];
            if(fb_mask[1])
                tmp[2*color-1:color] = fb_data[2*color-1:color];
            mem[fb_addr]=tmp;
            
        end
    end
end

//random stalls to check if it can handle memory not accepting write for a bit
reg stall_en = 0;
always @(posedge clk)
    fb_ready <= stall_en?(($urandom%4)!=0):1'b1; //stalls about 25% of the time

//count fin pulses (each fill must produce 1)

integer fin_count = 0;
always @(posedge clk) begin
    if(fin)
        fin_count = fin_count + 1;
end

//reference model (what the framebuffer should look like after a fill command is run)
reg [color-1:0] exp_px [0:xres*yres-1]; //array with 1 bit per pixel, no words nothing
integer errors = 0;

task init_mem;
    integer x,y;
    reg [color-1:0]v;
    begin
    for(y=0;y<yres;y=y+1)begin
        for(x=0;x<xres;x=x+1)begin
            v=(x*7 + y*13); //random color we fill in the thing framebuffer
            exp_px[y*xres + x] = v;
            tmp = mem[y*wpr + x/2];
            if(x%2)
                tmp[2*color-1:color] = v;
            else
                tmp[color-1:0] = v;
            mem[y*wpr + x/2] = tmp;
            
        end
    end
    end
endtask

task ref_fill(input integer x0,y0,wd,ht, input [color-1:0]c);
    integer x,y;
    begin
        $display("ref_fill x0=%0d y0=%0d wd=%0d ht=%0d c=%h", x0, y0, wd, ht, c);
        for(y=y0;y<y0+ht;y=y+1) begin
            for(x=0;x<x0+wd;x=x+1) begin
                exp_px[y*xres + x] = c;
            end
        end
    end
    endtask

task check_all(input [255:0]label);
    integer x,y,shown;
    reg [color-1:0]got;
    begin
        shown = 0;
        for(y=0; y<yres;y=y+1) begin
            for(x=0;x<xres;x=x+1)begin
                tmp = mem[y*wpr + x/2];
                got = (x%2)?tmp[2*color-1:color]:tmp[color-1:0];
                if (got !== exp_px[y*xres + x]) begin
                    errors = errors + 1;
                    if(shown<5) begin
                        $display("mismatch (%0s) at x=%0d y=%0d: got%h, expected %h", label,x,y,got,exp_px[y*xres + x]);
                        shown = shown + 1;
                    end
                end
            end
        end
    end
endtask

//run 1 fill and check
reg[255:0] label_s;

task do_fill(input integer x,y,wd,ht,input[color-1:0]c);
    integer timeout,fins_before;
    reg done_seen;
    begin
        fins_before = fin_count;
        @(negedge clk);
        x_start = x;
        y_start = y;
        w=wd;
        h=ht;
        color_in=c;
        start=1;
        @(negedge clk);
        start = 0;
        color_in = ~c; //changing it mid-fill musn't matter
        
        done_seen =0;
        timeout = 0;
        
        while(!done_seen && timeout<100000) begin
            @(posedge clk);
            if(fin)
                done_seen = 1;
            timeout = timeout+1;
        end
        if(!done_seen)begin
            $display("fail, timeout waiting for fin (x=%0d y=%0d w=%0d h=%0d)",x,y,wd,ht);
            errors = errors+1;
        end
        
        ref_fill(x,y,wd,ht,c);
        $sformat(label_s,"x=%0d y=%0d w=%0d h=%0d",x,y,wd,ht);
        check_all(label_s);
        if (errors != 0) begin
            $display("Stopping at first failing fill");
            $finish;
        end
    end
endtask


//test sequence

integer pass,i,rx,ry,rw,rh;

initial begin
    init_mem;
    repeat(4) @(negedge clk);
    rst = 0;
    
    for(pass = 0;pass<2;pass=pass+1) begin
        stall_en = pass;
        $display("pass %0d (stalls %s)",pass,pass?"ON":"OFF");
        
        do_fill(4,2,4,3,8'hF0); //even start, even width
        //do_fill(5,6,4,2,8'hF1); //odd start, even end (both edges taken partially)
        //do_fill(5,10,3,2,8'hF2);//odd start, odd width 
        //do_fill(4,12,3,2,8'hF3);//even start, odd width
        //do_fill(6,0,1,1,8'hF4);//single pixel, even x
        //do_fill(7,0,1,1,8'hF5);//single pixel, odd x
        //do_fill(7,8,2,2,8'hF6);//width 2, straddling a word boundary
        //do_fill(xres-1,yres-1,1,1,8'hF7); //bottom right corner
        //do_fill(0,0,1,yres,8'hF8); //one pixel wide column at left edge
        //do_fill(0,0,xres,yres,8'h00);//full screen clear
        
//        for(i=0;i<200;i=i+1)begin
//            rx=$urandom % xres;
//            ry=$urandom % yres;
//            rw= 1+($urandom %(xres-rx));
//            rh= 1+($urandom %(yres-ry));
//            do_fill(rx,ry,rw,rh,$urandom);
//        end
    end
    
    if(errors == 0)
        $display("all tests passed");
    else
        $display("fail, %0d errors",errors);
    $finish;
end
//watchdog
initial begin
    #50_000_000;
    $display("fail, global timeout");
    $finish;
end
endmodule