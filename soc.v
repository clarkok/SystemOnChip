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

    wire [31:0] ddr3_addr_i;
    wire [31:0] ddr3_data_i;
    wire [31:0] ddr3_data_o;
    reg         ddr3_we_i;
    reg         ddr3_rd_i;
    wire        ddr3_ack_o;

    wire [15:0] cache_state_value;
    wire [15:0] last_cache_state_value;
    wire [15:0] ctrl_state_value;

    ddr3_dev ddr3_dev(
        .clk(clk_sys),
        .clk_ddr(clk_ddr),
        .clk_ref(clk_ddr_ref),
        .rst(rst),

        .addr_i(ddr3_addr_i),
        .data_i(ddr3_data_i),
        .data_o(ddr3_data_o),
        .we_i(ddr3_we_i),
        .rd_i(ddr3_rd_i),
        .ack_o(ddr3_ack_o),

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

    reg [31:0] counter;
    reg [31:0] read_data;
    reg        init;

    initial begin
        counter     <= 0;
        ddr3_we_i   <= 1'b0;
        ddr3_rd_i   <= 1'b0;
        read_data   <= 0;
    end

    assign ddr3_addr_i  = {counter[15:0], counter[31:16]};
    assign ddr3_data_i  = counter;

    always @(posedge clk) begin
        if (rst) begin
            counter     <= 0;
            ddr3_we_i   <= 1'b0;
            ddr3_rd_i   <= 1'b0;
            read_data   <= 0;
            init        <= 1'b0;
        end
        else begin
            if (init) begin
                case ({ddr3_we_i, ddr3_rd_i})
                    2'b00:            begin {ddr3_we_i, ddr3_rd_i}  <= 2'b10;   counter <= counter + 1'b1; end
                    2'b10:  if (ddr3_ack_o) {ddr3_we_i, ddr3_rd_i}  <= 2'b01;
                    2'b01:  if (ddr3_ack_o) {ddr3_we_i, ddr3_rd_i}  <= 2'b00;
                endcase

                if (ddr3_rd_i && ddr3_ack_o) read_data <= ddr3_data_o;
            end
            else begin
                if (ddr3_ack_o)     init <= 1'b1;
            end
        end
    end

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

    reg [15:0] led;

    always @* begin
        case (sw[2:0])
            0: led  = cache_state_value;
            1: led  = ctrl_state_value;
            2: led  = {ddr3_we_i, ddr3_rd_i};
            3: led  = counter[15:0];
            4: led  = last_cache_state_value;
        endcase
    end

    board_disp_sword board_disp_sword(
        .clk(clk_sys),
        .rst(rst),

        .en({8{1'b1}}),
        .data(read_data),
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
