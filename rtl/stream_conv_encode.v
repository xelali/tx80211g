`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2019/10/21 22:35:33
// Design Name:
// Module Name: stream_conv_encode
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


module stream_conv_encode (input rst_n,
                          input clk,
                          input [3:0] sig_rate,
                          input clear,     // frame start: encoder state -> 0
                          input din,
                          input en,
                          output reg dout,
                          output reg [8:0] index,
                          output reg data_valid);
    // en accepts one bit every two clocks; pending emits the second coded bit.
    reg [5:0] shift_reg;
    reg second_bit;
    reg pending;
    reg [1:0] puncture_phase;
    reg [8:0] index_temp;
    reg [8:0] ncbps;
    wire rate_34 = sig_rate == 4'b1111 || sig_rate == 4'b0111 ||
                   sig_rate == 4'b1011 || sig_rate == 4'b0011;
    wire rate_23 = sig_rate == 4'b0001;
    always @(*) begin
        case (sig_rate)
            4'b1101, 4'b1111: ncbps = 48;
            4'b0101, 4'b0111: ncbps = 96;
            4'b1001, 4'b1011: ncbps = 192;
            default: ncbps = 288;
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 0;
            pending <= 0;
            second_bit <= 0;
            puncture_phase <= 0;
            index_temp <= 0;
            index <= 0;
            dout <= 0;
            data_valid <= 0;
        end
        else if (clear) begin
            shift_reg <= 0;
            pending <= 0;
            puncture_phase <= 0;
            index_temp <= 0;
            data_valid <= 0;
        end
        else begin
            data_valid <= 0;
            if (en) begin
                shift_reg <= {shift_reg[4:0], din};
                second_bit <= shift_reg[5] ^ shift_reg[2] ^ shift_reg[1] ^ shift_reg[0] ^ din;
                pending <= 1;
                if (!(rate_34 && puncture_phase == 2)) begin
                    dout <= shift_reg[5] ^ shift_reg[4] ^ shift_reg[2] ^ shift_reg[1] ^ din;
                    data_valid <= 1;
                    index <= index_temp;
                    if (index_temp == ncbps - 1) index_temp <= 0;
                    else index_temp <= index_temp + 1;
                end
            end
            else if (pending) begin
                pending <= 0;
                if ((!rate_34 && !rate_23) || puncture_phase == 0 ||
                    (rate_34 && puncture_phase == 2)) begin
                    dout <= second_bit;
                    data_valid <= 1;
                    index <= index_temp;
                    if (index_temp == ncbps - 1) index_temp <= 0;
                    else index_temp <= index_temp + 1;
                end
                if ((rate_34 && puncture_phase == 2) ||
                    (rate_23 && puncture_phase == 1) || (!rate_34 && !rate_23))
                    puncture_phase <= 0;
                else puncture_phase <= puncture_phase + 1;
            end
        end
    end

    // synthesis translate_off
    always @(posedge clk) if (rst_n === 1'b1 && !clear && en === 1'b1 && pending === 1'b1)
        $fatal(1, "stream_conv_encode: input bit arrived while a coded bit was pending");
    // synthesis translate_on
endmodule
