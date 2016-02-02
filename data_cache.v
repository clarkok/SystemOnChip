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
    localparam LINE_COUNT   = 128;

    localparam LINE_BYTES   = LINE_BITS / 8;
    localparam OFF_BITS     = `GET_WIDTH(LINE_BYTES-1);
    localparam HASH_BITS    = `GET_WIDTH(LINE_COUNT-1);
    localparam TAG_BITS     = 32 - OFF_BITS - HASH_BITS;

    wire        data_uncached   = (data_addr_i & UNCACHED_MASK) == UNCACHED_MASK;

    reg [LINE_BITS-1:0] caches  [0:LINE_COUNT-1];
    reg [31:0]          ents    [0:LINE_COUNT-1];
    reg [TAG_BITS-1:0]  tags    [0:LINE_COUNT-1];
    reg                 valids  [0:LINE_COUNT-1];
    reg                 dirties [0:LINE_COUNT-1];

    wire [OFF_BITS-1:0]     addr_off    = data_addr_i[OFF_BITS-1:0];
    wire [HASH_BITS-1:0]    addr_hash   = data_addr_i[HASH_BITS+OFF_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0]     addr_tag    = data_addr_i[31:HASH_BITS+OFF_BITS];

    wire                    cache_valid =  data_uncached || 
                                          (valids[addr_hash] && (tags[addr_hash] == addr_tag));
    wire [LINE_BITS-1:0]    cached_line = caches[addr_hash];
    reg  [HASH_BITS:0]      next_dirty;
    reg  [31:0]             data_data_r;

    wire [HASH_BITS-1:0]    out_hash    = addr_o[HASH_BITS+OFF_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0]     out_tag     = addr_o[31:HASH_BITS+OFF_BITS];

    localparam  S_IDLE  = 0,
                S_READ  = 1,
                S_WRITE = 2,
                S_FENCE = 3;

    reg [1:0] state;

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
            caches[i]   <= {LINE_BITS{1'b0}};
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
                        data_o  <= caches[addr_hash];
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

                        caches[out_hash]    <= data_i;
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
                            dirties[next_dirty]     <= 1'b0;
                            state                   <= S_FENCE;
                        end
                    end
                    else begin
                        if (next_dirty == 8'h80)    state   <= S_IDLE;
                        else begin
                            we_o            <= 1'b1;
                            addr_o          <={tags[next_dirty], next_dirty, {OFF_BITS{1'b0}}};
                            data_o          <= caches[next_dirty];
                        end
                    end
                end
            endcase
            if (data_we_i && (cache_valid && ~data_uncached)) begin
                if (ents[addr_hash][1]) begin
                    case (data_sel_i)
                        2'h0: begin
                            case (addr_off[OFF_BITS-1:0])
                                5'h00:  caches[addr_hash][8'h07:8'h00]  <= data_data_i[7:0];
                                5'h01:  caches[addr_hash][8'h0f:8'h08]  <= data_data_i[7:0];
                                5'h02:  caches[addr_hash][8'h17:8'h10]  <= data_data_i[7:0];
                                5'h03:  caches[addr_hash][8'h1f:8'h18]  <= data_data_i[7:0];
                                5'h04:  caches[addr_hash][8'h27:8'h20]  <= data_data_i[7:0];
                                5'h05:  caches[addr_hash][8'h2f:8'h28]  <= data_data_i[7:0];
                                5'h06:  caches[addr_hash][8'h37:8'h30]  <= data_data_i[7:0];
                                5'h07:  caches[addr_hash][8'h3f:8'h38]  <= data_data_i[7:0];
                                5'h08:  caches[addr_hash][8'h47:8'h40]  <= data_data_i[7:0];
                                5'h09:  caches[addr_hash][8'h4f:8'h48]  <= data_data_i[7:0];
                                5'h0a:  caches[addr_hash][8'h57:8'h50]  <= data_data_i[7:0];
                                5'h0b:  caches[addr_hash][8'h5f:8'h58]  <= data_data_i[7:0];
                                5'h0c:  caches[addr_hash][8'h67:8'h60]  <= data_data_i[7:0];
                                5'h0d:  caches[addr_hash][8'h6f:8'h68]  <= data_data_i[7:0];
                                5'h0e:  caches[addr_hash][8'h77:8'h70]  <= data_data_i[7:0];
                                5'h0f:  caches[addr_hash][8'h7f:8'h78]  <= data_data_i[7:0];
                                5'h10:  caches[addr_hash][8'h87:8'h80]  <= data_data_i[7:0];
                                5'h11:  caches[addr_hash][8'h8f:8'h88]  <= data_data_i[7:0];
                                5'h12:  caches[addr_hash][8'h97:8'h90]  <= data_data_i[7:0];
                                5'h13:  caches[addr_hash][8'h9f:8'h98]  <= data_data_i[7:0];
                                5'h14:  caches[addr_hash][8'ha7:8'ha0]  <= data_data_i[7:0];
                                5'h15:  caches[addr_hash][8'haf:8'ha8]  <= data_data_i[7:0];
                                5'h16:  caches[addr_hash][8'hb7:8'hb0]  <= data_data_i[7:0];
                                5'h17:  caches[addr_hash][8'hbf:8'hb8]  <= data_data_i[7:0];
                                5'h18:  caches[addr_hash][8'hc7:8'hc0]  <= data_data_i[7:0];
                                5'h19:  caches[addr_hash][8'hcf:8'hc8]  <= data_data_i[7:0];
                                5'h1a:  caches[addr_hash][8'hd7:8'hd0]  <= data_data_i[7:0];
                                5'h1b:  caches[addr_hash][8'hdf:8'hd8]  <= data_data_i[7:0];
                                5'h1c:  caches[addr_hash][8'he7:8'he0]  <= data_data_i[7:0];
                                5'h1d:  caches[addr_hash][8'hef:8'he8]  <= data_data_i[7:0];
                                5'h1e:  caches[addr_hash][8'hf7:8'hf0]  <= data_data_i[7:0];
                                5'h1f:  caches[addr_hash][8'hff:8'hf8]  <= data_data_i[7:0];
                            endcase
                        end
                        2'h1: begin
                            case (addr_off[OFF_BITS-1:1])
                                4'h0:   caches[addr_hash][8'h0f:8'h00]  <= data_data_i[15:0];
                                4'h1:   caches[addr_hash][8'h1f:8'h10]  <= data_data_i[15:0];
                                4'h2:   caches[addr_hash][8'h2f:8'h20]  <= data_data_i[15:0];
                                4'h3:   caches[addr_hash][8'h3f:8'h30]  <= data_data_i[15:0];
                                4'h4:   caches[addr_hash][8'h4f:8'h40]  <= data_data_i[15:0];
                                4'h5:   caches[addr_hash][8'h5f:8'h50]  <= data_data_i[15:0];
                                4'h6:   caches[addr_hash][8'h6f:8'h60]  <= data_data_i[15:0];
                                4'h7:   caches[addr_hash][8'h7f:8'h70]  <= data_data_i[15:0];
                                4'h8:   caches[addr_hash][8'h8f:8'h80]  <= data_data_i[15:0];
                                4'h9:   caches[addr_hash][8'h9f:8'h90]  <= data_data_i[15:0];
                                4'ha:   caches[addr_hash][8'haf:8'ha0]  <= data_data_i[15:0];
                                4'hb:   caches[addr_hash][8'hbf:8'hb0]  <= data_data_i[15:0];
                                4'hc:   caches[addr_hash][8'hcf:8'hc0]  <= data_data_i[15:0];
                                4'hd:   caches[addr_hash][8'hdf:8'hd0]  <= data_data_i[15:0];
                                4'he:   caches[addr_hash][8'hef:8'he0]  <= data_data_i[15:0];
                                4'hf:   caches[addr_hash][8'hff:8'hf0]  <= data_data_i[15:0];
                            endcase
                        end
                        2'h2: begin
                            case (addr_off[OFF_BITS-1:2])
                                3'h0:   caches[addr_hash][8'h1f:8'h00]  <= data_data_i[31:0];
                                3'h1:   caches[addr_hash][8'h3f:8'h20]  <= data_data_i[31:0];
                                3'h2:   caches[addr_hash][8'h5f:8'h40]  <= data_data_i[31:0];
                                3'h3:   caches[addr_hash][8'h7f:8'h60]  <= data_data_i[31:0];
                                3'h4:   caches[addr_hash][8'h9f:8'h80]  <= data_data_i[31:0];
                                3'h5:   caches[addr_hash][8'hbf:8'ha0]  <= data_data_i[31:0];
                                3'h6:   caches[addr_hash][8'hdf:8'hc0]  <= data_data_i[31:0];
                                3'h7:   caches[addr_hash][8'hff:8'he0]  <= data_data_i[31:0];
                            endcase
                        end

                        default: begin  end
                    endcase
                    dirties[addr_hash]  <= 1'b1;
                end
                else begin
                    hw_page_fault_o     <= 1'b1;
                end
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
            dirties[7'h00]: next_dirty  = 8'h00;
            dirties[7'h01]: next_dirty  = 8'h01;
            dirties[7'h02]: next_dirty  = 8'h02;
            dirties[7'h03]: next_dirty  = 8'h03;
            dirties[7'h04]: next_dirty  = 8'h04;
            dirties[7'h05]: next_dirty  = 8'h05;
            dirties[7'h06]: next_dirty  = 8'h06;
            dirties[7'h07]: next_dirty  = 8'h07;
            dirties[7'h08]: next_dirty  = 8'h08;
            dirties[7'h09]: next_dirty  = 8'h09;
            dirties[7'h0a]: next_dirty  = 8'h0a;
            dirties[7'h0b]: next_dirty  = 8'h0b;
            dirties[7'h0c]: next_dirty  = 8'h0c;
            dirties[7'h0d]: next_dirty  = 8'h0d;
            dirties[7'h0e]: next_dirty  = 8'h0e;
            dirties[7'h0f]: next_dirty  = 8'h0f;
            dirties[7'h10]: next_dirty  = 8'h10;
            dirties[7'h11]: next_dirty  = 8'h11;
            dirties[7'h12]: next_dirty  = 8'h12;
            dirties[7'h13]: next_dirty  = 8'h13;
            dirties[7'h14]: next_dirty  = 8'h14;
            dirties[7'h15]: next_dirty  = 8'h15;
            dirties[7'h16]: next_dirty  = 8'h16;
            dirties[7'h17]: next_dirty  = 8'h17;
            dirties[7'h18]: next_dirty  = 8'h18;
            dirties[7'h19]: next_dirty  = 8'h19;
            dirties[7'h1a]: next_dirty  = 8'h1a;
            dirties[7'h1b]: next_dirty  = 8'h1b;
            dirties[7'h1c]: next_dirty  = 8'h1c;
            dirties[7'h1d]: next_dirty  = 8'h1d;
            dirties[7'h1e]: next_dirty  = 8'h1e;
            dirties[7'h1f]: next_dirty  = 8'h1f;
            dirties[7'h20]: next_dirty  = 8'h20;
            dirties[7'h21]: next_dirty  = 8'h21;
            dirties[7'h22]: next_dirty  = 8'h22;
            dirties[7'h23]: next_dirty  = 8'h23;
            dirties[7'h24]: next_dirty  = 8'h24;
            dirties[7'h25]: next_dirty  = 8'h25;
            dirties[7'h26]: next_dirty  = 8'h26;
            dirties[7'h27]: next_dirty  = 8'h27;
            dirties[7'h28]: next_dirty  = 8'h28;
            dirties[7'h29]: next_dirty  = 8'h29;
            dirties[7'h2a]: next_dirty  = 8'h2a;
            dirties[7'h2b]: next_dirty  = 8'h2b;
            dirties[7'h2c]: next_dirty  = 8'h2c;
            dirties[7'h2d]: next_dirty  = 8'h2d;
            dirties[7'h2e]: next_dirty  = 8'h2e;
            dirties[7'h2f]: next_dirty  = 8'h2f;
            dirties[7'h30]: next_dirty  = 8'h30;
            dirties[7'h31]: next_dirty  = 8'h31;
            dirties[7'h32]: next_dirty  = 8'h32;
            dirties[7'h33]: next_dirty  = 8'h33;
            dirties[7'h34]: next_dirty  = 8'h34;
            dirties[7'h35]: next_dirty  = 8'h35;
            dirties[7'h36]: next_dirty  = 8'h36;
            dirties[7'h37]: next_dirty  = 8'h37;
            dirties[7'h38]: next_dirty  = 8'h38;
            dirties[7'h39]: next_dirty  = 8'h39;
            dirties[7'h3a]: next_dirty  = 8'h3a;
            dirties[7'h3b]: next_dirty  = 8'h3b;
            dirties[7'h3c]: next_dirty  = 8'h3c;
            dirties[7'h3d]: next_dirty  = 8'h3d;
            dirties[7'h3e]: next_dirty  = 8'h3e;
            dirties[7'h3f]: next_dirty  = 8'h3f;
            dirties[7'h40]: next_dirty  = 8'h40;
            dirties[7'h41]: next_dirty  = 8'h41;
            dirties[7'h42]: next_dirty  = 8'h42;
            dirties[7'h43]: next_dirty  = 8'h43;
            dirties[7'h44]: next_dirty  = 8'h44;
            dirties[7'h45]: next_dirty  = 8'h45;
            dirties[7'h46]: next_dirty  = 8'h46;
            dirties[7'h47]: next_dirty  = 8'h47;
            dirties[7'h48]: next_dirty  = 8'h48;
            dirties[7'h49]: next_dirty  = 8'h49;
            dirties[7'h4a]: next_dirty  = 8'h4a;
            dirties[7'h4b]: next_dirty  = 8'h4b;
            dirties[7'h4c]: next_dirty  = 8'h4c;
            dirties[7'h4d]: next_dirty  = 8'h4d;
            dirties[7'h4e]: next_dirty  = 8'h4e;
            dirties[7'h4f]: next_dirty  = 8'h4f;
            dirties[7'h50]: next_dirty  = 8'h50;
            dirties[7'h51]: next_dirty  = 8'h51;
            dirties[7'h52]: next_dirty  = 8'h52;
            dirties[7'h53]: next_dirty  = 8'h53;
            dirties[7'h54]: next_dirty  = 8'h54;
            dirties[7'h55]: next_dirty  = 8'h55;
            dirties[7'h56]: next_dirty  = 8'h56;
            dirties[7'h57]: next_dirty  = 8'h57;
            dirties[7'h58]: next_dirty  = 8'h58;
            dirties[7'h59]: next_dirty  = 8'h59;
            dirties[7'h5a]: next_dirty  = 8'h5a;
            dirties[7'h5b]: next_dirty  = 8'h5b;
            dirties[7'h5c]: next_dirty  = 8'h5c;
            dirties[7'h5d]: next_dirty  = 8'h5d;
            dirties[7'h5e]: next_dirty  = 8'h5e;
            dirties[7'h5f]: next_dirty  = 8'h5f;
            dirties[7'h60]: next_dirty  = 8'h60;
            dirties[7'h61]: next_dirty  = 8'h61;
            dirties[7'h62]: next_dirty  = 8'h62;
            dirties[7'h63]: next_dirty  = 8'h63;
            dirties[7'h64]: next_dirty  = 8'h64;
            dirties[7'h65]: next_dirty  = 8'h65;
            dirties[7'h66]: next_dirty  = 8'h66;
            dirties[7'h67]: next_dirty  = 8'h67;
            dirties[7'h68]: next_dirty  = 8'h68;
            dirties[7'h69]: next_dirty  = 8'h69;
            dirties[7'h6a]: next_dirty  = 8'h6a;
            dirties[7'h6b]: next_dirty  = 8'h6b;
            dirties[7'h6c]: next_dirty  = 8'h6c;
            dirties[7'h6d]: next_dirty  = 8'h6d;
            dirties[7'h6e]: next_dirty  = 8'h6e;
            dirties[7'h6f]: next_dirty  = 8'h6f;
            dirties[7'h70]: next_dirty  = 8'h70;
            dirties[7'h71]: next_dirty  = 8'h71;
            dirties[7'h72]: next_dirty  = 8'h72;
            dirties[7'h73]: next_dirty  = 8'h73;
            dirties[7'h74]: next_dirty  = 8'h74;
            dirties[7'h75]: next_dirty  = 8'h75;
            dirties[7'h76]: next_dirty  = 8'h76;
            dirties[7'h77]: next_dirty  = 8'h77;
            dirties[7'h78]: next_dirty  = 8'h78;
            dirties[7'h79]: next_dirty  = 8'h79;
            dirties[7'h7a]: next_dirty  = 8'h7a;
            dirties[7'h7b]: next_dirty  = 8'h7b;
            dirties[7'h7c]: next_dirty  = 8'h7c;
            dirties[7'h7d]: next_dirty  = 8'h7d;
            dirties[7'h7e]: next_dirty  = 8'h7e;
            dirties[7'h7f]: next_dirty  = 8'h7f;
            default:        next_dirty  = 8'h80;
        endcase
    end

endmodule
