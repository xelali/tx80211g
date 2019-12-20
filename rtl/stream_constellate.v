`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/10/22 19:22:35
// Design Name: 
// Module Name: stream_constellate
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


module stream_constellate(
    input rst_n,
    input clear,
    input clk,
    input din,
    input en,
    input [3:0] sig_rate,
    output reg [7:0] re,
    output reg [7:0] im,
    output reg [5:0] index,
    output reg data_valid
    );

    // serial -> parallel
    reg [7:0] pre_map_buffer;
    reg buf_data_valid;
    reg [2:0] ct_s2p;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pre_map_buffer <= 0;
            buf_data_valid <= 0;
            ct_s2p <= 0;
        end
        else if (clear) begin
            pre_map_buffer <= 0;
            buf_data_valid <= 0;
            ct_s2p <= 0;
        end
        else begin
            if (en) begin
                case (sig_rate)
                    // BPSK
                    4'b1101, 4'b1111: begin
                        pre_map_buffer[0] <= din;
                        buf_data_valid <= 1;
                    end
                    // QPSK
                    4'b0101, 4'b0111: begin
                        if (ct_s2p < 1) begin
                            pre_map_buffer[ct_s2p] <= din;
                            buf_data_valid <= 0; 
                            ct_s2p <= ct_s2p + 1;
                        end
                        else begin
                            pre_map_buffer[ct_s2p] <= din;
                            buf_data_valid <= 1;
                            ct_s2p <= 0;
                        end
                    end
                    // 16QAM
                    4'b1001, 4'b1011: begin
                        if (ct_s2p < 3) begin
                            pre_map_buffer[ct_s2p] <= din;
                            buf_data_valid <= 0;
                            ct_s2p <= ct_s2p + 1;
                        end
                        else begin
                            pre_map_buffer[ct_s2p] <= din;
                            buf_data_valid <= 1;
                            ct_s2p <= 0;
                        end
                    end
                    // 64QAM
                    4'b0001, 4'b0011: begin
                        if (ct_s2p < 5) begin
                            pre_map_buffer[ct_s2p] <= din;
                            buf_data_valid <= 0;
                            ct_s2p <= ct_s2p + 1;
                        end
                        else begin
                            pre_map_buffer[ct_s2p] <= din;
                            buf_data_valid <= 1;
                            ct_s2p <= 0;
                        end
                    end
                    // Invalid SIG_RATE input!
                    default: begin
                        pre_map_buffer <= 0;
                        buf_data_valid <= 0;
                        ct_s2p <= 0;
                    end
                endcase
            end
            else begin
                pre_map_buffer <= 0;
                buf_data_valid <= 0;
                ct_s2p <= 0;
            end
        end
    end

    // constellation map
    reg map_valid;
    reg [7:0] re_temp;
    reg [7:0] im_temp;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            re_temp <= 0;
            im_temp <= 0;
            map_valid <= 0;
        end
        else if (clear) begin
            re_temp <= 0;
            im_temp <= 0;
            map_valid <= 0;
        end
        else begin
            if (buf_data_valid) begin
                case (sig_rate)
                    // BPSK
                    4'b1101, 4'b1111: begin
                        // Scaler=1
                        case (pre_map_buffer[0])
                            1'b0: re_temp <= 8'b11000000; // -1
                            1'b1: re_temp <= 8'b01000000; // 1
                        endcase
                        im_temp <= 0;
                        map_valid <= 1;
                    end
                    // QPSK
                    4'b0101, 4'b0111: begin
                        // Scaler=sqrt(2)
                        case (pre_map_buffer[0])
                            1'b0: re_temp <= 8'b11010011; // -1
                            1'b1: re_temp <= 8'b00101101; // 1
                        endcase
                        case (pre_map_buffer[1])
                            1'b0: im_temp <= 8'b11010011; // -1
                            1'b1: im_temp <= 8'b00101101; // 1
                        endcase
                        map_valid <= 1;
                    end
                    // 16QAM
                    4'b1001, 4'b1011: begin
                        // Scaler=sqrt(10)
                        case (pre_map_buffer[1:0])
                            2'b00: re_temp <= 8'b11000011; // -3
                            2'b10: re_temp <= 8'b11101100; // -1
                            2'b11: re_temp <= 8'b00010100; // 1
                            2'b01: re_temp <= 8'b00111101; // 3
                        endcase
                        case (pre_map_buffer[3:2])
                            2'b00: im_temp <= 8'b11000011; // -3
                            2'b10: im_temp <= 8'b11101100; // -1
                            2'b11: im_temp <= 8'b00010100; // 1
                            2'b01: im_temp <= 8'b00111101; // 3
                        endcase
                        map_valid <= 1;
                    end
                    // 64QAM
                    4'b0001, 4'b0011: begin
                        // Scaler=sqrt(42)
                        case ({pre_map_buffer[0], pre_map_buffer[1], pre_map_buffer[2]})
                            3'b000: re_temp <= 8'b10111011; // -7
                            3'b001: re_temp <= 8'b11001111; // -5
                            3'b011: re_temp <= 8'b11100010; // -3
                            3'b010: re_temp <= 8'b11110110; // -1
                            3'b110: re_temp <= 8'b00001010; // 1
                            3'b111: re_temp <= 8'b00011110; // 3
                            3'b101: re_temp <= 8'b00110001; // 5
                            3'b100: re_temp <= 8'b01000101; // 7
                        endcase
                        case ({pre_map_buffer[3], pre_map_buffer[4], pre_map_buffer[5]})
                            3'b000: im_temp <= 8'b10111011; // -7
                            3'b001: im_temp <= 8'b11001111; // -5
                            3'b011: im_temp <= 8'b11100010; // -3
                            3'b010: im_temp <= 8'b11110110; // -1
                            3'b110: im_temp <= 8'b00001010; // 1
                            3'b111: im_temp <= 8'b00011110; // 3
                            3'b101: im_temp <= 8'b00110001; // 5
                            3'b100: im_temp <= 8'b01000101; // 7
                        endcase
                        map_valid <= 1;
                    end
                    // Invalid SIG_RATE input!
                    default: begin
                        re_temp <= 0;
                        im_temp <= 0;
                        map_valid <= 0;
                    end
                endcase
            end
            else begin
                map_valid <= 0;
                re_temp <= 0;
                im_temp <= 0;
            end
        end
    end

    /*
    Output Stage 
    */
    reg [5:0] index_tmp;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 0;
            index_tmp <= 0;
            re <= 0;
            im <= 0;
            data_valid <= 0;
        end
        else if (clear) begin
            index <= 0;
            index_tmp <= 0;
            re <= 0;
            im <= 0;
            data_valid <= 0;
        end
        else begin
            data_valid <= map_valid;
            if (map_valid) begin
                re <= re_temp;
                im <= im_temp;
                index <= index_tmp;
                if (index_tmp == 47) index_tmp <= 0;
                else index_tmp <= index_tmp + 1;
            end
        end
    end
endmodule
