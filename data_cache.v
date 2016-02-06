`include "functions.vh"

module data_cache(
    input  clk,
    input  rst,

    input  [31:0]   data_addr_i,
    output [31:0]   data_data_o,
    input  [31:0]   data_data_i,
    input  [1:0]    data_sel_i,
    input           data_we_i,
    input           data_rd_i,
    output          data_valid_o,

    input           mem_fc,
    output reg      hw_page_fault_o,

    output [31:0]   uncached_addr_o,
    input  [31:0]   uncached_data_i,
    output [31:0]   uncached_data_o,
    output [1:0]    uncached_sel_o,
    output          uncached_we_o,
    output          uncached_rd_o,
    input           uncached_valid_i,

    output reg [ 31:0]  addr_o,
    input      [255:0]  data_i,
    input      [ 31:0]  page_ent_i,
    output reg [255:0]  data_o,
    output reg          we_o,
    output reg          rd_o,
    input               ack_i,
    input               hw_page_fault_i
    );

    parameter UNCACHED_MASK = 32'hFFC00000;     // keep the most upper 4M bytes uncached

    localparam LINE_BITS    = 256;
    localparam LINE_COUNT   = 64;

    localparam LINE_BYTES   = LINE_BITS / 8;
    localparam OFF_BITS     = `GET_WIDTH(LINE_BYTES-1);
    localparam HASH_BITS    = `GET_WIDTH(LINE_COUNT-1);
    localparam TAG_BITS     = 32 - OFF_BITS - HASH_BITS;

    wire        data_uncached   = (data_addr_i & UNCACHED_MASK) == UNCACHED_MASK;

    // reg [LINE_BITS-1:0] caches  [0:LINE_COUNT-1];
    reg [31:0]          ents    [0:LINE_COUNT-1];
    reg [TAG_BITS-1:0]  tags    [0:LINE_COUNT-1];
    reg                 valids  [0:LINE_COUNT-1];
    reg                 dirties [0:LINE_COUNT-1];

    wire [OFF_BITS-1:0]     addr_off    = data_addr_i[OFF_BITS-1:0];
    wire [HASH_BITS-1:0]    addr_hash   = data_addr_i[HASH_BITS+OFF_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0]     addr_tag    = data_addr_i[31:HASH_BITS+OFF_BITS];

    wire                    cache_valid =  data_uncached || 
                                          (valids[addr_hash] && (tags[addr_hash] == addr_tag));
    wire [LINE_BITS-1:0]    cached_line;
    reg  [HASH_BITS:0]      next_dirty;
    reg  [31:0]             data_data_r;

    wire [HASH_BITS-1:0]    out_hash    = addr_o[HASH_BITS+OFF_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0]     out_tag     = addr_o[31:HASH_BITS+OFF_BITS];

    wire [HASH_BITS-1:0]    cache_addr;
    reg  [LINE_BITS-1:0]    cache_data_i;
    wire                    cache_we;

    data_cache_dram data_cache_dram(
        .clk(clk),
        .a(cache_addr),
        .d(cache_data_i),
        .spo(cached_line),
        .we(cache_we)
    );

    localparam  S_IDLE  = 0,
                S_READ  = 1,
                S_WRITE = 2,
                S_FENCE = 3;

    reg [1:0] state;

    assign cache_addr       = (state == S_IDLE) ?   addr_hash :
                              (state == S_FENCE) ?  next_dirty[5:0] : 
                                                    out_hash;

    assign data_valid_o     = data_uncached
                                ? uncached_valid_i
                                :((cache_valid || mem_fc) && (state == S_IDLE));
    assign data_data_o      = data_uncached
                                ? uncached_data_i
                                : data_data_r;
    assign uncached_addr_o  = data_addr_i;
    assign uncached_data_o  = data_data_i;
    assign uncached_sel_o   = data_sel_i;
    assign uncached_we_o    = data_uncached & data_we_i;
    assign uncached_rd_o    = data_uncached & data_rd_i;

    always @* begin
        if (state == S_READ && ack_i)   cache_data_i    = data_i;
        else begin
            case (data_sel_i)
                2'h0: begin
                    case (addr_off[OFF_BITS-1:0])
                        5'h00:  cache_data_i    = {cached_line[8'hFF:8'h08], data_data_i[7:0]};
                        5'h01:  cache_data_i    = {cached_line[8'hFF:8'h10], data_data_i[7:0], cached_line[8'h07:8'h00]};
                        5'h02:  cache_data_i    = {cached_line[8'hFF:8'h18], data_data_i[7:0], cached_line[8'h0f:8'h00]};
                        5'h03:  cache_data_i    = {cached_line[8'hFF:8'h20], data_data_i[7:0], cached_line[8'h17:8'h00]};
                        5'h04:  cache_data_i    = {cached_line[8'hFF:8'h28], data_data_i[7:0], cached_line[8'h1f:8'h00]};
                        5'h05:  cache_data_i    = {cached_line[8'hFF:8'h30], data_data_i[7:0], cached_line[8'h27:8'h00]};
                        5'h06:  cache_data_i    = {cached_line[8'hFF:8'h38], data_data_i[7:0], cached_line[8'h2f:8'h00]};
                        5'h07:  cache_data_i    = {cached_line[8'hFF:8'h40], data_data_i[7:0], cached_line[8'h37:8'h00]};
                        5'h08:  cache_data_i    = {cached_line[8'hFF:8'h48], data_data_i[7:0], cached_line[8'h3f:8'h00]};
                        5'h09:  cache_data_i    = {cached_line[8'hFF:8'h50], data_data_i[7:0], cached_line[8'h47:8'h00]};
                        5'h0a:  cache_data_i    = {cached_line[8'hFF:8'h58], data_data_i[7:0], cached_line[8'h4f:8'h00]};
                        5'h0b:  cache_data_i    = {cached_line[8'hFF:8'h60], data_data_i[7:0], cached_line[8'h57:8'h00]};
                        5'h0c:  cache_data_i    = {cached_line[8'hFF:8'h68], data_data_i[7:0], cached_line[8'h5f:8'h00]};
                        5'h0d:  cache_data_i    = {cached_line[8'hFF:8'h70], data_data_i[7:0], cached_line[8'h67:8'h00]};
                        5'h0e:  cache_data_i    = {cached_line[8'hFF:8'h78], data_data_i[7:0], cached_line[8'h6f:8'h00]};
                        5'h0f:  cache_data_i    = {cached_line[8'hFF:8'h80], data_data_i[7:0], cached_line[8'h77:8'h00]};
                        5'h10:  cache_data_i    = {cached_line[8'hFF:8'h88], data_data_i[7:0], cached_line[8'h7f:8'h00]};
                        5'h11:  cache_data_i    = {cached_line[8'hFF:8'h90], data_data_i[7:0], cached_line[8'h87:8'h00]};
                        5'h12:  cache_data_i    = {cached_line[8'hFF:8'h98], data_data_i[7:0], cached_line[8'h8f:8'h00]};
                        5'h13:  cache_data_i    = {cached_line[8'hFF:8'ha0], data_data_i[7:0], cached_line[8'h97:8'h00]};
                        5'h14:  cache_data_i    = {cached_line[8'hFF:8'ha8], data_data_i[7:0], cached_line[8'h9f:8'h00]};
                        5'h15:  cache_data_i    = {cached_line[8'hFF:8'hb0], data_data_i[7:0], cached_line[8'ha7:8'h00]};
                        5'h16:  cache_data_i    = {cached_line[8'hFF:8'hb8], data_data_i[7:0], cached_line[8'haf:8'h00]};
                        5'h17:  cache_data_i    = {cached_line[8'hFF:8'hc0], data_data_i[7:0], cached_line[8'hb7:8'h00]};
                        5'h18:  cache_data_i    = {cached_line[8'hFF:8'hc8], data_data_i[7:0], cached_line[8'hbf:8'h00]};
                        5'h19:  cache_data_i    = {cached_line[8'hFF:8'hd0], data_data_i[7:0], cached_line[8'hc7:8'h00]};
                        5'h1a:  cache_data_i    = {cached_line[8'hFF:8'hd8], data_data_i[7:0], cached_line[8'hcf:8'h00]};
                        5'h1b:  cache_data_i    = {cached_line[8'hFF:8'he0], data_data_i[7:0], cached_line[8'hd7:8'h00]};
                        5'h1c:  cache_data_i    = {cached_line[8'hFF:8'he8], data_data_i[7:0], cached_line[8'hdf:8'h00]};
                        5'h1d:  cache_data_i    = {cached_line[8'hFF:8'hf0], data_data_i[7:0], cached_line[8'he7:8'h00]};
                        5'h1e:  cache_data_i    = {cached_line[8'hFF:8'hf8], data_data_i[7:0], cached_line[8'hef:8'h00]};
                        5'h1f:  cache_data_i    = {                          data_data_i[7:0], cached_line[8'hf7:8'h00]};
                    endcase
                end
                2'h1: begin
                    case (addr_off[OFF_BITS-1:1])
                        4'h0:   cache_data_i    = {cached_line[8'hFF:8'h10], data_data_i[15:0]};
                        4'h1:   cache_data_i    = {cached_line[8'hFF:8'h20], data_data_i[15:0], cached_line[8'h0F:8'h00]};
                        4'h2:   cache_data_i    = {cached_line[8'hFF:8'h30], data_data_i[15:0], cached_line[8'h1F:8'h00]};
                        4'h3:   cache_data_i    = {cached_line[8'hFF:8'h40], data_data_i[15:0], cached_line[8'h2F:8'h00]};
                        4'h4:   cache_data_i    = {cached_line[8'hFF:8'h50], data_data_i[15:0], cached_line[8'h3F:8'h00]};
                        4'h5:   cache_data_i    = {cached_line[8'hFF:8'h60], data_data_i[15:0], cached_line[8'h4F:8'h00]};
                        4'h6:   cache_data_i    = {cached_line[8'hFF:8'h70], data_data_i[15:0], cached_line[8'h5F:8'h00]};
                        4'h7:   cache_data_i    = {cached_line[8'hFF:8'h80], data_data_i[15:0], cached_line[8'h6F:8'h00]};
                        4'h8:   cache_data_i    = {cached_line[8'hFF:8'h90], data_data_i[15:0], cached_line[8'h7F:8'h00]};
                        4'h9:   cache_data_i    = {cached_line[8'hFF:8'ha0], data_data_i[15:0], cached_line[8'h8F:8'h00]};
                        4'ha:   cache_data_i    = {cached_line[8'hFF:8'hb0], data_data_i[15:0], cached_line[8'h9F:8'h00]};
                        4'hb:   cache_data_i    = {cached_line[8'hFF:8'hc0], data_data_i[15:0], cached_line[8'haF:8'h00]};
                        4'hc:   cache_data_i    = {cached_line[8'hFF:8'hd0], data_data_i[15:0], cached_line[8'hbF:8'h00]};
                        4'hd:   cache_data_i    = {cached_line[8'hFF:8'he0], data_data_i[15:0], cached_line[8'hcF:8'h00]};
                        4'he:   cache_data_i    = {cached_line[8'hFF:8'hf0], data_data_i[15:0], cached_line[8'hdF:8'h00]};
                        4'hf:   cache_data_i    = {                          data_data_i[15:0], cached_line[8'heF:8'h00]};
                    endcase
                end
                2'h2: begin
                    case (addr_off[OFF_BITS-1:2])
                        3'h0:   cache_data_i    = {cached_line[8'hFF:8'h20], data_data_i};
                        3'h1:   cache_data_i    = {cached_line[8'hFF:8'h40], data_data_i, cached_line[8'h1F:8'h00]};
                        3'h2:   cache_data_i    = {cached_line[8'hFF:8'h60], data_data_i, cached_line[8'h3F:8'h00]};
                        3'h3:   cache_data_i    = {cached_line[8'hFF:8'h80], data_data_i, cached_line[8'h5F:8'h00]};
                        3'h4:   cache_data_i    = {cached_line[8'hFF:8'ha0], data_data_i, cached_line[8'h7F:8'h00]};
                        3'h5:   cache_data_i    = {cached_line[8'hFF:8'hc0], data_data_i, cached_line[8'h9F:8'h00]};
                        3'h6:   cache_data_i    = {cached_line[8'hFF:8'he0], data_data_i, cached_line[8'hbF:8'h00]};
                        3'h7:   cache_data_i    = {                          data_data_i, cached_line[8'hdF:8'h00]};
                    endcase
                end
            endcase
        end
    end
    assign cache_we     = (state == S_READ && ack_i) || 
                          (data_we_i && cache_valid && ~data_uncached && ents[addr_hash[1]]);

    task init;
    integer i;
    begin
        addr_o          <= 0;
        data_o          <= 0;
        we_o            <= 0;
        rd_o            <= 0;
        state           <= S_IDLE;
        hw_page_fault_o <= 0;
        for (i = 0; i < LINE_COUNT; i = i + 1) begin
            ents[i]     <= 32'b0;
            tags[i]     <= {TAG_BITS{1'b0}};
            valids[i]   <= 1'b0;
            dirties[i]  <= 1'b0;
        end
    end
    endtask

    initial init();

    integer i;
    always @(posedge clk) begin
        if (rst) init();
        else begin
            case (state)
                S_IDLE: begin
                    hw_page_fault_o     <= 0;
                    if (mem_fc) begin
                        state <= S_FENCE;
                        for (i = 0; i < LINE_COUNT; i = i + 1) begin
                            valids[i]   <= 1'b0;
                        end
                    end
                    else if (!(data_rd_i || data_we_i) || cache_valid) begin
                        state <= S_IDLE;
                    end
                    else if (dirties[addr_hash]) begin
                        state   <= S_WRITE;
                        addr_o  <={tags[addr_hash], addr_hash, {OFF_BITS{1'b0}}};
                        data_o  <= cached_line;
                        we_o    <= 1'b1;
                    end
                    else begin
                        state   <= S_READ;
                        addr_o  <={addr_tag, addr_hash, {OFF_BITS{1'b0}}};
                        rd_o    <= 1'b1;
                    end
                end
                S_READ: begin
                    if (ack_i) begin
                        state           <= S_IDLE;
                        rd_o            <= 1'b0;

                        ents[out_hash]      <= page_ent_i;
                        tags[out_hash]      <= out_tag;
                        valids[out_hash]    <= 1'b1;
                        hw_page_fault_o     <= hw_page_fault_i;
                    end
                end
                S_WRITE: begin
                    if (ack_i) begin
                        if (hw_page_fault_i) begin
                            state               <= S_IDLE;
                            we_o                <= 1'b0;
                            dirties[out_hash]   <= 1'b0;    // write failed, data lost
                            hw_page_fault_o     <= 1'b1;
                        end
                        else begin
                            dirties[out_hash]   <= 1'b0;
                            we_o                <= 1'b0;

                            state               <= S_READ;
                            addr_o              <= {addr_tag, addr_hash, {OFF_BITS{1'b0}}};
                            rd_o                <= 1'b1;
                        end
                    end
                end
                S_FENCE: begin
                    if (we_o) begin
                        if (ack_i) begin
                            we_o                    <= 1'b0;
                            dirties[next_dirty[5:0]]<= 1'b0;
                            state                   <= S_FENCE;
                        end
                    end
                    else begin
                        if (next_dirty == 7'h40)    state   <= S_IDLE;
                        else begin
                            we_o            <= 1'b1;
                            addr_o          <={tags[next_dirty[5:0]], next_dirty[5:0], {OFF_BITS{1'b0}}};
                            data_o          <= cached_line;
                        end
                    end
                end
            endcase
            if (data_we_i && (cache_valid && ~data_uncached)) begin
                dirties[addr_hash]  <= ents[addr_hash][1];
                hw_page_fault_o     <=~ents[addr_hash][1];
            end
        end
    end

    always @* begin
        case (addr_off[OFF_BITS-1:2])
            3'h0:   data_data_r = cached_line[ 31:  0];
            3'h1:   data_data_r = cached_line[ 63: 32];
            3'h2:   data_data_r = cached_line[ 95: 64];
            3'h3:   data_data_r = cached_line[127: 96];
            3'h4:   data_data_r = cached_line[159:128];
            3'h5:   data_data_r = cached_line[191:160];
            3'h6:   data_data_r = cached_line[223:192];
            3'h7:   data_data_r = cached_line[255:224];
        endcase
    end

    always @* begin
        case (1)
            dirties[6'h00]: next_dirty  = 7'h00;
            dirties[6'h01]: next_dirty  = 7'h01;
            dirties[6'h02]: next_dirty  = 7'h02;
            dirties[6'h03]: next_dirty  = 7'h03;
            dirties[6'h04]: next_dirty  = 7'h04;
            dirties[6'h05]: next_dirty  = 7'h05;
            dirties[6'h06]: next_dirty  = 7'h06;
            dirties[6'h07]: next_dirty  = 7'h07;
            dirties[6'h08]: next_dirty  = 7'h08;
            dirties[6'h09]: next_dirty  = 7'h09;
            dirties[6'h0a]: next_dirty  = 7'h0a;
            dirties[6'h0b]: next_dirty  = 7'h0b;
            dirties[6'h0c]: next_dirty  = 7'h0c;
            dirties[6'h0d]: next_dirty  = 7'h0d;
            dirties[6'h0e]: next_dirty  = 7'h0e;
            dirties[6'h0f]: next_dirty  = 7'h0f;
            dirties[6'h10]: next_dirty  = 7'h10;
            dirties[6'h11]: next_dirty  = 7'h11;
            dirties[6'h12]: next_dirty  = 7'h12;
            dirties[6'h13]: next_dirty  = 7'h13;
            dirties[6'h14]: next_dirty  = 7'h14;
            dirties[6'h15]: next_dirty  = 7'h15;
            dirties[6'h16]: next_dirty  = 7'h16;
            dirties[6'h17]: next_dirty  = 7'h17;
            dirties[6'h18]: next_dirty  = 7'h18;
            dirties[6'h19]: next_dirty  = 7'h19;
            dirties[6'h1a]: next_dirty  = 7'h1a;
            dirties[6'h1b]: next_dirty  = 7'h1b;
            dirties[6'h1c]: next_dirty  = 7'h1c;
            dirties[6'h1d]: next_dirty  = 7'h1d;
            dirties[6'h1e]: next_dirty  = 7'h1e;
            dirties[6'h1f]: next_dirty  = 7'h1f;
            dirties[6'h20]: next_dirty  = 7'h20;
            dirties[6'h21]: next_dirty  = 7'h21;
            dirties[6'h22]: next_dirty  = 7'h22;
            dirties[6'h23]: next_dirty  = 7'h23;
            dirties[6'h24]: next_dirty  = 7'h24;
            dirties[6'h25]: next_dirty  = 7'h25;
            dirties[6'h26]: next_dirty  = 7'h26;
            dirties[6'h27]: next_dirty  = 7'h27;
            dirties[6'h28]: next_dirty  = 7'h28;
            dirties[6'h29]: next_dirty  = 7'h29;
            dirties[6'h2a]: next_dirty  = 7'h2a;
            dirties[6'h2b]: next_dirty  = 7'h2b;
            dirties[6'h2c]: next_dirty  = 7'h2c;
            dirties[6'h2d]: next_dirty  = 7'h2d;
            dirties[6'h2e]: next_dirty  = 7'h2e;
            dirties[6'h2f]: next_dirty  = 7'h2f;
            dirties[6'h30]: next_dirty  = 7'h30;
            dirties[6'h31]: next_dirty  = 7'h31;
            dirties[6'h32]: next_dirty  = 7'h32;
            dirties[6'h33]: next_dirty  = 7'h33;
            dirties[6'h34]: next_dirty  = 7'h34;
            dirties[6'h35]: next_dirty  = 7'h35;
            dirties[6'h36]: next_dirty  = 7'h36;
            dirties[6'h37]: next_dirty  = 7'h37;
            dirties[6'h38]: next_dirty  = 7'h38;
            dirties[6'h39]: next_dirty  = 7'h39;
            dirties[6'h3a]: next_dirty  = 7'h3a;
            dirties[6'h3b]: next_dirty  = 7'h3b;
            dirties[6'h3c]: next_dirty  = 7'h3c;
            dirties[6'h3d]: next_dirty  = 7'h3d;
            dirties[6'h3e]: next_dirty  = 7'h3e;
            dirties[6'h3f]: next_dirty  = 7'h3f;
            default:        next_dirty  = 7'h40;
        endcase
    end

endmodule
