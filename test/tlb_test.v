module tlb_test;
    reg clk;
    reg rst;
    reg [31:0] mmu_base_i;
    reg mmu_we;
    reg [31:0] v_addr_i;
    reg v_lookup;
    reg [31:0] data_i;
    reg ack_i;

    wire [31:0] mmu_base_o;
    wire [31:0] v_ent_o;
    wire v_ack_o;
    wire [31:0] addr_o;
    wire [31:0] data_o;
    wire we_o;
    wire rd_o;
    wire page_fault;
    wire [31:0] page_fault_addr;

    tlb uut(
        .clk(clk),
        .rst(rst),
        .mmu_base_i(mmu_base_i),
        .mmu_we(mmu_we),
        .mmu_base_o(mmu_base_o),
        .v_addr_i(v_addr_i),
        .v_lookup(v_lookup),
        .v_ent_o(v_ent_o),
        .v_ack_o(v_ack_o),
        .addr_o(addr_o),
        .data_i(data_i),
        .data_o(data_o),
        .we_o(we_o),
        .rd_o(rd_o),
        .ack_i(ack_i),
        .page_fault(page_fault),
        .page_fault_addr(page_fault_addr)
    );

    task lookup;
    input [31:0] v_addr;
    begin
        @(negedge clk) begin
            v_addr_i    = v_addr;
            v_lookup    = 1'b1;
        end

        @(posedge v_ack_o) begin
            @(negedge clk) begin
                v_lookup    = 1'b0;
            end
        end
    end
    endtask

    task write_base;
    input [31:0] mmu_base;
    begin
        @(negedge clk) begin
            mmu_base_i  = mmu_base;
            mmu_we      = 1;

            #10;
            mmu_we      = 0;
        end
    end
    endtask

    initial begin
        clk = 0;
        rst = 0;
        mmu_base_i = 0;
        mmu_we = 0;
        v_addr_i = 0;
        v_lookup = 0;
        data_i = 0;
        ack_i = 0;

        #100;
        ack_i = 1;

        #10;
        ack_i = 0;

        #20;
        lookup(32'h0000_0000);

        #20;
        lookup(32'h0000_1000);

        #20;
        lookup(32'h0040_0000);

        #20;
        lookup(32'h0000_2000);

        #20;
        write_base(32'h0003_0000);

        #20;
        lookup(32'h0000_0000);
    end

    initial forever #5 clk = ~clk;

    reg busy = 0;
    always @(posedge clk) begin

        if (rd_o && ~busy) begin
            busy = 1;

            #70;

            case (addr_o)
                32'h0000_0000:  data_i = 32'h0001_0001;
                32'h0000_0004:  data_i = 32'h0002_0001;

                32'h0001_0000:  data_i = 32'h0000_0001;
                32'h0001_0004:  data_i = 32'h0001_0001;
                32'h0001_0008:  data_i = 32'h0000_0000;

                32'h0002_0000:  data_i = 32'h000F_0001;
                32'h0002_0004:  data_i = 32'h001F_0001;

                32'h0003_0000:  data_i = 32'h0002_0001;
                32'h0003_0004:  data_i = 32'h0001_0001;

                default:        data_i = 32'hxxxx_xxxx;
            endcase
            @(negedge clk) begin
                ack_i   = 1;
                busy    = 0;
                #10;
                ack_i   = 0;
            end
        end
    end

endmodule
