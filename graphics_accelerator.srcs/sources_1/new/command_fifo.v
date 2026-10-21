`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: command_fifo
// Description: Synchronous FIFO that queues GPU draw commands between the
//              command source (UART / testbench) and the command decoder.
//
//   - Registered empty / full flags (empty_reg / full_reg), asynchronous
//     active-high reset, separate write / read / flag / storage processes.
//   - First-word fall-through: while `empty` is low, `data_out` already shows
//     the oldest command. Latch it, then pulse `read_en` to remove it.
//   - write_en while full and read_en while empty are ignored.
//   - Pointers are PTR_SIZE = log2(DEPTH)+1 bits. The extra top bit tells a
//     full FIFO from an empty one (same low bits, different top bit), so all
//     DEPTH entries are usable. Only the low bits address the memory.
//   - The memory has no reset, so Vivado maps it to distributed RAM (LUTs).
//
// Suggested 64-bit command word (DATA_WIDTH = 64):
//   [63:61] opcode   001 = FILL_RECT, 010 = DRAW_LINE, 011 = BLIT
//   [60:51] x0       [50:41] y0
//   [40:31] w / x1   [30:21] h / y1
//   [20:13] color    [12:0]  reserved
//////////////////////////////////////////////////////////////////////////////////
module command_fifo #(
    parameter DEPTH      = 16,   // number of entries (power of 2, >= 2)
    parameter DATA_WIDTH = 64    // width of one command word
)(
    input  wire                  clk,
    input  wire                  reset,      // asynchronous, active high
    input  wire                  write_en,
    input  wire                  read_en,
    input  wire [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out,
    output wire                  empty,
    output wire                  full
);

    localparam PTR_SIZE = $clog2(DEPTH) + 1;

    (* ram_style = "distributed" *) reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    reg [PTR_SIZE-1:0] wr_ptr;
    reg [PTR_SIZE-1:0] rd_ptr;
    reg                empty_reg;
    reg                full_reg;

    // accepted operations and where the pointers will be after this clock
    wire do_write = write_en && !full_reg;
    wire do_read  = read_en  && !empty_reg;
    wire [PTR_SIZE-1:0] wr_ptr_next = wr_ptr + do_write;
    wire [PTR_SIZE-1:0] rd_ptr_next = rd_ptr + do_read;

    // Write process
    always @(posedge clk or posedge reset) begin
        if (reset)
            wr_ptr <= {PTR_SIZE{1'b0}};
        else if (do_write)
            wr_ptr <= wr_ptr + 1'b1;
    end

    // Read process
    always @(posedge clk or posedge reset) begin
        if (reset)
            rd_ptr <= {PTR_SIZE{1'b0}};
        else if (do_read)
            rd_ptr <= rd_ptr + 1'b1;
    end

    // Empty flag: pointers equal after this clock
    always @(posedge clk or posedge reset) begin
        if (reset)
            empty_reg <= 1'b1;
        else
            empty_reg <= (wr_ptr_next == rd_ptr_next);
    end

    // Full flag: low bits equal, top (wrap) bits different after this clock
    always @(posedge clk or posedge reset) begin
        if (reset)
            full_reg <= 1'b0;
        else
            full_reg <= (wr_ptr_next[PTR_SIZE-1]   != rd_ptr_next[PTR_SIZE-1]) &&
                        (wr_ptr_next[PTR_SIZE-2:0] == rd_ptr_next[PTR_SIZE-2:0]);
    end

    // Data storage (no reset, so it can be inferred as RAM)
    always @(posedge clk) begin
        if (do_write)
            memory[wr_ptr[PTR_SIZE-2:0]] <= data_in;
    end

    // Data retrieval
    assign data_out = empty_reg ? {DATA_WIDTH{1'bx}} : memory[rd_ptr[PTR_SIZE-2:0]];

    // Status outputs
    assign empty = empty_reg;
    assign full  = full_reg;

endmodule

