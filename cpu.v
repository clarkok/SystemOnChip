module cpu(
    input  clk,
    input  rst,

    output [ 31:0]  mem_addr_o,
    input  [255:0]  mem_data_i,
    output [255:0]  mem_data_o,
    output          mem_we_o,
    output          mem_rd_o,
    input           mem_ack_i,

    output [ 31:0]  bus_addr_o,
    input  [ 31:0]  bus_data_i,
    output [ 31:0]  bus_data_o,
    output [  1:0]  bus_sel_o,
    output          bus_we_o,
    output          bus_rd_o,
    input           bus_ack_i,

    input  [31:0]   devices_interrupt
    );

    wire [31:0] inst_addr_o;
    wire [31:0] inst_data_i;
    wire        inst_valid_i;
    wire [31:0] data_addr_o;
    wire [31:0] data_data_o;
    wire [31:0] data_data_i;
    wire [ 1:0] data_sel_o;
    wire        data_we_o;
    wire        data_rd_o;
    wire        data_valid_i;
    wire        mem_fc;
    wire        hw_page_fault;
    wire        hw_interrupt;
    wire [31:0] hw_cause;
    wire        exception;
    wire [31:0] cause;
    wire [31:0] epc;
    wire        eret;
    wire [ 4:0] cp0_addr_o;
    wire [31:0] cp0_data_i;
    wire [31:0] cp0_data_o;
    wire        cp0_we_o;
    wire [31:0] cp0_ehb;
    wire [31:0] cp0_epc;

    core core(
        .clk(clk),
        .rst(rst),
        .inst_addr_o(inst_addr_o),
        .inst_data_i(inst_data_i),
        .inst_valid_i(inst_valid_i),
        .data_addr_o(data_addr_o),
        .data_data_o(data_data_o),
        .data_data_i(data_data_i),
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

    wire [31:0] cp0_ptb;
    wire        cp0_ptb_we;
    wire        cp0_hw_page_fault;
    wire        cp0_hw_page_fault_addr;

    cp0 cp0(
        .clk(clk),
        .rst(rst),
        .cp0_addr_i(cp0_addr_o),
        .cp0_data_o(cp0_data_i),
        .cp0_data_i(cp0_data_o),
        .cp0_we_i(cp0_we_o),
        .cp0_epc_o(cp0_epc),
        .cp0_ehb_o(cp0_ehb),
        .cp0_ptb_o(cp0_ptb),
        .cp0_ptb_we(cp0_ptb_we),
        .exception(exception),
        .cause(cause),
        .epc(epc),
        .eret(eret),
        .hw_interrupt(hw_interrupt),
        .hw_cause(hw_cause),
        .devices_interrupt(devices_interrupt),
        .hw_page_fault(cp0_hw_page_fault),
        .hw_page_fault_addr(cp0_hw_page_fault_addr)
    );

    wire [ 31:0]    ci_addr_o;
    wire [255:0]    ci_data_i;
    wire            ci_rd_o;
    wire            ci_ack_i;
    wire            ci_hw_page_fault_o;
    wire            ci_hw_page_fault_i;

    inst_cache inst_cache(
        .clk(clk),
        .rst(rst),
        .inst_addr_i(inst_addr_o),
        .inst_data_o(inst_data_i),
        .inst_valid_o(inst_valid_i),
        .mem_fc(mem_fc),
        .hw_page_fault_o(ci_hw_page_fault_o),
        .addr_o(ci_addr_o),
        .data_i(ci_data_i),
        .rd_o(ci_rd_o),
        .ack_i(ci_ack_i),
        .hw_page_fault_i(ci_hw_page_fault_i)
    );

    wire [ 31:0]    cd_addr_o;
    wire [255:0]    cd_data_i;
    wire [ 31:0]    cd_page_ent_i;
    wire [255:0]    cd_data_o;
    wire            cd_we_o;
    wire            cd_rd_o;
    wire            cd_ack_i;
    wire            cd_hw_page_fault_o;
    wire            cd_hw_page_fault_i;

    data_cache data_cache(
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
        .hw_page_fault_o(cd_hw_page_fault_o),
        .uncached_addr_o(bus_addr_o),
        .uncached_data_i(bus_data_i),
        .uncached_data_o(bus_data_o),
        .uncached_sel_o(bus_sel_o),
        .uncached_we_o(bus_we_o),
        .uncached_rd_o(bus_rd_o),
        .uncached_valid_i(bus_ack_i),
        .addr_o(cd_addr_o),
        .data_i(cd_data_i),
        .page_ent_i(cd_page_ent_i),
        .data_o(cd_data_o),
        .we_o(cd_we_o),
        .rd_o(cd_rd_o),
        .ack_i(cd_ack_i),
        .hw_page_fault_i(cd_hw_page_fault_i)
    );

    wire [ 31:0]    v_addr_o;
    wire [255:0]    v_data_i;
    wire [255:0]    v_data_o;
    wire            v_we_o;
    wire            v_rd_o;
    wire            v_ack_i;
    wire            v_hw_page_fault_i;
    wire [ 31:0]    v_page_ent_i;

    arbiter arbiter(
        .clk(clk),
        .rst(rst),
        .cd_addr_i(cd_addr_o),
        .cd_data_o(cd_data_i),
        .cd_page_ent_o(cd_page_ent_i),
        .cd_data_i(cd_data_o),
        .cd_we_i(cd_we_o),
        .cd_rd_i(cd_rd_o),
        .cd_ack_o(cd_ack_i),
        .cd_hw_page_fault_o(cd_hw_page_fault_i),
        .ci_addr_i(ci_addr_o),
        .ci_data_o(ci_data_i),
        .ci_rd_i(ci_rd_o),
        .ci_ack_o(ci_ack_i),
        .ci_hw_page_fault_o(ci_hw_page_fault_i),
        .addr_o(v_addr_o),
        .data_i(v_data_i),
        .data_o(v_data_o),
        .we_o(v_we_o),
        .rd_o(v_rd_o),
        .ack_i(v_ack_i),
        .hw_page_fault_i(v_hw_page_fault_i),
        .page_ent_i(v_page_ent_i)
    );

    mmu mmu(
        .clk(clk),
        .rst(rst),
        .cp0_ptb_i(cp0_ptb),
        .cp0_ptb_we(cp0_ptb_we),
        .v_addr_i(v_addr_o),
        .v_data_o(v_data_i),
        .v_data_i(v_data_o),
        .v_rd_i(v_rd_o),
        .v_we_i(v_we_o),
        .v_ack_o(v_ack_i),
        .v_page_ent_o(v_page_ent_i),
        .v_hw_page_fault_o(v_hw_page_fault_i),
        .v_hw_page_fault_addr_o(cp0_hw_page_fault_addr),
        .addr_o(mem_addr_o),
        .data_i(mem_data_i),
        .data_o(mem_data_o),
        .rd_o(mem_rd_o),
        .we_o(mem_we_o),
        .ack_i(mem_ack_i)
    );

    assign hw_page_fault        = cd_hw_page_fault_o | ci_hw_page_fault_o;
    assign cp0_hw_page_fault    = v_hw_page_fault_i;
endmodule
