
`timescale 1 ns / 1 ps

	module Tx80211_v1_0_DATA_AXIS #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// AXI4Stream sink: Data Width
		parameter integer C_S_AXIS_TDATA_WIDTH	= 64
	)
	(
		// Users to add ports here
		output wire fifo_write_clk,
		output wire fifo_write_en,
		output wire [7:0] fifo_din,
		input wire fifo_full,
		// User ports ends
		// Do not modify the ports beyond this line

		// AXI4Stream sink: Clock
		input wire  S_AXIS_ACLK,
		// AXI4Stream sink: Reset
		input wire  S_AXIS_ARESETN,
		// Ready to accept data in
		output wire  S_AXIS_TREADY,
		// Data in
		input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
		// Indicates boundary of last packet
		input wire  S_AXIS_TLAST,
		// Data is in valid
		input wire  S_AXIS_TVALID
	);
	assign fifo_write_clk = S_AXIS_ACLK;
	assign fifo_write_en = S_AXIS_TVALID;
	assign fifo_din = S_AXIS_TDATA[7:0];
	assign S_AXIS_TREADY = ~fifo_full;
	// Add user logic here

	// User logic ends

	endmodule
