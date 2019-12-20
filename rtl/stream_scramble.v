`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/10/21 21:29:49
// Design Name: 
// Module Name: stream_scramble
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


module stream_scramble(
    input rst_n,
    input clk,
    input din,
    input en,
    input tail,         // tail bits are replaced by zeros after scrambling (17.3.5.3)
    input [7:1] seed,
    input load_seed,
    output reg dout,
    output reg data_valid
    );

    reg [7:1] scrambler;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 0;
            data_valid <= 0;
            scrambler <= 0;
        end
        else begin
            if (load_seed)
                scrambler <= seed;
            else begin
                if (en) begin
                    dout  <= tail ? 1'b0 : (din ^ scrambler[7] ^ scrambler[4]);
                    data_valid <= 1;
                    scrambler <= {scrambler[6:1], scrambler[7] + scrambler[4]};
                end
                else begin
                    dout <= 0;
                    data_valid <= 0;
                end
            end
        end
    end
endmodule
