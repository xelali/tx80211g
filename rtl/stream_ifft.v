`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/04 16:51:06
// Design Name: 
// Module Name: stream_ifft
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


module stream_ifft(
    input rst_n,
    input clk_din,
    input [7:0] din_re,
    input [7:0] din_im,
    input din_valid,
    output [7:0] dout_re,
    output [7:0] dout_im,
    output [5:0] dout_index,
    output dout_valid
    );
    // config
    reg [15:0] s_axis_config_tdata;
    reg s_axis_config_tvalid; // input
    wire s_axis_config_tready; // output
    // input data
    wire [31:0] s_axis_data_tdata;
    reg s_axis_data_tvalid; // input
    wire s_axis_data_tready; // output
    wire s_axis_data_tlast;  // input
    // output data
    wire [31:0] m_axis_data_tdata;
    wire [15:0] m_axis_data_tuser;
    wire m_axis_data_tvalid; // output
    wire m_axis_data_tready; // input
    wire m_axis_data_tlast;  // output
    // Overflow AXI (not used)
    wire [7:0] m_axis_status_tdata;
    wire m_axis_status_tvalid;
    wire m_axis_status_tready;
    // Events
    wire event_frame_started;
    wire event_tlast_unexpected;
    wire event_tlast_missing;
    wire event_fft_overflow;
    wire event_status_channel_halt;
    wire event_data_in_channel_halt;
    wire event_data_out_channel_halt;
    // FFT core
    xfft_0 IFFT (
        .aclk(clk_din),                                                // input wire aclk
        .aresetn(rst_n),                                          // input wire aresetn
        
        .s_axis_config_tdata(s_axis_config_tdata),                  // input wire [15 : 0] s_axis_config_tdata
        .s_axis_config_tvalid(s_axis_config_tvalid),                // input wire s_axis_config_tvalid
        .s_axis_config_tready(s_axis_config_tready),                // output wire s_axis_config_tready
        
        .s_axis_data_tdata(s_axis_data_tdata),                      // input wire [31 : 0] s_axis_data_tdata
        .s_axis_data_tvalid(s_axis_data_tvalid),                    // input wire s_axis_data_tvalid
        .s_axis_data_tready(s_axis_data_tready),                    // output wire s_axis_data_tready
        .s_axis_data_tlast(s_axis_data_tlast),                      // input wire s_axis_data_tlast
        
        // Transform result
        .m_axis_data_tdata(m_axis_data_tdata),                      // output wire [31 : 0] m_axis_data_tdata
        // Index output
        .m_axis_data_tuser(m_axis_data_tuser),                      // output wire [15 : 0] m_axis_data_tuser
        .m_axis_data_tvalid(m_axis_data_tvalid),                    // output wire m_axis_data_tvalid
        .m_axis_data_tready(m_axis_data_tready),                    // input wire m_axis_data_tready
        .m_axis_data_tlast(m_axis_data_tlast),                      // output wire m_axis_data_tlast
        
        // Overflow AXI (not used)
        .m_axis_status_tdata(m_axis_status_tdata),                  // output wire [7 : 0] m_axis_status_tdata
        .m_axis_status_tvalid(m_axis_status_tvalid),                // output wire m_axis_status_tvalid
        .m_axis_status_tready(m_axis_status_tready),                // input wire m_axis_status_tready
        
        // Events
        .event_frame_started(event_frame_started),                  // output wire event_frame_started
        .event_tlast_unexpected(event_tlast_unexpected),            // output wire event_tlast_unexpected
        .event_tlast_missing(event_tlast_missing),                  // output wire event_tlast_missing
        .event_fft_overflow(event_fft_overflow),                    // output wire event_fft_overflow
        .event_status_channel_halt(event_status_channel_halt),      // output wire event_status_channel_halt
        .event_data_in_channel_halt(event_data_in_channel_halt),    // output wire event_data_in_channel_halt
        .event_data_out_channel_halt(event_data_out_channel_halt)  // output wire event_data_out_channel_halt
        );
    // for sim
    assign s_axis_data_tlast = 0;
    assign m_axis_status_tready = 1;
    // configuration
    always @(posedge clk_din or negedge rst_n) begin
        if (!rst_n) begin
            s_axis_config_tvalid <= 0;
            s_axis_config_tdata <= {1'b0, 6'b101110, 1'b0, 2'b00, 6'b010000}; // SCALE_SCH=10 11 10 IFFT CP_LEN=16
        end
        else if (s_axis_config_tready) begin
            s_axis_config_tvalid <= 1;
        end
        else begin
            s_axis_config_tvalid <= 0;
        end
    end
    reg [7:0] din_re_buf;
    reg [7:0] din_im_buf;
    wire [15:0] mult_re;
    wire [15:0] mult_im;
    // data buffering
    always @(posedge clk_din or negedge rst_n) begin
        if (!rst_n) begin
            din_re_buf <= 0;
            din_im_buf <= 0;
            s_axis_data_tvalid <= 0;
        end
        else begin
            din_re_buf <= din_re;
            din_im_buf <= din_im;
            s_axis_data_tvalid <= din_valid;
        end 
    end
    // mult_xx = xx * 3 and sign extend
    assign mult_re[2:0]   = 3'b0;
    assign mult_re[10:3]  = din_re_buf[7:0];
    assign mult_re[15:11] = {5{din_re_buf[7]}};
    assign mult_im[2:0]   = 3'b0;
    assign mult_im[10:3]  = din_im_buf[7:0];
    assign mult_im[15:11] = {5{din_im_buf[7]}};
    assign s_axis_data_tdata[31:0] = {mult_im, mult_re};

    //data output
    reg output_en;
    always @(posedge clk_din or negedge rst_n) begin
        if (!rst_n) begin
            output_en <= 0;
        end
        else begin
            output_en <= 1;
        end
    end
    assign m_axis_data_tready = output_en;

    wire [15:0] ifft_res_re;
    wire [15:0] ifft_res_im;
    wire [5:0] kn_index;

    assign kn_index = m_axis_data_tuser[5:0];
    assign dout_index = kn_index;
    assign ifft_res_re = m_axis_data_tdata[15:0];
    assign ifft_res_im = m_axis_data_tdata[31:16];
    // saturate to 8 bit (OFDM peaks can exceed +/-127 at this scaling)
    function [7:0] sat8(input [15:0] v);
        sat8 = ($signed(v) > 127) ? 8'sd127 : ($signed(v) < -128) ? -8'sd128 : v[7:0];
    endfunction
    assign dout_re = sat8(ifft_res_re);
    assign dout_im = sat8(ifft_res_im);
    assign dout_valid = m_axis_data_tvalid;
endmodule
