`timescale 1ns / 1ps
// Two-bank buffer between the 120 MHz DATA path and the 20 MHz output: the mapper
// fills one bank while the other is played out, one symbol per 80 clk_sys cycles,
// timed from the first mapped SIGNAL subcarrier.

module symbol_buffer(
    input rst_n,
    input clk_din,
    input clk_sys,
    input start,
    input [7:0] din_re,
    input [7:0] din_im,
    input [5:0] din_index,
    input din_valid,
    input signal_start,
    output reg [7:0] dout_re,
    output reg [7:0] dout_im,
    output reg [5:0] dout_index,
    output reg dout_valid,
    // Sticky until rst_n: a symbol missed its 4 us read slot (late), or the
    // writer started a bank the reader had not consumed yet (early).
    output reg underflow,
    output reg overflow
    );
    reg [15:0] memory [0:127];
    reg write_bank;
    reg [1:0] ready;
    (* ASYNC_REG = "TRUE" *) reg [1:0] ready_s, ready_d;
    reg [1:0] consumed;
    reg read_bank;
    reg [6:0] cycle;
    reg active;
    reg available;
    reg missed;
    (* ASYNC_REG = "TRUE" *) reg [1:0] consumed_s, consumed_d;
    always @(posedge clk_din or negedge rst_n) begin
        if (!rst_n) begin
            write_bank <= 0;
            ready <= 0;
            consumed_s <= 0;
            consumed_d <= 0;
            overflow <= 0;
        end
        else begin
            consumed_s <= consumed;
            consumed_d <= consumed_s;
            if (start) begin
                write_bank <= 0;
                ready <= 0;
            end
            else if (din_valid) begin
                // Starting a bank that still holds an unread symbol.
                if (din_index == 0 && ready[write_bank] != consumed_d[write_bank])
                    overflow <= 1;
                if (din_index == 47) begin
                    ready[write_bank] <= ~ready[write_bank];
                    write_bank <= ~write_bank;
                end
            end
        end
    end
    always @(posedge clk_din) begin
        if (din_valid) memory[{write_bank, din_index}] <= {din_re, din_im};
    end
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            ready_s <= 0;
            ready_d <= 0;
            consumed <= 0;
            read_bank <= 0;
            cycle <= 0;
            active <= 0;
            available <= 0;
            missed <= 0;
            underflow <= 0;
            dout_valid <= 0;
            dout_index <= 0;
            dout_re <= 0;
            dout_im <= 0;
        end
        else begin
            ready_s <= ready;
            ready_d <= ready_s;
            dout_valid <= 0;
            if (start) begin
                consumed <= 0;
                read_bank <= 0;
                active <= 0;
                available <= 0;
                missed <= 0;
            end
            else if (signal_start) begin
                active <= 1;
                // Account for the registered RAM output and the pilot input.
                cycle <= 2;
            end
            else if (active) begin
                if (cycle == 79) begin
                    cycle <= 0;
                    available <= ready_d[read_bank] != consumed[read_bank];
                    // An empty slot is normal only after the last symbol.
                    if (ready_d[read_bank] == consumed[read_bank]) missed <= 1;
                end
                else cycle <= cycle + 1;
                // A symbol arriving after an empty slot was late.
                if (missed && ready_d[read_bank] != consumed[read_bank])
                    underflow <= 1;
                if (available && cycle < 48) begin
                    {dout_re, dout_im} <= memory[{read_bank, cycle[5:0]}];
                    dout_index <= cycle[5:0];
                    dout_valid <= 1;
                    if (cycle == 47) begin
                        consumed[read_bank] <= ready_d[read_bank];
                        read_bank <= ~read_bank;
                        available <= 0;
                    end
                end
            end
        end
    end

    // synthesis translate_off
    // Simulation only: stop at the first timing slip.
    always @(posedge underflow) $fatal(1, "symbol_buffer: DATA symbol missed its 4 us slot");
    always @(posedge overflow)  $fatal(1, "symbol_buffer: bank overwritten before it was read");
    // synthesis translate_on
endmodule
