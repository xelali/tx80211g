`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/10/26 09:05:18
// Design Name: 
// Module Name: stream_interleaver
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


module stream_interleaver(
    input rst_n,
    input clear,
    input clk,
    input din,
    input [8:0] din_index,
    input en,
    input [3:0] sig_rate,
    output reg dout,
    output reg data_valid
    );
    /* 
    Interleaver Stage 1
    */
    reg din_buf;
    reg write_en_1;
    reg write_addr_sel_1;
    reg [9:0] write_addr_1;
    reg read_en_1;
    reg [9:0] read_addr_1;
    reg itv_1_data_valid;
    wire dout_1;
    blk_mem_interleaver BLK_MEM_INTER_1 (
        .clka(clk),    // input wire clka
        .ena(write_en_1),      // input wire ena
        .wea(write_en_1),      // input wire [0 : 0] wea
        .addra(write_addr_1),  // input wire [9 : 0] addra
        .dina(din_buf),    // input wire [0 : 0] dina

        .clkb(clk),    // input wire clkb
        .enb(read_en_1),      // input wire enb
        .addrb(read_addr_1),  // input wire [9 : 0] addrb
        .doutb(dout_1)  // output wire [0 : 0] doutb
    );
    
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            din_buf <= 0;
            write_en_1 <= 0;
            write_addr_sel_1 <= 0;
            write_addr_1 <= 0;
            read_addr_1 <= 0;
            read_en_1 <= 0;
            itv_1_data_valid <= 0;
        end
        else if (clear) begin
            din_buf <= 0;
            write_en_1 <= 0;
            write_addr_sel_1 <= 0;
            write_addr_1 <= 0;
            read_addr_1 <= 0;
            read_en_1 <= 0;
            itv_1_data_valid <= 0;
        end
        else begin
            /*
            write address gen
            */
            if (en) begin
                din_buf <= din;
                write_en_1 <= 1;
                case (sig_rate)
                    // BPSK 48
                    4'b1101, 4'b1111: begin
                        if (!write_addr_sel_1)
                            write_addr_1 <= din_index[3:0] + (din_index[3:0] << 1) + din_index[5:4];
                        else
                            write_addr_1 <= din_index[3:0] + (din_index[3:0] << 1) + din_index[5:4] + 48;
                        if (din_index == 47) begin
                            write_addr_sel_1 <= ~write_addr_sel_1;
                            read_en_1 <= 1;
                        end
                    end
                    // QPSK 96
                    4'b0101, 4'b0111: begin
                        if (!write_addr_sel_1)
                            write_addr_1 <= (din_index[3:0] << 2) + (din_index[3:0] << 1) + din_index[6:4];
                        else
                            write_addr_1 <= (din_index[3:0] << 2) + (din_index[3:0] << 1) + din_index[6:4] + 96;
                        if (din_index == 95) begin
                            write_addr_sel_1 <= ~write_addr_sel_1;
                            read_en_1 <= 1;
                        end
                    end
                    // 16QAM 192
                    4'b1001, 4'b1011: begin
                        if (!write_addr_sel_1)
                            write_addr_1 <= (din_index[3:0] << 3) + (din_index[3:0] << 2) + din_index[7:4];
                        else
                            write_addr_1 <= (din_index[3:0] << 3) + (din_index[3:0] << 2) + din_index[7:4] + 192;
                        if (din_index == 191) begin
                            write_addr_sel_1 <= ~write_addr_sel_1;
                            read_en_1 <= 1;
                        end
                    end
                    // 64QAM 288
                    4'b0001, 4'b0011: begin
                        if (!write_addr_sel_1)
                            write_addr_1 <= (din_index[3:0] << 4) + (din_index[3:0] << 1) + din_index[8:4];
                        else
                            write_addr_1 <= (din_index[3:0] << 4) + (din_index[3:0] << 1) + din_index[8:4] + 288;
                        if (din_index == 287) begin
                            write_addr_sel_1 <= ~write_addr_sel_1;
                            read_en_1 <= 1;
                        end
                    end
                    // Invalid SIG_RATE input!
                    default: begin
                        read_en_1 <= 0;
                    end
                endcase
                
            end
            // din en not valid
            else begin
                write_addr_1 <= 0;
                write_en_1 <= 0;
                din_buf <= 0;
            end
            // always excuted @ posedge of clk
            /*
            Counter Part
            */
            if (read_en_1) begin
                case (sig_rate)
                    // BPSK 48
                    4'b1101, 4'b1111: begin
                        if (read_addr_1 == 95)
                            read_addr_1 <= 0;
                        else
                            read_addr_1 <= read_addr_1 + 1;
                    end
                    // QPSK 96
                    4'b0101, 4'b0111: begin
                        if (read_addr_1 == 191)
                            read_addr_1 <= 0;
                        else
                            read_addr_1 <= read_addr_1 + 1;
                    end
                    // 16QAM 192
                    4'b1001, 4'b1011: begin
                        if (read_addr_1 == 383)
                            read_addr_1 <= 0;
                        else
                            read_addr_1 <= read_addr_1 + 1;
                    end
                    // 64QAM 288
                    4'b0001, 4'b0011: begin
                        if (read_addr_1 == 575)
                            read_addr_1 <= 0;
                        else
                            read_addr_1 <= read_addr_1 + 1;
                    end
                    // Invalid SIG_RATE input!
                    default: begin
                        read_addr_1 <= 0;
                    end
                endcase
            end

            if (read_en_1) begin
                itv_1_data_valid <= 1;
                //dout <= dout_1;
            end
            else begin
                itv_1_data_valid <= 0;
                //dout <= dout_1;
            end
                

            case (sig_rate)
                // BPSK 48
                4'b1101, 4'b1111: begin
                    if (read_addr_1 == 47 || read_addr_1 == 95)
                        read_en_1 <= 0;
                end
                // QPSK 96
                4'b0101, 4'b0111: begin
                    if (read_addr_1 == 95 || read_addr_1 == 191)
                        read_en_1 <= 0;
                end
                // 16QAM 192
                4'b1001, 4'b1011: begin
                    if (read_addr_1 == 191 || read_addr_1 == 383)
                        read_en_1 <= 0;
                end
                // 64QAM 288
                4'b0001, 4'b0011: begin
                    if (read_addr_1 == 287 || read_addr_1 == 575)
                        read_en_1 <= 0;
                end
                // Invalid SIG_RATE input!
                default: begin
                    read_en_1 <= 0;
                end
            endcase
        end
    end

    /* 
    Interleaver Stage 2
    */
    reg din_buf_2;
    reg [5:0] din_index_2; // gen by module (not a input)
    reg write_en_2;
    reg [1:0] write_addr_pattern_2;
    reg [1:0] ct_pattern;
    reg [5:0] write_addr_2;
    reg read_en_2;
    reg [5:0] read_addr_2;
    reg itv_2_data_valid;
    wire dout_2;
    blk_mem_itv_2 BLK_MEM_INTER_2 (
        .clka(clk),    // input wire clka
        .ena(write_en_2),      // input wire ena
        .wea(write_en_2),      // input wire [0 : 0] wea
        .addra(write_addr_2),  // input wire [5 : 0] addra
        .dina(din_buf_2),    // input wire [0 : 0] dina

        .clkb(clk),    // input wire clkb
        .enb(read_en_2),      // input wire enb
        
        .addrb(read_addr_2),  // input wire [5 : 0] addrb
        .doutb(dout_2)  // output wire [0 : 0] doutb
    );
    always @ (posedge clk or negedge rst_n) begin
        // reset
        if (!rst_n) begin
            din_buf_2 <= 0;
            din_index_2 <= 0;
            write_en_2 <= 0;
            write_addr_pattern_2 <= 0;
            ct_pattern <= 0; // use for qam16 itv
            write_addr_2 <= 0;
            read_addr_2 <= 0;
            read_en_2 <= 0;
            itv_2_data_valid <= 0;
        end
        else if (clear) begin
            din_buf_2 <= 0;
            din_index_2 <= 0;
            write_en_2 <= 0;
            write_addr_pattern_2 <= 0;
            ct_pattern <= 0; // use for qam16 itv
            write_addr_2 <= 0;
            read_addr_2 <= 0;
            read_en_2 <= 0;
            itv_2_data_valid <= 0;
        end
        // not reset @ clk
        else begin
            if (itv_1_data_valid) begin
                din_buf_2 <= dout_1;
                // counter ce:itv_1_data_valid

                write_en_2 <= 1;
                case (sig_rate)
                    // BPSK QPSK no need for 2nd itv
                    4'b1101, 4'b1111, 4'b0101, 4'b0111: begin
                        write_addr_2 <= din_index_2;
                        if (din_index_2 == 11 || din_index_2 == 23) begin
                            read_en_2 <= 1;
                        end
                        if (din_index_2 < 23)
                            din_index_2 <= din_index_2 + 1;
                        else
                            din_index_2 <= 0;
                    end
                    // 16QAM 192 12/12 pattern 12 21
                    4'b1001, 4'b1011: begin
                        case (write_addr_pattern_2)
                            2'b00: begin
                                write_addr_2 <= din_index_2;
                                
                                if (din_index_2 == 11) begin
                                    write_addr_pattern_2 <= 2'b01;
                                    read_en_2 <= 1;
                                end
                            end
                            2'b01: begin
                                // inverse last bit of addr
                                write_addr_2[5:1] <= {1'b0, din_index_2[4:1]};
                                write_addr_2[0] <= ~din_index_2[0];

                                if (din_index_2 == 23) begin
                                    write_addr_pattern_2 <= 2'b00;
                                    read_en_2 <= 1;
                                end
                            end
                            default: 
                                write_addr_pattern_2 <= 0;
                        endcase
                        if (din_index_2 < 23)
                            din_index_2 <= din_index_2 + 1;
                        else
                            din_index_2 <= 0;
                    end
                    // 64QAM 288 18/18/18 pattern 123 312 231
                    4'b0001, 4'b0011: begin
                        case (write_addr_pattern_2)
                            2'b00: begin
                                write_addr_2 <= din_index_2;
                                if (din_index_2 == 17) begin
                                    write_addr_pattern_2 <= 2'b01;
                                    read_en_2 <= 1;
                                end
                            end
                            2'b01: begin
                                case (ct_pattern)
                                    2'b00:
                                        write_addr_2 <= din_index_2 + 2;
                                    2'b01:
                                        write_addr_2 <= din_index_2 - 1;
                                    2'b10:
                                        write_addr_2 <= din_index_2 - 1;
                                    default: 
                                        ct_pattern <= 0;
                                endcase
                                if (din_index_2 == 35) begin
                                    write_addr_pattern_2 <= 2'b10;
                                    read_en_2 <= 1;
                                end
                            end
                            2'b10: begin
                                case (ct_pattern)
                                    2'b00:
                                        write_addr_2 <= din_index_2 + 1;
                                    2'b01:
                                        write_addr_2 <= din_index_2 + 1;
                                    2'b10:
                                        write_addr_2 <= din_index_2 - 2;
                                    default: 
                                        ct_pattern <= 0;
                                endcase
                                if (din_index_2 == 53) begin
                                    write_addr_pattern_2 <= 2'b00;
                                    read_en_2 <= 1;
                                end
                            end
                            default: 
                                write_addr_pattern_2 <= 0;
                        endcase
                        // inc pattern
                        if (ct_pattern < 2'b10)
                            ct_pattern <= ct_pattern + 1;
                        else
                            ct_pattern <= 0;
                        // inc index
                        if (din_index_2 < 53)
                            din_index_2 <= din_index_2 + 1;
                        else
                            din_index_2 <= 0;
                    end
                    // Invalid SIG_RATE input!
                    default: begin
                        read_en_2 <= 0;
                    end
                endcase
            end
            // itv_1 data not valid
            else begin
                write_addr_2 <= 0;
                write_en_2 <= 0;
                din_buf_2 <= 0;
                din_index_2 <= 0;
                write_addr_pattern_2 <= 0; // for qam64 288/54 = 4.3333
            end
            // always excuted @ posedge of clk
            /*
            Counter Part
            */
            if (read_en_2) begin
                case (sig_rate)
                    // BPSK QPSk 16QAM
                    4'b1101, 4'b1111, 4'b0101, 4'b0111, 4'b1001, 4'b1011: begin
                        if (read_addr_2 == 23)
                            read_addr_2 <= 0;
                        else
                            read_addr_2 <= read_addr_2 + 1;
                    end
                    // 64QAM 288
                    4'b0001, 4'b0011: begin
                        if (read_addr_2 == 53)
                            read_addr_2 <= 0;
                        else
                            read_addr_2 <= read_addr_2 + 1;
                    end
                    // Invalid SIG_RATE input!
                    default: begin
                        read_addr_2 <= 0;
                    end
                endcase
            end

            if (read_en_2) begin
                itv_2_data_valid <= 1;
            end
            else begin
                itv_2_data_valid <= 0;
            end

            case (sig_rate)
                // BPSK QPSK, 16QAM
                4'b1101, 4'b1111, 4'b0101, 4'b0111,  4'b1001, 4'b1011: begin
                    if (read_addr_2 == 23 && !itv_1_data_valid) begin
                        read_en_2 <= 0;
                        read_addr_2 <= 0;
                    end
                end
                // 64QAM 288
                4'b0001, 4'b0011: begin
                    if ((read_addr_2 == 53 || read_addr_2 == 17) && !itv_1_data_valid) begin
                        read_en_2 <= 0;
                        read_addr_2 <= 0;
                    end
                end
                // Invalid SIG_RATE input!
                default: begin
                    read_en_2 <= 0;
                end
            endcase
        end
    end
    /*
    Data output
    */
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 0;
            data_valid <= 0;
        end
        else if (clear) begin
            dout <= 0;
            data_valid <= 0;
        end
        else begin
            data_valid <= itv_2_data_valid;
            
            if (itv_2_data_valid) begin
                dout <= dout_2;
            end
            else begin
                dout <= 0;
            end
        end
    end
endmodule
