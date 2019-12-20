`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/15 11:02:00
// Design Name: 
// Module Name: training_seq_gen
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


module training_seq_gen(
    input rst_n,
    input clk_sys,
    input start_ts,
    output reg [7:0] dout_re,
    output reg [7:0] dout_im,
    output reg dout_valid,
    output reg ts_last
    );
    /*
    Training Sequence Generation
    */
    wire signed [7:0] ts_re;
    wire signed [7:0] ts_im;
    wire ts_valid;

    wire start_sts;
    wire start_lts;
    wire [7:0] sts_re;
    wire [7:0] sts_im;
    wire [7:0] sts_index;
    wire sts_valid;
    sts_gen ShortTSGenerator(
        .rst_n(rst_n),
        .clk(clk_sys),
        .en(start_sts),
        // output
        .re(sts_re),
        .im(sts_im),
        .index(sts_index),
        .data_valid(sts_valid)
    );
    wire [7:0] lts_re;
    wire [7:0] lts_im;
    wire [7:0] lts_index;
    wire lts_valid;
    lts_gen LongTSGenerator(
        .rst_n(rst_n),
        .clk(clk_sys),
        .en(start_lts),
        // output
        .re(lts_re),
        .im(lts_im),
        .index(lts_index),
        .data_valid(lts_valid)
    );
    reg [8:0] ts_counter;
    reg send_ts;
    
    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            ts_counter <= 0;
            send_ts <= 0;
            dout_re <= 0;
            dout_im <= 0;
            dout_valid <= 0;
            ts_last <= 0;
        end
        else begin
            if (start_ts)
                send_ts <= 1;
            else if (send_ts) begin
                
                if (ts_counter == 321) ts_last <= 1;
                else ts_last <= 0;

                if (ts_counter <= 321) begin
                    ts_counter <= ts_counter + 1;
                    dout_re <= ts_re;
                    dout_im <= ts_im;
                    dout_valid <= ts_valid;
                end
                else begin
                    ts_counter <= 0;
                    dout_re <= 0;
                    dout_im <= 0;
                    dout_valid <= 0;
                    // reset trigger
                    send_ts <= 0;
                end
            end
        end
    end
    assign start_sts = send_ts && ts_counter < 161 ? 1:0;
    assign start_lts = send_ts && ts_counter > 159 && ts_counter < 321 ? 1:0;
    assign ts_re = send_ts && ts_counter <= 160 ? sts_re : 
                   send_ts && ts_counter == 161 ? sts_re + lts_re :
                   send_ts && ts_counter <= 321 ? lts_re : 0;
    assign ts_im = send_ts && ts_counter <= 160 ? sts_im : 
                   send_ts && ts_counter == 161 ? sts_im + lts_im :
                   send_ts && ts_counter <= 321 ? lts_im : 0;
    assign ts_valid = sts_valid | lts_valid;
endmodule
