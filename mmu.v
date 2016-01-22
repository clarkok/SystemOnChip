module mmu(
    input  clk,
    input  rst,

    input  [31:0] mmu_base_i,
    input         mmu_we,
    output [31:0] mmu_base_o,

    input  [31:0] v_addr_i,
    input  [31:0] v_data_i,
    output [31:0] v_data_o,
    input         v_we_i,
    input         v_rd_i,
    output        v_ack_o,

    output [31:0] addr_o,
    input  [31:0] data_i,
    output [31:0] data_o,
    output        we_o,
    output        rd_o,
    input         ack_i,

    output        page_fault,
    output [31:0] page_fault_addr
    );

    wire        v_lookup;
    wire [31:0] v_ent_o;
    wire        v_ack_o;

    wire [31:0] tlb_addr_o;
    wire [31:0] tlb_data_o;
    wire        tlb_we_o;
    wire        tlb_rd_o;
    wire        tlb_page_fault;
    wire [31:0] tlb_page_fault_addr;

    reg  [19:0] last_page;
    reg  [31:0] last_page_ent;
    reg         we_fault;
    reg         we_fault_addr;

    wire [19:0] page            = v_addr_i[31:12];
    wire        last_cached     = (page == last_page);
    wire [31:0] phy_addr        = {last_page_ent[31:12], v_addr_i[11:0]};

    assign v_data_o     = data_i;
    assign v_ack_o      = last_cached && ack_i;
    assign addr_o       = last_cached ? phy_addr : tlb_addr_o;
    assign data_o       = last_cached ? v_data_o : tlb_data_o;
    assign we_o         = last_cached ? v_we_i   : tlb_we_o;
    assign rd_o         = last_cached ? v_rd_i   : tlb_rd_o;

    assign page_fault       = we_fault || tlb_page_fault;
    assign page_fault_addr  = we_fault ? we_fault_addr : tlb_page_fault_addr;

    assign v_lookup     = ~last_cached;

    task init;
    begin
        last_page       <= 19'hFFFFF;
        last_page_ent   <= 32'h00000000;
        we_fault        <= 1'b0;
        we_fault_addr   <= 32'h00000000;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst || mmu_we) init();
        else begin
            if (~last_cached && v_ack_o) begin
                last_page       <= page;
                last_page_ent   <= v_ent_o;
            end
        end
    end

    tlb tlb(
        .clk(clk),
        .rst(rst),
        .mmu_base_i(mmu_base_i),
        .mmu_we(mmu_we),
        .mmu_base_o(mmu_base_o),
        .v_addr_i(v_addr_i),
        .v_lookup(v_lookup),
        .v_ent_o(v_ent_o),
        .v_ack_o(v_ack_o),
        .addr_o(tlb_addr_o),
        .data_i(data_i),
        .data_o(tlb_data_o),
        .we_o(tlb_we_o),
        .rd_o(tlb_rd_o),
        .ack_i(ack_i),
        .page_fault(tlb_page_fault),
        .page_fault_addr(tlb_page_fault_addr)
    );
endmodule
