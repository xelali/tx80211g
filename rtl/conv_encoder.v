`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2019/10/21 22:35:33
// Design Name:
// Module Name: conv_encoder
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


module conv_encoder(input rst_n,
                    input clk,
                    input clear,
                    input din,
                    input en,
                    output reg [1:0] dout,
                    output reg data_valid);
    reg [6:1] shift_reg;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= 6'd0;
            dout       <= 2'd0;
            data_valid <= 0;
        end
        else if (clear) begin
            shift_reg  <= 6'd0;
            data_valid <= 0;
        end
        else begin
            if (en) begin
                dout[0]    <= shift_reg[6] + shift_reg[5] + shift_reg[3] + shift_reg[2] + din;
                dout[1]    <= shift_reg[6] + shift_reg[3] + shift_reg[2] + shift_reg[1] + din;
                data_valid <= 1;
                shift_reg  <= {shift_reg[5:1], din};
            end
            else
                data_valid <= 0;
        end
    end
endmodule
