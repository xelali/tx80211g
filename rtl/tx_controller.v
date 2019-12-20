`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/07 20:40:16
// Design Name: 
// Module Name: tx_controller
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


module tx_controller(
    input global_rst_n,
    input clk_sys,
    // Control
    input start_tx,
    output reg busy,
    // Resets
    output reg reset_phy,
    // Scrambler
    output [7:1] scrambler_seed,
    // Config AXI IO
    input [31:0] s_config_tdata,
    input s_config_tvalid,
    // Tx Control
    output reg load_signal_field,
    input send_data_field,
    // Frame Control
    output reg start_frame,
    output reg start_ts,
    output reg start_sig,
    output reg start_data,
    output reg end_frame
    );

    // Scrambler seed (any non-zero value is legal).
    assign scrambler_seed = 7'b1011101;
    // start_tx comes from the AXI clock domain: synchronise it
    reg [1:0] start_tx_sync;
    always @(posedge clk_sys or negedge global_rst_n) begin
        if (!global_rst_n) start_tx_sync <= 0;
        else start_tx_sync <= {start_tx_sync[0], start_tx};
    end
    // Counters
    reg [8:0] tx_header_counter;

    // FSM
    // TODO:use gray code or use reg output
    localparam INIT0 = 0, INIT1 = 1, INIT2 = 2, INIT3 = 3;
    localparam LOAD_SIG = 4, PHY_RDY = 5, TX_HEADER = 6, TX_DATA = 7, TX_END = 8;
    reg [3:0] state, next_state;
    // control signals
    reg tx_header;
    // state reg
    always @(posedge clk_sys or negedge global_rst_n) begin
        if (!global_rst_n) state <= INIT0;
        else state <= next_state;
    end
    // reset_phy (active low) is the async reset of the data path, so it comes from a
    // flop (glitch-free). It is decoded from next_state to change together with state.
    always @(posedge clk_sys or negedge global_rst_n) begin
        if (!global_rst_n) reset_phy <= 0;
        else case (next_state)
            INIT0, INIT1, INIT2: reset_phy <= 0;
            default: reset_phy <= 1;
        endcase
    end
    // next stage
    always @(*) begin
        next_state = state;
        case (state)
            // INIT Phase: reset hardware, wait loading config
            INIT0 : next_state = INIT1;
            INIT1 : next_state = INIT2;
            INIT2 : next_state = INIT3;
            INIT3 : if (s_config_tvalid) next_state = LOAD_SIG;
                    else next_state = INIT3;
            LOAD_SIG : next_state = PHY_RDY;
            // TX Phase: wait tx command, then send payload
            PHY_RDY : if (start_tx_sync[1]) next_state = TX_HEADER;
                      else next_state = PHY_RDY;
            TX_HEADER : if (tx_header_counter >= 330) next_state = TX_DATA;
                        else next_state = TX_HEADER;
            TX_DATA: if (!send_data_field) next_state = TX_END;
                     else next_state = TX_DATA;
            TX_END : next_state = INIT3;
            default: next_state = INIT0;
        endcase
    end
    // output logic
    always @(*) begin
        // load_signal_field
        case (state)
            LOAD_SIG: load_signal_field = 1; 
            default: load_signal_field = 0;
        endcase
        // tx_header
        case (state)
            TX_HEADER: tx_header = 1;
            default:   tx_header = 0;
        endcase
        // end_frame
        case (state)
            TX_END:  end_frame = 1;
            default: end_frame = 0;
        endcase
        // busy
        case (state)
            PHY_RDY: busy = 0; 
            default: busy = 1;
        endcase
    end

    // Transmit timing, in clk_sys (20 MHz) cycles from entering TX_HEADER.
    // start_ts and start_sig are used at 20 MHz, start_data at 120 MHz (clk_cb).
    parameter START_TS_OFFSET = 32;
    parameter START_TS_DURATION = 1;
    parameter START_SIG_OFFSET = 1;
    parameter START_SIG_DURATION = 2;
    parameter START_DATA_OFFSET = 10;
    parameter START_DATA_DURATION = 2;
    always @(*) begin
        // start frame
        if (tx_header_counter < 4 && tx_header) start_frame = 1;
        else start_frame = 0;
        // traininig sequence
        if (tx_header_counter >= START_TS_OFFSET &&
            tx_header_counter < START_TS_OFFSET + START_TS_DURATION) start_ts = 1;
        else start_ts = 0;

        // signal field
        if (tx_header_counter >= START_SIG_OFFSET &&
            tx_header_counter < START_SIG_OFFSET + START_SIG_DURATION) start_sig = 1;
        else start_sig = 0;
        // data field
        if (tx_header_counter >= START_DATA_OFFSET &&
            tx_header_counter < START_DATA_OFFSET + START_DATA_DURATION) start_data = 1;
        else start_data = 0;

    end

    // header counter
    always @(posedge clk_sys or negedge global_rst_n) begin
        if (!global_rst_n) begin
            tx_header_counter <= 0;
        end
        else begin
            if (tx_header) begin
                tx_header_counter <= tx_header_counter + 1;
            end
            else tx_header_counter <= 0;
        end
    end

endmodule
