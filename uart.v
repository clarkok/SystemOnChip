`include "functions.vh"
module uart(
    input  clk,
    input  rst,

    input      uart_rxd,
    output reg uart_txd,

    input  [7:0]    data_in,
    input           data_send,
    output          data_sent,

    output [7:0]    data_out,
    output          data_received
    );

    parameter BAUD_RATE = 460800;
    parameter CLK_FREQ  = 100_000_000;   // 100MHz

    localparam CLK_DIV          = CLK_FREQ / BAUD_RATE;
    localparam CLK_DIV_WIDTH    = `GET_WIDTH(CLK_DIV);
    localparam HALF_CLK_DIV     = CLK_DIV / 2;

    //
    // tx_state:
    //  0   : idle
    //  1   : start_bit
    //  2-9 : data
    //  10  : stop_bit
    //
    reg  [3:0]              tx_state;
    reg  [7:0]              tx_buf;
    reg  [CLK_DIV_WIDTH:0]  tx_count;

    //
    // rx_state:
    //  0   : idle
    //  1   : verify_start_bit
    //  2-9 : data
    //  10  : stop_bit
    //
    reg  [3:0]              rx_state;
    reg  [7:0]              rx_buf;
    reg  [CLK_DIV_WIDTH:0]  rx_count;

    reg  [CLK_DIV_WIDTH:0]  sample_counter;

    wire rx_sampled         = (sample_counter >= HALF_CLK_DIV);

    assign data_sent        = (tx_state == 10) && (!tx_count);
    assign data_out         = rx_buf;
    assign data_received    = (rx_state == 10) && (rx_count == HALF_CLK_DIV);

    task init;
    begin
        tx_count        <= 0;
        tx_buf          <= 0;
        tx_state        <= 0;

        rx_count        <= 0;
        rx_buf          <= 0;
        rx_state        <= 0;

        uart_txd        <= 1;
        sample_counter  <= 0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            // tx logic
            if (tx_count) tx_count  <= tx_count - 1;
            else begin
                case (tx_state)
                    4'h0 : begin
                        if (data_send) begin
                            tx_buf      <= data_in;
                            tx_count    <= CLK_DIV-1;
                            tx_state    <= 4'h1;
                            uart_txd    <= 1'b0;
                        end
                    end
                    4'h1 : begin
                        tx_buf      <= {1'b0, tx_buf[7:1]};
                        tx_count    <= CLK_DIV-1;
                        tx_state    <= 4'h2;
                        uart_txd    <= tx_buf[0];
                    end
                    4'h2 : begin
                        tx_buf      <= {1'b0, tx_buf[7:1]};
                        tx_count    <= CLK_DIV-1;
                        tx_state    <= 4'h3;
                        uart_txd    <= tx_buf[0];
                    end
                    4'h3 : begin
                        tx_buf      <= {1'b0, tx_buf[7:1]};
                        tx_count    <= CLK_DIV-1;
                        tx_state    <= 4'h4;
                        uart_txd    <= tx_buf[0];
                    end
                    4'h4 : begin
                        tx_buf      <= {1'b0, tx_buf[7:1]};
                        tx_count    <= CLK_DIV-1;
                        tx_state    <= 4'h5;
                        uart_txd    <= tx_buf[0];
                    end
                    4'h5 : begin
                        tx_buf      <= {1'b0, tx_buf[7:1]};
                        tx_count    <= CLK_DIV-1;
                        tx_state    <= 4'h6;
                        uart_txd    <= tx_buf[0];
                    end
                    4'h6 : begin
                        tx_buf      <= {1'b0, tx_buf[7:1]};
                        tx_count    <= CLK_DIV-1;
                        tx_state    <= 4'h7;
                        uart_txd    <= tx_buf[0];
                    end
                    4'h7 : begin
                        tx_buf      <= {1'b0, tx_buf[7:1]};
                        tx_count    <= CLK_DIV-1;
                        tx_state    <= 4'h8;
                        uart_txd    <= tx_buf[0];
                    end
                    4'h8 : begin
                        tx_buf      <= {1'b0, tx_buf[7:1]};
                        tx_count    <= CLK_DIV-1;
                        tx_state    <= 4'h9;
                        uart_txd    <= tx_buf[0];
                    end
                    4'h9 : begin
                        tx_count    <= CLK_DIV-1;
                        tx_state    <= 4'ha;
                        uart_txd    <= 1'b1;
                    end
                    4'ha : begin
                        tx_count    <= CLK_DIV-1;
                        tx_state    <= 4'h0;
                    end
                endcase
            end

            // rx logic
            if (rx_count) begin
                rx_count        <= rx_count - 1;
                sample_counter  <= sample_counter + uart_rxd;
            end
            else begin
                sample_counter  <= 0;
                case (rx_state) 
                    4'h0 : begin
                        if (~uart_rxd) begin
                            rx_state    <= 4'h1;
                            rx_count    <= CLK_DIV-1;
                            sample_counter  <= 0;
                        end
                    end
                    4'h1 : begin
                        if (~rx_sampled) begin
                            rx_state    <= 4'h2;
                            rx_count    <= CLK_DIV-1;
                        end
                        else begin
                            rx_state    <= 4'h0;
                            rx_count    <= 0;
                        end
                    end
                    4'h2 : begin
                        rx_buf      <= {rx_sampled, rx_buf[7:1]};
                        rx_count    <= CLK_DIV-1;
                        rx_state    <= 4'h3;
                    end
                    4'h3 : begin
                        rx_buf      <= {rx_sampled, rx_buf[7:1]};
                        rx_count    <= CLK_DIV-1;
                        rx_state    <= 4'h4;
                    end
                    4'h4 : begin
                        rx_buf      <= {rx_sampled, rx_buf[7:1]};
                        rx_count    <= CLK_DIV-1;
                        rx_state    <= 4'h5;
                    end
                    4'h5 : begin
                        rx_buf      <= {rx_sampled, rx_buf[7:1]};
                        rx_count    <= CLK_DIV-1;
                        rx_state    <= 4'h6;
                    end
                    4'h6 : begin
                        rx_buf      <= {rx_sampled, rx_buf[7:1]};
                        rx_count    <= CLK_DIV-1;
                        rx_state    <= 4'h7;
                    end
                    4'h7 : begin
                        rx_buf      <= {rx_sampled, rx_buf[7:1]};
                        rx_count    <= CLK_DIV-1;
                        rx_state    <= 4'h8;
                    end
                    4'h8 : begin
                        rx_buf      <= {rx_sampled, rx_buf[7:1]};
                        rx_count    <= CLK_DIV-1;
                        rx_state    <= 4'h9;
                    end
                    4'h9 : begin
                        rx_buf      <= {rx_sampled, rx_buf[7:1]};
                        rx_count    <= CLK_DIV-1;
                        rx_state    <= 4'ha;
                    end
                    4'ha : begin
                        if (rx_sampled) begin
                            rx_state    <= 4'h0;
                            rx_count    <= HALF_CLK_DIV;
                        end
                        else begin
                            rx_count    <= CLK_DIV-1;
                            rx_state    <= 4'h0;
                        end
                    end
                endcase
            end
        end
    end

endmodule
