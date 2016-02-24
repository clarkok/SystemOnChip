module cpu_test;
    reg  clk;
    reg  rst;
    reg           bios_ack_i;
    reg  [31:0]   devices_interrupt;
    reg  [255:0]  ctrl_data_i;
    reg           ctrl_ack_i;

    wire [ 31:0]  ctrl_addr_o;
    wire [255:0]  ctrl_data_o;
    wire          ctrl_we_o;
    wire          ctrl_rd_o;
    wire [ 31:0]  bus_data_i;
    wire          bus_ack_i;
    wire [ 31:0]  bios_data_i;
    wire [255:0]  mem_data_i;
    wire          mem_ack_i;
    wire [ 31:0]  mem_addr_o;
    wire [255:0]  mem_data_o;
    wire          mem_we_o;
    wire          mem_rd_o;
    wire [ 31:0]  bus_addr_o;
    wire [ 31:0]  bus_data_o;
    wire [  1:0]  bus_sel_o;
    wire          bus_we_o;
    wire          bus_rd_o;
    wire [ 31:0]  bios_addr_o;
    wire          bios_rd_o;
    wire [31:0]   the_pc;

    cpu uut(
        .clk(clk),
        .rst(rst),
        .mem_addr_o(mem_addr_o),
        .mem_data_i(mem_data_i),
        .mem_data_o(mem_data_o),
        .mem_we_o(mem_we_o),
        .mem_rd_o(mem_rd_o),
        .mem_ack_i(mem_ack_i),
        .bus_addr_o(bus_addr_o),
        .bus_data_i(bus_data_i),
        .bus_data_o(bus_data_o),
        .bus_sel_o(bus_sel_o),
        .bus_we_o(bus_we_o),
        .bus_rd_o(bus_rd_o),
        .bus_ack_i(bus_ack_i),
        .bios_addr_o(bios_addr_o),
        .bios_data_i(bios_data_i),
        .bios_rd_o(bios_rd_o),
        .bios_ack_i(bios_ack_i),
        .devices_interrupt(devices_interrupt),
        .the_pc(the_pc)
    );

    ddr3_cache ddr3_cache(
        .clk(clk),
        .addr_i(mem_addr_o),
        .data_o(mem_data_i),
        .data_i(mem_data_o),
        .we_i(mem_we_o),
        .rd_i(mem_rd_o),
        .ack_o(mem_ack_i),
        .ctrl_addr_o(ctrl_addr_o),
        .ctrl_data_i(ctrl_data_i),
        .ctrl_data_o(ctrl_data_o),
        .ctrl_we_o(ctrl_we_o),
        .ctrl_rd_o(ctrl_rd_o),
        .ctrl_ack_i(ctrl_ack_i)
    );

    bios_dev bios_dev(
        .clk(clk),
        .rst(rst),
        .addr_i(bus_addr_o),
        .data_o(bus_data_i),
        .data_i(bus_data_o),
        .sel_i(bus_sel_o),
        .rd_i(bus_rd_o),
        .we_i(bus_we_o),
        .ack_o(bus_ack_i),
        .inst_addr_i(bios_addr_o),
        .inst_data_o(bios_data_i)
    );

    initial begin
        clk = 0;
        rst = 0;
        bios_ack_i = 1;
        ctrl_data_i = 0;
        ctrl_ack_i = 0;
        devices_interrupt = 0;

        #50;
        ctrl_ack_i = 1;
        #10;
        ctrl_ack_i = 0;
    end

    initial forever #5 clk = ~clk;

    reg [255:0] _ddr3_sim [0:1023];

    always @(posedge clk) begin
        if (ctrl_rd_o) begin
            #30;
            ctrl_data_i <= _ddr3_sim[ctrl_addr_o[14:5]];
            @(posedge clk) begin
                ctrl_ack_i   <= 1;
                #10;
                ctrl_ack_i   <= 0;
                #10;
            end
        end
        else if (ctrl_we_o) begin
            #30;
            _ddr3_sim[ctrl_addr_o[14:5]] <= ctrl_data_o;
            @(posedge clk) begin
                ctrl_ack_i   <= 1;
                #10;
                ctrl_ack_i   <= 0;
                #10;
            end
        end
    end

    always @(posedge clk) begin
        if (bus_addr_o == 32'hFFFF_FE0C && bus_we_o) begin
            $display("%c", bus_data_o);
        end
    end

endmodule
