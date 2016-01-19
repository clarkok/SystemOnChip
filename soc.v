module soc(
    input clk,
    input rstn,

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

    reg [31:0] disp_value;

    initial begin
        disp_value  <= 0;
    end

    wire data_send;
    wire data_sent;
    wire [7:0] data_in;
    wire [7:0] data_out;
    wire data_received;

    assign data_send = data_received;
    assign data_in = data_out;

    always @(posedge clk) begin
        if (data_received) begin
            disp_value <= {disp_value[23:0], data_out};
        end
    end

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

    wire [31:0] ddr3_disp_value;
    wire [15:0] ddr3_state_value;

    ddr3_dev ddr3_dev(
        .clk(clk_sys),
        .clk_ddr(clk_ddr),
        .clk_ref(clk_ddr_ref),
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

        .disp_value(ddr3_disp_value),
        .state_value(ddr3_state_value)
    );

    dsp dsp(
        .clk_in1(clk),
        .clk_out1(clk_sys),
        .clk_out2(clk_vga),
        .clk_out3(clk_ddr),
        .clk_out4(clk_ddr_ref)
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

        .disp_value()
    );

    assign tri_led0 = 3'b111;
    assign tri_led1 = 3'b111;

    board_disp_sword board_disp_sword(
        .clk(clk_sys),
        .rst(rst),

        .en({8{1'b1}}),
        .data(ddr3_disp_value),
        .dot(sram_dq[39:32]),
        .led(ddr3_state_value),

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
