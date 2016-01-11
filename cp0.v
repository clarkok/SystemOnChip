module CoProcessor0(
    input clk,
    input rst,

    input  [4:0] cp0_addr_r,
    output [DATA_WIDTH-1:0] cp0_data_r,

    input  cp0_we,
    input  [4:0] cp0_addr_w,
    input  [DATA_WIDTH-1:0] cp0_data_w,

    input  exception,
    input  [DATA_WIDTH-1:0] cause,
    input  [ADDR_WIDTH-1:0] pc,

    input  [4:0] int_device,
    output int_permit
    );

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;

    parameter STATUS    = 12;
    parameter CAUSE     = 13;
    parameter EPC       = 14;

    reg [DATA_WIDTH-1:0] rf [0:31];

    assign cp0_data_r = rf[cp0_addr_r];
    assign int_permit = rf[STATUS][31] & rf[STATUS][int_device];

    task init;
    integer i;
    begin
        for (i = 0; i < 32; i = i + 1)
            rf[i] <= 32'b0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin 
            if (cp0_we) rf[cp0_addr_w] <= cp0_data_w;
            if (exception) begin
                rf[STATUS][31]  <= 1'b0;
                rf[CAUSE]       <= cause;
                rf[EPC]         <= pc;
            end
        end
    end
endmodule

