`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.10.2026 19:25:18
// Design Name: 
// Module Name: bres_line
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


module bres_line#(
    parameter xres = 640,
    parameter yres = 480,
    parameter color = 8,
    parameter bitres = $clog2(xres)
    )
    (
    input wire clk,rst,strt,
    input wire [bitres-1:0] x0,y0,x1,y1,
    input wire [color-1:0] color1,
    output wire fb_we,
    output wire [bitres-1:0] fb_x,fb_y,
    output wire [color-1:0] fb_data,
    output wire done
    );
    
    localparam idle=2'b00,plot=2'b01,step=2'b10,sdone=2'b11;
    reg[1:0]state;
    
    //unsigned positions
    reg[bitres-1:0] cur_x,cur_y,end_x,end_y;
    reg x_dir,y_dir; //direction of line, basically if variable is 0, x or y is decreasing, if variable is 1, x or y is incraesing
    reg [color-1:0] clr;
    
    reg signed [bitres:0]dx,dy,err;
    
    //magnitude of distance, initially from start (x0,y0) to (x1,y1)
    wire [bitres-1:0] abs_dx = (x1>x0)?x1-x0:x0-x1; //we're calculating this as if the arithmetic is done normally, x1-x0 would result in a massive 10 bit number (unsigned),
    wire [bitres-1:0] abs_dy = (y1>y0)?y1-y0:y0-y1;
    
    wire signed [bitres:0] w_dx = $signed({1'b0,abs_dx});
    wire signed [bitres:0] w_dy = -$signed({1'b0,abs_dy});
    
    wire signed [bitres+1:0] e = {err,1'b0}; // come back to this later
    wire step_x = (e >=dy); //because dy we forced to be negative a bit back
    wire step_y = (e<=dx);
    wire at_end = (cur_x == end_x) && (cur_y == end_y);
    
    always @(posedge clk) begin
        if(rst)
            state <= idle;
        else case(state)
            idle: if(strt) begin
                    cur_x <= x0; cur_y = x0;
                    end_x <= x1; end_y = y1;
                    x_dir <= (x0<x1);
                    y_dir <= (y0<y1);
                    dx <= w_dx;
                    dy <= w_dy;
                    err <= w_dx + w_dy;
                    clr <= color1;
                    state <= plot;
                  end
            plot: state <= at_end?sdone:step;
            step: begin
                if(step_x) cur_x <= x_dir?cur_x +1'b1:cur_x-1'b1;
                if(step_y) cur_y <= y_dir?cur_y +1'b1:cur_y-1'b1;
                err <= err +(step_x?dy:{(bitres+1){1'b0}}) + (step_y?dx:{(bitres){1'b0}}); // the bitres part in curly brackets is a replication operator, it replicates 0 bitres+1 times so it's length matches with err
                state <= plot;
                end
            sdone: state <=idle;
        endcase
    end
    
    assign fb_we = (state == plot);
    assign fb_x = cur_x;
    assign fb_y = cur_y;
    assign fb_data = clr;
    assign done = (state == sdone);
endmodule
