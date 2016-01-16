//
// uart device
//
// 1024Byte used as buffer
// 4Byte-addressed
// Lower 512Byte used as transmitting buffer
// Upper 512Byte used as receiving buffer, which is read-only
//
// Address 1024 is used as transmitting control register, writing this 
// register is a blocking operation.
// The register has the structure as following:
// | upper 20 bits | lower 12 bits |
// | task id       | length        |
//
// Address 1028 is used as receiving control register, setting this register
// to zero deasscert interrupt
// The register has the structure as following:
// | upper 20 bits | lower 12 bits |
// | task id       | length        |
//
module uart_dev(
    input  clk,
    input  rst,

    input  uart_rxd,
    output uart_txd,

    input           wb_stb,
    input           wb_we,
    input  [31:0]   wb_addr,
    input  [31:0]   wb_din,
    output [31:0]   wb_dout,
    output          wb_ack,

    output          interrupt
    );

    wire [ 6:0] buffer_tx_addra;
    wire [31:0] buffer_tx_dina;
    wire        buffer_tx_wea;

    wire [ 6:0] buffer_tx_addrb;
    wire [31:0] buffer_tx_doutb;

    uart_buffer uart_buffer_tx(
        .clka(clk),
        .clkb(clk),

        .addra(buffer_tx_addra),
        .dina(buffer_tx_dina),
        .wea(buffer_tx_wea),

        .addrb(buffer_tx_addrb),
        .doutb(buffer_tx_doutb)
    );

    wire [ 6:0] buffer_rx_addra;
    wire [31:0] buffer_rx_dina;
    wire        buffer_rx_wea;

    wire [ 6:0] buffer_rx_addrb;
    wire [31:0] buffer_rx_doutb;

    uart_buffer uart_buffer_rx(
        .clka(clk),
        .clkb(clk),

        .addra(buffer_rx_addra),
        .dina(buffer_rx_dina),
        .wea(buffer_rx_wea),
        
        .addrb(buffer_rx_addrb),
        .doutb(buffer_rx_doutb)
    );

    wire [ 7:0] uart_din;
    wire        uart_send;
    wire        uart_sent;
    wire        uart_dout;
    wire        uart_recv;

    uart uart(
        .clk(clk),
        .rst(rst),

        .uart_rxd(uart_rxd),
        .uart_txd(uart_txd),

        .data_in(uart_din),
        .data_send(uart_send),
        .data_sent(uart_sent),
        .data_out(uart_dout),
        .data_received(uart_recv)
    );

    reg  [31:0] tx_ctrl;
    reg  [31:0] rx_ctrl;

    reg  [31:0] rx_buf;

    //
    // tx_state
    //  512: idle
    //  516 - 519: send ctrl
    //  0 - 511: send data
    //
    reg  [9:0]  tx_state;
    //
    // rx_state
    //  512: idle
    //  516 - 519: recv ctrl
    //  0 - 511: recv data
    //
    reg  [9:0]  rx_state;

    wire [9:0]  tx_state_next;
    wire [9:0]  rx_state_next;

    assign wb_dout     = wb_addr[10] 
                            ? (wb_addr[2] ? rx_state : tx_state)
                            : (wb_addr[9] ? buffer_rx_doutb : buffer_tx_doutb);
    assign wb_ack       = wb_stb && 
                         (wb_addr[10]
                            ? (wb_addr[2] ? 1'b1 : (~wb_we || tx_state_next == 512))
                            : (1'b1));
    assign interrupt    = (rx_ctrl != 0);

    assign buffer_tx_addra  = wb_addr[8:2];
    assign buffer_tx_dina   = wb_din;
    assign buffer_tx_wea    = (wb_addr[10:9] == 2'b00) && wb_stb && wb_we;

    assign buffer_tx_addrb  = tx_state[9] ? wb_addr[8:2] : tx_state[8:2];
    wire [31:0] tx_data     = tx_state[9] ? tx_ctrl : buffer_tx_doutb;
    assign uart_din         = (tx_state[1:0] == 2'b00) ? tx_data[ 7: 0] :
                              (tx_state[1:0] == 2'b01) ? tx_data[15: 8] :
                              (tx_state[1:0] == 2'b10) ? tx_data[23:16] :
                                                         tx_data[31:24];
    assign uart_send        = tx_state != 512;

    assign tx_state_next    = (tx_state == 512)                 ? ((wb_stb && ({wb_addr[10], wb_addr[2]} == 2'b10) && wb_we) ? 516 : 512) :
                              (~uart_sent)                      ? tx_state :
                              (tx_state == 519)                 ? 0 :
                              (tx_state == (tx_ctrl[12:0]-1))   ? 512 :
                                                                  tx_state + 1;
    wire [31:0] tx_ctrl_next    = (wb_stb && wb_we && ({wb_addr[10], wb_addr[2]} == 2'b10))     ? wb_din : tx_ctrl;

    assign buffer_rx_addra  = rx_state[8:2];
    assign buffer_rx_dina   = {rx_buf[23:0], uart_din};
    assign buffer_rx_wea    = ~rx_state[9] && uart_recv && (rx_state[1:0] == 2'b11);
    assign buffer_rx_addrb  = wb_addr[8:2];
    assign rx_state_next    = (rx_state == 512)                 ? (uart_recv ? 516 : 512) :
                              (~uart_recv)                      ? rx_state :
                              (rx_state == 519)                 ? 0 :
                              (rx_state == (rx_ctrl[12:0]-1))   ? 512 :
                                                                  rx_state + 1;

    wire [31:0] rx_ctrl_next    = (wb_stb && wb_we && (wb_addr[10] && wb_addr[2])) ? wb_din :
                                  (uart_recv && (rx_state == 519)) ? {rx_buf[23:0], uart_din} :
                                  rx_ctrl;
    wire [31:0] rx_buf_next     = uart_recv ? {rx_buf[23:0], uart_din} : rx_buf;

    task init;
    begin
        tx_ctrl     <= 0;
        rx_ctrl     <= 0;
        tx_state    <= 512;
        rx_state    <= 512;
        rx_buf      <= 0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            tx_ctrl     <= tx_ctrl_next;
            tx_state    <= tx_state_next;
            rx_ctrl     <= rx_ctrl_next;
            rx_state    <= rx_state_next;
            rx_buf      <= rx_buf_next;
        end
    end
endmodule
