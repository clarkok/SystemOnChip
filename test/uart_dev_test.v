`timescale 1ns / 1ps

module uart_dev_test;
    reg clk;
    reg rst;
    reg uart_rxd;
    reg wb_stb;
    reg wb_we;
    reg [31:0] wb_addr;
    reg [31:0] wb_din;

    wire [31:0] wb_dout;
    wire wb_ack;
    wire interrupt;

    uart_dev uut(
        .clk(clk),
        .rst(rst),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .wb_stb(wb_stb),
        .wb_we(wb_we),
        .wb_addr(wb_addr),
        .wb_din(wb_din),
        .wb_dout(wb_dout),
        .wb_ack(wb_ack),
        .interrupt(interrupt)
    );

    task send;
    input [7:0] data;
    begin
        #480;
        uart_rxd = 0;

        #480;
        uart_rxd = data[0];

        #480;
        uart_rxd = data[1];

        #480;
        uart_rxd = data[2];

        #480;
        uart_rxd = data[3];

        #480;
        uart_rxd = data[4];

        #480;
        uart_rxd = data[5];

        #480;
        uart_rxd = data[6];

        #480;
        uart_rxd = data[7];

        #480;
        uart_rxd = 1;

        #480;
    end
    endtask

    task write_buffer;
    input [31:0] addr;
    input [31:0] data;
    begin
        wb_we   = 1;
        wb_stb  = 1;
        wb_addr = addr;
        wb_din  = data;

        #10;
        wb_we   = 0;
        wb_stb  = 0;

        #10;
    end
    endtask

    task send_buffer;
    input [31:0] ctrl;
    begin
        wb_we   = 1;
        wb_stb  = 1;
        wb_addr = 1024;
        wb_din  = ctrl;

        #10;

        @(posedge wb_ack) begin
            @(posedge clk) begin
                wb_we   = 0;
                wb_stb  = 0;
            end
        end
    end
    endtask

    initial begin
        clk = 0;
        rst = 0;
        uart_rxd = 1;
        wb_stb = 0;
        wb_we = 0;
        wb_addr = 0;
        wb_din = 0;

        #100;

        write_buffer(0, 32'h01234567);
        write_buffer(4, 32'h01234567);
        write_buffer(8, 32'h01234567);
        write_buffer(12, 32'h01234567);

        send_buffer(32'h00000_00F);

        send(8'h00);
        send(8'h01);
        send(8'h00);
        send(8'h00);

        send(8'h00);
        send(8'h01);
        send(8'h02);
        send(8'h03);
        send(8'h04);
        send(8'h05);
        send(8'h06);
        send(8'h07);
        send(8'h08);
        send(8'h09);
        send(8'h0a);
        send(8'h0b);
        send(8'h0c);
        send(8'h0d);
        send(8'h0e);
        send(8'h0f);
    end

    initial forever #5 clk = ~clk;
endmodule

