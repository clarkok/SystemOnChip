`include "functions.vh"

module ddr3_cache_ctrl(
    input  clk,
    input  rst,

    input  [31:0]  addr_i,
    input  [31:0]  data_i,
    output [31:0]  data_o,
    input          we_i,
    input          rd_i,
    output         ack_o,

    output reg [28:0]     ctrl_addr_i,
    output reg [255:0]    ctrl_data_i,
    input      [255:0]    ctrl_data_o,
    output                ctrl_we_i,
    output                ctrl_rd_i,
    input                 ctrl_ack_o,

    output     [15:0] state_value,
    output reg [15:0] last_state_value
    );

    localparam TOTAL_ADDR_BITS  = 29;                               // 512MByte
    localparam UNIT_BITS        = `GET_WIDTH(256 / 8 - 1);
    localparam HASH_BITS        = 9;                                // 512 cache lines
    localparam TAG_BITS         = TOTAL_ADDR_BITS - UNIT_BITS - HASH_BITS;

    wire [8:0]      cache_addr_i;
    wire [255:0]    cache_data_i;
    wire [255:0]    cache_data_o;
    wire            cache_we_i;

    ddr3_cache ddr3_cache(
        .clka(clk),
        .addra(cache_addr_i),
        .dina(cache_data_i),
        .douta(cache_data_o),
        .wea(cache_we_i)
    );

    reg [TAG_BITS-1:0]  tags[0:511];
    reg [511:0]         valid;
    reg [511:0]         dirties;

    localparam S_INIT                   = 3'h0;
    localparam S_IDLE                   = 3'h1;
    localparam S_WRITE_CACHE            = 3'h2;
    localparam S_READ_CACHE             = 3'h3;
    localparam S_READ_BEFORE_WRITE      = 3'h4;
    localparam S_WRITE_AFTER_READ       = 3'h5;
    localparam S_END                    = 3'h6;

    wire [HASH_BITS-1:0]    hash    =  addr_i[HASH_BITS+UNIT_BITS-1:UNIT_BITS];
    wire [TAG_BITS-1:0]     tag     =  addr_i[28:HASH_BITS+UNIT_BITS];

    reg  [2:0]      state;
    reg  [255:0]    write_buf;

    reg  [31:0]     data_o_r;
    assign          data_o          =  data_o_r;
    assign          ack_o           = (state == S_END);
    assign          ctrl_we_i       = (state == S_WRITE_CACHE);
    assign          ctrl_rd_i       = (state == S_READ_CACHE);

    assign          cache_addr_i    =  hash;
    assign          cache_data_i    = (state == S_WRITE_AFTER_READ) ? write_buf : ctrl_data_o;
    assign          cache_we_i      = (state == S_READ_CACHE && ctrl_ack_o) ||
                                      (state == S_WRITE_AFTER_READ);

    wire [28:0]             write_addr  = {tags[hash], hash, {UNIT_BITS{1'b0}}};
    wire [28:0]             read_addr   = {tag,        hash, {UNIT_BITS{1'b0}}};

    wire                    read    =  rd_i;
    wire                    write   =  we_i;
    wire                    cached  =  valid[hash] &&
                                      (tags [hash] == tag);
    wire                    missed  = ~cached;
    wire                    dirty   =  dirties[hash];
    wire                    clear   = ~dirty;

    always @* begin
        case (addr_i[UNIT_BITS-1:2])
            0: data_o_r = cache_data_o[ 31:  0];
            1: data_o_r = cache_data_o[ 63: 32];
            2: data_o_r = cache_data_o[ 95: 64];
            3: data_o_r = cache_data_o[127: 96];
            4: data_o_r = cache_data_o[159:128];
            5: data_o_r = cache_data_o[191:160];
            6: data_o_r = cache_data_o[223:192];
            7: data_o_r = cache_data_o[255:224];
        endcase
    end

    always @* begin
        case (addr_i[UNIT_BITS-1:2])
            0: write_buf = {cache_data_o[255: 32], data_i};
            1: write_buf = {cache_data_o[255: 64], data_i, cache_data_o[ 31:  0]};
            2: write_buf = {cache_data_o[255: 96], data_i, cache_data_o[ 63:  0]};
            3: write_buf = {cache_data_o[255:128], data_i, cache_data_o[ 95:  0]};
            4: write_buf = {cache_data_o[255:160], data_i, cache_data_o[127:  0]};
            5: write_buf = {cache_data_o[255:192], data_i, cache_data_o[159:  0]};
            6: write_buf = {cache_data_o[255:224], data_i, cache_data_o[191:  0]};
            7: write_buf = {                       data_i, cache_data_o[223:  0]};
        endcase
    end

    task init;
    integer i;
    begin
        state       <= S_INIT;
        valid       <= 512'b0;
        dirties     <= 512'b0;
        ctrl_addr_i <= 29'b0;
        ctrl_data_i <= 256'b0;

        for (i = 0; i < 512; i = i + 1)
            tags[i] <= 0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            ctrl_data_i <= cache_data_o;

            case (state)
                S_INIT: if (ctrl_ack_o)                 state <= S_END;                 // assert an ACK to upper level
                S_IDLE: begin
                    case (1)
                        read && cached:                 state <= S_END;
                        read && missed && dirty:  begin state <= S_WRITE_CACHE;         ctrl_addr_i <=  write_addr; end
                        read && missed && clear:  begin state <= S_READ_CACHE;          ctrl_addr_i <=  read_addr;  end
                        write && cached:                state <= S_READ_BEFORE_WRITE;
                        write && missed && dirty: begin state <= S_WRITE_CACHE;         ctrl_addr_i <=  write_addr; end
                        write && missed && clear: begin state <= S_READ_CACHE;          ctrl_addr_i <=  read_addr;  end
                    endcase
                end
                S_WRITE_CACHE:  if (ctrl_ack_o)   begin state <= S_READ_CACHE;          ctrl_addr_i <=  read_addr; dirties[hash] <= 1'b0; end
                S_READ_CACHE: begin
                    case (1)
                        ctrl_ack_o && read:       begin state <= S_END;                 tags[hash]  <= tag; valid[hash] <= 1'b1; dirties[hash] <= 1'b0; end
                        ctrl_ack_o && write:      begin state <= S_READ_BEFORE_WRITE;   tags[hash]  <= tag; valid[hash] <= 1'b1; dirties[hash] <= 1'b0; end
                    endcase
                end
                S_READ_BEFORE_WRITE:                    state <= S_WRITE_AFTER_READ;
                S_WRITE_AFTER_READ:               begin state <= S_END;                 dirties[hash] <= 1'b1; end
                S_END:                                  state <= S_IDLE;
            endcase
        end
    end

    assign state_value  = state;
    always @(posedge clk)   if (state_value)    last_state_value    <= state_value;

endmodule
