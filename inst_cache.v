`include "functions.vh"

module inst_cache(
    input  clk,
    input  rst,

    input  [31:0]   inst_addr_i,
    output [31:0]   inst_data_o,
    output          inst_valid_o,

    input           mem_fc,
    output          hw_page_fault_o,

    output     [ 31:0]  uncached_addr_o,
    input      [ 31:0]  uncached_data_i,
    output              uncached_rd_o,
    input               uncached_ack_i,

    output reg [ 31:0]  addr_o,
    input      [255:0]  data_i,
    output reg          rd_o,
    input               ack_i,
    input               hw_page_fault_i
    );

    parameter UNCACHED_MASK = 32'hFFFF_F000;

    localparam LINE_BITS    = 256;
    localparam LINE_COUNT   = 64;

    localparam LINE_BYTES   = LINE_BITS / 8;
    localparam OFF_BITS     = `GET_WIDTH(LINE_BYTES-1);
    localparam HASH_BITS    = `GET_WIDTH(LINE_COUNT-1);
    localparam TAG_BITS     = 32 - OFF_BITS - HASH_BITS;

    wire    inst_uncached   = (inst_addr_i & UNCACHED_MASK) == UNCACHED_MASK;

    reg [TAG_BITS-1:0]  tags    [0:LINE_COUNT-1];
    reg                 valids  [0:LINE_COUNT-1];

    wire [OFF_BITS-1:0]     addr_off    = inst_addr_i[OFF_BITS-1:0];
    wire [HASH_BITS-1:0]    addr_hash   = inst_addr_i[HASH_BITS+OFF_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0]     addr_tag    = inst_addr_i[31:HASH_BITS+OFF_BITS];

    wire [LINE_BITS-1:0]    cached_line;

    wire [HASH_BITS-1:0]    rd_hash = addr_o[HASH_BITS+OFF_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0]     rd_tag  = addr_o[31:HASH_BITS+OFF_BITS];

    inst_cache_dram inst_cache_dram(
        .clk(clk),
        .a(ack_i ? rd_hash : addr_hash),
        .d(data_i),
        .spo(cached_line),
        .we(ack_i)
    );

    reg  [31:0] inst_data_r;

    assign inst_data_o      = inst_uncached ? uncached_data_i : inst_data_r;
    assign inst_valid_o     = inst_uncached ? uncached_ack_i  : valids[addr_hash] && (tags[addr_hash] == addr_tag);
    assign hw_page_fault_o  = hw_page_fault_i;

    always @* begin
        case (addr_off[OFF_BITS-1:2])
            3'h0:   inst_data_r = cached_line[ 31:  0];
            3'h1:   inst_data_r = cached_line[ 63: 32];
            3'h2:   inst_data_r = cached_line[ 95: 64];
            3'h3:   inst_data_r = cached_line[127: 96];
            3'h4:   inst_data_r = cached_line[159:128];
            3'h5:   inst_data_r = cached_line[191:160];
            3'h6:   inst_data_r = cached_line[223:192];
            3'h7:   inst_data_r = cached_line[255:224];
        endcase
    end

    task init;
    integer i;
    begin
        addr_o  <= 0;
        rd_o    <= 0;
        for (i = 0; i < LINE_COUNT; i = i + 1) begin
            tags[i]     <= {TAG_BITS{1'b0}};
            valids[i]   <= 1'b0;
        end
    end
    endtask

    initial init();

    integer i;
    always @(posedge clk) begin
        if (rst) init();
        else begin
            if (rd_o) begin
                if (ack_i) begin
                    tags[rd_hash]       <= rd_tag;
                    valids[rd_hash]     <= ~hw_page_fault_i;
                    addr_o              <= 0;
                    rd_o                <= 0;
                end
            end
            else begin
                if (~inst_uncached && ~inst_valid_o) begin
                    addr_o  <= inst_addr_i;
                    rd_o    <= 1;
                end
            end

            if (mem_fc) begin
                for (i = 0; i < LINE_COUNT; i = i + 1)
                    valids[i]   <= 0;
            end
        end
    end
endmodule
