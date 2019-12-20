`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/01 23:21:12
// Design Name: 
// Module Name: stream_pilot_aboard
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


module stream_pilot_aboard(
    input rst_n,
    input clk,
    input start,
    input din_valid,
    input [7:0] din_re,
    input [7:0] din_im,
    input [5:0] din_index,
    output reg [7:0] dout_re,
    output reg [7:0] dout_im,
    output reg dout_valid
    );
    
    reg [7:0] din_re_buf;
    reg [7:0] din_im_buf;
    reg din_valid_buf;
    reg [5:0] din_index_buf;
    // data input buffering
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            din_re_buf <= 0;
            din_im_buf <= 0;
            din_valid_buf <= 0;
            din_index_buf <= 0;
        end
        else begin
            din_re_buf <= din_re;
            din_im_buf <= din_im;
            din_valid_buf <= din_valid;
            din_index_buf <= din_index;
        end
    end
    // pilot scrambler

    // pilot insertion
    reg [6:0] write_addr;
    reg write_en;
    reg write_addr_sel;
    reg [7:0] ram_din_re;
    reg [7:0] ram_din_im;
    reg pilot_aboard_start;
    wire pilot_polarity;
    reg [1:0] pilot_postion;
    reg [6:0] read_addr;
    reg read_en;
    reg read_valid;
    wire [7:0] ram_dout_re;
    wire [7:0] ram_dout_im;
    
    blk_mem_pilot BLK_MEM_PILOT_RE (
        .clka(clk),    // input wire clka
        .ena(write_en),      // input wire ena
        .wea(write_en),      // input wire [0 : 0] wea
        .addra(write_addr),  // input wire [6 : 0] addra
        .dina(ram_din_re),    // input wire [7 : 0] dina
        
        .clkb(clk),    // input wire clkb
        .enb(read_en),      // input wire enb
        .addrb(read_addr),  // input wire [6 : 0] addrb
        .doutb(ram_dout_re)  // output wire [7 : 0] doutb
        );
    
    blk_mem_pilot BLK_MEM_PILOT_IM (
        .clka(clk),    // input wire clka
        .ena(write_en),      // input wire ena
        .wea(write_en),      // input wire [0 : 0] wea
        .addra(write_addr),  // input wire [6 : 0] addra
        .dina(ram_din_im),    // input wire [7 : 0] dina
        
        .clkb(clk),    // input wire clkb
        .enb(read_en),      // input wire enb
        .addrb(read_addr),  // input wire [6 : 0] addrb
        .doutb(ram_dout_im)  // output wire [7 : 0] doutb
        );
    
    pilot_scrambler PILOT_SCRAMBLER (
        .clk(clk),
        .advance(pilot_aboard_start && pilot_postion == 2'b11),
        .rst_n(rst_n),
        .clear(start),
        .dout(pilot_polarity)
    );

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_addr <= 0;
            write_en <= 0;
            write_addr_sel <= 0;
            ram_din_re <= 0;
            ram_din_im <= 0;
            pilot_aboard_start <= 0;
            pilot_postion <= 0;
            read_addr <= 0;
            read_en <= 0;
            read_valid <= 0;
        end
        else begin
            if (din_valid_buf) begin
                write_addr[6] <= write_addr_sel; // ping-pong buffering
                case (din_index_buf) // iFFT sub-carrier map
                    0,1,2,3,4:
                        write_addr[5:0] <= din_index_buf + 38;
                    5,6,7,8,9,10,11,12,13,14,15,16,17:
                        write_addr[5:0] <= din_index_buf + 39;
                    18,19,20,21,22,23: 
                        write_addr[5:0] <= din_index_buf + 40;
                    24,25,26,27,28,29:
                        write_addr[5:0] <= din_index_buf - 23; 
                    30,31,32,33,34,35,36,37,38,39,40,41,42:
                        write_addr[5:0] <= din_index_buf - 22;
                    43,44,45,46,47 : 
                        write_addr[5:0] <= din_index_buf - 21;
                    default :
                        write_addr[5:0] <= 0;
                endcase
                write_en <= 1;
                ram_din_re <= din_re_buf;
                ram_din_im <= din_im_buf;
                if (din_index_buf == 47)
                    pilot_aboard_start <= 1;
            end
            else if (pilot_aboard_start) begin
                ram_din_im <= 0; // no imagination
                case (pilot_postion)
                    /*
                     1 -1  1  1
                    -1  1 -1 -1
                    */
                    2'b00: begin
                        write_addr[5:0] <= 7;
                        if (!pilot_polarity)
                            ram_din_re <= 8'b01000000;
                        else
                            ram_din_re <= 8'b11000000;
                        pilot_postion <= pilot_postion + 1;
                    end
                    2'b01: begin
                        write_addr[5:0] <= 21;
                        if (!pilot_polarity)
                            ram_din_re <= 8'b11000000;
                        else
                            ram_din_re <= 8'b01000000;
                        pilot_postion <= pilot_postion + 1;
                    end
                    2'b10: begin
                        write_addr[5:0] <= 43;
                        if (!pilot_polarity)
                            ram_din_re <= 8'b01000000;
                        else
                            ram_din_re <= 8'b11000000;
                        pilot_postion <= pilot_postion + 1;
                    end
                    2'b11: begin
                        write_addr[5:0] <= 57;
                        if (!pilot_polarity)
                            ram_din_re <= 8'b01000000;
                        else
                            ram_din_re <= 8'b11000000;
                        pilot_postion <= 0;
                        pilot_aboard_start <= 0;
                        read_en <= 1;
                        write_addr_sel <= ~write_addr_sel;
                    end
                endcase
            end
            else begin // nothing valid
                write_addr[5:0] <= 0;
                write_en <= 0;
                ram_din_re <= 0;
                ram_din_im <= 0;
            end
            // always when not reset
            if (read_addr == 63 || read_addr == 127)
                read_en <= 0;
            
            if (read_en) begin // valid 1 clk delay
                read_valid <= 1;
                read_addr <= read_addr + 1;
            end
            else begin
                read_valid <= 0;
            end
        end
    end

    // data output
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout_re <= 0;
            dout_im <= 0;
            dout_valid <= 0;
        end
        else begin
            if (read_valid) begin
                dout_re <= ram_dout_re;
                dout_im <= ram_dout_im;
                dout_valid <= 1;
            end
            else begin
                dout_re <= 0;
                dout_im <= 0;
                dout_valid <= 0;
            end
        end
    end
endmodule