`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/15 16:37:15
// Design Name: 
// Module Name: windowing_combiner
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


module windowing_combiner(
    input rst_n,
    input clk_sys,
    input start_frame,
    input end_frame,
    // Training Seq Input
    input signed [7:0] ts_re,
    input signed [7:0] ts_im,
    input ts_en,
    input ts_last,
    // IFFT Input
    input signed [7:0] ifft_re,
    input signed [7:0] ifft_im,
    input ifft_en,
    input [5:0] ifft_index,
    // Tx Output
    output reg signed [7:0] tx_re,
    output reg signed [7:0] tx_im,
    output reg tx_valid
    );
    reg [2:0] state;
    reg [2:0] next_state;
    localparam IDLE = 0, MUX_TS = 1, MUX_IFFT = 2;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n)  state <= IDLE;
        else state <= next_state;
    end
    always @(*) begin
        next_state = state;
        case (state)
            IDLE : if(start_frame) next_state = MUX_TS;
            MUX_TS : if(ts_last) next_state = MUX_IFFT;
            MUX_IFFT : if(!ifft_en) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    reg [5:0] last_ifft_index;
    reg signed [7:0] first_ifft_re;
    reg signed [7:0] first_ifft_im;
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n)  last_ifft_index <= 0;
        else last_ifft_index <= ifft_index;
    end

    reg signed [7:0] mux_out_re;
    reg signed [7:0] mux_out_im;
    reg save_first_val;
    always @(*) begin
        save_first_val = 0;
        case (state)
            IDLE : begin
                mux_out_re = 0;
                mux_out_im = 0;
            end
            MUX_TS : begin
                if (ts_last) begin
                    mux_out_re = ts_re + (ifft_re >>> 1);
                    mux_out_im = ts_im + (ifft_im >>> 1);
                end
                else begin
                    mux_out_re = ts_re;
                    mux_out_im = ts_im;
                end
            end
            MUX_IFFT : begin
                if (last_ifft_index == 63 && ifft_index == 0) begin
                    save_first_val = 1;
                    mux_out_re = ifft_re;
                    mux_out_im = ifft_im;
                end
                else if (last_ifft_index == 63 && ifft_index == 48) begin
                    mux_out_re = (ifft_re >>> 1) + first_ifft_re;
                    mux_out_im = (ifft_im >>> 1) + first_ifft_im;
                end
                else begin
                    mux_out_re = ifft_re;
                    mux_out_im = ifft_im;
                end
            end
            default: begin
                mux_out_re = 0;
                mux_out_im = 0;
            end
        endcase
    end
    // Save Value
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            first_ifft_re <= 0;
            first_ifft_im <= 0;
        end
        else begin
            if (save_first_val) begin
                first_ifft_re <= mux_out_re >>> 1;
                first_ifft_im <= mux_out_im >>> 1;
            end
        end
    end
    // Output
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            tx_re <= 0;
            tx_im <= 0;
            tx_valid <= 0;
        end
        else begin
            tx_re <= mux_out_re;
            tx_im <= mux_out_im;
            tx_valid <= ifft_en | ts_en;
        end
    end
endmodule
