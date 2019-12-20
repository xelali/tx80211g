`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/14 20:32:58
// Design Name: 
// Module Name: data_source
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


module data_source(
    input rst_n,
    input clk_cb,
    input [3:0] sig_rate,
    input [11:0] sig_length,
    input fifo_wr_clk,
    input fifo_wr_en,
    input [7:0] fifo_din,
    input start_data,
    output wire dout,
    output wire valid,
    output wire tail,           // this bit is a tail bit: scrambler output must be forced to 0
    output reg send_data_field,
    output wire fifo_full
    );
    /*
    DATA field bit source (IEEE 802.11 17.3.5.3 - 17.3.5.4)
      bits [0, 16+8*LENGTH)          SERVICE + PSDU, read from the FIFO (software pushes SERVICE+PSDU)
      bits [16+8*LENGTH, +6)         tail, zero after scrambling
      bits up to N_SYM * N_DBPS      pad, zero before scrambling
    One OFDM symbol (4 us) = 480 processing-clock cycles (120 MHz).
    Input bits use alternate cycles, leaving two cycles for the encoder pair.
    Anything left in the FIFO after the frame is drained so it cannot leak into the next frame.
    */
    wire fifo_dout;
    wire fifo_valid;
    wire empty;
    reg fifo_read_en;

    fifo_transmitter FIFOTransmitter (
        .rst(~rst_n),                  // input wire rst
        // Write
        .wr_clk(fifo_wr_clk),            // input wire wr_clk
        .wr_en(fifo_wr_en),              // input wire wr_en
        .din(fifo_din),                  // input wire [7 : 0] din
        // Read
        .rd_clk(clk_cb),            // input wire rd_clk
        .rd_en(fifo_read_en),              // input wire rd_en
        .dout(fifo_dout),                // output wire [0 : 0] dout
        .valid(fifo_valid),              // output wire valid
        // Events
        .full(fifo_full),                // output wire full
        .empty(empty),              // output wire empty
        .underflow(),      // output wire underflow
        .wr_rst_busy(),  // output wire wr_rst_busy
        .rd_rst_busy()  // output wire rd_rst_busy
    );

    reg [8:0] ndbps;
    always @(*) begin
        case (sig_rate)
            4'b1101: ndbps = 24;  4'b1111: ndbps = 36;
            4'b0101: ndbps = 48;  4'b0111: ndbps = 72;
            4'b1001: ndbps = 96;  4'b1011: ndbps = 144;
            4'b0001: ndbps = 192; 4'b0011: ndbps = 216;
            default: ndbps = 24;
        endcase
    end
    wire [15:0] psdu_bits = {1'b0, sig_length, 3'b000} + 16'd16; // SERVICE + PSDU
    wire [15:0] tail_end  = psdu_bits + 16'd6;

    reg [8:0] ncbps;
    always @(*) begin
        case (sig_rate)
            4'b1101, 4'b1111: ncbps = 48;
            4'b0101, 4'b0111: ncbps = 96;
            4'b1001, 4'b1011: ncbps = 192;
            default: ncbps = 288;
        endcase
    end
    // WAIT makes the first symbol's latency the same at every rate:
    // wait + 2*N_DBPS (source) + N_CBPS (interleaver readout) = 768 clocks, so
    // symbol 0 reaches symbol_buffer before its slot at SIGNAL + 4 us.
    reg [9:0] wait_count;
    localparam IDLE = 0, SYMBOL = 1, DRAIN = 2, WAIT = 3;
    reg [1:0]  st;
    reg [15:0] bit_idx;       // bit position in the DATA field
    reg [8:0]  data_counter;  // bit within symbol
    reg [8:0]  cyc;           // 120 MHz cycle within symbol (0..479)
    // pipeline: slot decided at edge k, FIFO data valid after edge k+1
    reg slot, slot_from_fifo, slot_tail;
    reg slot_d, from_fifo_d, tail_d;

    always @(posedge clk_cb or negedge rst_n) begin
        if (!rst_n) begin
            st <= IDLE;
            wait_count <= 0;
            fifo_read_en <= 0;
            bit_idx <= 0;
            data_counter <= 0;
            cyc <= 0;
            slot <= 0; slot_from_fifo <= 0; slot_tail <= 0;
            send_data_field <= 0;
        end
        else begin
            fifo_read_en <= 0;
            slot <= 0; slot_from_fifo <= 0; slot_tail <= 0;
            case (st)
                IDLE: begin
                    bit_idx <= 0;
                    data_counter <= 0;
                    cyc <= 0;
                    if (start_data) begin
                        st <= WAIT;
                        wait_count <= 768 - (ndbps << 1) - ncbps;
                        send_data_field <= 1;
                    end
                end
                WAIT: begin
                    if (wait_count == 0) st <= SYMBOL;
                    else wait_count <= wait_count - 1;
                end
                SYMBOL: begin
                    if (!cyc[0] && data_counter < ndbps) begin
                        slot <= 1;
                        slot_from_fifo <= (bit_idx < psdu_bits);
                        slot_tail <= (bit_idx >= psdu_bits) && (bit_idx < tail_end);
                        fifo_read_en <= (bit_idx < psdu_bits);
                        bit_idx <= bit_idx + 1;
                        data_counter <= data_counter + 1;
                    end
                    if (cyc == 479) begin
                        cyc <= 0;
                        data_counter <= 0;
                        // bit_idx already counts this symbol's bits
                        if (bit_idx >= tail_end) begin
                            st <= DRAIN;
                            send_data_field <= 0;
                        end
                    end
                    else cyc <= cyc + 1;
                end
                DRAIN: begin
                    // discard bytes pushed beyond SERVICE + PSDU
                    fifo_read_en <= !empty && !fifo_read_en;
                    if (empty) st <= IDLE;
                end
                default: st <= IDLE;
            endcase
        end
    end

    // delay the slot flags by one clock to line up with the FIFO read data
    always @(posedge clk_cb or negedge rst_n) begin
        if (!rst_n) begin
            slot_d <= 0; from_fifo_d <= 0; tail_d <= 0;
        end
        else begin
            slot_d <= slot; from_fifo_d <= slot_from_fifo; tail_d <= slot_tail;
        end
    end
    assign valid = slot_d;
    assign dout  = from_fifo_d ? fifo_dout : 1'b0;
    assign tail  = tail_d;
endmodule
