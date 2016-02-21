module flash_dev_test;
    reg  clk;
    reg  rst;
    reg  [31:0]   addr_i;
    reg  [31:0]   data_i;
    reg  [ 1:0]   sel_i;
    reg           rd_i;
    reg           we_i;
    reg  [ 1:0]   bpi_rynby;

    wire [31:0]   bpi_q;
    wire          ack_o;
    wire          bpi_oen;
    wire          bpi_rstn;
    wire          bpi_wen;
    wire          interrupt;
    wire [ 1:0]   bpi_cen;
    wire [25:0]   bpi_a;
    wire [31:0]   data_o;

    flash_dev uut(
        .clk(clk),
        .rst(rst),
        .addr_i(addr_i),
        .data_o(data_o),
        .data_i(data_i),
        .sel_i(sel_i),
        .rd_i(rd_i),
        .we_i(we_i),
        .ack_o(ack_o),
        .interrupt(interrupt),
        .bpi_a(bpi_a),
        .bpi_q(bpi_q),
        .bpi_cen(bpi_cen),
        .bpi_oen(bpi_oen),
        .bpi_wen(bpi_wen),
        .bpi_rstn(bpi_rstn),
        .bpi_rynby(bpi_rynby)
    );

    task read;
    input [31:0] addr;
    begin
        @(posedge clk) begin
            addr_i  <= addr;
            rd_i    <= 1'b1;
        end

        @(posedge clk) begin
            if (ack_o) begin
                rd_i    <= 1'b0;
            end
        end
    end
    endtask

    task write;
    input [31:0] addr;
    input [31:0] data;
    begin
        @(posedge clk) begin
            addr_i  <= addr;
            data_i  <= data;
            we_i    <= 1'b1;
        end

        @(posedge clk) begin
            if (ack_o) begin
                we_i    <= 1'b0;
            end
        end
    end
    endtask

    initial begin
        clk = 0;
        rst = 0;
        data_i = 0;
        addr_i = 0;
        sel_i = 2;
        rd_i = 0;
        we_i = 0;

        #100;
        write(32'h0000_0000, 32'h1234_5678);
        write(32'h0000_0004, 32'h8765_4321);
        write(32'h0000_0008, 32'h1020_3040);
        read(32'h0000_0000);

        #100;
        write(32'hFFFF_FE00, 32'h2000_0000);
    end

    initial forever #5 clk = ~clk;

endmodule
