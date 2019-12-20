`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/09 17:06:45
// Design Name: test123
// Module Name: 80211_transmitter
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


module transmitter(
    input rst_n,
    input clk,
    // frame data input
    input fifo_wr_clk,
    input [7:0] fifo_din,
    input fifo_wr_en,
    output fifo_full,
    // signal config input
    input [31:0] s_config_tdata,
    input s_config_tvalid,
    // event and trigger
    input tx_now,
    output wire busy,
    // tx output
    output dout_clk,
    output [7:0] tx_data_re,
    output [7:0] tx_data_im,
    output wire tx_data_valid
    );
    wire [3:0] sig_rate;
    wire [11:0] sig_length;
    /*
    Clock Generation    
    */
    wire clk_din, clk_cb, clk_sys;
    wire main_locked;
    clock_gen ClockGenerator
    (
        // input
        .clk_in(clk),
        .rst_n(rst_n),
        // output
        .clk_cb(clk_cb),
        .clk_din(clk_din),
        .clk_sys(clk_sys),

        .main_locked(main_locked)
    );
    
    /*
    Transmitter Controller
    */
    // controller output
    wire [7:1] scrambler_seed;
    wire load_signal_field;
    wire rst_phy;
    wire start_frame, start_ts, start_sig, start_data, end_frame;
    // controller input
    wire send_data_field;
    tx_controller TxController
    (
        .global_rst_n(rst_n & main_locked), // input
        .clk_sys(clk_sys),    // input
        // Control
        .start_tx(tx_now),  // input
        .busy(busy),        // output
        // Resets
        .reset_phy(rst_phy),    // output
        // Scrambler
        .scrambler_seed(scrambler_seed), // output [7:1]
        // Config AXI IO
        .s_config_tdata(s_config_tdata),     // input [23:0]
        .s_config_tvalid(s_config_tvalid),   // input 
        // Tx Control
        .send_data_field(tx_data_valid),   // input
        .load_signal_field(load_signal_field),                 // output
        // Frame Control
        .start_frame(start_frame), // output
        .start_ts(start_ts),       // output
        .start_sig(start_sig),     // output
        .start_data(start_data),   // output
        .end_frame(end_frame)      // output
    );
    /*** CLOCK REGION CB_CLK ***/
    /*
    Data Source
    */
    wire data_dout;
    wire data_dout_valid;
    wire data_dout_tail;
    reg [7:0] real_fifo;
    integer i;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            real_fifo[i] <= fifo_din[7 - i];
        end
    end
    data_source DataSource(
        .rst_n(rst_n),
        .clk_cb(clk_cb),
        .sig_rate(sig_rate),
        .sig_length(sig_length),
        // FIFO
        .fifo_wr_clk(fifo_wr_clk),
        .fifo_wr_en(fifo_wr_en),
        .fifo_din(real_fifo),
        .fifo_full(fifo_full),
        // IO
        .start_data(start_data),
        .dout(data_dout),
        .valid(data_dout_valid),
        .tail(data_dout_tail),
        // EVENT
        .send_data_field(send_data_field)
    );
    /*
    Scrambler
    */
    wire scrambler_dout;
    wire scrambler_data_valid;
    stream_scramble StreamScrambler(
        .rst_n(rst_phy),
        .clk(clk_cb),
        .din(data_dout),
        .en(data_dout_valid),
        .tail(data_dout_tail),
        .seed(scrambler_seed),
        .load_seed(start_frame),
        // output
        .dout(scrambler_dout),
        .data_valid(scrambler_data_valid)
    );
    /*
    Convolutional Encoder (DATA Field)
    */
    wire conv_dout;
    wire conv_dout_valid;
    wire [8:0] conv_dout_index;
    stream_conv_encode StreamConvEncoder(
        .rst_n(rst_phy),
        .clk(clk_cb),
        .sig_rate(sig_rate),
        .clear(start_frame),

        .din(scrambler_dout),
        .en(scrambler_data_valid),
        // output
        .dout(conv_dout),
        .index(conv_dout_index),
        .data_valid(conv_dout_valid)
    );
    /*
    Signal Source
    */
    wire sig_dout;
    wire sig_dout_valid;
    wire tx_signal_field;
    signal_source SignalSource(
        .rst_n(rst_n),
        .clk_sys(clk_sys),
        // DI
        .signal_din(s_config_tdata[23:0]),
        .load_sig(load_signal_field),
        // DO
        .start_sig(start_sig),
        .sig_dout(sig_dout),
        .sig_dout_valid(sig_dout_valid),
        .tx_signal_field(tx_signal_field),
        // CONSTANT
        .SIG_RATE(sig_rate),
        .SIG_LENGTH(sig_length)
    );
    /*
    Convolutional Encoder (SIG Field)
    */
    wire sig_conv_dout;
    wire sig_conv_dout_valid;
    wire [8:0] sig_conv_dout_index;
    stream_conv_encode StreamConvEncoderSIG(
        .rst_n(rst_phy),
        .clk(clk_sys),
        .sig_rate(4'b1101),
        .clear(start_frame),

        .din(sig_dout),
        .en(sig_dout_valid),
        // output
        .dout(sig_conv_dout),
        .index(sig_conv_dout_index),
        .data_valid(sig_conv_dout_valid)
    );
    /*** CLOCK REGION DIN_CLK ***/
    /*
    Interleaver
    */
    wire itv_dout;
    wire itv_data_valid;
    stream_interleaver StreamInterleaver(
        .rst_n(rst_phy),
        .clear(start_frame),
        .clk(clk_din),
        
        .din(conv_dout),
        .din_index(conv_dout_index),
        .en(conv_dout_valid),

        .sig_rate(sig_rate),
        
        .dout(itv_dout),
        .data_valid(itv_data_valid)
    );
    /*
    Constellation
    */
    wire [7:0] mod_re;
    wire [7:0] mod_im;
    wire [5:0] mod_index;
    wire mod_data_valid;
    stream_constellate StreamConstellation(
        .rst_n(rst_phy),
        .clear(start_frame),
        .clk(clk_din),

        .din(itv_dout),
        .en(itv_data_valid),

        .sig_rate(sig_rate),

        .re(mod_re),
        .im(mod_im),
        .index(mod_index),
        .data_valid(mod_data_valid)
    );
    /*
    Interleaver (SIG)
    */
    wire sig_itv_dout;
    wire sig_itv_data_valid;
    stream_interleaver StreamInterleaverSIG(
        .rst_n(rst_phy),
        .clear(start_frame),
        .clk(clk_sys), // 20M clock
        
        .din(sig_conv_dout),
        .din_index(sig_conv_dout_index),
        .en(sig_conv_dout_valid),

        .sig_rate(4'b1101),
        
        .dout(sig_itv_dout),
        .data_valid(sig_itv_data_valid)
    );
    /*
    Constellation (SIG)
    */
    wire [7:0] sig_mod_re;
    wire [7:0] sig_mod_im;
    wire [5:0] sig_mod_index;
    wire sig_mod_data_valid;
    stream_constellate StreamConstellationSIG(
        .rst_n(rst_phy),
        .clear(start_frame),
        .clk(clk_sys), // clock 20M

        .din(sig_itv_dout),
        .en(sig_itv_data_valid),

        .sig_rate(4'b1101),

        .re(sig_mod_re),
        .im(sig_mod_im),
        .index(sig_mod_index),
        .data_valid(sig_mod_data_valid)
    );

    /*** CLOCK REGION SYS_CLK ***/
    /*
    Insert Pilot
    */
    wire [7:0] ifft_din_re;
    wire [7:0] ifft_din_im;
    wire ifft_din_valid;
    wire [7:0] buffered_re, buffered_im;
    wire [5:0] buffered_index;
    wire buffered_valid;
    wire sym_underflow, sym_overflow;
    symbol_buffer SymbolBuffer(
        .rst_n(rst_phy),
        .clk_din(clk_din),
        .clk_sys(clk_sys),
        .start(start_frame),
        .din_re(mod_re),
        .din_im(mod_im),
        .din_index(mod_index),
        .din_valid(mod_data_valid),
        .signal_start(sig_mod_data_valid && sig_mod_index == 0),
        .dout_re(buffered_re),
        .dout_im(buffered_im),
        .dout_index(buffered_index),
        .dout_valid(buffered_valid),
        // Sticky timing-slip flags; not connected to a status register.
        .underflow(sym_underflow),
        .overflow(sym_overflow)
    );
    // mux
    reg [7:0] pilot_din_re;
    reg [7:0] pilot_din_im;
    reg [5:0] pilot_din_index;
    reg pilot_din_valid;
    always @(*) begin
        if (tx_signal_field) begin
            pilot_din_re = sig_mod_re;
            pilot_din_im = sig_mod_im;
            pilot_din_index = sig_mod_index;
            pilot_din_valid = sig_mod_data_valid;
        end
        else begin
            pilot_din_re = buffered_re;
            pilot_din_im = buffered_im;
            pilot_din_index = buffered_index;
            pilot_din_valid = buffered_valid;
        end
    end
    stream_pilot_aboard StreamPilotAboard(
        .rst_n(rst_phy),
        .clk(clk_sys),
        .start(start_frame),

        .din_re(pilot_din_re),
        .din_im(pilot_din_im),
        .din_index(pilot_din_index),
        .din_valid(pilot_din_valid),

        .dout_re(ifft_din_re),
        .dout_im(ifft_din_im),
        .dout_valid(ifft_din_valid)
    );
    /*
    IFFT
    */
    wire [7:0] ifft_dout_re;
    wire [7:0] ifft_dout_im;
    wire [5:0] ifft_dout_index;
    wire ifft_dout_valid;
    stream_ifft StreamIFFT(
        .rst_n(rst_phy),
        .clk_din(clk_sys),
        // DI
        .din_re(ifft_din_re),
        .din_im(ifft_din_im),
        .din_valid(ifft_din_valid),
        // DO
        .dout_re(ifft_dout_re),
        .dout_im(ifft_dout_im),
        .dout_index(ifft_dout_index),
        .dout_valid(ifft_dout_valid)
    );
    /*
    Training Sequence Generator
    */
    wire [7:0] ts_dout_re;
    wire [7:0] ts_dout_im;
    wire ts_dout_valid;
    wire ts_last;
    training_seq_gen TrainingSeqGen(
        .rst_n(rst_phy),
        .clk_sys(clk_sys),
        .start_ts(start_ts),
        .dout_re(ts_dout_re),
        .dout_im(ts_dout_im),
        .dout_valid(ts_dout_valid),
        .ts_last(ts_last)
    );
    /* 
    Output Mux and Windowing
    */
    
    windowing_combiner WindowingCombiner(
        .rst_n(rst_phy),
        .clk_sys(clk_sys),
        .start_frame(start_frame),
        .end_frame(end_frame),
        //
        .ts_re(ts_dout_re),
        .ts_im(ts_dout_im),
        .ts_en(ts_dout_valid),
        .ts_last(ts_last),
        //
        .ifft_re(ifft_dout_re),
        .ifft_im(ifft_dout_im),
        .ifft_en(ifft_dout_valid),
        .ifft_index(ifft_dout_index),
        //
        .tx_re(tx_data_re),
        .tx_im(tx_data_im),
        .tx_valid(tx_data_valid)
    );
    assign dout_clk = clk_sys;
endmodule
