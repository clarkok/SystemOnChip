module soc_test;
    reg   clk;
    reg   rstn;
    reg   [15:0] sw;
    reg   ps2_clk;
    reg   ps2_data;

    wire uart_rxd;
    wire [47:0] sram_dq;
    wire [ 3:0] ddr3_dqs_n;
    wire [ 3:0] ddr3_dqs_p;
    wire [31:0] ddr3_dq;
    wire        ddr3_cas_n;
    wire        ddr3_ras_n;
    wire        ddr3_reset_n;
    wire        ddr3_we_n;
    wire [ 0:0] ddr3_ck_n;
    wire [ 0:0] ddr3_ck_p;
    wire [ 0:0] ddr3_cke;
    wire [ 0:0] ddr3_cs_n;
    wire [ 0:0] ddr3_odt;
    wire [ 2:0] ddr3_ba;
    wire [ 3:0] ddr3_dm;
    wire [13:0] ddr3_addr;
    wire [19:0] sram_addr;
    wire [2:0] tri_led0;
    wire [2:0] tri_led1;
    wire [3:0] vga_b;
    wire [3:0] vga_g;
    wire [3:0] vga_r;
    wire led_clk;
    wire led_clr;
    wire led_do;
    wire led_pen;
    wire seg_clk;
    wire seg_clr;
    wire seg_do;
    wire seg_pen;
    wire sram_ce;
    wire sram_oen;
    wire sram_wen;
    wire uart_txd;
    wire vga_hs;
    wire vga_vs;

    soc uut(
        .clk(clk),
        .rstn(rstn),
        .sw(sw),
        .tri_led0(tri_led0),
        .tri_led1(tri_led1),
        .seg_clk(seg_clk),
        .seg_clr(seg_clr),
        .seg_do(seg_do),
        .seg_pen(seg_pen),
        .led_clk(led_clk),
        .led_clr(led_clr),
        .led_do(led_do),
        .led_pen(led_pen),
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
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
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

    ddr3_module lo(
        .reset_n(ddr3_reset_n),
        .ck(ddr3_ck_p),
        .ck_n(ddr3_ck_n),
        .cke(ddr3_cke),
        .s_n(ddr3_cs_n),
        .ras_n(ddr3_ras_n),
        .cas_n(ddr3_cas_n),
        .we_n(ddr3_we_n),
        .ba(ddr3_ba),
        .addr(ddr3_addr),
        .odt(ddr3_odt),
        .dqs(ddr3_dqs_p),
        .dqs_n(ddr3_dqs_n),
        .dq(ddr3_dq)
    );

    reg  [7:0]  uart_data_i;
    reg         uart_data_send;
    wire        uart_data_sent;
    wire [7:0]  uart_data_o;
    wire        uart_data_received;

    uart uart_receiver(
        .clk(clk),
        .rst(rst),
        .uart_rxd(uart_txd),
        .uart_txd(uart_rxd),
        .data_in(uart_data_i),
        .data_send(uart_data_send),
        .data_sent(uart_data_sent),
        .data_out(uart_data_o),
        .data_received(uart_data_received)
    );

    always @(posedge clk) begin
        if (uart_data_received) begin
            $display("%c", uart_data_o);
        end
    end

    initial begin
        clk = 0;
        rstn = 1;

        uart_data_i = 0;
        uart_data_send = 0;
    end

    initial forever #5 clk = ~clk;

endmodule
