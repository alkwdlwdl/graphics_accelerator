`timescale 1ns / 1ps
// Self-checking testbench for command_fifo: directed tests plus a random
// write/read stress run compared against a software model.
module tb_command_fifo;
    localparam DATA_WIDTH = 64;
    localparam DEPTH      = 16;

    reg clk = 0, reset = 1;
    reg write_en = 0, read_en = 0;
    reg [DATA_WIDTH-1:0] data_in = 0;
    wire full, empty;
    wire [DATA_WIDTH-1:0] data_out;

    command_fifo #(.DEPTH(DEPTH), .DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk), .reset(reset),
        .write_en(write_en), .read_en(read_en),
        .data_in(data_in), .data_out(data_out),
        .empty(empty), .full(full));

    always #5 clk = ~clk;

    // software model (circular, bigger than the DUT)
    reg [DATA_WIDTH-1:0] model [0:63];
    integer head = 0, tail = 0, mcnt = 0;
    integer errors = 0, i, k;
    reg do_w, do_r;

    // one clock cycle: drive inputs at negedge, check state, update model
    task cycle(input w, input [DATA_WIDTH-1:0] d, input r);
        begin
            @(negedge clk);
            write_en = w; data_in = d; read_en = r;
            #1;
            if (full  !== (mcnt == DEPTH)) begin $display("FAIL full=%b mcnt=%0d", full, mcnt); errors = errors + 1; end
            if (empty !== (mcnt == 0))     begin $display("FAIL empty=%b mcnt=%0d", empty, mcnt); errors = errors + 1; end
            if (mcnt > 0 && data_out !== model[head % 64]) begin
                $display("FAIL data_out=%h expected=%h", data_out, model[head % 64]); errors = errors + 1;
            end
            if (mcnt == 0 && (^data_out) !== 1'bx) begin
                $display("FAIL data_out should be x while empty"); errors = errors + 1;
            end
            do_w = w && (mcnt < DEPTH);
            do_r = r && (mcnt > 0);
            if (do_w) begin model[tail % 64] = d; tail = tail + 1; end
            if (do_r) begin head = head + 1; end
            mcnt = tail - head;
            @(posedge clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        reset = 0;

        // test 1: after reset the FIFO is empty
        cycle(0, 0, 0);

        // test 2: read on empty is ignored
        cycle(0, 0, 1);
        cycle(0, 0, 0);

        // test 3: first write into an empty FIFO clears empty, does not set full
        cycle(1, 64'h1234, 0);
        cycle(0, 0, 0);
        cycle(0, 0, 1);
        cycle(0, 0, 0);

        // test 4: fill to full
        for (i = 0; i < DEPTH; i = i + 1) cycle(1, 64'hA000_0000_0000_0000 + i, 0);
        cycle(0, 0, 0);
        if (!full) begin $display("FAIL: not full after %0d writes", DEPTH); errors = errors + 1; end

        // test 5: write while full is ignored
        cycle(1, 64'hDEAD_BEEF_DEAD_BEEF, 0);
        cycle(1, 64'hDEAD_BEEF_DEAD_BEEF, 0);

        // test 6: drain in order
        for (i = 0; i < DEPTH; i = i + 1) cycle(0, 0, 1);
        cycle(0, 0, 0);
        if (!empty) begin $display("FAIL: not empty after drain"); errors = errors + 1; end

        // test 7: simultaneous write and read across pointer wraparound
        cycle(1, 64'h1111, 0);
        for (i = 0; i < 100; i = i + 1) cycle(1, 64'h2000 + i, 1);
        for (i = 0; i < 5; i = i + 1) cycle(0, 0, 1);

        // test 8: random stress (biased so it hits both full and empty)
        for (k = 0; k < 3; k = k + 1) begin
            for (i = 0; i < 3000; i = i + 1) begin
                if (k == 0)      cycle(($urandom % 4) != 0, {$urandom, $urandom}, ($urandom % 4) == 0);
                else if (k == 1) cycle(($urandom % 4) == 0, {$urandom, $urandom}, ($urandom % 4) != 0);
                else             cycle($urandom % 2, {$urandom, $urandom}, $urandom % 2);
            end
        end

        // test 9: asynchronous reset clears the flags immediately
        cycle(1, 64'h5555, 0);
        cycle(1, 64'h6666, 0);
        @(negedge clk);
        write_en = 0; read_en = 0;
        #2 reset = 1;
        #1;
        if (!empty || full) begin $display("FAIL: async reset did not clear flags"); errors = errors + 1; end
        @(negedge clk); reset = 0;

        if (errors == 0) $display("PASS");
        else $display("FAILED with %0d errors", errors);
        $finish;
    end
endmodule
