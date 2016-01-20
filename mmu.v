module mmu(
    input  clk,
    input  rst,

    input  [31:0] mmu_base_i,
    input         mmu_we,
    output [31:0] mmu_base_o,

    input  [31:0] v_addr_i,
    input         v_lookup,
    output [31:0] v_ent_o,
    output        v_ack_o,

    output [31:0] addr_o,
    input  [31:0] data_i,
    output [31:0] data_o,
    output        we_o,
    output        rd_o,
    input         ack_i,

    output reg          page_fault,
    output reg [31:0]   page_fault_addr
    );

    reg  [31:0] mmu_base;
    reg  [31:0] v_addr_r;
    reg  [31:0] addr_r;

    reg  [31:0] page_dir_caches [63:0];
    reg  [ 3:0] page_dir_tags   [63:0];
    reg         page_dir_valids [63:0];

    reg  [31:0] page_ent_caches [63:0];
    reg  [13:0] page_ent_tags   [63:0];
    reg         page_ent_valids [63:0];

    reg  [3:0]  state;

    localparam  S_INIT              = 4'h0,
                S_IDLE              = 4'h1,
                S_QUERY             = 4'h2,
                S_LOAD_DIR          = 4'h3,
                S_LOAD_ENT          = 4'h4,
                S_END               = 4'h5;

    wire [ 9:0] v_page_dir      = v_addr_r[31:22];
    wire [ 9:0] v_page_ent      = v_addr_r[21:12];
    wire [11:0] v_offset        = v_addr_r[11: 0];

    wire [ 3:0] v_dir_tag       = v_addr_r[31:28];
    wire [ 5:0] v_dir_hash      = v_addr_r[27:22];
    wire [13:0] v_ent_tag       = v_addr_r[31:18];
    wire [ 5:0] v_ent_hash      = v_addr_r[17:12];

    wire [31:0] v_dir_value     = page_dir_caches[v_dir_hash];
    wire [31:0] v_ent_value     = page_ent_caches[v_ent_hash];

    wire        v_dir_cached    = page_dir_valids[v_dir_hash] && (page_dir_tags[v_dir_hash] == v_dir_tag);
    wire        v_ent_cached    = page_ent_valids[v_ent_hash] && (page_ent_tags[v_dir_hash] == v_ent_tag);

    wire        v_dir_addr      = {mmu_base[31:12],     v_page_dir, 2'b00};
    wire        v_ent_addr      = {v_dir_value[31:12],  v_page_ent, 2'b00};

    assign      v_ent_o         = page_ent_caches[v_ent_hash];
    assign      v_ack_o         = (state == S_END);

    assign      addr_o          = addr_r;
    assign      data_o          = 32'b0;
    assign      we_o            = 1'b0;
    assign      rd_o            = (state == S_LOAD_DIR) || (state == S_LOAD_ENT);

    task init;
    integer i;
    begin
        mmu_base            <= 32'b0;
        v_addr_r            <= 32'b0;
        addr_r              <= 32'b0;
        state               <= S_INIT;
        page_fault          <= 1'b0;
        page_fault_addr     <= 32'b0;

        for (i = 0; i < 64; i = i + 1) begin
            page_dir_caches[i]  <= 32'b0;
            page_dir_tags[i]    <= 4'b0;
            page_dir_valids[i]  <= 1'b0;

            page_ent_caches[i]  <= 32'b0;
            page_ent_tags[i]    <= 13'b0;
            page_ent_valids[i]  <= 1'b0;
        end
    end
    endtask

    initial init();

    integer i;
    always @(posedge clk) begin
        if (rst) init();
        else begin
            case (state)
                S_INIT:     if (ack_i)          state <= S_END;
                S_IDLE:     if (v_lookup)       state <= S_QUERY;
                S_QUERY: begin
                    case (1)
                        ~v_dir_cached:    begin state <= S_LOAD_DIR;    addr_r      <= v_dir_addr;  end
                        ~v_ent_cached:    begin state <= S_LOAD_ENT;    addr_r      <= v_ent_addr;  end
                        default:          begin state <= S_END;         page_fault  <= ~v_ent_value[0]; if (~v_ent_value[0]) page_fault_addr <= v_addr_i;   end
                    endcase
                end
                S_LOAD_DIR: begin
                    if (ack_i) begin
                        state <= S_LOAD_ENT;
                        if (~data_i[0]) begin
                            page_fault      <= 1'b1;
                            page_fault_addr <= v_addr_i;
                            state           <= S_END;
                        end
                    end
                end
                S_LOAD_ENT: if (ack_i)    begin state <= S_END;         page_fault  <= ~v_ent_value[0]; if (~v_ent_value[0]) page_fault_addr <= v_addr_i;   end
                S_END:                          state <= S_IDLE;
            endcase

            if (mmu_we) begin
                mmu_base            <= mmu_base_i;
                page_fault          <= 1'b0;

                for (i = 0; i < 64; i = i + 1) begin
                    page_dir_valids[i]  <= 64'b0;
                    page_ent_valids[i]  <= 64'b0;
                end
            end
        end
    end

endmodule
