module core_data_cache_test;
    reg  clk;
    reg  rst;
    reg  hw_page_fault;
    reg  [31:0] devices_interrupt;

    wire [31:0] inst_addr_o;
    wire [31:0] inst_data_i;
    wire        inst_valid_i;

    wire [31:0] data_addr_o;
    wire [31:0] data_data_i;
    wire [31:0] data_data_o;
    wire [1:0]  data_sel_o;
    wire        data_we_o;
    wire        data_rd_o;
    wire        data_valid_i;

    wire        hw_page_fault_i;
    wire        hw_interrupt;
    wire [31:0] hw_cause;
    wire        exception;
    wire [31:0] cause;
    wire [31:0] epc;
    wire        eret;
    wire [4:0]  cp0_addr_o;
    wire [31:0] cp0_data_i;
    wire [31:0] cp0_data_o;
    wire        cp0_we_o;
    wire [31:0] cp0_ehb;
    wire [31:0] cp0_epc;
    wire [31:0] cp0_ptb;

    wire [31:0] ci_addr_o;
    reg  [255:0] ci_data_i;
    wire ci_rd_o;
    reg  ci_ack_i;

    wire [31:0] uncached_addr_o;
    wire [31:0] uncached_data_i;
    wire [31:0] uncached_data_o;
    wire [1:0] uncached_sel_o;
    wire uncached_we_o;
    wire uncached_rd_o;
    reg uncached_valid_i;

    wire [31:0] cd_addr_o;
    reg [255:0] cd_data_i;
    reg [31:0] page_ent_i;
    wire [255:0] cd_data_o;
    wire cd_we_o;
    wire cd_rd_o;
    reg cd_ack_i;

    core core_uut(
        .clk(clk),
        .rst(rst),
        .inst_addr_o(inst_addr_o),
        .inst_data_i(inst_data_i),
        .inst_valid_i(inst_valid_i),
        .data_addr_o(data_addr_o),
        .data_data_i(data_data_i),
        .data_data_o(data_data_o),
        .data_sel_o(data_sel_o),
        .data_we_o(data_we_o),
        .data_rd_o(data_rd_o),
        .data_valid_i(data_valid_i),
        .mem_fc(mem_fc),
        .hw_page_fault(hw_page_fault_i),
        .hw_interrupt(hw_interrupt),
        .hw_cause(hw_cause),
        .exception(exception),
        .cause(cause),
        .epc(epc),
        .eret(eret),
        .cp0_addr_o(cp0_addr_o),
        .cp0_data_i(cp0_data_i),
        .cp0_data_o(cp0_data_o),
        .cp0_we_o(cp0_we_o),
        .cp0_ehb(cp0_ehb),
        .cp0_epc(cp0_epc)
    );

    cp0 cp0_uut(
        .clk(clk),
        .rst(rst),
        .cp0_addr_i(cp0_addr_o),
        .cp0_data_o(cp0_data_i),
        .cp0_data_i(cp0_data_o),
        .cp0_we_i(cp0_we_o),
        .cp0_epc_o(cp0_epc),
        .cp0_ehb_o(cp0_ehb),
        .cp0_ptb_o(cp0_ptb),
        .exception(exception),
        .cause(cause),
        .epc(epc),
        .eret(eret),
        .hw_interrupt(hw_interrupt),
        .hw_cause(hw_cause),
        .devices_interrupt(devices_interrupt)
    );

    inst_cache uut_inst_cache(
        .clk(clk),
        .rst(rst),
        .inst_addr_i(inst_addr_o),
        .inst_data_o(inst_data_i),
        .inst_valid_o(inst_valid_i),
        .mem_fc(mem_fc),
        .addr_o(ci_addr_o),
        .data_i(ci_data_i),
        .rd_o(ci_rd_o),
        .ack_i(ci_ack_i)
    );

    data_cache uut_data_cache(
        .clk(clk),
        .rst(rst),
        .data_addr_i(data_addr_o),
        .data_data_o(data_data_i),
        .data_data_i(data_data_o),
        .data_sel_i(data_sel_o),
        .data_we_i(data_we_o),
        .data_rd_i(data_rd_o),
        .data_valid_o(data_valid_i),
        .mem_fc(mem_fc),
        .hw_page_fault_o(hw_page_fault_i),
        .uncached_addr_o(uncached_addr_o),
        .uncached_data_i(uncached_data_i),
        .uncached_data_o(uncached_data_o),
        .uncached_sel_o(uncached_sel_o),
        .uncached_we_o(uncached_we_o),
        .uncached_rd_o(uncached_rd_o),
        .uncached_valid_i(uncached_valid_i),
        .addr_o(cd_addr_o),
        .data_i(cd_data_i),
        .page_ent_i(page_ent_i),
        .data_o(cd_data_o),
        .we_o(cd_we_o),
        .rd_o(cd_rd_o),
        .ack_i(cd_ack_i),
        .hw_page_fault_i(hw_page_fault)
    );

    reg [255:0] ram [0:7];

    always @(posedge clk) begin
        if (cd_we_o) begin
            #70;
            @(negedge clk) begin
                ram[cd_addr_o[7:5]]     <= cd_data_o;
                cd_ack_i                <= 1;
                #10;
                cd_ack_i                <= 0;
            end
        end
        else if (cd_rd_o) begin
            #70;
            @(negedge clk) begin
                cd_data_i   <= ram[cd_addr_o[7:5]];
                cd_ack_i    <= 1;
                #10;
                cd_ack_i    <= 0;
            end
        end
        else if (ci_rd_o) begin
            #70;
            @(negedge clk) begin
                ci_data_i   <= ram[ci_addr_o[7:5]];
                ci_ack_i    <= 1;
                #10;
                ci_ack_i    <= 0;
            end
        end
    end

    reg [31:0] counter;

    initial begin
        clk = 0;
        rst = 0;
        hw_page_fault = 0;
        devices_interrupt = 0;
        counter = 100;
        ci_data_i = 256'b0;
        ci_ack_i = 0;
        uncached_valid_i = 1;
        cd_data_i = 256'b0;
        page_ent_i = 32'hFFFFFFFF;
        cd_ack_i = 0;
        $readmemh("/home/c/c-stack/SoC/hardware/test/core_inst_cache_test.256", ram);
    end

    assign uncached_data_i = counter;

    always @(posedge clk) begin
        if (counter) counter    <= counter - 1;
        devices_interrupt[1]    <= ~|counter;
        if (uncached_we_o) begin
            counter <= uncached_data_o;
        end
    end

    initial forever #5 clk = ~clk;
endmodule
