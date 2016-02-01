module core_cp0_test;
    reg  clk;
    reg  rst;
    reg  inst_valid_i;
    reg  data_valid_i;
    reg  hw_page_fault;
    reg  [31:0] devices_interrupt;

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
        .mem_sc(mem_sc),
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

    reg [31:0] ram [0:63];

    assign inst_data_i = ram[inst_addr_o[7:2]];
    assign data_data_i = ram[data_addr_o[7:2]];

    always @(posedge clk) begin
        if (data_we_o)  begin
            if (data_addr_o == 32'hFFFF0000) 
                counter                 <= data_data_o;
            else
                ram[data_addr_o[7:2]]   <= data_data_o;
        end
    end

    reg [31:0] counter;

    initial begin
        clk = 0;
        rst = 0;
        inst_valid_i = 1;
        data_valid_i = 1;
        hw_page_fault = 0;
        devices_interrupt = 0;
        counter = 100;
        $readmemh("/home/c/c-stack/SoC/hardware/test/core_cp0_test.hex", ram);
    end

    always @(posedge clk) begin
        if (counter) counter    <= counter - 1;
        devices_interrupt[1]    <= ~|counter;
    end

    initial forever #5 clk = ~clk;
endmodule
