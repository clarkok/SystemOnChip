`include "functions.vh"

module ddr3_cache(
    input  clk,
    input  rst,

    input  [ 31:0]  addr_i,
    output [255:0]  data_o,
    input  [255:0]  data_i,
    input           we_i,
    input           rd_i,
    output          ack_o,

    output reg [ 28:0]  ctrl_addr_o,
    output     [255:0]  ctrl_data_o,
    input      [255:0]  ctrl_data_i,
    output reg          ctrl_we_o,
    output reg          ctrl_rd_o,
    input               ctrl_ack_i
    );

    parameter   CACHE_LINES     = 1024;

    localparam  ADDR_BITS       = 29;
    localparam  LINE_BYTES      = 32;
    localparam  OFF_BITS        = `GET_WIDTH(LINE_BYTES-1);
    localparam  HASH_BITS       = `GET_WIDTH(CACHE_LINES-1);
    localparam  TAG_BITS        = ADDR_BITS-HASH_BITS-OFF_BITS;

    reg  [HASH_BITS-1:0]    cache_addr_i;
    reg  [255:0]            cache_data_i;
    wire [255:0]            cache_data_o;
    reg                     cache_we_i;

    ddr3_cache_mem ddr3_cache_mem(
        .clka(clk),
        .addra(cache_addr_i),
        .dina(cache_data_i),
        .douta(cache_data_o),
        .wea(cache_we_i)
    );

    wire [HASH_BITS-1:0]    tags_addr_w;
    wire [HASH_BITS-1:0]    tags_addr_r;
    wire [TAG_BITS-1:0]     tags_data_o;
    wire [TAG_BITS-1:0]     tags_data_i;
    wire                    tags_we;
    ddr3_cache_tags ddr3_cache_tags(
        .clk(clk),
        .a(tags_addr_w),
        .d(tags_data_i),
        .dpra(tags_addr_r),
        .dpo(tags_data_o),
        .we(tags_we)
    );
    reg                     valids[0:CACHE_LINES-1];
    reg                     dirties[0:CACHE_LINES-1];

    localparam  S_INIT = 0,
                S_IDLE = 1,
                S_READ = 2,
                S_WRITE = 3,
                S_WAIT = 4,
                S_END = 5;

    reg  [`GET_WIDTH(S_END-1):0] state;

    wire [HASH_BITS-1:0]    addr_hash   = addr_i[HASH_BITS+OFF_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0]     addr_tag    = addr_i[ADDR_BITS-1:HASH_BITS+OFF_BITS];

    wire [HASH_BITS-1:0]    ctrl_hash   = ctrl_addr_o[HASH_BITS+OFF_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0]     ctrl_tag    = ctrl_addr_o[ADDR_BITS-1:HASH_BITS+OFF_BITS];

    wire cache_valid    = valids[addr_hash] && (addr_tag == tags_data_o);

    assign  data_o      = cache_data_o;
    assign  ack_o       =(state == S_END);
    assign  ctrl_data_o = cache_data_o;

    assign  tags_addr_w = state == S_IDLE ? addr_hash : ctrl_hash;
    assign  tags_addr_r = addr_hash;
    assign  tags_data_i = state == S_IDLE ? addr_tag  : ctrl_tag;
    assign  tags_we     = (state == S_IDLE && ~cache_valid && ~dirties[addr_hash] && we_i) || (state == S_READ && ctrl_ack_i);

    task init;
    integer i;
    begin
        ctrl_addr_o     <= 0;
        ctrl_we_o       <= 0;
        ctrl_rd_o       <= 0;
        state           <= S_INIT;
        cache_addr_i    <= 0;
        cache_data_i    <= 256'b0;
        cache_we_i      <= 0;

        for (i = 0; i < CACHE_LINES; i = i + 1) begin
            valids[i]   <= 1'b0;
            dirties[i]  <= 1'b0;
        end
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            case (state)
                S_INIT:     if (ctrl_ack_i)     state <= S_IDLE;
                S_IDLE: begin
                    case (1)
                        (rd_i && cache_valid): begin
                            cache_addr_i        <= addr_hash;
                            cache_we_i          <= 0;
                            state               <= S_WAIT;
                        end
                        (we_i && cache_valid): begin
                            cache_addr_i        <= addr_hash;
                            cache_data_i        <= data_i;
                            cache_we_i          <= 1;
                            dirties[addr_hash]  <= 1;
                            state               <= S_END;
                        end
                        (~cache_valid && dirties[addr_hash]): begin
                            cache_addr_i        <= addr_hash;
                            cache_we_i          <= 0;
                            ctrl_addr_o         <={tags_data_o, addr_hash, {OFF_BITS{1'b0}}};
                            ctrl_we_o           <= 1;
                            state               <= S_WRITE;
                        end
                        (~cache_valid && ~dirties[addr_hash] && we_i): begin
                            cache_addr_i        <= addr_hash;
                            cache_data_i        <= data_i;
                            cache_we_i          <= 1;
                            dirties[addr_hash]  <= 1;
                            valids[addr_hash]   <= 1;
                            state               <= S_END;
                        end
                        (~cache_valid && ~dirties[addr_hash] && rd_i): begin
                            ctrl_addr_o         <={addr_tag, addr_hash, {OFF_BITS{1'b0}}};
                            ctrl_rd_o           <= 1;
                            state               <= S_READ;
                        end
                    endcase
                end
                S_READ: begin
                    if (ctrl_ack_i) begin
                        ctrl_rd_o           <= 0;
                        cache_addr_i        <= addr_hash;
                        cache_data_i        <= ctrl_data_i;
                        cache_we_i          <= 1;
                        valids[ctrl_hash]   <= 1;
                        state               <= S_WAIT;
                    end
                end
                S_WRITE: begin
                    if (ctrl_ack_i) begin
                        ctrl_we_o           <= 0;
                        ctrl_rd_o           <= 1;
                        ctrl_addr_o         <={addr_tag, addr_hash, {OFF_BITS{1'b0}}};
                        dirties[ctrl_hash]  <= 0;
                        state               <= S_READ;
                    end
                end
                S_WAIT: begin
                    cache_we_i      <= 0;
                    state           <= S_END;
                end
                S_END: begin
                    state           <= S_IDLE;
                end
            endcase
        end
    end

endmodule
