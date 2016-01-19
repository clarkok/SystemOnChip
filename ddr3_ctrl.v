module ddr3_ctrl(
    input  clk,
    input  clk_ddr,
    input  clk_ref,
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

    input  [ 31:0]  addr_i,
    input  [255:0]  data_i,
    output [255:0]  data_o,
    input           we_i,
    input           rd_i,
    output          ack_o,

    output [15:0]    state_value
    );

    wire            init_calib_complete;
    reg  [ 28:0]    s_axi_awaddr;
    wire            s_axi_awvalid;
    wire            s_axi_awready;
    reg  [255:0]    s_axi_wdata;
    wire            s_axi_wvalid;
    wire            s_axi_wready;
    wire            s_axi_bvalid;
    reg  [ 28:0]    s_axi_araddr;
    wire            s_axi_arvalid;
    wire            s_axi_arready;
    wire            s_axi_rready;
    wire [255:0]    s_axi_rdata;
    wire            s_axi_rlast;
    wire            s_axi_rvalid;
    wire            ui_clk;
    wire            ui_clk_sync_rst;

    reg             ui_we;
    reg             ui_rd;
    wire            ui_we_flag;
    wire            ui_rd_flag;
    
    reg             we_i_last;
    reg             rd_i_last;
    wire            clk_we_flag = we_i & ~we_i_last;
    wire            clk_rd_flag = rd_i & ~rd_i_last;

    task init_clk;
    begin
        we_i_last   <= 1'b0;
        rd_i_last   <= 1'b0;
    end
    endtask

    initial init_clk();

    always @(posedge clk) begin
        if (rst) init_clk();
        else begin
            we_i_last   <= we_i;
            rd_i_last   <= rd_i;
        end
    end

    async_flag async_we(
        .clk_src(clk),
        .flag_src(clk_we_flag),
        .clk_dst(ui_clk),
        .flag_dst(ui_we_flag)
    );

    async_flag async_rd(
        .clk_src(clk),
        .flag_src(clk_rd_flag),
        .clk_dst(ui_clk),
        .flag_dst(ui_rd_flag)
    );

    localparam  S_INIT = 0,
                S_IDLE = 1,
                S_READ_A = 2,
                S_READ_D = 3,
                S_WRITE_A = 4,
                S_WRITE_D = 5,
                S_END = 6;

    wire        ui_ack  = (state == S_END);

    async_flag async_ack(
        .clk_src(ui_clk),
        .flag_src(ui_ack),
        .clk_dst(clk),
        .flag_dst(ack_o)
    );

    reg [2:0]   state;
    reg [255:0] data_buf;

    assign s_axi_awvalid = (state == S_WRITE_A);
    assign s_axi_wvalid = (state == S_WRITE_D);

    assign s_axi_arvalid = (state == S_READ_A);
    assign s_axi_rready = (state == S_READ_D);
    assign data_o = data_buf;

    task init();
    begin
        s_axi_awaddr    <= 32'b0;
        s_axi_wdata     <= 256'b0;
        s_axi_araddr    <= 32'b0;
        state           <= S_INIT;
        data_buf        <= 255'b0;
        ui_we           <= 1'b0;
        ui_rd           <= 1'b0;
    end
    endtask

    initial init(); 

    always @(posedge ui_clk) begin
        if (ui_clk_sync_rst) init();
        else begin
            if (ui_we_flag)     ui_we <= 1'b1;
            if (ui_rd_flag)     ui_rd <= 1'b1;

            case (state)
                S_INIT: if (init_calib_complete)    state <= S_IDLE;
                S_IDLE: begin
                    s_axi_awaddr    <= addr_i;
                    s_axi_araddr    <= addr_i;
                    s_axi_wdata     <= data_i;
                    if (ui_rd) begin
                        state   <= S_READ_A;
                        ui_rd   <= 1'b0;
                    end
                    else if (ui_we) begin
                        state   <= S_WRITE_A;
                        ui_we   <= 1'b0;
                    end
                end
                S_READ_A:   if (s_axi_arready)      state <= S_READ_D;
                S_READ_D:   if (s_axi_rvalid) begin state <= S_END; data_buf <= s_axi_rdata;    end
                S_WRITE_A:  if (s_axi_awready)      state <= S_WRITE_D;
                S_WRITE_D:  if (s_axi_wready)       state <= S_END;
                S_END:                              state <= S_IDLE;
            endcase
        end
    end

    ddr3_mig ddr3_mig (
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
         .sys_clk_i                      (clk_ddr),
         .clk_ref_i                      (clk_ref),
    // Application interface ports
         .ui_clk                         (ui_clk),
         .ui_clk_sync_rst                (ui_clk_sync_rst),
         .mmcm_locked                    (),
         .aresetn                        (~rst),
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
         .s_axi_wstrb                    (32'hFFFFFFFF),
         .s_axi_wlast                    (1'b1),
         .s_axi_wvalid                   (s_axi_wvalid),
         .s_axi_wready                   (s_axi_wready),
    // Slave Interface Write Response Ports
         .s_axi_bready                   (1'b1),
         .s_axi_bid                      (),
         .s_axi_bresp                    (),
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
         .s_axi_rresp                    (),
         .s_axi_rlast                    (s_axi_rlast),
         .s_axi_rvalid                   (s_axi_rvalid),
    // AXI CTRL port
         .init_calib_complete            (init_calib_complete),
         .sys_rst                        (rst)
        );

    assign state_value  = state;

endmodule
