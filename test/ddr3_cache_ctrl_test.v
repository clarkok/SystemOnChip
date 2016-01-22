module ddr3_cache_ctrl_test;
    reg clk;
    reg rst;
    reg [31:0] addr_i;
    reg [31:0] data_i;
    reg we_i;
    reg rd_i;
    reg [255:0] ctrl_data_o;
    reg ctrl_ack_o;

    wire [31:0] data_o;
    wire [28:0] ctrl_addr_i;
    wire [255:0] ctrl_data_i;
    wire ctrl_we_i;
    wire ctrl_rd_i;
    wire [15:0] state_value;

    ddr3_cache_ctrl uut(
        .clk(clk),
        .rst(rst),
        .addr_i(addr_i),
        .data_i(data_i),
        .data_o(data_o),
        .we_i(we_i),
        .rd_i(rd_i),
        .ack_o(ack_o),
        .ctrl_addr_i(ctrl_addr_i),
        .ctrl_data_i(ctrl_data_i),
        .ctrl_data_o(ctrl_data_o),
        .ctrl_we_i(ctrl_we_i),
        .ctrl_rd_i(ctrl_rd_i),
        .ctrl_ack_o(ctrl_ack_o),
        .state_value(state_value)
    );

    task write;
    input [31:0] addr;
    input [31:0] data;
    begin
        @(negedge clk) begin
            we_i        = 1;
            data_i      = data;
            addr_i      = addr;
        end

        @(posedge ack_o) begin
            #10;
            we_i        = 0;
        end
    end
    endtask

    task read;
    input [31:0] addr;
    begin
        @(negedge clk) begin
            rd_i        = 1;
            addr_i      = addr;
        end

        @(posedge ack_o) begin
            #10;
            rd_i    = 0;
        end
    end
    endtask

    integer i;

    initial begin
        clk         = 0;
        rst         = 0;
        addr_i      = 0;
        data_i      = 0;
        we_i        = 0;
        rd_i        = 0;
        ctrl_data_o = 255'b0;
        ctrl_ack_o  = 0;

        #100;
        ctrl_ack_o  = 1;
        #10;
        ctrl_ack_o  = 0;

        #10;
        for (i = 0; i < 4096; i = i + 1) write({i[29:0], 2'b00}, i);

        for (i = 0; i < 4096; i = i + 1) read({i[29:0], 2'b00});
    end

    initial forever #5 clk = ~clk;

    reg [255:0] _ddr3_sim [0:255];

    initial begin
        for (i = 0; i < 256; i = i + 1) _ddr3_sim[i] = 256'b0;
    end

    always @(posedge ctrl_we_i) begin
        _ddr3_sim[ctrl_addr_i[7:0]]     = ctrl_data_i;
        #60;
        @(negedge clk) ctrl_ack_o  = 1;
        #10;
        @(negedge clk) ctrl_ack_o  = 0;
    end

    always @(posedge ctrl_rd_i) begin
        #60;
        ctrl_data_o     = _ddr3_sim[ctrl_addr_i[7:0]];
        @(negedge clk) ctrl_ack_o  = 1;
        #10;
        @(negedge clk) ctrl_ack_o  = 0;
    end

endmodule
