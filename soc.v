module soc(
    input clk,
    input rstn,

    input  [15:0] sw,

    output [2:0] tri_led0,
    output [2:0] tri_led1,

    output seg_clk,
    output seg_clr,
    output seg_do,
    output seg_pen,

    output led_clk,
    output led_clr,
    output led_do,
    output led_pen,

    output [19:0] sram_addr,
    inout  [47:0] sram_dq,
    output sram_ce,
    output sram_oen,
    output sram_wen,

    output [3:0] vga_b,
    output [3:0] vga_g,
    output [3:0] vga_r,
    output vga_hs,
    output vga_vs,

    input  uart_rxd,
    output uart_txd,

    inout  [31:0] ddr3_dq,
    inout  [ 3:0] ddr3_dqs_n,
    inout  [ 3:0] ddr3_dqs_p,
    output [13:0] ddr3_addr,
    output [ 2:0] ddr3_ba,
    output        ddr3_ras_n,
    output        ddr3_cas_n,
    output        ddr3_we_n,
    output        ddr3_reset_n,
    output [ 0:0] ddr3_ck_p,
    output [ 0:0] ddr3_ck_n,
    output [ 0:0] ddr3_cke,
    output [ 0:0] ddr3_cs_n,
    output [ 3:0] ddr3_dm,
    output [ 0:0] ddr3_odt
    );

    wire clk_sys;
    wire clk_vga;
    wire clk_ddr;
    wire clk_ddr_ref;
    wire rst = ~rstn;

    wire [ 31:0]    mem_addr_o;
    wire [255:0]    mem_data_i;
    wire [255:0]    mem_data_o;
    wire            mem_we_o;
    wire            mem_rd_o;
    wire            mem_ack_i;

    wire [ 31:0]    bus_addr_o;
    wire [ 31:0]    bus_data_i;
    wire [ 31:0]    bus_data_o;
    wire [  1:0]    bus_sel_o;
    wire            bus_we_o;
    wire            bus_rd_o;
    wire            bus_ack_i;

    wire [ 31:0]    devices_interrupt;

    cpu cpu(
        .clk(clk_sys),
        .rst(rst),
        .mem_addr_o(mem_addr_o),
        .mem_data_i(mem_data_i),
        .mem_data_o(mem_data_o),
        .mem_we_o(mem_we_o),
        .mem_rd_o(mem_rd_o),
        .mem_ack_i(mem_ack_i),
        .bus_addr_o(bus_addr_o),
        .bus_data_i(bus_data_i),
        .bus_data_o(bus_data_o),
        .bus_sel_o(bus_sel_o),
        .bus_we_o(bus_we_o),
        .bus_rd_o(bus_rd_o),
        .bus_ack_i(bus_ack_i),
        .devices_interrupt(devices_interrupt)
    );

    ddr3_dev ddr3_dev(
        .clk(clk_sys),
        .clk_ddr(clk_ddr),
        .clk_ref(clk_ddr_ref),
        .rst(rst),

        .addr_i(mem_addr_o),
        .data_i(mem_data_o),
        .data_o(mem_data_i),
        .we_i(mem_we_o),
        .rd_i(mem_rd_o),
        .ack_o(mem_ack_i),

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
        .ddr3_odt(ddr3_odt)
    );

    wire [31:0] gpu_addr_o;
    wire [31:0] gpu_data_i;
    wire [31:0] gpu_data_o;
    wire [ 1:0] gpu_sel_o;
    wire        gpu_rd_o;
    wire        gpu_we_o;
    wire        gpu_ack_i;

    bus bus(
        .clk(clk_sys),
        .rst(rst),

        .m_addr_i(bus_addr_i),
        .m_data_o(bus_data_o),
        .m_data_i(bus_data_i),
        .m_sel_i(bus_sel_i),
        .m_rd_i(bus_rd_i),
        .m_we_i(bus_we_i),
        .m_ack_o(bus_ack_o),

        .gpu_addr_o(gpu_addr_o),
        .gpu_data_i(gpu_data_i),
        .gpu_data_o(gpu_data_o),
        .gpu_sel_o(gpu_sel_o),
        .gpu_rd_o(gpu_rd_o),
        .gpu_we_o(gpu_we_o),
        .gpu_ack_i(gpu_ack_i),

        .uart_addr_o(uart_addr_o),
        .uart_data_i(uart_data_i),
        .uart_data_o(uart_data_o),
        .uart_sel_o(uart_sel_o),
        .uart_rd_o(uart_rd_o),
        .uart_we_o(uart_we_o),
        .uart_ack_i(uart_ack_i),

        .ps2_addr_o(ps2_addr_o),
        .ps2_data_i(ps2_data_i),
        .ps2_data_o(ps2_data_o),
        .ps2_sel_o(ps2_sel_o),
        .ps2_rd_o(ps2_rd_o),
        .ps2_we_o(ps2_we_o),
        .ps2_ack_i(ps2_ack_i)
    );

    gpu gpu(
        .clk(clk_sys),
        .clk_vga(clk_vga),
        .rst(rst),

        .sram_addr(sram_addr),
        .sram_dq(sram_dq),
        .sram_ce(sram_ce),
        .sram_oen(sram_oen),
        .sram_wen(sram_wen),

        .vga_b(vga_b),
        .vga_g(vga_g),
        .vga_r(vga_r),
        .vga_hs(vga_hs),
        .vga_vs(vga_vs),

        .bus_addr_i(gpu_addr_o),
        .bus_data_o(gpu_data_i),
        .bus_data_i(gpu_data_o),
        .bus_sel_i(gpu_sel_o),
        .bus_rd_i(gpu_rd_o),
        .bus_we_i(gpu_we_o),
        .bus_ack_o(gpu_ack_i)
    );

    uart uart(
        .clk(clk_sys),
        .rst(rst),

        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),

        .data_in(data_in),
        .data_send(data_send),
        .data_sent(data_sent),
        .data_out(data_out),
        .data_received(data_received)
    );

    dsp dsp(
        .clk_in1(clk),
        .clk_out1(clk_sys),
        .clk_out2(clk_vga),
        .clk_out3(clk_ddr),
        .clk_out4(clk_ddr_ref)
    );

    assign tri_led0 = 3'b111;
    assign tri_led1 = 3'b111;

    reg [15:0] led = 0;

    board_disp_sword board_disp_sword(
        .clk(clk_sys),
        .rst(rst),

        .en({8{1'b1}}),
        .data(counter),
        .dot(sram_dq[39:32]),
        .led(led),

        .led_clk(led_clk),
        .led_en(led_pen),
        .led_clr_n(led_clr),
        .led_do(led_do),

        .seg_clk(seg_clk),
        .seg_en(seg_pen),
        .seg_clr_n(seg_clr),
        .seg_do(seg_do)
    );
endmodule
