module mmu_test;
    reg clk;
    reg rst;
    reg [31:0] mmu_base_i;
    reg mmu_we;
    reg [255:0] v_addr_i;
    reg [255:0] v_data_i;
    reg v_we_i;
    reg v_rd_i;
    reg [255:0] data_i;
    reg ack_i;

    wire [31:0] mmu_base_o;
    wire [255:0] v_data_o;
    wire v_ack_o;
    wire [31:0] addr_o;
    wire [255:0] data_o;
    wire we_o;
    wire rd_o;
    wire page_fault;

    mmu uut(
        .clk(clk),
        .rst(rst),
        .mmu_base_i(mmu_base_i),
        .mmu_we(mmu_we),
        .mmu_base_o(mmu_base_o),
        .v_addr_i(v_addr_i),
        .v_data_i(v_data_i),
        .v_data_o(v_data_o),
        .v_we_i(v_we_i),
        .v_rd_i(v_rd_i),
        .v_ack_o(v_ack_o),
        .addr_o(addr_o),
        .data_i(data_i),
        .data_o(data_o),
        .we_o(we_o),
        .rd_o(rd_o),
        .ack_i(ack_i),
        .page_fault(page_fault)
    );

    task write_base;
    input [31:0] base;
    begin
        @(negedge clk) begin
            mmu_base_i  = base;
            mmu_we      = 1;

            #10;
            mmu_we      = 0;
        end
    end
    endtask

    task read_vaddr;
    input [31:0] addr;
    begin
        @(negedge clk) begin
            v_addr_i    = addr;
            v_rd_i      = 1;
            #10;
        end

        @(posedge v_ack_o) begin
            #5;
            @(posedge clk) v_rd_i   = 0;
        end
    end
    endtask

    task write_vaddr;
    input [31:0] addr;
    input [31:0] data;
    begin
        @(negedge clk) begin
            v_addr_i    = addr;
            v_we_i      = 1;
            #10;
        end

        @(posedge v_ack_o) begin
            #5;
            @(posedge clk) v_we_i   = 0;
        end
    end
    endtask
    
    initial begin
        clk = 0;
        rst = 0;
        mmu_base_i = 0;
        mmu_we = 0;
        v_addr_i = 0;
        v_data_i = 0;
        v_we_i = 0;
        v_rd_i = 0;
        ack_i = 0;

        #100;
        ack_i = 1;
        #10;
        ack_i = 0;

        #10;
        write_base(0);
        read_vaddr(0);
        write_vaddr(0, 32'h01234567);

        #10;
        read_vaddr(32'h0000_1000);
        read_vaddr(32'h0000_1004);
        read_vaddr(32'h0000_1008);
        read_vaddr(32'h0000_100C);
        read_vaddr(32'h0000_1010);
        read_vaddr(32'h0000_1014);
        read_vaddr(32'h0000_1018);
        read_vaddr(32'h0000_101C);
        read_vaddr(32'h0000_1020);
        read_vaddr(32'h0000_1024);
        read_vaddr(32'h0000_1028);
        read_vaddr(32'h0000_102C);
        read_vaddr(32'h0000_1030);
        read_vaddr(32'h0000_1034);
        read_vaddr(32'h0000_1038);
        read_vaddr(32'h0000_103C);

        #10;
        write_vaddr(32'h0000_2000, 32'h01234567);
        read_vaddr(32'h0000_0000);

        #10;
        write_base(0);
        read_vaddr(32'h0000_0000);
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

        if (we_o && ~busy) begin
            busy = 1;

            #70;

            @(negedge clk) begin
                ack_i   = 1;
                busy    = 0;
                #10;
                ack_i   = 0;
            end
        end
    end
endmodule
