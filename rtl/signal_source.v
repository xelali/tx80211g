`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/14 20:32:58
// Design Name: 
// Module Name: signal_source
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


module signal_source(
    input rst_n,
    input clk_sys,
    input [23:0] signal_din,
    input load_sig,
    input start_sig,
    output reg sig_dout,
    output reg sig_dout_valid,
    output reg tx_signal_field,
    output [3:0] SIG_RATE,
    output [11:0] SIG_LENGTH
    );
    // Load Signal
    reg [23:0] SIGNAL;
    assign SIG_RATE = {SIGNAL[0], SIGNAL[1], SIGNAL[2], SIGNAL[3]};
    assign SIG_LENGTH = SIGNAL[16:5];
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            SIGNAL <= 0;
        end
        else begin
            if (load_sig) begin 
                SIGNAL <= signal_din;
            end
        end
    end
    // Signal Field Shift Reg
    reg [6:0] sig_counter;
    reg send_sig_field;
    reg bit_phase;
    reg [2:0] start_delay;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            sig_dout <= 0;
            sig_dout_valid <= 0;
            sig_counter <= 0;
            bit_phase <= 0;
            start_delay <= 0;
            send_sig_field <= 0;
            tx_signal_field <= 0;
        end
        else begin
            sig_dout_valid <= 0;
            if (start_sig) begin
                send_sig_field <= 1;
                bit_phase <= 0;
                start_delay <= 4;
            end
            // Four-clock start delay aligns SIGNAL with the end of the preamble.
            else if (start_delay != 0) begin
                start_delay <= start_delay - 1;
            end
            else if (send_sig_field) begin
                bit_phase <= ~bit_phase;
                if (!bit_phase) begin
                    if (sig_counter < 24) begin
                        sig_dout <= SIGNAL[sig_counter];
                        sig_dout_valid <= 1;
                        tx_signal_field <= 1;
                        sig_counter <= sig_counter + 1;
                    end
                    else if (sig_counter < 60) begin
                        sig_dout <= 0;
                        sig_dout_valid <= 0;
                        tx_signal_field <= 1;
                        sig_counter <= sig_counter + 1;
                    end
                    else begin
                        sig_dout <= 0;
                        sig_dout_valid <= 0;
                        tx_signal_field <= 0;
                        sig_counter <= 0;
                        // reset trigger
                        send_sig_field <= 0;
                    end
                end
            end
            else begin
                bit_phase <= 0;
                sig_dout <= 0;
                sig_dout_valid <= 0;
                tx_signal_field <= 0;
                sig_counter <= 0;
            end
        end 
    end
endmodule
