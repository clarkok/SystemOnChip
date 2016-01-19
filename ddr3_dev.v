`include "functions.vh"

module ddr3_dev(
    input  clk,
    input  clk_ddr,
    input  clk_ref,
    input  rst,

    input  [31:0]  addr_i,
    input  [31:0]  data_i,
    output [31:0]  data_o,
    input          we_i,
    input          rd_i,
    output         ack_o,

    inout  [31:0] ddr3_dq,
    inout  [ 3:0] ddr3_dqs_n,
    inout  [ 3:0] ddr3_dqs_p,
    output [13:0] ddr3_addr,
    output [ 2:0] ddr3_ba,
    output        ddr3_ras_n,
    output        ddr3_cas_n,
    output        ddr3_we_n,
    output        ddr3_reset_n,
    output        ddr3_ck_p,
    output        ddr3_ck_n,
    output        ddr3_cke,
    output        ddr3_cs_n,
    output [ 3:0] ddr3_dm,
    output        ddr3_odt,

    output [15:0] cache_state_value,
    output [15:0] ctrl_state_value
    );

    wire [28:0]     ctrl_addr_i;
    wire [255:0]    ctrl_data_i;
    wire [255:0]    ctrl_data_o;
    wire            ctrl_we_i;
    wire            ctrl_rd_i;
    wire            ctrl_ack_o;

    ddr3_ctrl ddr3_ctrl(
        .clk(clk),
        .clk_ddr(clk_ddr),
        .clk_ref(clk_ref),
        .rst(rst),

        .ddr3_dq(ddr3_dq),
        .ddr3_dqs_n(ddr3_dqs_n),
        .ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_addr(ddr3_addr),
        .ddr3_ba(ddr3_ba),
        .ddr3_ras_n(ddr3_ras_n),
        .ddr3_cas_n(ddr3_cas_n),
        .ddr3_we_n(ddr3_we_n),
        .ddr3_reset_n(ddr3_reset_n),
        .ddr3_ck_p(ddr3_ck_p),
        .ddr3_ck_n(ddr3_ck_n),
        .ddr3_cke(ddr3_cke),
        .ddr3_cs_n(ddr3_cs_n),
        .ddr3_dm(ddr3_dm),
        .ddr3_odt(ddr3_odt),

        .addr_i(ctrl_addr_i),
        .data_i(ctrl_data_i),
        .data_o(ctrl_data_o),
        .we_i(ctrl_we_i),
        .rd_i(ctrl_rd_i),
        .ack_o(ctrl_ack_o),

        .state_value(ctrl_state_value)
    );

    ddr3_cache_ctrl ddr3_cache_ctrl(
        .clk(clk),
        .rst(rst),

        .addr_i(addr_i),
        .data_i(data_i),
        .data_o(data_o),
        .we_i(we_i),
        .rd_i(rd_i),
        .ack_o(ack_o),

        .ctrl_addr_i(ctrl_addr_i),
        .ctrl_data_i(ctrl_data_i),
        .ctrl_data_o(ctrl_data_o),
        .ctrl_we_i(ctrl_we_i),
        .ctrl_rd_i(ctrl_rd_i),
        .ctrl_ack_o(ctrl_ack_o),

        .state_value(cache_state_value)
    );

endmodule
