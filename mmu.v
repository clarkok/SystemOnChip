module MemoryManageUnit(
    input  clk,
    input  rst,

    input  [ADDR_WIDTH-1:0] inst_addr,
    output [DATA_WIDTH-1:0] inst_out,
    output inst_valid,

    output [ADDR_WIDTH-1:0] inst_addr_o,
    input  [DATA_WIDTH-1:0] inst_in,
    input  inst_valid_i,

    input  [ADDR_WIDTH-1:0] data_addr,
    output [DATA_WIDTH-1:0] data_out,
    input  [DATA_WIDTH-1:0] data_in,
    input  data_we,
    input  data_rd,
    input  [3:0] data_sel,
    output data_ready,

    output [ADDR_WIDTH-1:0] data_addr_o,
    input  [DATA_WIDTH-1:0] data_out_i,
    output [DATA_WIDTH-1:0] data_in_o,
    output data_we_o,
    output data_rd_o,
    output [3:0] data_sel_o,
    input  data_ready_i,
    output cacheable,

    output [4:0] cp0_addr_r,
    input  [DATA_WIDTH-1:0] cp0_data_r,

    output cp0_we,
    output [4:0] cp0_addr_w,
    output [DATA_WIDTH-1:0] cp0_data_w,

    output pf_exception
    );

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter CP0_REASON_ADDR = 10;
    parameter CP0_PT_ADDR = 11;

    reg [63:0] i_tlb [0:31];
    reg [63:0] d_tlb [0:31];

    task init;
    begin
        integer i;
        for (i = 0; i < 32; i = i + 1) begin
            i_tlb[i] <= 64'b0;
            d_tlb[i] <= 64'b0;
        end
    end
    endtask

    wire [19:0] inst_vpn = inst_addr[31:12];
    wire [19:0] data_vpn = inst_addr[31:12];

    wire [4:0] inst_tlb_index =
        i_tlb[ 1][63:44] == inst_vpn ? 5'd01 :
        i_tlb[ 2][63:44] == inst_vpn ? 5'd02 :
        i_tlb[ 3][63:44] == inst_vpn ? 5'd03 :
        i_tlb[ 4][63:44] == inst_vpn ? 5'd04 :
        i_tlb[ 5][63:44] == inst_vpn ? 5'd05 :
        i_tlb[ 6][63:44] == inst_vpn ? 5'd06 :
        i_tlb[ 7][63:44] == inst_vpn ? 5'd07 :
        i_tlb[ 8][63:44] == inst_vpn ? 5'd08 :
        i_tlb[ 9][63:44] == inst_vpn ? 5'd09 :
        i_tlb[10][63:44] == inst_vpn ? 5'd10 :
        i_tlb[11][63:44] == inst_vpn ? 5'd11 :
        i_tlb[12][63:44] == inst_vpn ? 5'd12 :
        i_tlb[13][63:44] == inst_vpn ? 5'd13 :
        i_tlb[14][63:44] == inst_vpn ? 5'd14 :
        i_tlb[15][63:44] == inst_vpn ? 5'd15 :
        i_tlb[16][63:44] == inst_vpn ? 5'd16 :
        i_tlb[17][63:44] == inst_vpn ? 5'd17 :
        i_tlb[18][63:44] == inst_vpn ? 5'd18 :
        i_tlb[19][63:44] == inst_vpn ? 5'd19 :
        i_tlb[20][63:44] == inst_vpn ? 5'd20 :
        i_tlb[21][63:44] == inst_vpn ? 5'd21 :
        i_tlb[22][63:44] == inst_vpn ? 5'd22 :
        i_tlb[23][63:44] == inst_vpn ? 5'd23 :
        i_tlb[24][63:44] == inst_vpn ? 5'd24 :
        i_tlb[25][63:44] == inst_vpn ? 5'd25 :
        i_tlb[26][63:44] == inst_vpn ? 5'd26 :
        i_tlb[27][63:44] == inst_vpn ? 5'd27 :
        i_tlb[28][63:44] == inst_vpn ? 5'd28 :
        i_tlb[29][63:44] == inst_vpn ? 5'd29 :
        i_tlb[30][63:44] == inst_vpn ? 5'd30 :
        i_tlb[31][63:44] == inst_vpn ? 5'd31 :
                                       5'd00;
    wire [4:0] data_tlb_index =
        d_tlb[ 1][63:44] == data_vpn ? 5'd01 :
        d_tlb[ 2][63:44] == data_vpn ? 5'd02 :
        d_tlb[ 3][63:44] == data_vpn ? 5'd03 :
        d_tlb[ 4][63:44] == data_vpn ? 5'd04 :
        d_tlb[ 5][63:44] == data_vpn ? 5'd05 :
        d_tlb[ 6][63:44] == data_vpn ? 5'd06 :
        d_tlb[ 7][63:44] == data_vpn ? 5'd07 :
        d_tlb[ 8][63:44] == data_vpn ? 5'd08 :
        d_tlb[ 9][63:44] == data_vpn ? 5'd09 :
        d_tlb[10][63:44] == data_vpn ? 5'd10 :
        d_tlb[11][63:44] == data_vpn ? 5'd11 :
        d_tlb[12][63:44] == data_vpn ? 5'd12 :
        d_tlb[13][63:44] == data_vpn ? 5'd13 :
        d_tlb[14][63:44] == data_vpn ? 5'd14 :
        d_tlb[15][63:44] == data_vpn ? 5'd15 :
        d_tlb[16][63:44] == data_vpn ? 5'd16 :
        d_tlb[17][63:44] == data_vpn ? 5'd17 :
        d_tlb[18][63:44] == data_vpn ? 5'd18 :
        d_tlb[19][63:44] == data_vpn ? 5'd19 :
        d_tlb[20][63:44] == data_vpn ? 5'd20 :
        d_tlb[21][63:44] == data_vpn ? 5'd21 :
        d_tlb[22][63:44] == data_vpn ? 5'd22 :
        d_tlb[23][63:44] == data_vpn ? 5'd23 :
        d_tlb[24][63:44] == data_vpn ? 5'd24 :
        d_tlb[25][63:44] == data_vpn ? 5'd25 :
        d_tlb[26][63:44] == data_vpn ? 5'd26 :
        d_tlb[27][63:44] == data_vpn ? 5'd27 :
        d_tlb[28][63:44] == data_vpn ? 5'd28 :
        d_tlb[29][63:44] == data_vpn ? 5'd29 :
        d_tlb[30][63:44] == data_vpn ? 5'd30 :
        d_tlb[31][63:44] == data_vpn ? 5'd31 :
                                       5'd00;

    assign inst_addr_o = {i_tlb[inst_tlb_index][31:12], inst_addr[11:0]};
    assign data_addr_o = {d_tlb[data_tlb_index][31:12], data_addr[11:0]};

endmodule
