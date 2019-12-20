`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2019/10/21 19:00:26
// Design Name:
// Module Name: clock_gen
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


module clock_gen(
                 input rst_n,
                 input clk_in,
                 output clk_cb,
                 output clk_din,
                 output clk_sys,
                 output main_locked);
    /*
    Main Clock
    clk_20m for SIGNAL and output, clk_120m for DATA
    */

    wire clk_20m, clk_120m;
    wire locked_clk_main;
    clk_main CLK_MAIN
    (
        // Clock out ports
        .clk_20m(clk_20m),     // output clk_20m
        .clk_120m(clk_120m),     // output clk_120m
        // Status and control signals
        .reset(~rst_n), // input reset
        .locked(locked_clk_main),       // output locked
        // Clock in ports
        .clk_in1(clk_in)      // input clk_in1
    );
    
    assign clk_sys = clk_20m;
    assign main_locked = locked_clk_main;
    
    // clk_din and clk_cb are the same 120 MHz clock; valid enables set the rate.
    assign clk_din = clk_120m;
    assign clk_cb = clk_120m;
endmodule
