module core_test;
    reg clk;
    reg rst;
    reg inst_valid_i;
    reg data_valid_i;
    reg hw_page_fault;
    reg hw_interrupt;
    reg [31:0] hw_cause;
    reg [31:0] cp0_ehb;
    reg [31:0] cp0_epc;

    wire [31:0] data_data_i;
    wire [31:0] inst_data_i;
    wire [31:0] cp0_data_i;

    wire [31:0] inst_addr_o;
    wire [31:0] data_addr_o;
    wire [31:0] data_data_o;
    wire [1:0] data_sel_o;
    wire data_we_o;
    wire data_rd_o;
    wire mem_fc;
    wire mem_sc;
    wire exception;
    wire [31:0] cause;
    wire [31:0] epc;
    wire eret;
    wire [4:0] cp0_addr_o;
    wire [31:0] cp0_data_o;
    wire cp0_we_o;

    core uut(
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

    reg [31:0] rom [63:0];
    reg [31:0] cp0 [31:0];

    assign inst_data_i = rom[inst_addr_o[7:2]];
    assign data_data_i = rom[data_addr_o[7:2]];

    integer i;
    initial begin
        clk = 0;
        rst = 0;
        inst_valid_i = 1;
        data_valid_i = 1;
        hw_page_fault = 0;
        hw_interrupt = 0;
        hw_cause = 0;
        cp0_ehb = 32'h00000004;
        cp0_epc = 0;
        for (i = 0; i < 32; i = i + 1)  cp0[i] = i;
        $readmemh("/home/c/c-stack/SoC/hardware/test/core_test.hex", rom);
    end

    initial forever #5 clk = ~clk;

    assign cp0_data_i = cp0[cp0_addr_o[4:0]];

    always @(posedge clk) begin
        if (exception)  cp0_epc                 <= epc;
        if (cp0_we_o)   cp0[cp0_addr_o[4:0]]    <= cp0_data_o;
    end
endmodule
