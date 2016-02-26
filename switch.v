module switch(
    input  clk,
    input  rst,

    input  [15:0] sw,

    input  [31:0]   addr_i,
    output [31:0]   data_o,
    input  [31:0]   data_i,
    input  [ 1:0]   sel_i,
    input           rd_i,
    input           we_i,
    output          ack_o,

    output          interrupt
    );

    reg  [15:0] sw_status;

    assign data_o       = {16'b0, sw};
    assign interrupt    = (sw != sw_status);
    assign ack_o        = 1'b1;

    task init;
    begin
        sw_status   <= 15'b0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            if (we_i)   sw_status <= data_i;
        end
    end
endmodule
