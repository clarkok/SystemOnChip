module datetime(
    input  clk,
    input  rst,

    input  [31:0]   addr_i,
    output [31:0]   data_o,
    input  [31:0]   data_i,
    input  [ 1:0]   sel_i,
    input           rd_i,
    input           we_i,
    output          ack_o
    );

    parameter CLOCK_FREQ    = 100_000_000;

    reg  [31:0] unix_time_reg;
    reg  [31:0] counter;

    assign data_o       = unix_time_reg;
    assign ack_o        = 1'b1;

    task init;
    begin
        unix_time_reg   <= 0;
        counter         <= CLOCK_FREQ;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            if (we_i)           unix_time_reg   <= data_i;
            else begin
                if (counter)    counter         <= counter - 1;
                else begin
                    counter         <= CLOCK_FREQ;
                    unix_time_reg   <= unix_time_reg + 1;
                end
            end
        end
    end
endmodule
