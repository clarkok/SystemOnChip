module core_inst_cache_test;
    reg  clk;
    reg  rst;
    reg  data_valid_i;
    reg  hw_page_fault;
    reg  [31:0] devices_interrupt;

    wire        inst_valid_i;
    wire [31:0] inst_addr_o;
    wire [31:0] inst_data_i;
    wire [31:0] data_addr_o;
    wire [31:0] data_data_i;
    wire [31:0] data_data_o;
    wire        data_we_o;
    wire        data_rd_o;
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
        .hw_page_fault(hw_page_fault),
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

    reg [31:0] ram [0:63];
    reg [255:0] insts [0:7];

    assign data_data_i = ram[data_addr_o[7:2]];

    always @(posedge clk) begin
        if (data_we_o)  begin
            if (data_addr_o == 32'hFFFF0000) 
                counter                 <= data_data_o;
            else
                ram[data_addr_o[7:2]]   <= data_data_o;
        end

        if (ci_rd_o) begin
            #70;
            @(negedge clk) begin
                ci_data_i   <= insts[ci_addr_o[7:5]];
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
        data_valid_i = 1;
        hw_page_fault = 0;
        devices_interrupt = 0;
        counter = 100;
        ci_data_i = 256'b0;
        ci_ack_i = 0;
        $readmemh("/home/c/c-stack/SoC/hardware/test/core_inst_cache_test.hex", ram);
        $readmemh("/home/c/c-stack/SoC/hardware/test/core_inst_cache_test.256", insts);
    end

    always @(posedge clk) begin
        if (counter) counter    <= counter - 1;
        devices_interrupt[1]    <= ~|counter;
    end

    initial forever #5 clk = ~clk;
endmodule
