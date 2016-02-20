module flash_test;
    reg clk;
    reg rst;
    reg [25:0]  block_addr;
    reg [31:0]  data_i;
    reg         we_i;
    reg         rd_i;
    reg         bpi_rynby;

    wire [31:0] data_o;
    wire        ack_o;

    wire [25:0] bpi_a;
    wire [31:0] bpi_q;
    wire [ 1:0] bpi_cen;
    wire        bpi_oen;
    wire        bpi_wen;
    wire        bpi_rstn;

    flash uut(
        .clk(clk),
        .rst(rst),
        .block_addr(block_addr),
        .data_i(data_i),
        .data_o(data_o),
        .we_i(we_i),
        .rd_i(rd_i),
        .ack_o(ack_o),
        .bpi_a(bpi_a),
        .bpi_q(bpi_q),
        .bpi_cen(bpi_cen),
        .bpi_oen(bpi_oen),
        .bpi_wen(bpi_wen),
        .bpi_rstn(bpi_rstn),
        .bpi_rynby(bpi_rynby)
    );

    initial begin
        clk         = 0;
        rst         = 0;
        block_addr  = 0;
        data_i      = 0;
        we_i        = 0;
        rd_i        = 0;

        #100;
        // rd_i        = 1;
        we_i        = 1;
    end

    initial forever #5 clk = ~clk;

endmodule
