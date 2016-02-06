module ps2(
    input  clk,
    input  rst,

    input  ps2_clk,
    input  ps2_data,

    input  [31:0]   addr_i,
    output [31:0]   data_o,
    input  [31:0]   data_i,
    input  [ 1:0]   sel_i,
    input           rd_i,
    input           we_i,
    output          ack_o,

    output          interrupt
    );

    reg [3:0] state;
    reg [7:0] data;

    wire ps2_clkn       = ~ps2_clk;
    wire buffer_empty;

    assign data_o[31:8] = 24'b0;
    assign interrupt    = ~buffer_empty;

    always @(posedge ps2_clkn) begin
        if (rst) begin
            state   <= 0;
            data    <= 0;
        end
        else begin
            if (counter >= 1 && counter <= 8) begin
                data    <= {ps2_data, data[7:1]};
            end
            else if (counter == 10) begin
                counter <= 0;
            end
        end
    end

    ps2_buffer ps2_buffer(
        .rst(rst),
        .wr_clk(ps2_clkn),
        .rd_clk(clk),

        .full(),
        .empty(buffer_empty),
        .valid(ack_o),
        .din(data),
        .dout(data_o[7:0]),
        .wr_en(state == 9),
        .rd_en(rd_i)
    );

endmodule
