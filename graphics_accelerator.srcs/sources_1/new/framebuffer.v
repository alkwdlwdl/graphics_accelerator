`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.09.2026 23:05:19
// Design Name: 
// Module Name: framebuffer
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


module framebuffer#(
    parameter xres = 640,
    parameter yres = 480,
    parameter color_bits = 8
    )
    (
    input clk,
    //write port stuff
    input [$clog2(xres*yres)-1:0]wr_addr,
    input [color_bits-1:0]wr_data,
    input wr_en,
    //read port stuff 
    input [9:0]pixel_x,
    input [9:0]pixel_y,
    output [color_bits-1:0]rd_data
    );
    
    localparam addr_width = $clog2(xres*yres);
    reg [color_bits-1:0] mem [0:(xres*yres)-1]; //memory arryas are conventionally written [lsb:msb] which is why number of locations is written that way
    wire [$clog2(xres*yres)-1:0]rd_addr = pixel_y * xres + pixel_x;
    
    //write logic
    always @(posedge clk) begin
        if(wr_en)
            mem[wr_addr] <= wr_data;
    end
    
    //read logic
    //
    // IMPORTANT:read side is registered, so rd_data is 1 clock cycle behind pixel_x/pixel_y
    //
    //make sure vsync and hsync are delayed by 1 clock cycle too otherwise its gonna be a pain
    
    reg [color_bits-1:0]rd_data_reg;
    always @(posedge clk)
        rd_data_reg <= mem[rd_addr];
        
    assign rd_data = rd_data_reg;
endmodule 
