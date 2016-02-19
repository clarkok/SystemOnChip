module uart_dev(
    input  clk,
    input  rst,

    input  uart_rxd,
    output uart_txd,

    input  [31:0]   addr_i,
    output [31:0]   data_o,
    input  [31:0]   data_i,
    input  [ 1:0]   sel_i,
    input           rd_i,
    input           we_i,
    output          ack_o,

    output          interrupt
    );

    localparam  S_IDLE  = 0,
                S_END   = 1,
                S_SEND  = 2;
    reg  [1:0]  rx_state;
    reg  [1:0]  tx_state;

    wire [7:0]  uart_data_in;
    wire        uart_data_send;
    wire        uart_data_sent;

    wire [7:0]  uart_data_out;
    wire        uart_data_received;

    uart uart(
        .clk(clk),
        .rst(rst),
        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),
        .data_in(uart_data_in),
        .data_send(uart_data_send),
        .data_sent(uart_data_sent),
        .data_out(uart_data_out),
        .data_received(uart_data_received)
    );

    wire        rx_full;
    wire        rx_empty;
    wire [7:0]  rx_dout;
    wire        rx_rd;

    reg  [7:0]  rx_din;
    reg         rx_we;

    uart_buffer rx_buffer(
        .clk(clk),
        .srst(rst),
        .full(rx_full),
        .din(rx_din),
        .wr_en(rx_we),
        .empty(rx_empty),
        .dout(rx_dout),
        .rd_en(rx_rd)
    );

    assign rx_rd        = rd_i && (addr_i == 32'hFFFFFE08);
    assign data_o       = {24'b0, rx_dout};
    assign interrupt    = ~rx_empty;

    wire        tx_full;
    wire [7:0]  tx_din;
    wire        tx_we;
    wire        tx_empty;
    wire [7:0]  tx_dout;
    wire        tx_rd;

    uart_buffer tx_buffer(
        .clk(clk),
        .srst(rst),
        .full(tx_full),
        .din(tx_din),
        .wr_en(tx_we),
        .empty(tx_empty),
        .dout(tx_dout),
        .rd_en(tx_rd)
    );

    assign tx_din           = data_i[7:0];
    assign tx_we            = we_i && (addr_i == 32'hFFFFFE0C);
    assign tx_rd            = ~tx_empty && (tx_state == S_IDLE);
    assign uart_data_in     = tx_dout;
    assign uart_data_send   = (tx_state == S_SEND);

    assign ack_o            = (we_i && ~tx_full) || (rd_i && rx_state == S_END);

    task init;
    begin
        rx_din      <= 0;
        rx_we       <= 0;
        rx_state    <= S_IDLE;
        tx_state    <= S_IDLE;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            rx_din  <= uart_data_out;
            rx_we   <= uart_data_received;

            case (rx_state)
                S_IDLE: if (rd_i)   rx_state <= S_END;
                S_END:              rx_state <= S_IDLE;
            endcase

            case (tx_state)
                S_IDLE: if (~tx_empty)      tx_state <= S_SEND;
                S_SEND: if (uart_data_sent) tx_state <= S_END;
                S_END:                      tx_state <= S_IDLE;
            endcase
        end
    end

endmodule
