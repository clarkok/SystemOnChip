module data_cache_test;
    reg clk;
    reg rst;
    reg [31:0] data_addr;
    reg [31:0] data_out;
    reg data_we;
    reg data_rd;
    reg [3:0] data_sel;
    reg data_sign_ext;
    reg [31:0] data_i;
    reg ack_i;
    reg fence;

    wire [31:0] data_in;
    wire data_ready;
    wire [31:0] addr_o;
    wire [31:0] data_o;
    wire we_o;
    wire rd_o;

    data_cache uut(
        .clk(clk),
        .rst(rst),
        .data_addr(data_addr),
        .data_in(data_in),
        .data_out(data_out),
        .data_we(data_we),
        .data_rd(data_rd),
        .data_sel(data_sel),
        .data_ready(data_ready),
        .data_sign_ext(data_sign_ext),
        .addr_o(addr_o),
        .data_i(data_i),
        .data_o(data_o),
        .we_o(we_o),
        .rd_o(rd_o),
        .ack_i(ack_i),
        .fence(fence)
    );

    task read;
    input [31:0] addr;
    begin
        @(posedge clk) begin
            data_addr = addr;
            data_rd = 1;

            #3;
            if (data_ready) begin
                @(posedge clk) begin
                    data_rd = 0;
                    #5;
                end
            end
            else begin
                @(posedge data_ready) begin
                    @(posedge clk) begin
                        data_rd = 0;
                        #5;
                    end
                end
            end
        end
    end
    endtask

    task write;
    input [31:0] addr;
    input [31:0] data;
    begin
        @(posedge clk) begin
            data_addr = addr;
            data_out = data;
            data_we = 1;

            #3;
            if (data_ready) begin
                @(posedge clk) begin
                    data_we = 0;
                    #5;
                end
            end
            else begin
                @(posedge data_ready) begin
                    @(posedge clk) begin
                        data_we = 0;
                        #5;
                    end
                end
            end
        end
    end
    endtask

    initial begin
        clk = 0;
        rst = 0;
        data_addr = 0;
        data_out = 0;
        data_we = 0;
        data_rd = 0;
        data_sel = 4'b1111;
        data_sign_ext = 0;
        data_i = 0;
        ack_i = 0;
        fence = 0;

        #100;
        read(32'h0000_0000);
        write(32'h0000_0004, 32'h0123_4567);
        read(32'h0001_0000);
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

        if (we_o & ~busy) begin
            busy    = 1;
            #30.2;
            ack_i   = 1'b1;
            busy    = 0;
            #10;
            ack_i   = 1'b0;
        end
    end
endmodule
