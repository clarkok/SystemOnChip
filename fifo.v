`include "functions.vh"

module grey_counter(
    input  clk,
    input  rst,
    output reg [WIDTH-1:0] counter,
    input  count
    );
    
    parameter WIDTH = 32;
    
    reg [WIDTH-1:0] binary_counter;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            binary_counter  <= {WIDTH{1'b0}} + 1;
            counter         <= {WIDTH{1'b0}};
        end
        else if (count) begin
            binary_counter  <= binary_counter + 1;
            counter         <= {
                    binary_counter[WIDTH-1],
                    binary_counter[WIDTH-2:0] ^ binary_counter[WIDTH-1:1]
                };
        end
    end
    
endmodule

module fifo(
    input  clk_r,
    input  clk_w,
    
    input  rst,
    input  rd,
    input  we,
    output reg [DATA_WIDTH-1:0] data_o,
    input  reg [DATA_WIDTH-1:0] data_i,
    output empty,
    output full
    );
    
    parameter DATA_WIDTH = 32;
    parameter BUFFER_SIZE = 1024;
    
    localparam BUFFER_DEPTH = `GET_WIDTH(BUFFER_SIZE);
    
    reg [DATA_WIDTH-1:0] queue [0:BUFFER_SIZE-1];
    reg [BUFFER_DEPTH-1:0] ptr_r;
    reg [BUFFER_DEPTH-1:0] ptr_w;
    
    wire [BUFFER_DEPTH-1:0] ptr_r_next = ptr_r + 1;
    wire [BUFFER_DEPTH-1:0] ptr_w_next = ptr_w + 1;
    
    assign data_o   = queue[ptr_r];
    assign empty    = (ptr_r == ptr_w);
    assign full     = (ptr_r == ptr_w_next);
    
    task init;
    begin
        ptr_r <= 0;
        ptr_w <= 0;
    end
    endtask
    
    initial init();
    
    always @(posedge clk_r) begin
        if (rd) begin
            
        end
    end
endmodule