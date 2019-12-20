`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/02 12:05:35
// Design Name: 
// Module Name: pilot_scrambler
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


module pilot_scrambler(
    input clk,
    input advance,      // one pulse per OFDM symbol, after its pilots are written
    input rst_n,
    input clear,        // frame start (sync): reload all-ones state (p_0 is for SIGNAL)
    output dout         // current polarity: 0 -> p_n = +1, 1 -> p_n = -1
    );
    // Pilot polarity p_n (IEEE 802.11 17.3.5.10): scrambler x^7+x^4+1 seeded all-ones.
    // It must advance exactly once per OFDM symbol and stay stable while the four
    // pilots of that symbol are written.
    reg [7:1] scrambler;
    assign dout = scrambler[7] ^ scrambler[4];
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n)
            scrambler <= 7'b1111111;
        else if (clear)
            scrambler <= 7'b1111111;
        else if (advance)
            scrambler <= {scrambler[6:1], scrambler[7] ^ scrambler[4]};
    end
endmodule
