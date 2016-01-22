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

module data_cache(
    input  clk,
    input  rst,

    input  [31:0] data_addr,
    output [31:0] data_in,
    input  [31:0] data_out,
    input         data_we,
    input         data_rd,
    input  [3:0]  data_sel,
    input         data_sign_ext,
    output        data_ready,

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
    reg                   dirties[0:CACHE_LINES-1];

    reg [31:0] data_in_b;
    reg [31:0] data_in_r;
    reg [31:0] addr_o_r;
    reg [31:0] data_o_r;

    wire [TAG_BITS-1:0]  tag    = data_addr[31:HASH_BITS+LINE_BITS];
    wire [HASH_BITS-1:0] hash   = data_addr[HASH_BITS+LINE_BITS-1:LINE_BITS];
    wire [LINE_BITS-1:0] offset = data_addr[LINE_BITS-1:0];

    wire [CACHE_WIDTH-1:0]  cached_line = cache[hash];

    localparam  S_IDLE      = CACHE_WORDS * 2 + 2,
                S_READ      = 0,
                S_READ_END  = CACHE_WORDS,
                S_WRITE     = CACHE_WORDS + 1,
                S_WRITE_END = CACHE_WORDS * 2 + 1;
    reg [`GET_WIDTH(S_WRITE_END-1)-1:0] state;

    assign data_in      = data_in_r;
    assign data_ready   = valids[hash] && (tags[hash] == tag) && (state == S_IDLE);
    assign addr_o       = addr_o_r;
    assign data_o       = data_o_r;
    assign we_o         = (state >= S_WRITE && state < S_WRITE_END);
    assign rd_o         = (state >= S_READ && state < S_READ_END);

    always @* begin
        case (offset[LINE_BITS-1:2])
            4'h0: data_in_b     = cached_line[9'h01f:9'h000];
            4'h1: data_in_b     = cached_line[9'h03f:9'h020];
            4'h2: data_in_b     = cached_line[9'h05f:9'h040];
            4'h3: data_in_b     = cached_line[9'h07f:9'h060];
            4'h4: data_in_b     = cached_line[9'h09f:9'h080];
            4'h5: data_in_b     = cached_line[9'h0bf:9'h0a0];
            4'h6: data_in_b     = cached_line[9'h0df:9'h0c0];
            4'h7: data_in_b     = cached_line[9'h0ff:9'h0e0];
            4'h8: data_in_b     = cached_line[9'h11f:9'h100];
            4'h9: data_in_b     = cached_line[9'h13f:9'h120];
            4'ha: data_in_b     = cached_line[9'h15f:9'h140];
            4'hb: data_in_b     = cached_line[9'h17f:9'h160];
            4'hc: data_in_b     = cached_line[9'h19f:9'h180];
            4'hd: data_in_b     = cached_line[9'h1bf:9'h1a0];
            4'he: data_in_b     = cached_line[9'h1df:9'h1c0];
            4'hf: data_in_b     = cached_line[9'h1ff:9'h1e0];
        endcase

        case (data_sel)
            4'b0001:    data_in_r   = {{24{data_sign_ext & data_in_b[ 7]}}, data_in_b[ 7:0]};
            4'b0011:    data_in_r   = {{16{data_sign_ext & data_in_b[15]}}, data_in_b[15:0]};
            4'b1111:    data_in_r   =                                       data_in_b;
        endcase
    end

    always @* begin
        case (addr_o_r[LINE_BITS-1:2])
            4'h0: data_o_r      = cached_line[9'h01f:9'h000];
            4'h1: data_o_r      = cached_line[9'h03f:9'h020];
            4'h2: data_o_r      = cached_line[9'h05f:9'h040];
            4'h3: data_o_r      = cached_line[9'h07f:9'h060];
            4'h4: data_o_r      = cached_line[9'h09f:9'h080];
            4'h5: data_o_r      = cached_line[9'h0bf:9'h0a0];
            4'h6: data_o_r      = cached_line[9'h0df:9'h0c0];
            4'h7: data_o_r      = cached_line[9'h0ff:9'h0e0];
            4'h8: data_o_r      = cached_line[9'h11f:9'h100];
            4'h9: data_o_r      = cached_line[9'h13f:9'h120];
            4'ha: data_o_r      = cached_line[9'h15f:9'h140];
            4'hb: data_o_r      = cached_line[9'h17f:9'h160];
            4'hc: data_o_r      = cached_line[9'h19f:9'h180];
            4'hd: data_o_r      = cached_line[9'h1bf:9'h1a0];
            4'he: data_o_r      = cached_line[9'h1df:9'h1c0];
            4'hf: data_o_r      = cached_line[9'h1ff:9'h1e0];
        endcase
    end

    task init;
    integer i;
    begin
        for (i = 0; i < CACHE_LINES; i = i + 1) begin
            cache[i]    <= {CACHE_WIDTH{1'b0}};
            tags[i]     <= {TAG_BITS{1'b0}};
            valids[i]   <= 1'b0;
            dirties[i]  <= 1'b0;
        end

        state       <= S_IDLE;
        addr_o_r    <= 32'b0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            case (state)
                S_IDLE: begin
                    // TODO if (fence)
                    case (1)
                        data_ready:             state   <= S_IDLE;
                        ~valids[hash]:    begin state   <= S_READ;  addr_o_r    <= {tag, hash, 6'b0};   tags[hash]  <= tag; end
                        dirties[hash]:    begin state   <= S_WRITE; addr_o_r    <= {tags[hash], hash, 6'b0};    end
                        default:          begin state   <= S_READ;  addr_o_r    <= {tag, hash, 6'b0};   tags[hash]  <= tag; end
                    endcase
                end
                S_READ_END:               begin state   <= S_IDLE;  valids[hash]    <= 1'b1;    end
                S_WRITE_END: begin
                    if (data_rd)          begin state   <= S_READ;  addr_o_r    <= {tag, hash, 6'b0};   tags[hash]  <= tag; end
                    else                  begin state   <= S_IDLE;  dirties[hash]   <= 1'b0;    end
                end
                default: begin
                    if (ack_i) begin
                        if (state >= S_READ && state < S_READ_END) begin
                            case (addr_o_r[LINE_BITS-1:2])
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
                        end
                        state       <= state + 1;
                        addr_o_r    <= addr_o_r + 3'h4;
                    end
                end
            endcase
            if (valids[hash] && data_ready && data_we) begin
                dirties[hash]   <= 1'b1;
                case (data_sel)
                    4'b0001: begin
                        case (data_addr[LINE_BITS-1:0])
                            6'h00: cache[hash][9'h007:9'h000]   <= data_out[7:0];
                            6'h01: cache[hash][9'h00f:9'h008]   <= data_out[7:0];
                            6'h02: cache[hash][9'h017:9'h010]   <= data_out[7:0];
                            6'h03: cache[hash][9'h01f:9'h018]   <= data_out[7:0];
                            6'h04: cache[hash][9'h027:9'h020]   <= data_out[7:0];
                            6'h05: cache[hash][9'h02f:9'h028]   <= data_out[7:0];
                            6'h06: cache[hash][9'h037:9'h030]   <= data_out[7:0];
                            6'h07: cache[hash][9'h03f:9'h038]   <= data_out[7:0];
                            6'h08: cache[hash][9'h047:9'h040]   <= data_out[7:0];
                            6'h09: cache[hash][9'h04f:9'h048]   <= data_out[7:0];
                            6'h0a: cache[hash][9'h057:9'h050]   <= data_out[7:0];
                            6'h0b: cache[hash][9'h05f:9'h058]   <= data_out[7:0];
                            6'h0c: cache[hash][9'h067:9'h060]   <= data_out[7:0];
                            6'h0d: cache[hash][9'h06f:9'h068]   <= data_out[7:0];
                            6'h0e: cache[hash][9'h077:9'h070]   <= data_out[7:0];
                            6'h0f: cache[hash][9'h07f:9'h078]   <= data_out[7:0];
                            6'h10: cache[hash][9'h087:9'h080]   <= data_out[7:0];
                            6'h11: cache[hash][9'h08f:9'h088]   <= data_out[7:0];
                            6'h12: cache[hash][9'h097:9'h090]   <= data_out[7:0];
                            6'h13: cache[hash][9'h09f:9'h098]   <= data_out[7:0];
                            6'h14: cache[hash][9'h0a7:9'h0a0]   <= data_out[7:0];
                            6'h15: cache[hash][9'h0af:9'h0a8]   <= data_out[7:0];
                            6'h16: cache[hash][9'h0b7:9'h0b0]   <= data_out[7:0];
                            6'h17: cache[hash][9'h0bf:9'h0b8]   <= data_out[7:0];
                            6'h18: cache[hash][9'h0c7:9'h0c0]   <= data_out[7:0];
                            6'h19: cache[hash][9'h0cf:9'h0c8]   <= data_out[7:0];
                            6'h1a: cache[hash][9'h0d7:9'h0d0]   <= data_out[7:0];
                            6'h1b: cache[hash][9'h0df:9'h0d8]   <= data_out[7:0];
                            6'h1c: cache[hash][9'h0e7:9'h0e0]   <= data_out[7:0];
                            6'h1d: cache[hash][9'h0ef:9'h0e8]   <= data_out[7:0];
                            6'h1e: cache[hash][9'h0f7:9'h0f0]   <= data_out[7:0];
                            6'h1f: cache[hash][9'h0ff:9'h0f8]   <= data_out[7:0];
                            6'h20: cache[hash][9'h107:9'h100]   <= data_out[7:0];
                            6'h21: cache[hash][9'h10f:9'h108]   <= data_out[7:0];
                            6'h22: cache[hash][9'h117:9'h110]   <= data_out[7:0];
                            6'h23: cache[hash][9'h11f:9'h118]   <= data_out[7:0];
                            6'h24: cache[hash][9'h127:9'h120]   <= data_out[7:0];
                            6'h25: cache[hash][9'h12f:9'h128]   <= data_out[7:0];
                            6'h26: cache[hash][9'h137:9'h130]   <= data_out[7:0];
                            6'h27: cache[hash][9'h13f:9'h138]   <= data_out[7:0];
                            6'h28: cache[hash][9'h147:9'h140]   <= data_out[7:0];
                            6'h29: cache[hash][9'h14f:9'h148]   <= data_out[7:0];
                            6'h2a: cache[hash][9'h157:9'h150]   <= data_out[7:0];
                            6'h2b: cache[hash][9'h15f:9'h158]   <= data_out[7:0];
                            6'h2c: cache[hash][9'h167:9'h160]   <= data_out[7:0];
                            6'h2d: cache[hash][9'h16f:9'h168]   <= data_out[7:0];
                            6'h2e: cache[hash][9'h177:9'h170]   <= data_out[7:0];
                            6'h2f: cache[hash][9'h17f:9'h178]   <= data_out[7:0];
                            6'h30: cache[hash][9'h187:9'h180]   <= data_out[7:0];
                            6'h31: cache[hash][9'h18f:9'h188]   <= data_out[7:0];
                            6'h32: cache[hash][9'h197:9'h190]   <= data_out[7:0];
                            6'h33: cache[hash][9'h19f:9'h198]   <= data_out[7:0];
                            6'h34: cache[hash][9'h1a7:9'h1a0]   <= data_out[7:0];
                            6'h35: cache[hash][9'h1af:9'h1a8]   <= data_out[7:0];
                            6'h36: cache[hash][9'h1b7:9'h1b0]   <= data_out[7:0];
                            6'h37: cache[hash][9'h1bf:9'h1b8]   <= data_out[7:0];
                            6'h38: cache[hash][9'h1c7:9'h1c0]   <= data_out[7:0];
                            6'h39: cache[hash][9'h1cf:9'h1c8]   <= data_out[7:0];
                            6'h3a: cache[hash][9'h1d7:9'h1d0]   <= data_out[7:0];
                            6'h3b: cache[hash][9'h1df:9'h1d8]   <= data_out[7:0];
                            6'h3c: cache[hash][9'h1e7:9'h1e0]   <= data_out[7:0];
                            6'h3d: cache[hash][9'h1ef:9'h1e8]   <= data_out[7:0];
                            6'h3e: cache[hash][9'h1f7:9'h1f0]   <= data_out[7:0];
                            6'h3f: cache[hash][9'h1ff:9'h1f8]   <= data_out[7:0];
                        endcase
                    end
                    4'b0011: begin
                        case (data_addr[LINE_BITS-1:1])
                            5'h00: cache[hash][9'h00f:9'h000]   <= data_out[15:0];
                            5'h01: cache[hash][9'h01f:9'h010]   <= data_out[15:0];
                            5'h02: cache[hash][9'h02f:9'h020]   <= data_out[15:0];
                            5'h03: cache[hash][9'h03f:9'h030]   <= data_out[15:0];
                            5'h04: cache[hash][9'h04f:9'h040]   <= data_out[15:0];
                            5'h05: cache[hash][9'h05f:9'h050]   <= data_out[15:0];
                            5'h06: cache[hash][9'h06f:9'h060]   <= data_out[15:0];
                            5'h07: cache[hash][9'h07f:9'h070]   <= data_out[15:0];
                            5'h08: cache[hash][9'h08f:9'h080]   <= data_out[15:0];
                            5'h09: cache[hash][9'h09f:9'h090]   <= data_out[15:0];
                            5'h0a: cache[hash][9'h0af:9'h0a0]   <= data_out[15:0];
                            5'h0b: cache[hash][9'h0bf:9'h0b0]   <= data_out[15:0];
                            5'h0c: cache[hash][9'h0cf:9'h0c0]   <= data_out[15:0];
                            5'h0d: cache[hash][9'h0df:9'h0d0]   <= data_out[15:0];
                            5'h0e: cache[hash][9'h0ef:9'h0e0]   <= data_out[15:0];
                            5'h0f: cache[hash][9'h0ff:9'h0f0]   <= data_out[15:0];
                            5'h10: cache[hash][9'h10f:9'h100]   <= data_out[15:0];
                            5'h11: cache[hash][9'h11f:9'h110]   <= data_out[15:0];
                            5'h12: cache[hash][9'h12f:9'h120]   <= data_out[15:0];
                            5'h13: cache[hash][9'h13f:9'h130]   <= data_out[15:0];
                            5'h14: cache[hash][9'h14f:9'h140]   <= data_out[15:0];
                            5'h15: cache[hash][9'h15f:9'h150]   <= data_out[15:0];
                            5'h16: cache[hash][9'h16f:9'h160]   <= data_out[15:0];
                            5'h17: cache[hash][9'h17f:9'h170]   <= data_out[15:0];
                            5'h18: cache[hash][9'h18f:9'h180]   <= data_out[15:0];
                            5'h19: cache[hash][9'h19f:9'h190]   <= data_out[15:0];
                            5'h1a: cache[hash][9'h1af:9'h1a0]   <= data_out[15:0];
                            5'h1b: cache[hash][9'h1bf:9'h1b0]   <= data_out[15:0];
                            5'h1c: cache[hash][9'h1cf:9'h1c0]   <= data_out[15:0];
                            5'h1d: cache[hash][9'h1df:9'h1d0]   <= data_out[15:0];
                            5'h1e: cache[hash][9'h1ef:9'h1e0]   <= data_out[15:0];
                            5'h1f: cache[hash][9'h1ff:9'h1f0]   <= data_out[15:0];
                        endcase
                    end
                    4'b1111: begin
                        case (data_addr[LINE_BITS-1:2])
                            4'h0: cache[hash][9'h01f:9'h000]    <= data_out;
                            4'h1: cache[hash][9'h03f:9'h020]    <= data_out;
                            4'h2: cache[hash][9'h05f:9'h040]    <= data_out;
                            4'h3: cache[hash][9'h07f:9'h060]    <= data_out;
                            4'h4: cache[hash][9'h09f:9'h080]    <= data_out;
                            4'h5: cache[hash][9'h0bf:9'h0a0]    <= data_out;
                            4'h6: cache[hash][9'h0df:9'h0c0]    <= data_out;
                            4'h7: cache[hash][9'h0ff:9'h0e0]    <= data_out;
                            4'h8: cache[hash][9'h11f:9'h100]    <= data_out;
                            4'h9: cache[hash][9'h13f:9'h120]    <= data_out;
                            4'ha: cache[hash][9'h15f:9'h140]    <= data_out;
                            4'hb: cache[hash][9'h17f:9'h160]    <= data_out;
                            4'hc: cache[hash][9'h19f:9'h180]    <= data_out;
                            4'hd: cache[hash][9'h1bf:9'h1a0]    <= data_out;
                            4'he: cache[hash][9'h1df:9'h1c0]    <= data_out;
                            4'hf: cache[hash][9'h1ff:9'h1e0]    <= data_out;
                        endcase
                    end
                endcase
            end
        end
    end

endmodule
