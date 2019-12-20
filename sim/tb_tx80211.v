`timescale 1ns / 1ps
// Testbench for the 802.11a transmitter core.
// Mimics what Tx80211_v1_0 + the Zynq C driver do:
//   1. write SIGNAL word to config (bit 24 = valid, as in the AXI wrapper)
//   2. push the byte stream (SERVICE + PSDU, as prepared by software) into the FIFO
//   3. pulse tx_now, wait until busy drops again
// Plusargs:
//   +fifo=<file>    hex bytes, one per line, exactly what the SW DMA would push
//   +signal=<hex>   24-bit SIGNAL word as written by software
//   +out=<dir>      output directory for dumps
//   +nframes=<n>    transmit n frames (default 1): the same frame, or one per +vectors line
//   +vectors=<file> per frame: "<fifo file> <signal hex> <out dir>" (rate changes without reset)
module tb_tx80211;
    reg clk = 0;            // 100 MHz, same as PS FCLK in the real design
    reg wr_clk = 0;         // AXIS clock for FIFO writes
    reg rst_n = 0;
    always #5 clk = ~clk;
    always #4 wr_clk = ~wr_clk;

    reg  [7:0]  fifo_din = 0;
    reg         fifo_wr_en = 0;
    wire        fifo_full;
    reg  [31:0] cfg = 0;
    reg         tx_now = 0;
    wire        busy;
    wire        dout_clk;
    wire [7:0]  tx_re, tx_im;
    wire        tx_valid;

    transmitter dut (
        .rst_n(rst_n), .clk(clk),
        .fifo_wr_clk(wr_clk), .fifo_din(fifo_din), .fifo_wr_en(fifo_wr_en), .fifo_full(fifo_full),
        .s_config_tdata(cfg), .s_config_tvalid(cfg[24]),
        .tx_now(tx_now), .busy(busy),
        .dout_clk(dout_clk), .tx_data_re(tx_re), .tx_data_im(tx_im), .tx_data_valid(tx_valid)
    );

    // ---------------------------------------------------------------- stimulus
    reg [7:0] fifo_mem [0:4095];
    integer   nbytes, i, f, nframes, frame;
    reg [23:0] signal_word;
    reg [1023:0] fifo_file, outdir;
    reg capture = 0;
    reg [1023:0] vector_file;
    integer vectors = 0;
    integer scan;

    // file handles
    integer f_out, f_scr, f_conv, f_itv, f_mod, f_ifftin, f_ifftout, f_sig, f_pilot, f_ev;

    initial begin
        if (!$value$plusargs("fifo=%s", fifo_file)) fifo_file = "fifo.hex";
        if (!$value$plusargs("signal=%h", signal_word)) signal_word = 24'h000000;
        if (!$value$plusargs("out=%s", outdir)) outdir = ".";
        if (!$value$plusargs("nframes=%d", nframes)) nframes = 1;
        if ($value$plusargs("vectors=%s", vector_file)) begin
            vectors = $fopen(vector_file, "r");
            if (!vectors) $fatal(1, "Cannot open vectors");
        end

        #200 rst_n = 1;
        wait (dut.main_locked === 1'b1);
        $display("[tb] %t MMCM locked", $time);
        #2000;

        for (frame = 0; frame < nframes; frame = frame + 1) begin
            if (vectors) begin
                scan = $fscanf(vectors, "%s %h %s\n", fifo_file, signal_word, outdir);
                if (scan != 3) $fatal(1, "Missing frame vector");
            end
            if (vectors || frame == 0) begin
                for (i = 0; i < 4096; i = i + 1) fifo_mem[i] = 8'hxx;
                $readmemh(fifo_file, fifo_mem);
                nbytes = 0;
                while (nbytes < 4096 && fifo_mem[nbytes] !== 8'hxx) nbytes = nbytes + 1;
                $display("[tb] %0d FIFO bytes, SIGNAL=%06h", nbytes, signal_word);

                f_out     = $fopen({outdir, "/tx_out.txt"}, "w");
                f_scr     = $fopen({outdir, "/tap_scrambler.txt"}, "w");
                f_conv    = $fopen({outdir, "/tap_conv.txt"}, "w");
                f_itv     = $fopen({outdir, "/tap_itv.txt"}, "w");
                f_mod     = $fopen({outdir, "/tap_mod.txt"}, "w");
                f_sig     = $fopen({outdir, "/tap_sig_mod.txt"}, "w");
                f_ifftin  = $fopen({outdir, "/tap_ifft_in.txt"}, "w");
                f_ifftout = $fopen({outdir, "/tap_ifft_out.txt"}, "w");
                f_pilot   = $fopen({outdir, "/tap_pilot.txt"}, "w");
                f_ev      = $fopen({outdir, "/events.txt"}, "w");

            end
            // software: encoder_dma_write(0, (1<<24) | signal)
            @(posedge clk) cfg <= {8'h01, signal_word};
            // software: DMA the FIFO content
            for (i = 0; i < nbytes; i = i + 1) begin
                @(posedge wr_clk);
                while (fifo_full) @(posedge wr_clk);
                fifo_din <= fifo_mem[i];
                fifo_wr_en <= 1;
            end
            @(posedge wr_clk) fifo_wr_en <= 0;
            #2000;
            wait (busy === 1'b0);
            $fwrite(f_ev, "frame %0d fire %0t\n", frame, $time);
            // software: open fire, clear it once busy is seen
            // (random AXI-side phase w.r.t. the 20/120 MHz clocks)
            #(($urandom % 8) * 10);
            @(posedge clk) tx_now <= 1;
            capture <= 1;
            wait (busy === 1'b1);
            @(posedge clk) tx_now <= 0;
            if (vectors) begin
                cfg <= 0;
                wait (dut.end_frame === 1'b1);
                wait (dut.end_frame === 1'b0);
            end
            else wait (busy === 1'b0);
            $fwrite(f_ev, "frame %0d done %0t\n", frame, $time);
            #20000; // idle gap, keep capturing
            if (vectors) begin
                capture = 0;
                $fclose(f_out); $fclose(f_scr); $fclose(f_conv); $fclose(f_itv);
                $fclose(f_mod); $fclose(f_sig); $fclose(f_ifftin); $fclose(f_ifftout);
                $fclose(f_pilot); $fclose(f_ev);
            end
        end
        capture <= 0;
        $display("[tb] %t done", $time);
        if (!vectors) $fclose(f_out);
        $finish;
    end

    // safety timeout
    initial begin
        #50_000_000;
        $fatal(1, "[tb] TIMEOUT");
    end

    // ---------------------------------------------------------------- capture
    // every clk_sys cycle while capturing: valid re im   (re/im signed 8 bit)
    always @(posedge dout_clk) if (capture)
        $fwrite(f_out, "%0d %0d %0d\n", tx_valid, $signed(tx_re), $signed(tx_im));

    // stage taps
    always @(posedge dut.clk_cb) if (capture && dut.scrambler_data_valid)
        $fwrite(f_scr, "%0d\n", dut.scrambler_dout);
    always @(posedge dut.clk_din) if (capture && dut.conv_dout_valid)
        $fwrite(f_conv, "%0d %0d\n", dut.conv_dout, dut.conv_dout_index);
    always @(posedge dut.clk_din) if (capture && dut.itv_data_valid)
        $fwrite(f_itv, "%0d\n", dut.itv_dout);
    always @(posedge dut.clk_din) if (capture && dut.mod_data_valid)
        $fwrite(f_mod, "%0d %0d %0d\n", $signed(dut.mod_re), $signed(dut.mod_im), dut.mod_index);
    always @(posedge dut.clk_sys) if (capture && dut.sig_mod_data_valid)
        $fwrite(f_sig, "%0d %0d %0d\n", $signed(dut.sig_mod_re), $signed(dut.sig_mod_im), dut.sig_mod_index);
    always @(posedge dut.clk_sys) if (capture && dut.ifft_din_valid)
        $fwrite(f_ifftin, "%0d %0d\n", $signed(dut.ifft_din_re), $signed(dut.ifft_din_im));
    always @(posedge dut.clk_sys) if (capture && dut.ifft_dout_valid)
        $fwrite(f_ifftout, "%0d %0d %0d %0d\n",
                $signed(dut.StreamIFFT.ifft_res_re), $signed(dut.StreamIFFT.ifft_res_im),
                dut.ifft_dout_index, dut.StreamIFFT.event_fft_overflow);
    // pilot writes into the pilot RAM: addr value polarity
    always @(posedge dut.clk_sys) if (capture && dut.StreamPilotAboard.pilot_aboard_start)
        $fwrite(f_pilot, "%0d %0d %0d\n", dut.StreamPilotAboard.pilot_postion,
                dut.StreamPilotAboard.pilot_polarity, $time);
    // FSM / event trace
    reg [3:0] last_state = 0;
    always @(posedge dut.clk_sys) begin
        if (capture && dut.TxController.state !== last_state)
            $fwrite(f_ev, "state %0d -> %0d at %0t\n", last_state, dut.TxController.state, $time);
        last_state <= dut.TxController.state;
        if (capture && dut.StreamIFFT.event_fft_overflow)
            $fwrite(f_ev, "fft_overflow %0t\n", $time);
        if (capture && (dut.StreamIFFT.event_tlast_missing | dut.StreamIFFT.event_tlast_unexpected))
            $fwrite(f_ev, "fft_tlast_event %0t\n", $time);
    end
endmodule
