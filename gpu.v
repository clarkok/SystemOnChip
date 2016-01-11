module gpu(
    input  clk,
    input  clk_vga,
    input  rst,

    output [19:0] sram_addr,
    inout  [47:0] sram_dq,
    output        sram_ce,
    output        sram_oen,
    output        sram_wen,

    output [ 3:0] vga_b,
    output [ 3:0] vga_g,
    output [ 3:0] vga_r,
    output        vga_hs,
    output        vga_vs,

    // debug
    output [31:0] disp_value
    );

    reg [31:0] gcore_master_rom [0:63];
    initial $readmemh("gcore_master.hex", gcore_master_rom);

    wire [31:0] gcore_master_inst_addr;
    wire [20:0] gcore_master_data_addr;
    wire [47:0] gcore_master_data_in;
    wire [47:0] gcore_master_data_in_from_sram;
    wire [47:0] gcore_master_data_in_from_cpg;
    wire [47:0] gcore_master_data_out;
    wire        gcore_master_data_we;
    wire        gcore_master_data_rd;
    wire        gcore_master_data_sel;
    wire        gcore_master_data_ready;
    wire        gcore_master_data_ready_from_sram;
    wire        gcore_master_data_ready_from_cpg;

    assign gcore_master_data_sel    = gcore_master_data_we || gcore_master_data_rd;
    assign gcore_master_data_ready  = ~gcore_master_data_sel ||
                                    ((~gcore_master_data_addr[20]) ? gcore_master_data_ready_from_sram : gcore_master_data_ready_from_cpg);
    assign gcore_master_data_in     = (~gcore_master_data_addr[20]) ? gcore_master_data_in_from_sram : gcore_master_data_in_from_cpg;

    GCore gcore_master(
        .clk(clk),
        .rst(rst),
        .inst_addr(gcore_master_inst_addr),
        .inst_in(gcore_master_rom[gcore_master_inst_addr[7:2]]),
        .inst_valid(1'b1),
        .data_addr(gcore_master_data_addr),
        .data_in(gcore_master_data_in),
        .data_out(gcore_master_data_out),
        .data_we(gcore_master_data_we),
        .data_rd(gcore_master_data_rd),
        .data_sel(),
        .data_ready(gcore_master_data_ready)
    );

    reg [31:0] gcore_slave_rom [0:63];
    initial $readmemh("gcore_slave.hex", gcore_slave_rom);

    wire [31:0] gcore_slave_inst_addr;
    wire [20:0] gcore_slave_data_addr;
    wire [47:0] gcore_slave_data_in;
    wire [47:0] gcore_slave_data_in_from_sram;
    wire [47:0] gcore_slave_data_in_from_cpg;
    wire [47:0] gcore_slave_data_out;
    wire        gcore_slave_data_we;
    wire        gcore_slave_data_rd;
    wire        gcore_slave_data_sel;
    wire        gcore_slave_data_ready;
    wire        gcore_slave_data_ready_from_sram;
    wire        gcore_slave_data_ready_from_cpg;

    assign gcore_slave_data_sel     = gcore_slave_data_we || gcore_slave_data_rd;
    assign gcore_slave_data_ready   = ~gcore_slave_data_sel ||
                                    ((~gcore_slave_data_addr[20]) ? gcore_slave_data_ready_from_sram : gcore_slave_data_ready_from_cpg);
    assign gcore_slave_data_in      = (~gcore_slave_data_addr[20]) ? gcore_slave_data_in_from_sram : gcore_slave_data_in_from_cpg;

    GCore gcore_slave(
        .clk(clk),
        .rst(rst),
        .inst_addr(gcore_slave_inst_addr),
        .inst_in(gcore_slave_rom[gcore_slave_inst_addr[7:2]]),
        .inst_valid(1'b1),
        .data_addr(gcore_slave_data_addr),
        .data_in(gcore_slave_data_in),
        .data_out(gcore_slave_data_out),
        .data_we(gcore_slave_data_we),
        .data_rd(gcore_slave_data_rd),
        .data_sel(),
        .data_ready(gcore_slave_data_ready)
    );

    wire [19:0] vga_addr;
    wire [47:0] vga_data;
    wire        vga_sel;
    wire        vga_valid;
    wire [47:0] vga_offset;
    wire        vga_offset_sel;

    vga vga(
        .clk(clk),
        .clk_vga(clk_vga),
        .rst(rst),

        .vga_b(vga_b),
        .vga_g(vga_g),
        .vga_r(vga_r),
        .vga_hs(vga_hs),
        .vga_vs(vga_vs),

        .vga_addr(vga_addr),
        .vga_data(vga_data),
        .vga_sel(vga_sel),
        .vga_valid(vga_valid),

        .vga_offset_in(vga_offset[19:0]),
        .vga_offset_sel(vga_offset_sel)
    );

    coprocessor_gpu cpg(
        .clk(clk),
        .rst(rst),

        .addr_0(gcore_master_data_addr[19:0]),
        .data_in_0(gcore_master_data_out),
        .data_out_0(gcore_master_data_in_from_cpg),
        .data_sel_0(gcore_master_data_addr[20] && gcore_master_data_sel),
        .data_we_0(gcore_master_data_addr[20] && gcore_master_data_we),
        .data_ready_0(gcore_master_data_ready_from_cpg),

        .addr_1(gcore_slave_data_addr[19:0]),
        .data_in_1(gcore_slave_data_out),
        .data_out_1(gcore_slave_data_in_from_cpg),
        .data_sel_1(gcore_slave_data_addr[20] && gcore_slave_data_sel),
        .data_we_1(gcore_slave_data_addr[20] && gcore_slave_data_we),
        .data_ready_1(gcore_slave_data_ready_from_cpg),

        .vga_offset_sel(vga_offset_sel),
        .vga_offset(vga_offset),
        .interrupt()
    );

    sram sram(
        .clk(clk),
        .rst(rst),

        .sram_addr(sram_addr),
        .sram_dq(sram_dq),
        .sram_ce(sram_ce),
        .sram_oen(sram_oen),
        .sram_wen(sram_wen),

        .vga_addr(vga_addr),
        .vga_data(vga_data),
        .vga_sel(vga_sel),
        .vga_valid(vga_valid),

        .gpu_master_addr(gcore_master_data_addr[19:0]),
        .gpu_master_data_o(gcore_master_data_in_from_sram),
        .gpu_master_data_i(gcore_master_data_out),
        .gpu_master_sel((~gcore_master_data_addr[20]) && gcore_master_data_sel),
        .gpu_master_we((~gcore_master_data_addr[20]) && gcore_master_data_we),
        .gpu_master_valid(gcore_master_data_ready_from_sram),

        .gpu_slave_addr(gcore_slave_data_addr[19:0]),
        .gpu_slave_data_o(gcore_slave_data_in_from_sram),
        .gpu_slave_data_i(gcore_slave_data_out),
        .gpu_slave_sel((~gcore_slave_data_addr[20]) && gcore_slave_data_sel),
        .gpu_slave_we((~gcore_slave_data_addr[20]) && gcore_slave_data_we),
        .gpu_slave_valid(gcore_slave_data_ready_from_sram)
    );

    assign disp_value = vga_data[31:0];

endmodule
