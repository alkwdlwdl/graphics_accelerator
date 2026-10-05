`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 30.09.2026 23:39:25
// Design Name: 
// Module Name: framebuffer_test
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


module framebuffer_test(

    );
    
    reg clk = 0;
    reg [5:0] wr_addr;
    reg [7:0] wr_data;
    reg wr_en;
    reg [9:0]pixel_x;
    reg [9:0]pixel_y;
    wire [7:0]rd_data;
    
    //an 8x8 grid jjust to test, 
    
framebuffer #(
    .xres(8),
    .yres(8),
    .color_bits(8)
    )test(
    .clk(clk),
    .wr_addr(wr_addr),
    .wr_data(wr_data),
    .wr_en(wr_en),
    .pixel_x(pixel_x),
    .pixel_y(pixel_y),
    .rd_data(rd_data)
);
        
always #5 clk=~clk; //10ns clock period since last time sim fucked up by stopping sim at 1000ns

initial begin
    $dumpfile("framebuffer_test.vcd");
    $dumpvars(0,framebuffer_test);
    
    //test phase 1: manually write a few pixels
    wr_en = 1'b1;
    wr_addr = 6'd0; wr_data = 8'hAA; @(posedge clk);#1; //pixel (0,0)
    wr_addr = 6'd6; wr_data = 8'hFF; @(posedge clk);#1; //pixel (6,0)
    wr_addr = 6'd12; wr_data = 8'hAB; @(posedge clk);#1; //pixel (4,1) since 8*1 + 4 = 12
    wr_en = 0;
    
    //test phase 2: emulate scanout(i havent made  it yet so this works, its  just to check if framebuffer works or nah)
    pixel_x = 0; pixel_y = 0; @(posedge clk);#1;//rd_data should show AA
    pixel_x = 4; pixel_y = 0; @(posedge clk);#1;//rd_data should show XX
    pixel_x = 6; pixel_y = 0; @(posedge clk);#1;//rd_data should show FF
    pixel_x = 4; pixel_y = 1; @(posedge clk);#1;//rd_data should show AB
    @(posedge clk);
    
    #200 $finish;
end
    
endmodule
