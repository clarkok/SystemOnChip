module ddr3_ctrl(
    input  clk,
    input  rst,

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

    output [31:0] disp_value,
    output [ 2:0] state_value
    );

    wire interrupt;
    wire init_calib_complete;
    wire [28:0] s_axi_awaddr;
    wire        s_axi_awvalid;
    wire        s_axi_awready;
    wire [31:0] s_axi_wdata;
    wire [ 3:0] s_axi_wstrb;
    wire        s_axi_wvalid;
    wire        s_axi_wready;
    wire [ 1:0] s_axi_bresp;
    wire        s_axi_bvalid;
    wire [28:0] s_axi_araddr;
    wire        s_axi_arvalid;
    wire        s_axi_arready;
    wire        s_axi_rready;
    wire [31:0] s_axi_rdata;
    wire [ 1:0] s_axi_rresp;
    wire        s_axi_rlast;
    wire        s_axi_rvalid;

    localparam  S_WAIT = 0,
                S_WRITE = 1,
                S_WRITE_END = 2,
                S_READ = 3,
                S_READ_END = 4,
                S_IDLE = 5;

    wire ui_clk;

    reg [2:0] state;
    reg [31:0] data_src;
    reg [31:0] data_dst;

    assign disp_value = data_dst;
    assign state_value = state;
    assign s_axi_awaddr = 0;
    assign s_axi_awvalid = (state == S_WRITE);
    assign s_axi_wdata = data_src;
    assign s_axi_wstrb = 4'b1111;
    assign s_axi_wvalid = (state == S_WRITE_END);
    assign s_axi_araddr = 0;
    assign s_axi_arvalid = (state == S_READ);
    assign s_axi_rvalid = (state == S_READ_END);

    initial begin 
        state <= 0;
        data_src <= 0;
        data_dst <= 0;
    end

    always @(posedge ui_clk) begin
        if (init_calib_complete) begin
            state <= S_WRITE;
        end

        case (state)
            S_WRITE:        if (s_axi_awready)  state <= S_WRITE_END;
            S_WRITE_END:    if (s_axi_wready)   state <= S_READ;
            S_READ:         if (s_axi_arready)  state <= S_READ_END;
            S_READ_END:     if (s_axi_rready)   begin data_dst <= s_axi_rdata; state <= S_WRITE; data_src <= data_src + 1; end
        endcase
    end

    ddr3 u_ddr3 (
    // Memory interface ports
         .ddr3_dq                        (ddr3_dq),
         .ddr3_dqs_n                     (ddr3_dqs_n),
         .ddr3_dqs_p                     (ddr3_dqs_p),
         .ddr3_addr                      (ddr3_addr),
         .ddr3_ba                        (ddr3_ba),
         .ddr3_ras_n                     (ddr3_ras_n),
         .ddr3_cas_n                     (ddr3_cas_n),
         .ddr3_we_n                      (ddr3_we_n),
         .ddr3_reset_n                   (ddr3_reset_n),
         .ddr3_ck_p                      (ddr3_ck_p),
         .ddr3_ck_n                      (ddr3_ck_n),
         .ddr3_cke                       (ddr3_cke),
         .ddr3_cs_n                      (ddr3_cs_n),
         .ddr3_dm                        (ddr3_dm),
         .ddr3_odt                       (ddr3_odt),
         .sys_clk_i                      (clk),
    // Application interface ports
         .ui_clk                         (ui_clk),
         .ui_clk_sync_rst                (),
         .aresetn                        (rst),
         .app_sr_req                     (0),
         .app_sr_active                  (),
         .app_ref_req                    (0),
         .app_ref_ack                    (),
         .app_zq_req                     (0),
         .app_zq_ack                     (),

    // Slave Interface Write Address Ports
         .s_axi_awid                     (0),
         .s_axi_awaddr                   (s_axi_awaddr),
         .s_axi_awlen                    (0),
         .s_axi_awsize                   ($clog2(4)),
         .s_axi_awburst                  (2'b01),
         .s_axi_awlock                   (0),
         .s_axi_awcache                  (0),
         .s_axi_awprot                   (0),
         .s_axi_awqos                    (0),
         .s_axi_awvalid                  (s_axi_awvalid),
         .s_axi_awready                  (s_axi_awready),
    // Slave Interface Write Data Ports
         .s_axi_wdata                    (s_axi_wdata),
         .s_axi_wstrb                    (s_axi_wstrb),
         .s_axi_wlast                    (1'b1),
         .s_axi_wvalid                   (s_axi_wvalid),
         .s_axi_wready                   (s_axi_wready),
    // Slave Interface Write Response Ports
         .s_axi_bready                   (1'b1),
         .s_axi_bid                      (),
         .s_axi_bresp                    (s_axi_bresp),
         .s_axi_bvalid                   (s_axi_bvalid),
    // Slave Interface Read Address Ports
         .s_axi_arid                     (0),
         .s_axi_araddr                   (s_axi_araddr),
         .s_axi_arlen                    (0),
         .s_axi_arsize                   ($clog2(4)),
         .s_axi_arburst                  (2'b01),
         .s_axi_arlock                   (0),
         .s_axi_arcache                  (0),
         .s_axi_arprot                   (0),
         .s_axi_arqos                    (0),
         .s_axi_arvalid                  (s_axi_arvalid),
         .s_axi_arready                  (s_axi_arready),
    // Slave Interface Read Data Ports
         .s_axi_rready                   (s_axi_rready),
         .s_axi_rid                      (),
         .s_axi_rdata                    (s_axi_rdata),
         .s_axi_rresp                    (s_axi_rresp),
         .s_axi_rlast                    (s_axi_rlast),
         .s_axi_rvalid                   (s_axi_rvalid),
    // AXI CTRL port
         .init_calib_complete            (init_calib_complete),
         .sys_rst                        (rst)
        );

endmodule
