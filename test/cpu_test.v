module cpu_test;
    reg clk;
    reg rst;
    reg [255:0] mem_data_i;
    reg mem_ack_i;
    reg bus_ack_i;

    wire [31:0] mem_addr_o;
    wire [255:0] mem_data_o;
    wire mem_we_o;
    wire mem_rd_o;

    wire [31:0] bus_addr_o;
    wire [31:0] bus_data_i;
    wire [31:0] bus_data_o;
    wire [1:0] bus_sel_o;
    wire bus_we_o;
    wire bus_rd_o;

    wire [31:0] devices_interrupt;

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
        .devices_interrupt(devices_interrupt)
    );

    reg [255:0] ram [0:7];
    reg [31:0] counter;

    initial begin
        clk                 = 0;
        rst                 = 0;
        mem_data_i          = 0;
        mem_ack_i           = 0;
        bus_ack_i           = 1;
        counter             = 100;
        $readmemh("/home/c/c-stack/SoC/hardware/test/cpu_test.256", ram);
    end

    assign bus_data_i           = counter;
    assign devices_interrupt    = {30'b0, ~|counter, 1'b0};

    always @(posedge clk) begin
        if (mem_rd_o) begin
            #70;
            @(negedge clk) begin
                mem_data_i  <= ram[mem_addr_o[7:5]];
                mem_ack_i   <= 1;
                #10;
                mem_ack_i   <= 0;
            end
        end
        else if (mem_we_o) begin
            #70;
            @(negedge clk) begin
                ram[mem_addr_o[7:5]]    <= mem_data_o;
                mem_ack_i               <= 1;
                #10;
                mem_ack_i               <= 0;
            end
        end
    end

    always @(posedge clk) begin
        if (bus_we_o) begin
            counter     <= bus_data_o;
        end
        else if (counter) begin
            counter     <= counter - 1;
        end
    end

    initial forever #5 clk = ~clk;

endmodule
