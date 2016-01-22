`include "functions.vh"

module inst_cache(
    input  clk,
    input  rst,

    input  [31:0] inst_addr,
    output [31:0] inst_in,
    output        inst_valid,

    output [31:0] addr_o,
    input  [31:0] data_i,
    output [31:0] data_o,
    output        we_o,
    output        rd_o,
    input         ack_i,

    input         fence
    );

    parameter CACHE_WIDTH   = 512;
    parameter CACHE_LINES   = 64;

    localparam CACHE_BYTES  = CACHE_WIDTH / 8;
    localparam CACHE_WORDS  = CACHE_BYTES / 4;

    localparam LINE_BITS    = `GET_WIDTH(CACHE_BYTES-1);
    localparam HASH_BITS    = `GET_WIDTH(CACHE_LINES-1);
    localparam TAG_BITS     = 32 - HASH_BITS - LINE_BITS;

    reg [CACHE_WIDTH-1:0] cache  [0:CACHE_LINES-1];
    reg [TAG_BITS-1:0]    tags   [0:CACHE_LINES-1];
    reg                   valids [0:CACHE_LINES-1];

    reg [31:0]  inst_in_r;
    reg [31:0]  addr_o_r;

    wire [TAG_BITS-1:0]  tag    = inst_addr[31:HASH_BITS+LINE_BITS];
    wire [HASH_BITS-1:0] hash   = inst_addr[HASH_BITS+LINE_BITS-1:LINE_BITS];
    wire [LINE_BITS-1:0] offset = inst_addr[LINE_BITS-1:0];

    wire [CACHE_WIDTH-1:0]  cached_line = cache[hash];

    localparam  S_IDLE = CACHE_WORDS + 1,
                S_READ = 0,
                S_END  = CACHE_WORDS;
    reg [`GET_WIDTH(CACHE_WORDS):0] state;

    assign inst_in      = inst_in_r;
    assign inst_valid   = valids[hash] && (tags[hash] == tag);
    assign addr_o       = addr_o_r;
    assign data_o       = 32'h0;
    assign we_o         = 1'b0;
    assign rd_o         = (state >= S_READ && state < S_END);

    always @* begin
        case (offset[LINE_BITS-1:2])
            4'h0: inst_in_r     = cached_line[9'h01f:9'h000];
            4'h1: inst_in_r     = cached_line[9'h03f:9'h020];
            4'h2: inst_in_r     = cached_line[9'h05f:9'h040];
            4'h3: inst_in_r     = cached_line[9'h07f:9'h060];
            4'h4: inst_in_r     = cached_line[9'h09f:9'h080];
            4'h5: inst_in_r     = cached_line[9'h0bf:9'h0a0];
            4'h6: inst_in_r     = cached_line[9'h0df:9'h0c0];
            4'h7: inst_in_r     = cached_line[9'h0ff:9'h0e0];
            4'h8: inst_in_r     = cached_line[9'h11f:9'h100];
            4'h9: inst_in_r     = cached_line[9'h13f:9'h120];
            4'ha: inst_in_r     = cached_line[9'h15f:9'h140];
            4'hb: inst_in_r     = cached_line[9'h17f:9'h160];
            4'hc: inst_in_r     = cached_line[9'h19f:9'h180];
            4'hd: inst_in_r     = cached_line[9'h1bf:9'h1a0];
            4'he: inst_in_r     = cached_line[9'h1df:9'h1c0];
            4'hf: inst_in_r     = cached_line[9'h1ff:9'h1e0];
        endcase
    end

    task init;
    integer i;
    begin
        for (i = 0; i < CACHE_LINES; i = i + 1) begin
            cache[i]    <= {CACHE_WIDTH{1'b0}};
            tags[i]     <= {TAG_BITS{1'b0}};
            valids[i]   <= 1'b0;
        end

        state       <= S_IDLE;
        addr_o_r    <= 0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst || fence) init();
        else begin
            case (state)
                S_IDLE: begin
                    if (~inst_valid) begin
                        addr_o_r        <= {tag, hash, 6'b0};
                        valids[hash]    <= 1'b0;
                        state           <= S_READ;
                        tags[hash]      <= tag;
                    end
                end
                S_END: begin
                    state           <= S_IDLE;
                    valids[hash]    <= 1'b1;
                end
                default: begin
                    if (ack_i) begin
                        if ({tag, hash} != inst_addr[31:LINE_BITS]) begin   // if address changed when reading
                            state   <= S_IDLE;                              // interrupt, leaving cache line invalid
                        end
                        else begin
                            case (state)
                                4'h0: cache[hash][9'h01f:9'h000]    <= data_i;
                                4'h1: cache[hash][9'h03f:9'h020]    <= data_i;
                                4'h2: cache[hash][9'h05f:9'h040]    <= data_i;
                                4'h3: cache[hash][9'h07f:9'h060]    <= data_i;
                                4'h4: cache[hash][9'h09f:9'h080]    <= data_i;
                                4'h5: cache[hash][9'h0bf:9'h0a0]    <= data_i;
                                4'h6: cache[hash][9'h0df:9'h0c0]    <= data_i;
                                4'h7: cache[hash][9'h0ff:9'h0e0]    <= data_i;
                                4'h8: cache[hash][9'h11f:9'h100]    <= data_i;
                                4'h9: cache[hash][9'h13f:9'h120]    <= data_i;
                                4'ha: cache[hash][9'h15f:9'h140]    <= data_i;
                                4'hb: cache[hash][9'h17f:9'h160]    <= data_i;
                                4'hc: cache[hash][9'h19f:9'h180]    <= data_i;
                                4'hd: cache[hash][9'h1bf:9'h1a0]    <= data_i;
                                4'he: cache[hash][9'h1df:9'h1c0]    <= data_i;
                                4'hf: cache[hash][9'h1ff:9'h1e0]    <= data_i;
                            endcase

                            state       <= state + 1'b1;
                            addr_o_r    <= addr_o_r + 3'h4;
                        end
                    end
                end
            endcase
        end
    end
endmodule
