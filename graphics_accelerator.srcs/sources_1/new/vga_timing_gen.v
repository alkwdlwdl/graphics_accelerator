`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.09.2026 19:26:42
// Design Name: 
// Module Name: vga_timing_gen
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


module vga_timing_gen(
    input clk,
    input reset,
    output reg hsync,
    output reg vsync,
    output reg vid_active,
    output reg [9:0] pixel_x,
    output reg [9:0] pixel_y
    );
    //horizontal timing parameters(no of pixels or clk cycles)
    localparam [9:0]h_dis = 10'd640;
    localparam [9:0]h_fp = 10'd16;
    localparam [9:0]h_sy = 10'd96;
    localparam [9:0]h_bp = 10'd44;
    localparam [9:0]h_tot = 10'd800;
    //vertical timing parameters(no of pixels or clk cycles)
    localparam [9:0]v_dis = 10'd480;
    localparam [9:0]v_fp = 10'd10;
    localparam [9:0]v_sy = 10'd2;
    localparam [9:0]v_bp = 10'd33;
    localparam [9:0]v_tot = 10'd525;
    
    reg [9:0]h_count;
    reg [9:0]v_count;
    reg [9:0]i;
    
    always @(posedge clk or posedge reset)
        begin
        if(reset)
            begin
            
            h_count <=10'd0;   // 10 bits for each pixel counts, since their maximum value is 800 (including front porch,
            v_count <=10'd0;   // (cont.) backporch, sync) for h_count and 525 for v_count
            hsync <= 1'b1;     //**both sync signals are active low, which means when its value is 0, its active**
            vsync <= 1'b1;
            vid_active <= 1'b0; // high only when pixel count is in the drawing region (h_count<h_dis and v_count<v_dis)
            pixel_x <= 10'd0;   //pixel coordinates on the grid, similar to how each element in matrix is referred to
            pixel_y <= 10'd0;   // like row x,column y
        end
        else begin
            if(h_count < h_tot - 10'd1)begin
                h_count <= h_count+1;   // h_count increments till its max value h_tot -1 (since indexing begins with 0
            end
            else begin
                h_count<=10'd0;  // when h_count reaches 799, it must reset to 0, and vcount must incremement by 1, unless it is its max value
                if(v_count < v_tot -10'd1 )begin
                    v_count <= v_count+1;
                end
                else begin
                    v_count <= 10'd0;
                end
            end
                
            if(h_count<h_dis && v_count<v_dis)begin
                vid_active <= 1'd1;    //when pixel counts are in actual display region(640x480 pixels)
                pixel_x <= h_count;    // pixel counts are equal to h and v counts
                pixel_y <= v_count;
            end
            else begin
                vid_active <= 1'd0;
                pixel_x <= 10'd0;      //otherwise its just 0, since values cant immediately reset to 0, the buffers exist 
                pixel_y <= 10'd0;      // as the porches and sync, the values we took are the industry standard
            end
            hsync <= ~((h_count >= h_dis+h_fp && h_count < h_dis + h_fp + h_sy)); //h/vsync must only be 0 when its in the
            vsync <= ~((v_count >= v_dis+v_fp && v_count < v_dis + v_fp + v_sy)); //sync range, comes after front porch and before back
                                    
        end
    end         
    
endmodule
