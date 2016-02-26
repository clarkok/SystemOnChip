`include "exceptions.vh"

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

    input  ps2_clk,
    input  ps2_data,

    output [25:0]   bpi_a,
    inout  [31:0]   bpi_q,
    output [ 1:0]   bpi_cen,
    output          bpi_oen,
    output          bpi_wen,
    output          bpi_rstn,
    input  [ 1:0]   bpi_rynby,

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

    wire [ 31:0]    bios_inst_addr_o;
    wire [ 31:0]    bios_inst_data_i;

    wire [ 31:0]    devices_interrupt;

    wire [ 31:0]    disp_value;

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
        .bios_addr_o(bios_inst_addr_o),
        .bios_data_i(bios_inst_data_i),
        .bios_rd_o(),
        .bios_ack_i(1'b1),
        .devices_interrupt(devices_interrupt),
        .the_pc(disp_value)
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

    wire [31:0] bios_addr_o;
    wire [31:0] bios_data_i;
    wire [31:0] bios_data_o;
    wire [ 1:0] bios_sel_o;
    wire        bios_rd_o;
    wire        bios_we_o;
    wire        bios_ack_i;

    wire [31:0] flash_addr_o;
    wire [31:0] flash_data_i;
    wire [31:0] flash_data_o;
    wire [ 1:0] flash_sel_o;
    wire        flash_rd_o;
    wire        flash_we_o;
    wire        flash_ack_i;

    wire [31:0] timer_addr_o;
    wire [31:0] timer_data_i;
    wire [31:0] timer_data_o;
    wire [ 1:0] timer_sel_o;
    wire        timer_rd_o;
    wire        timer_we_o;
    wire        timer_ack_i;

    wire [31:0] uart_addr_o;
    wire [31:0] uart_data_i;
    wire [31:0] uart_data_o;
    wire [ 1:0] uart_sel_o;
    wire        uart_rd_o;
    wire        uart_we_o;
    wire        uart_ack_i;

    wire [31:0] ps2_addr_o;
    wire [31:0] ps2_data_i;
    wire [31:0] ps2_data_o;
    wire [ 1:0] ps2_sel_o;
    wire        ps2_rd_o;
    wire        ps2_we_o;
    wire        ps2_ack_i;

    wire [31:0] sw_addr_o;
    wire [31:0] sw_data_i;
    wire [31:0] sw_data_o;
    wire [ 1:0] sw_sel_o;
    wire        sw_rd_o;
    wire        sw_we_o;
    wire        sw_ack_i;

    wire [31:0] dt_addr_o;
    wire [31:0] dt_data_i;
    wire [31:0] dt_data_o;
    wire [ 1:0] dt_sel_o;
    wire        dt_rd_o;
    wire        dt_we_o;
    wire        dt_ack_i;

    bus bus(
        .clk(clk_sys),
        .rst(rst),

        .m_addr_i(bus_addr_o),
        .m_data_o(bus_data_i),
        .m_data_i(bus_data_o),
        .m_sel_i(bus_sel_o),
        .m_rd_i(bus_rd_o),
        .m_we_i(bus_we_o),
        .m_ack_o(bus_ack_i),

        .gpu_addr_o(gpu_addr_o),
        .gpu_data_i(gpu_data_i),
        .gpu_data_o(gpu_data_o),
        .gpu_sel_o(gpu_sel_o),
        .gpu_rd_o(gpu_rd_o),
        .gpu_we_o(gpu_we_o),
        .gpu_ack_i(gpu_ack_i),

        .bios_addr_o(bios_addr_o),
        .bios_data_i(bios_data_i),
        .bios_data_o(bios_data_o),
        .bios_sel_o(bios_sel_o),
        .bios_rd_o(bios_rd_o),
        .bios_we_o(bios_we_o),
        .bios_ack_i(bios_ack_i),

        .flash_addr_o(flash_addr_o),
        .flash_data_i(flash_data_i),
        .flash_data_o(flash_data_o),
        .flash_sel_o(flash_sel_o),
        .flash_rd_o(flash_rd_o),
        .flash_we_o(flash_we_o),
        .flash_ack_i(flash_ack_i),

        .timer_addr_o(timer_addr_o),
        .timer_data_i(timer_data_i),
        .timer_data_o(timer_data_o),
        .timer_sel_o(timer_sel_o),
        .timer_rd_o(timer_rd_o),
        .timer_we_o(timer_we_o),
        .timer_ack_i(timer_ack_i),

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
        .ps2_ack_i(ps2_ack_i),

        .sw_addr_o(sw_addr_o),
        .sw_data_i(sw_data_i),
        .sw_data_o(sw_data_o),
        .sw_sel_o(sw_sel_o),
        .sw_rd_o(sw_rd_o),
        .sw_we_o(sw_we_o),
        .sw_ack_i(sw_ack_i),

        .dt_addr_o(dt_addr_o),
        .dt_data_i(dt_data_i),
        .dt_data_o(dt_data_o),
        .dt_sel_o(dt_sel_o),
        .dt_rd_o(dt_rd_o),
        .dt_we_o(dt_we_o),
        .dt_ack_i(dt_ack_i)
    );

    bios_dev bios_dev(
        .clk(clk_sys),
        .rst(rst),

        .addr_i(bios_addr_o),
        .data_o(bios_data_i),
        .data_i(bios_data_o),
        .sel_i(bios_sel_o),
        .rd_i(bios_sel_o),
        .we_i(bios_sel_o),
        .ack_o(bios_ack_i),

        .inst_addr_i(bios_inst_addr_o),
        .inst_data_o(bios_inst_data_i)
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

    timer timer(
        .clk(clk_sys),
        .rst(rst),

        .addr_i(timer_addr_o),
        .data_o(timer_data_i),
        .data_i(timer_data_o),
        .sel_i(timer_sel_o),
        .rd_i(timer_sel_o),
        .we_i(timer_sel_o),
        .ack_o(timer_ack_i),

        .interrupt(devices_interrupt[`TIMER_INT])
    );

    ps2 ps2(
        .clk(clk_sys),
        .rst(rst),

        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),

        .addr_i(ps2_addr_o),
        .data_o(ps2_data_i),
        .data_i(ps2_data_o),
        .sel_i(ps2_sel_o),
        .rd_i(ps2_rd_o),
        .we_i(ps2_we_o),
        .ack_o(ps2_ack_i),

        .interrupt(devices_interrupt[`PS2_INT])
    );

    uart_dev uart_dev(
        .clk(clk_sys),
        .rst(rst),

        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),

        .addr_i(uart_addr_o),
        .data_o(uart_data_i),
        .data_i(uart_data_o),
        .sel_i(uart_sel_o),
        .rd_i(uart_rd_o),
        .we_i(uart_we_o),
        .ack_o(uart_ack_i),

        .interrupt(devices_interrupt[`UART_INT])
    );

    flash_dev flash_dev(
        .clk(clk_sys),
        .rst(rst),

        .bpi_a(bpi_a),
        .bpi_q(bpi_q),
        .bpi_cen(bpi_cen),
        .bpi_oen(bpi_oen),
        .bpi_wen(bpi_wen),
        .bpi_rstn(bpi_rstn),
        .bpi_rynby(bpi_rynby),

        .addr_i(flash_addr_o),
        .data_o(flash_data_i),
        .data_i(flash_data_o),
        .sel_i(flash_sel_o),
        .rd_i(flash_rd_o),
        .we_i(flash_we_o),
        .ack_o(flash_ack_i),

        .interrupt(devices_interrupt[`FLASH_INT])
    );

    switch switch(
        .clk(clk_sys),
        .rst(rst),

        .sw(sw),

        .addr_i(sw_addr_o),
        .data_o(sw_data_i),
        .data_i(sw_data_o),
        .sel_i(sw_sel_o),
        .rd_i(sw_rd_o),
        .we_i(sw_we_o),
        .ack_o(sw_ack_i),

        .interrupt()
    );

    datetime datetime(
        .clk(clk_sys),
        .rst(rst),

        .addr_i(dt_addr_o),
        .data_o(dt_data_i),
        .data_i(dt_data_o),
        .sel_i(dt_sel_o),
        .rd_i(dt_rd_o),
        .we_i(dt_we_o),
        .ack_o(dt_ack_i)
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
        .data(disp_value),
        .dot(sram_dq[39:32]),
        .led(devices_interrupt[15:0]),

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
