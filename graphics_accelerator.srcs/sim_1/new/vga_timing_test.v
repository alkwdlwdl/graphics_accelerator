`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.09.2026 23:18:23
// Design Name: 
// Module Name: vga_timing_test
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


module vga_timing_test;
reg clk;
reg reset;

wire h_sync,v_sync,vid_active;
wire [9:0]pixel_x,pixel_y;

vga_timing_gen(.clk(clk),.reset(reset),.pixel_x(pixel_x),.pixel_y(pixel_y),.vid_active(vid_active),
                .hsync(hsync),.vsync(vsync));

always begin
    #20 clk = ~clk;
end

initial begin
    clk <= 1'b0;
    reset <= 1'b1;
    #100;         //hold reset to 1 for 100 ns, so that we make sure it works on the correct clock pulse
    reset <= 1'b0;
    //for 1 frame, run for 20ms, or 2*10^6 ns, since display is 640x480@50, so theres 50 frames per second, which is 1 frame every 20ms 
    #20000000;
    
    $display("Simulation completed");
    $finish;
end

initial begin  //the 0 after % removes any trailing 0s)
    $monitor("Time=%0t ns | reset = %b | h_x = %0d | v_y = %0d | vid_active = %b | hsync = %b | vsync = %b",$time,reset,pixel_x,pixel_y,vid_active,hsync,vsync);
    end
endmodule
