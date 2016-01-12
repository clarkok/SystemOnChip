//
// uart module
//
// 1024Byte used as buffer
// 4Byte-addressed
// Lower 512Byte used as transmitting buffer
// Upper 512Byte used as receiving buffer
//
// Address 1024 is used as transmitting control register, writing this 
// register is a blocking operation.
// The register has the structure as following:
// | upper 22 bits | lower 10 bits |
// | task id       | length        |
//
// Address 1028 is used as receiving control register, setting this register
// to zero deasscert interrupt
// The register has the structure as following:
// | upper 22 bits | lower 10 bits |
// | task id       | length        |
//
module uart_dev(
    input  clk,
    input  rst,

    input  uart_rxd,
    output uart_txd,

    input           wb_stb,
    input           wb_we,
    input  [ 1:0]   wb_sel,
    input  [31:0]   wb_addr,
    input  [31:0]   wb_din,
    output [31:0]   wb_dout,
    output          wb_ack,

    output          interrupt
    );

    wire [31:0]     buffer_din;
    wire [31:0]     buffer_dout;
    wire            buffer_we;

    reg  [31:0]     tx_ctrl;
    reg  [31:0]     rx_ctrl;
    reg             done;

    uart_buffer uart_buffer(
        .clka(clk),
        .rsta(rst),
        .addra(wb_addr[9:2]),
        .dina(buffer_din),
        .douta(buffer_dout),
        .wea(buffer_we)
    );

    assign wb_dout  = wb_addr[10] ? (wb_addr[2] ? rx_ctrl : tx_ctrl) : buffer_dout;
    assign wb_ack   = wb_sel && ~wb_we && done;

    task init;
    begin
        tx_ctrl <= 0;
        rx_ctrl <= 0;
        done    <= 0;
    end
    endtask


endmodule
