module timer(
    input  clk,
    input  rst,

    input  [31:0]   addr_i,
    output [31:0]   data_o,
    input  [31:0]   data_i,
    input  [ 1:0]   sel_i,
    input           rd_i,
    input           we_i,
    output          ack_o,

    output          interrupt
    );

    reg [31:0]  counter;

    assign  data_o      = counter;
    assign  ack_o       = 1'b1;
    assign  interrupt   = ~|counter;

    task init;
    begin
        counter     <= 32'b0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else if (we_i)      counter <= data_i;
        else if (counter)   counter <= counter - 1;
    end
endmodule
