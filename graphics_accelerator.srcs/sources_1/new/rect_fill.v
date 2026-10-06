`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.10.2026 22:29:55
// Design Name: 
// Module Name: rect_fill
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


module rect_fill#(
    parameter xres = 640,
    parameter yres = 480,
    parameter color = 8,
    parameter bitres = $clog2(xres)+1,//number of bits per row
    parameter wpr = xres/2, //wrods per row
    parameter addr_w = $clog2(wpr*yres) //number of bits  needed to account for every word in the framebuffer 
    )
    (
    input wire clk,rst,
    //inputs from controller
    input wire start,
    input wire [bitres-1:0] x_start, y_start, w , h,//coordinates of top left corner of rect, its width and height
    input wire [color-1:0]color_in,
    
    //inputs to framevubffer
    output wire fb_we, //enabling write to framebuffer
    output wire [addr_w-1:0]fb_addr, //which pixel to write to in framebuffer
    output wire [2*color-1:0]fb_data, //what color we're writing to fb, 2*color since we're writing for 2 pixels
    output wire [1:0]fb_mask, //the mask which goes over the screen(the 2 pixels we're gonna change
    input wire fb_ready, //whther memory is ready to accept values or not
    
    output reg fin //when rect is done being drawn
); 

localparam idle = 1'b0, fill = 1'b1;
reg state; //holds the value of start after it drops

reg [bitres-2:0] cur_wx, wx_first, wx_last; // current word column index (-2 since we write 2 pixels per cycle), first and last variables are the first and last word column of the rectangle
reg [bitres-1:0] cur_y, y_last; //current and final row
reg [addr_w-1:0] cur_addr,row_addr; //cur_addr : address being written now, row_addr : address of the start of current row
reg [1:0] first_mask,last_mask; //which pixels to wrwite in the f irst and lasst word of each row
reg [color-1:0] color_r; //the color, latched on start so caller cacn change color_in mid fill

//computed once when start is active (it only becomes high at the first cycle of the draw period, low otherwise
wire [bitres-1:0]x_last_c = x_start + w -1; //coordinates of last pixel of row
wire [addr_w-1:0]start_addr = y_start * wpr +(x_start>>1);//address of the first word, row offset(y_start * wpr + word column (the x_start term)
//outputs:
wire first_word = (cur_wx == wx_first); // flags whether the current word is left or rright edge of rectangle
wire last_word = (cur_wx == wx_last);

assign fb_we = (state == fill);  
assign fb_addr = cur_addr;
assign fb_data = {color_r, color_r}; //mask determines which half matters
assign fb_mask = (first_word? first_mask:2'b11)&(last_word?last_mask:2'b11);

wire accept = fb_we & fb_ready; //write happens only when we enable it and memory is ready to accept it

always @(posedge clk) begin
    if(rst) begin
        state <= idle;
        fin <= 1'b0;
    end
    else begin
        fin <=1'b0;
        case (state)
            idle: if(start) begin
                    // i realized i messed up while writing the comments, by line i mean row and by row i mean column
                    
                    
                    
                    cur_wx <= x_start >> 1; //2 pixels are represented by 1 word by right shifting
                    wx_first <= x_start >> 1;
                    wx_last <= x_last_c >> 1;
                    //to make sure we get the proper number of pixels, if x_start is odd, then first condition is applied, which tells it to ignore the first even bit
                    //in a word, every msb bit will be even, and lsb bit will be odd, how we've designed the screen is that its topleft pixel is (0,0), and it increases if you go right or down, and vice versa
                    //but in code we write msb first then lsb, msb->lsb, so it might be a bit weird trying to visualize it 
                    first_mask <= x_start[0] ? 2'b10 : 2'b11; 
                    last_mask <= x_last_c[0] ? 2'b11 : 2'b01;
                    //the rect_fill module will be idle for some time to reset, otherwise it will be in fill mode, which is why we're resetting the current line to the start
                    cur_y <= y_start;
                    y_last <= y_start + h-1; //-1 because lines go from 0 to yres (480 in this case)
                    cur_addr <= start_addr;
                    row_addr <= start_addr;
                    color_r <= color_in;
                    state <= fill;
                end
            fill: if(accept) begin
                    if(cur_wx == wx_last)begin
                        cur_wx <= wx_first; //if its at last word of row, resets to the start of the row (on the next line on y axis)
                        if(cur_y == y_last) begin
                            state <= idle; //if at last line, then its done drawing the rectangle, set state back to idle
                            fin <= 1'b1; //signal that its done drawing
                        end
                        else begin
                            cur_y <= cur_y + 1; //increment current line count by 1 if at last word of row and not last line
                            row_addr <= row_addr + wpr; //increment address by wpr, essentially increments address to next line
                            cur_addr <= row_addr + wpr; 
                        end
                    end
                    else begin
                         cur_wx <= cur_wx + 1; //if not at last word of row, increment the current word and address by 1
                         cur_addr <= cur_addr + 1;
                    end
                    
                  end
            endcase
    end
end

endmodule
