`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.10.2026 21:29:06
// Design Name: 
// Module Name: bres_tb
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


module bres_tb;
localparam W=32, H=18;
localparam B = $clog2(W); //number of bits allocated to
localparam A = $clog2(W*H);
localparam colorbit = 8;

reg clk = 0;
always #5 clk = ~clk;

initial begin
    #1000000;
    $display("WATCHDOG: simulation did not finish");
    $finish;
end

//inputs to the bresline module and framebuffer
reg rst = 1, strt = 0;
reg [B-1:0] b_start_x,b_start_y,b_end_x,b_end_y;
reg [colorbit-1:0] b_color;
reg [B-1:0] fb_rd_pixel_x, fb_rd_pixel_y;

//outputs
wire fb_we, done;
wire [B-1:0] fb_x,fb_y;
wire [A-1:0] fb_wr_addr = fb_y*W + fb_x;
wire [colorbit-1:0] fb_data,fb_rd_data;

framebuffer #(.xres(W),.yres(H),.color_bits(colorbit))f1(.clk(clk),.wr_addr(fb_wr_addr),.wr_data(fb_data),
    .pixel_x(fb_rd_pixel_x),.pixel_y(fb_rd_pixel_y),.rd_data(fb_rd_data),.wr_en(fb_we));

bres_line #(.xres(W),.yres(H),.color(colorbit))b1(.clk(clk),.rst(rst),.strt(strt),.x0(b_start_x),.y0(b_start_y),
    .x1(b_end_x),.y1(b_end_y),.color1(b_color),.fb_we(fb_we),.fb_x(fb_x),.fb_y(fb_y),.fb_data(fb_data),.done(done));
    
//always @(posedge clk)
//    if (fb_we)
//        $display("%0t write (%0d,%0d) = %0d  addr=%0d", $time, fb_x, fb_y, fb_data, fb_wr_addr);
    
task draw_line(input [B-1:0] ax0,ay0,ax1,ay1,input [colorbit-1:0]c);
    begin
        @(negedge clk); //wait until negedge of clk, execute whatevers below it
        b_start_x = ax0;
        b_start_y = ay0;
        b_end_x = ax1;
        b_end_y = ay1;
        b_color = c;
        strt = 1;
        @(negedge clk); //then wait until it hits negedge of clk again, reset strt to 0
        strt = 0;
        while(!done)@(negedge clk); //if done is 0, wait until clk's falling edge,then check done again, if done is 1, leave loop
    end
endtask

task rd_px(input [B-1:0]x,y,output[colorbit-1:0]val);begin
    fb_rd_pixel_x=x;
    fb_rd_pixel_y=y;
    @(posedge clk); #1;
    val = fb_rd_data;
//    if (val !== {colorbit{1'bx}})
//        $display("%0t: lit pixel (%0d,%0d) = %0d", $time, x, y, val);
end
endtask

integer errors;
task line_check(input integer ax0,ay0,ax1,ay1,input [colorbit-1:0]c);
    real m,b,ideal_y,diff;
    integer i,j,abc,lo_x,hi_x; // abc to count number of pixels in the case where x1-x0 is 0, its weird but you'll understand, used k initially which messed with outer module im guessing
    reg [colorbit-1:0]v;
    reg vertcheck,expected;
    begin
    errors = 0;
    if(ax0-ax1==0) vertcheck=1'b1;
    else begin
        m = (ay1-ay0)*1.0/(ax1-ax0);
        vertcheck = 1'b0;
    end
    b = ay0-m*ax0;
    if(vertcheck!==1) begin
        for(i=0;i<W;i=i+1)begin
            for(j=0;j<H;j=j+1)begin
                ideal_y=m*i+b;
                rd_px(i,j,v);
                diff = j*1.0-ideal_y;
                if(diff<0) diff= -diff;
                if(v!=={colorbit{1'bx}})begin
                    if(diff>0.5001) errors = errors+1;
                end
            end
        end
    end
    else begin
        abc = 0;
        for(i=0;i<W;i=i+1)begin
            for(j=0;j<H;j=j+1)begin
                rd_px(i,j,v);
                if(v!=1'bx) k=k+1;
            end
        end
        expected = (ay1>ay0?ay1-ay0:ay0-ay1)+1;
        errors = (abc>expected)?abc-expected:expected-abc;
    end
    $display("line (%0d,%0d)->(%0d,%0d): errors = %0d", ax0, ay0, ax1, ay1, errors);
end 
endtask

integer k;
initial begin

    repeat(3) @(posedge clk);
    @(negedge clk);
    rst = 0; //holds reset for a few cycles
    
    draw_line(2,2,31,17,8'd255);
    $display("mem(2,2) = %h  mem(31,17) = %h", f1.mem[2*W+2], f1.mem[17*W+31]);
    line_check(2,2,31,17,8'd255);
    for (k = 0; k < W*H; k = k + 1) f1.mem[k] = {colorbit{1'bx}};
    draw_line(0,0,0,17,8'd128);
    line_check(0,0,0,17,8'd128);
    for (k = 0; k < W*H; k = k + 1) f1.mem[k] = {colorbit{1'bx}};
    draw_line(0,0,10,10,8'd64);
    line_check(0,0,10,10,8'd64);
    $finish;
     
end
    
endmodule
