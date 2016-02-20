module flash(
    input  clk,
    input  rst,

    input  [25:0]   block_addr,
    input  [31:0]   data_i,
    output [31:0]   data_o,
    input           we_i,
    input           rd_i,
    output          ack_o,

    output reg [25:0]   bpi_a,
    inout      [31:0]   bpi_q,
    output reg [ 1:0]   bpi_cen,
    output reg          bpi_oen,
    output reg          bpi_wen,
    output reg          bpi_rstn,
    input      [ 1:0]   bpi_rynby
    );

    reg  [31:0] data_or;
    reg  [31:0] timer;

    reg  [6:0] counter;
    wire [6:0] counter_next = counter + 1'b1;

    reg  [31:0] bpi_qr;
    assign bpi_q    = bpi_oen ? bpi_qr : {32{1'bz}};

    localparam  S_INIT = 0,
                S_IDLE = 1,
                S_READ = 2,
                S_WRITE = 3,
                S_END = 4;
    reg  [2:0] state;

    localparam  O_INIT  = 0,
                O_IDLE  = 1,
                O_OE    = 2,
                O_WE    = 3,
                O_WAIT  = 4,
                O_END   = 5;
    reg  [2:0] op_state;

    assign data_o   = data_or;
    assign ack_o    = (state != S_INIT) && (op_state == O_END) && (timer == 0);

    task init;
    begin
        bpi_a       <= 0;
        bpi_qr      <= 0;
        bpi_cen     <= 2'b11;
        bpi_oen     <= 1;
        bpi_wen     <= 1;
        bpi_rstn    <= 1;

        data_or     <= 0;
        timer       <= 30000;
        counter     <= 0;
        state       <= S_INIT;
        op_state    <= O_INIT;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            case (state)
                S_INIT: begin
                    if (op_state == O_END)
                        state <= S_IDLE;
                end
                S_IDLE: begin
                    if (we_i) begin
                        state   <= S_WRITE;
                        counter <= 0;
                    end
                    else if (rd_i) begin
                        state   <= S_READ;
                        counter <= 0;
                    end
                end
                S_READ: begin
                    if (op_state == O_END && timer == 0) begin
                        if (counter_next)   counter <= counter_next;
                        else                state   <= S_END;
                    end
                end
                S_WRITE: begin
                    if (op_state == O_END && timer == 0) begin
                        if (counter_next)   counter <= counter_next;
                        else                state   <= S_END;
                    end
                end
                S_END:  state <= S_IDLE;
            endcase

            if (timer)  timer <= timer - 1;
            else begin
                case (op_state)
                    O_INIT: op_state <= O_END;
                    O_IDLE: begin
                        bpi_a       <= {block_addr[18:0], counter};
                        if (state == S_READ) begin
                            bpi_cen     <= 2'b00;
                            bpi_oen     <= 1'b1;
                            bpi_wen     <= 1'b1;
                            timer       <= 8;
                            op_state    <= O_OE;
                        end
                        else if (state == S_WRITE) begin
                            bpi_cen     <= 2'b00;
                            bpi_oen     <= 1'b1;
                            bpi_wen     <= 1'b1;
                            bpi_qr      <= data_i;
                            timer       <= 0;
                            op_state    <= O_WE;
                        end
                    end
                    O_OE: begin
                        bpi_oen     <= 1'b0;
                        timer       <= 2;
                        op_state    <= O_END;
                    end
                    O_WE: begin
                        bpi_wen     <= 1'b0;
                        timer       <= 3;
                        op_state    <= O_WAIT;
                    end
                    O_WAIT: begin
                        bpi_cen     <= 2'b11;
                        bpi_wen     <= 1'b1;
                        timer       <= 2;
                        op_state    <= O_END;
                    end
                    O_END:  begin
                        op_state    <= O_IDLE;
                        bpi_a       <= 0;
                        bpi_cen     <= 2'b11;
                        bpi_oen     <= 1'b1;
                        data_or     <= bpi_q;
                    end
                endcase
            end
        end
    end

endmodule
