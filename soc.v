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

    wire [31:0] inst_addr_o;
    wire [31:0] inst_data_i;

    bios_rom bios_rom(
        .a(inst_addr_o[11:2]),
        .spo(inst_data_i)
    );

    wire [31:0] data_addr_o;
    wire [31:0] data_data_i;
    wire [31:0] data_data_o;
    wire        data_we_o;
    wire        data_rd_o;
    wire [3:0]  data_sel_o;
    wire        data_valid_i;

    core core(
        .clk(clk_sys),
        .rst(rst),
        .inst_addr_o(inst_addr_o),
        .inst_data_i(inst_data_i),
        .inst_valid_i(1'b1),
        .data_addr_o(data_addr_o),
        .data_data_i(data_data_i),
        .data_data_o(data_data_o),
        .data_sel_o(data_sel_o),
        .data_we_o(data_we_o),
        .data_rd_o(data_rd_o),
        .data_valid_i(data_valid_i),
        .mem_fc(),
        .mem_sc(),
        .hw_page_fault(1'b0),
        .hw_interrupt(1'b0),
        .hw_cause(32'b0),
        .exception(),
        .cause(),
        .epc(),
        .eret(),
        .cp0_addr_o(),
        .cp0_data_i(32'b0),
        .cp0_data_o(),
        .cp0_we_o(),
        .cp0_exception_base(32'b0)
    );

    wire [31:0] cache_addr_o;
    wire [31:0] cache_data_i;
    wire [31:0] cache_data_o;
    wire        cache_we_o;
    wire        cache_rd_o;
    wire        cache_ack_i;

    data_cache data_cache(
        .clk(clk_sys),
        .rst(rst),
        .data_addr(data_addr_o),
        .data_in(data_data_i),
        .data_out(data_data_o),
        .data_we(data_we_o),
        .data_rd(data_rd_o),
        .data_sel(data_sel_o),
        .data_sign_ext(1'b0),
        .data_ready(data_valid_i),
        .addr_o(cache_addr_o),
        .data_i(cache_data_i),
        .data_o(cache_data_o),
        .we_o(cache_we_o),
        .rd_o(cache_rd_o),
        .ack_i(cache_ack_i),
        .fence(1'b0)
    );

    wire [31:0] mmu_addr_o;
    wire [31:0] mmu_data_i;
    wire [31:0] mmu_data_o;
    wire        mmu_we_o;
    wire        mmu_rd_o;
    wire        mmu_ack_i;

    mmu mmu(
        .clk(clk),
        .rst(rst),
        .mmu_base_i(32'b0),
        .mmu_we(1'b0),
        .mmu_base_o(),
        .v_addr_i(cache_addr_o),
        .v_data_i(cache_data_o),
        .v_data_o(cache_data_i),
        .v_we_i(cache_we_o),
        .v_rd_i(cache_rd_o),
        .v_ack_o(cache_ack_i),
        .addr_o(mmu_addr_o),
        .data_i(mmu_data_i),
        .data_o(mmu_data_o),
        .we_o(mmu_we_o),
        .rd_o(mmu_rd_o),
        .ack_i(mmu_ack_i),
        .page_fault(),
        .page_fault_addr()
    );

    ddr3_dev ddr3_dev(
        .clk(clk_sys),
        .clk_ddr(clk_ddr),
        .clk_ref(clk_ddr_ref),
        .rst(rst),

        .addr_i(mmu_addr_o),
        .data_i(mmu_data_o),
        .data_o(mmu_data_i),
        .we_i(mmu_we_o),
        .rd_i(mmu_rd_o),
        .ack_o(mmu_ack_i),

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

        .cache_state_value(cache_state_value),
        .last_cache_state_value(last_cache_state_value),
        .ctrl_state_value(ctrl_state_value)
    );

    assign tri_led0 = 3'b111;
    assign tri_led1 = 3'b111;

    reg [15:0] led;

    always @* begin
        case (sw[2:0])
            0: led  = cache_state_value;
            1: led  = ctrl_state_value;
            2: led  = 32'b0;
            3: led  = 32'b0;
            4: led  = last_cache_state_value;
            5: led  = data_data_o;
        endcase
    end

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
