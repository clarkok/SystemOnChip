module arbiter(
    input  clk,
    input  rst,

    input  [ 31:0]  cd_addr_i,
    output [255:0]  cd_data_o,
    output [ 31:0]  cd_page_ent_o,
    input  [255:0]  cd_data_i,
    input           cd_we_i,
    input           cd_rd_i,
    output          cd_ack_o,
    output          cd_hw_page_fault_o,

    input  [ 31:0]  ci_addr_i,
    output [255:0]  ci_data_o,
    input           ci_rd_i,
    output          ci_ack_o,
    output          ci_hw_page_fault_o,

    output reg [ 31:0]  addr_o,
    input      [255:0]  data_i,
    output reg [255:0]  data_o,
    output reg          we_o,
    output reg          rd_o,
    input               ack_i,
    input               hw_page_fault_i,
    input      [ 31:0]  page_ent_i
    );

    reg     ci_operating;
    reg     in_operation;

    assign  cd_data_o           = data_i;
    assign  cd_page_ent_o       = page_ent_i;
    assign  cd_ack_o            = ~ci_operating && ack_i;
    assign  cd_hw_page_fault_o  = ~ci_operating && hw_page_fault_i;

    assign  ci_data_o           = data_i;
    assign  ci_ack_o            = ci_operating && ack_i;
    assign  ci_hw_page_fault_o  = ci_operating && hw_page_fault_i;

    task init;
    begin
        ci_operating    <= 0;
        in_operation    <= 0;
        addr_o          <= 0;
        data_o          <= 256'b0;
        we_o            <= 0;
        rd_o            <= 0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            if (in_operation) begin
                if (ack_i) begin
                    in_operation    <= 0;
                    rd_o            <= 0;
                    we_o            <= 0;
                end
            end
            else begin
                if (cd_rd_i || cd_we_i) begin
                    ci_operating    <= 0;
                    in_operation    <= 1;
                    addr_o          <= cd_addr_i;
                    data_o          <= cd_data_i;
                    we_o            <= cd_we_i;
                    rd_o            <= cd_rd_i;
                end
                else if (ci_rd_i) begin
                    ci_operating    <= 1;
                    in_operation    <= 1;
                    addr_o          <= ci_addr_i;
                    data_o          <= 256'b0;
                    we_o            <= 1'b0;
                    rd_o            <= 1'b1;
                end
                else begin
                    in_operation    <= 0;
                    rd_o            <= 0;
                    we_o            <= 0;
                end
            end
        end
    end

endmodule
