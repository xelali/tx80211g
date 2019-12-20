
`timescale 1 ns / 1 ps

	module Tx80211_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface CTRL_AXI
		parameter integer C_CTRL_AXI_DATA_WIDTH	= 32,
		parameter integer C_CTRL_AXI_ADDR_WIDTH	= 4,

		// Parameters of Axi Slave Bus Interface DATA_AXIS
		parameter integer C_DATA_AXIS_TDATA_WIDTH	= 64
	)
	(
		// Users to add ports here
		output wire [15:0] tx_data_re,
		output wire [15:0] tx_data_im,
		output wire tx_data_valid,
		output wire tx_data_clk,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface CTRL_AXI
		input wire  ctrl_axi_aclk,
		input wire  ctrl_axi_aresetn,
		input wire [C_CTRL_AXI_ADDR_WIDTH-1 : 0] ctrl_axi_awaddr,
		input wire [2 : 0] ctrl_axi_awprot,
		input wire  ctrl_axi_awvalid,
		output wire  ctrl_axi_awready,
		input wire [C_CTRL_AXI_DATA_WIDTH-1 : 0] ctrl_axi_wdata,
		input wire [(C_CTRL_AXI_DATA_WIDTH/8)-1 : 0] ctrl_axi_wstrb,
		input wire  ctrl_axi_wvalid,
		output wire  ctrl_axi_wready,
		output wire [1 : 0] ctrl_axi_bresp,
		output wire  ctrl_axi_bvalid,
		input wire  ctrl_axi_bready,
		input wire [C_CTRL_AXI_ADDR_WIDTH-1 : 0] ctrl_axi_araddr,
		input wire [2 : 0] ctrl_axi_arprot,
		input wire  ctrl_axi_arvalid,
		output wire  ctrl_axi_arready,
		output wire [C_CTRL_AXI_DATA_WIDTH-1 : 0] ctrl_axi_rdata,
		output wire [1 : 0] ctrl_axi_rresp,
		output wire  ctrl_axi_rvalid,
		input wire  ctrl_axi_rready,

		// Ports of Axi Slave Bus Interface DATA_AXIS
		input wire  data_axis_aclk,
		input wire  data_axis_aresetn,
		output wire  data_axis_tready,
		input wire [C_DATA_AXIS_TDATA_WIDTH-1 : 0] data_axis_tdata,
		input wire  data_axis_tlast,
		input wire  data_axis_tvalid,

		//User
		input wire clk,
		input wire rst_n
	);

// Instantiation of Axi Bus Interface CTRL_AXI
	wire [31:0] s_config_tdata;
	wire open_fire;
	wire busy;
	Tx80211_v1_0_CTRL_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_CTRL_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_CTRL_AXI_ADDR_WIDTH)
	) Tx80211_v1_0_CTRL_AXI_inst (
		.S_AXI_ACLK(ctrl_axi_aclk),
		.S_AXI_ARESETN(ctrl_axi_aresetn),
		.S_AXI_AWADDR(ctrl_axi_awaddr),
		.S_AXI_AWPROT(ctrl_axi_awprot),
		.S_AXI_AWVALID(ctrl_axi_awvalid),
		.S_AXI_AWREADY(ctrl_axi_awready),
		.S_AXI_WDATA(ctrl_axi_wdata),
		.S_AXI_WSTRB(ctrl_axi_wstrb),
		.S_AXI_WVALID(ctrl_axi_wvalid),
		.S_AXI_WREADY(ctrl_axi_wready),
		.S_AXI_BRESP(ctrl_axi_bresp),
		.S_AXI_BVALID(ctrl_axi_bvalid),
		.S_AXI_BREADY(ctrl_axi_bready),
		.S_AXI_ARADDR(ctrl_axi_araddr),
		.S_AXI_ARPROT(ctrl_axi_arprot),
		.S_AXI_ARVALID(ctrl_axi_arvalid),
		.S_AXI_ARREADY(ctrl_axi_arready),
		.S_AXI_RDATA(ctrl_axi_rdata),
		.S_AXI_RRESP(ctrl_axi_rresp),
		.S_AXI_RVALID(ctrl_axi_rvalid),
		.S_AXI_RREADY(ctrl_axi_rready),
		//User 
		.busy(busy),
		.open_fire(open_fire),
		.s_config_tdata(s_config_tdata)
	);

// Instantiation of Axi Bus Interface DATA_AXIS
	wire fifo_write_clk;
	wire fifo_write_en;
	wire [7:0] fifo_din;
	wire fifo_full;

	Tx80211_v1_0_DATA_AXIS # ( 
		.C_S_AXIS_TDATA_WIDTH(C_DATA_AXIS_TDATA_WIDTH)
	) Tx80211_v1_0_DATA_AXIS_inst (
		.S_AXIS_ACLK(data_axis_aclk),
		.S_AXIS_ARESETN(data_axis_aresetn),
		.S_AXIS_TREADY(data_axis_tready),
		.S_AXIS_TDATA(data_axis_tdata),
		.S_AXIS_TLAST(data_axis_tlast),
		.S_AXIS_TVALID(data_axis_tvalid),
		.fifo_din(fifo_din),
		.fifo_full(fifo_full),
		.fifo_write_clk(fifo_write_clk),
		.fifo_write_en(fifo_write_en)
	);

	// Add user logic here
	wire [7:0] tx_data_re_8;
	wire [7:0] tx_data_im_8;
    transmitter  u_transmitter (
    .rst_n                   (rst_n),
    .clk                     (clk),
    .fifo_wr_clk             (fifo_write_clk),
    .fifo_din                (fifo_din         [7:0]),
    .fifo_wr_en              (fifo_write_en),
    .s_config_tdata          (s_config_tdata   [31:0]),
    .s_config_tvalid         (s_config_tdata   [24]),
    .tx_now                  (open_fire),
    
    .fifo_full               (fifo_full),
    .busy                    (busy),
    .dout_clk                (tx_data_clk),
    .tx_data_re              (tx_data_re_8),
    .tx_data_im              (tx_data_im_8),
    .tx_data_valid           (tx_data_valid)
    );
	// User logic ends
	assign tx_data_re = {tx_data_re_8 , 8'd0};
	assign tx_data_im = {tx_data_im_8 , 8'd0};
endmodule
