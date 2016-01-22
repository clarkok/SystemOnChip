module inst_cache_test;
    reg clk;
    reg rst;
    reg [31:0] inst_addr;
    reg [31:0] data_i;
    reg ack_i;
    reg fence;

    wire [31:0] inst_in;
    wire inst_valid;
    wire [31:0] addr_o;
    wire [31:0] data_o;
    wire we_o;
    wire rd_o;

    inst_cache uut(
        .clk(clk),
        .rst(rst),
        .inst_addr(inst_addr),
        .inst_in(inst_in),
        .inst_valid(inst_valid),
        .addr_o(addr_o),
        .data_i(data_i),
        .data_o(data_o),
        .we_o(we_o),
        .rd_o(rd_o),
        .ack_i(ack_i),
        .fence(fence)
    );

    task at;
    input [31:0] addr;
    begin
        @(posedge clk) begin
            if (inst_valid) begin
                    inst_addr  = addr;
            end
            else begin
                @(posedge inst_valid) begin
                    @(posedge clk) begin
                        inst_addr  = addr;
                    end
                end
            end
        end
    end
    endtask

    initial begin
        clk = 0;
        rst = 0;
        inst_addr = 0;
        data_i = 0;
        ack_i = 0;
        fence = 0;

        at(32'h0000_0000);
        at(32'h0000_0004);
        at(32'h0000_0008);
        at(32'h0000_000c);
        at(32'h0000_0010);
        at(32'h0000_0014);
        at(32'h0000_0018);
        at(32'h0000_001c);
        at(32'h0000_0020);
        at(32'h0000_0130);
        at(32'h0000_0134);
        at(32'h0000_0138);
        at(32'h0000_013c);
        at(32'h0000_0130);
        at(32'h0000_0004);
        at(32'h0000_0008);
    end

    initial forever #5 clk = ~clk;

    reg busy = 0;
    always @(posedge clk) begin
        if (rd_o & ~busy) begin
            busy    = 1;
            #30.2;
            data_i  = addr_o;
            ack_i   = 1'b1;
            busy    = 0;
            #10;
            ack_i   = 1'b0;
        end
    end
endmodule
