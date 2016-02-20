`timescale 1ns / 1ps

module uart_test;
    reg clk;
    reg rst;

    reg uart_rxd;
    reg [7:0] data_in;
    reg data_send;

    wire uart_txd;
    wire data_sent;
    wire [7:0] data_out;
    wire data_received;

    uart uut(
        .clk(clk),
        .rst(rst),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .data_in(data_in),
        .data_send(data_send),
        .data_sent(data_sent),
        .data_out(data_out),
        .data_received(data_received)
    );

    task send;
    input [7:0] data;
    begin
        #2170;
        uart_rxd = 0;

        #2170;
        uart_rxd = data[0];

        #2170;
        uart_rxd = data[1];

        #2170;
        uart_rxd = data[2];

        #2170;
        uart_rxd = data[3];

        #2170;
        uart_rxd = data[4];

        #2170;
        uart_rxd = data[5];

        #2170;
        uart_rxd = data[6];

        #2170;
        uart_rxd = data[7];

        #2170;
        uart_rxd = 1;

        #2170;
    end
    endtask

    initial begin
        clk = 0;
        rst = 0;
        uart_rxd = 1;
        data_in = 8'hA0;
        data_send = 1;

        #100;

        send(8'b10101100);
    end

    initial forever #5 clk = ~clk;

endmodule
