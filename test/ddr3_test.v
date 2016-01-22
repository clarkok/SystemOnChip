module ddr3_test;
    reg   clk;
    reg   clk_ddr;
    reg   clk_ref;
    reg   rst;
    reg   [28:0] addr_i;
    reg   [255:0] data_i;
    reg   we_i;
    reg   rd_i;

    wire   [31:0] ddr3_dq;
    wire   [ 3:0] ddr3_dqs_n;
    wire   [ 3:0] ddr3_dqs_p;
    wire   [13:0] ddr3_addr;
    wire   [ 2:0] ddr3_ba;
    wire          ddr3_ras_n;
    wire          ddr3_cas_n;
    wire          ddr3_we_n;
    wire          ddr3_reset_n;
    wire   [ 0:0] ddr3_ck_p;
    wire   [ 0:0] ddr3_ck_n;
    wire   [ 0:0] ddr3_cke;
    wire   [ 0:0] ddr3_cs_n;
    wire   [ 3:0] ddr3_dm;
    wire   [ 0:0] ddr3_odt;

    wire   [255:0] data_o;
    wire   ack_o;

    wire   [ 2:0] state_value;

    ddr3_ctrl uut(
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

        .addr_i(addr_i),
        .data_i(data_i),
        .data_o(data_o),
        .we_i(we_i),
        .rd_i(rd_i),
        .ack_o(ack_o),
        .state_value(state_value)
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
        .dq(ddr3_dq[15:0])
    );

    initial begin
        clk         = 0;
        clk_ddr     = 0;
        clk_ref     = 1;
        rst         = 1;
        data_i      = 0;

        #10
        rst         = 0;

        @(posedge ack_o) begin
            @(negedge clk) begin
                we_i    = 1;
                data_i  = 255'h01234567_01234567_01234567_01234567_01234567_01234567_01234567_01234567;
            end
            @(posedge ack_o) begin
                @(posedge clk) begin
                    we_i    = 0;
                end
            end

            @(negedge clk) begin
                rd_i    = 1;
            end
            @(posedge ack_o) begin
                @(posedge clk) begin
                    rd_i    = 0;
                end
            end

            @(negedge clk) begin
                we_i    = 1;
                addr_i  = 28'hF000_000;
                data_i  = 255'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF;
            end
            @(posedge ack_o) begin
                @(posedge clk) begin
                    we_i    = 0;
                end
            end

            @(negedge clk) begin
                rd_i    = 1;
            end
            @(posedge ack_o) begin
                @(posedge clk) begin
                    rd_i    = 0;
                end
            end

            @(negedge clk) begin
                rd_i    = 1;
                addr_i  = 0;
            end
            @(posedge ack_o) begin
                @(posedge clk) begin
                    rd_i    = 0;
                end
            end
        end
    end

    initial forever #5 clk = ~clk;
    initial forever #5 clk_ddr = ~clk_ddr;
    initial forever #5 clk_ref = ~clk_ref;
endmodule
