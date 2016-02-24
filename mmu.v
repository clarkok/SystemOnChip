`include "functions.vh"

module mmu(
    input  clk,
    input  rst,

    input  [31:0]   cp0_ptb_i,
    input           cp0_ptb_we,

    input  [ 31:0]  v_addr_i,
    output [255:0]  v_data_o,
    input  [255:0]  v_data_i,
    input           v_rd_i,
    input           v_we_i,
    output          v_ack_o,

    output [ 31:0]  v_page_ent_o,
    output          v_hw_page_fault_o,
    output [ 31:0]  v_hw_page_fault_addr_o,

    output reg [ 31:0]  addr_o,
    input      [255:0]  data_i,
    output reg [255:0]  data_o,
    output reg          rd_o,
    output reg          we_o,
    input               ack_i
    );

    parameter   PAGING_MASK     = 32'hC000_0000;

    localparam  DIR_LINES       = 4;
    localparam  DIR_OFF_BITS    = 3;
    localparam  DIR_HASH_BITS   = `GET_WIDTH(DIR_LINES-1);
    localparam  DIR_TAG_BITS    = 10 - DIR_HASH_BITS - DIR_OFF_BITS;

    localparam  ENT_LINES       = 16;
    localparam  ENT_OFF_BITS    = 3;
    localparam  ENT_HASH_BITS   = `GET_WIDTH(DIR_LINES-1);
    localparam  ENT_TAG_BITS    = 10 - DIR_HASH_BITS - DIR_OFF_BITS;

    reg  [255:0]            tlb_dir         [0:DIR_LINES-1];
    reg  [DIR_TAG_BITS-1:0] tlb_dir_tags    [0:DIR_LINES-1];
    reg                     tlb_dir_valids  [0:DIR_LINES-1];

    reg  [255:0]            tlb_ent         [0:ENT_LINES-1];
    reg  [ENT_TAG_BITS-1:0] tlb_ent_tags    [0:ENT_LINES-1];
    reg                     tlb_ent_valids  [0:ENT_LINES-1];

    wire                        paging_en       = ((v_addr_i & PAGING_MASK) != PAGING_MASK);

    wire [9:0]                  v_dir           = v_addr_i[31:22];
    wire [DIR_OFF_BITS-1:0]     v_dir_off       = v_dir[DIR_OFF_BITS-1:0];
    wire [DIR_HASH_BITS-1:0]    v_dir_hash      = v_dir[DIR_HASH_BITS+DIR_OFF_BITS-1:DIR_OFF_BITS];
    wire [DIR_TAG_BITS-1:0]     v_dir_tag       = v_dir[9:DIR_HASH_BITS+DIR_OFF_BITS];

    wire [19:0]                 v_ent           = v_addr_i[31:12];
    wire [ENT_OFF_BITS-1:0]     v_ent_off       = v_ent[ENT_OFF_BITS-1:0];
    wire [ENT_HASH_BITS-1:0]    v_ent_hash      = v_ent[ENT_HASH_BITS+ENT_OFF_BITS-1:ENT_OFF_BITS];
    wire [ENT_TAG_BITS-1:0]     v_ent_tag       = v_ent[19:ENT_HASH_BITS+ENT_OFF_BITS];

    reg  [31:0]     tlb_dir_r;
    reg  [31:0]     tlb_ent_r;

    wire            v_dir_valid     = tlb_dir_valids[v_dir_hash] && 
                                     (tlb_dir_tags[v_dir_hash] == v_dir_tag);
    wire            v_dir_pfault    = v_dir_valid && ~tlb_dir_r[0];

    wire            v_ent_valid     = tlb_ent_valids[v_ent_hash] && 
                                        (tlb_ent_tags[v_ent_hash] == v_ent_tag);
    wire            v_ent_pfault    = v_ent_valid && ~tlb_ent_r[0];

    localparam  S_IDLE      = 0,
                S_READ_DIR  = 1,
                S_CHECK_DIR = 2,
                S_READ_ENT  = 3;
    reg  [1:0] state;

    assign  v_data_o                = data_i;
    assign  v_ack_o                 = (~v_rd_i && ~v_we_i)  ? 0 :
                                      (~paging_en)          ? ack_i :
                                                              (state == S_IDLE) &&
                                                              (v_ent_valid ? ack_i : 
                                                                (v_ent_pfault || v_dir_pfault));
    assign  v_page_ent_o            = tlb_ent_r | {30'b0, ~paging_en, 1'b0};
    assign  v_hw_page_fault_o       = paging_en && (v_dir_pfault || v_ent_pfault);
    assign  v_hw_page_fault_addr_o  = v_addr_i;

    always @* begin
        case (v_dir_off)
            3'h0:   tlb_dir_r   = tlb_dir[v_dir_hash][8'h1f:8'h00];
            3'h1:   tlb_dir_r   = tlb_dir[v_dir_hash][8'h3f:8'h20];
            3'h2:   tlb_dir_r   = tlb_dir[v_dir_hash][8'h5f:8'h40];
            3'h3:   tlb_dir_r   = tlb_dir[v_dir_hash][8'h7f:8'h60];
            3'h4:   tlb_dir_r   = tlb_dir[v_dir_hash][8'h9f:8'h80];
            3'h5:   tlb_dir_r   = tlb_dir[v_dir_hash][8'hbf:8'ha0];
            3'h6:   tlb_dir_r   = tlb_dir[v_dir_hash][8'hdf:8'hc0];
            3'h7:   tlb_dir_r   = tlb_dir[v_dir_hash][8'hff:8'he0];
        endcase
    end

    always @* begin
        case (v_ent_off)
            3'h0:   tlb_ent_r   = tlb_ent[v_ent_hash][8'h1f:8'h00];
            3'h1:   tlb_ent_r   = tlb_ent[v_ent_hash][8'h3f:8'h20];
            3'h2:   tlb_ent_r   = tlb_ent[v_ent_hash][8'h5f:8'h40];
            3'h3:   tlb_ent_r   = tlb_ent[v_ent_hash][8'h7f:8'h60];
            3'h4:   tlb_ent_r   = tlb_ent[v_ent_hash][8'h9f:8'h80];
            3'h5:   tlb_ent_r   = tlb_ent[v_ent_hash][8'hbf:8'ha0];
            3'h6:   tlb_ent_r   = tlb_ent[v_ent_hash][8'hdf:8'hc0];
            3'h7:   tlb_ent_r   = tlb_ent[v_ent_hash][8'hff:8'he0];
        endcase
    end

    task init();
    integer i;
    begin
        addr_o      <= 0;
        addr_o      <= 256'b0;
        rd_o        <= 0;
        we_o        <= 0;
        state       <= S_IDLE;

        for (i = 0; i < 4; i = i + 1) begin
            tlb_dir[i]          <= 256'b0;
            tlb_dir_tags[i]     <= {DIR_TAG_BITS{1'b0}};
            tlb_dir_valids[i]   <= 1'b0;
        end

        for (i = 0; i < 16; i = i + 1) begin
            tlb_ent[i]          <= 256'b0;
            tlb_ent_tags[i]     <= {ENT_TAG_BITS{1'b0}};
            tlb_ent_valids[i]   <= 1'b0;
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
                    if      (~v_rd_i && ~v_we_i)        state   <= S_IDLE;
                    else if (~paging_en) begin
                        state   <= S_IDLE;
                        if (ack_i) begin
                            rd_o    <= 0;
                            we_o    <= 0;
                        end
                        else begin
                            addr_o  <= v_addr_i;
                            data_o  <= v_data_i;
                            rd_o    <= v_rd_i;
                            we_o    <= v_we_i;
                        end
                    end
                    else if (v_ent_valid) begin
                        state   <= S_IDLE;

                        if (ack_i) begin
                            rd_o    <= 0;
                            we_o    <= 0;
                        end
                        else if (~v_ent_pfault) begin
                            addr_o  <= {tlb_ent_r[31:12], v_addr_i[11:0]};
                            data_o  <= v_data_o;
                            rd_o    <= v_rd_i;
                            we_o    <= v_we_i;
                        end
                    end
                    else if (v_dir_valid) begin
                        if (v_dir_pfault)               state   <= S_IDLE;
                        else begin
                            state   <= S_READ_ENT;

                            addr_o  <= {tlb_ent_r[31:12], v_ent_tag, v_ent_hash, 5'b0};
                            rd_o    <= 1;
                        end
                    end
                    else begin
                        state   <= S_READ_DIR;

                        addr_o  <= {cp0_ptb_i[31:12], v_dir_tag, v_dir_hash, 5'b0};
                        rd_o    <= 1;
                    end
                end
                S_READ_DIR: begin
                    if (ack_i) begin
                        state   <= S_CHECK_DIR;
                        rd_o    <= 0;

                        tlb_dir[v_dir_hash]         <= data_i;
                        tlb_dir_tags[v_dir_hash]    <= addr_o[DIR_TAG_BITS+DIR_HASH_BITS+4:DIR_HASH_BITS+5];
                        tlb_dir_valids[v_dir_hash]  <= 1'b1;
                    end
                end
                S_CHECK_DIR: begin
                    if (v_dir_pfault) begin
                        state   <= S_IDLE;
                    end
                    else begin
                        state   <= S_READ_ENT;
                        addr_o  <= {cp0_ptb_i[31:12], v_dir_tag, v_dir_hash, 5'b0};
                        rd_o    <= 1;
                    end
                end
                S_READ_ENT: begin
                    if (ack_i) begin
                        state   <= S_IDLE;

                        tlb_ent[v_ent_hash]         <= data_i;
                        tlb_ent_tags[v_ent_hash]    <= addr_o[ENT_TAG_BITS+ENT_HASH_BITS+4:ENT_HASH_BITS+5];
                        tlb_dir_valids[v_ent_hash]  <= 1'b1;
                    end
                end
            endcase
            if (cp0_ptb_we) begin
                for (i = 0; i < DIR_LINES; i = i + 1) begin
                    tlb_dir_valids[i]   <= 1'b0;
                end
                for (i = 0; i < ENT_LINES; i = i + 1) begin
                    tlb_ent_valids[i]   <= 1'b0;
                end
            end
        end
    end

endmodule
