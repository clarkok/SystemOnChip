module bus(
    input  clk,
    input  rst,

    input  [31:0]   m_addr_i,
    output [31:0]   m_data_o,
    input  [31:0]   m_data_i,
    input  [ 1:0]   m_sel_i,
    input           m_rd_i,
    input           m_we_i,
    output          m_ack_o,

    output [31:0]   gpu_addr_o,
    input  [31:0]   gpu_data_i,
    output [31:0]   gpu_data_o,
    output [ 1:0]   gpu_sel_o,
    output          gpu_rd_o,
    output          gpu_we_o,
    input           gpu_ack_i,

    output [31:0]   bios_addr_o,
    input  [31:0]   bios_data_i,
    output [31:0]   bios_data_o,
    output [ 1:0]   bios_sel_o,
    output          bios_rd_o,
    output          bios_we_o,
    input           bios_ack_i,

    output [31:0]   flash_addr_o,
    input  [31:0]   flash_data_i,
    output [31:0]   flash_data_o,
    output [ 1:0]   flash_sel_o,
    output          flash_rd_o,
    output          flash_we_o,
    input           flash_ack_i,

    output [31:0]   timer_addr_o,
    input  [31:0]   timer_data_i,
    output [31:0]   timer_data_o,
    output [ 1:0]   timer_sel_o,
    output          timer_rd_o,
    output          timer_we_o,
    input           timer_ack_i,

    output [31:0]   uart_addr_o,
    input  [31:0]   uart_data_i,
    output [31:0]   uart_data_o,
    output [ 1:0]   uart_sel_o,
    output          uart_rd_o,
    output          uart_we_o,
    input           uart_ack_i,

    output [31:0]   ps2_addr_o,
    input  [31:0]   ps2_data_i,
    output [31:0]   ps2_data_o,
    output [ 1:0]   ps2_sel_o,
    output          ps2_rd_o,
    output          ps2_we_o,
    input           ps2_ack_i
    );

    /*
        From            To              Usage
        0x0000_0000     0xFFC0_0000     Main memory
        0xFFC0_0000     0xFFFF_F000     Graphic memory
        0xFFFF_F000     0xFFFF_FC00     Bios
        0xFFFF_FC00     0xFFFF_FE00     Flash data
        0xFFFF_FE00     0xFFFF_FE04     Flash ctrl
        0xFFFF_FE04     0xFFFF_FE08     Timer
        0xFFFF_FE08     0xFFFF_FE0C     UART Rx
        0xFFFF_FE0C     0xFFFF_FE10     UART Tx
        0xFFFF_FE10     0xFFFF_FE14     PS2
    */

    parameter   GPU_ADDR_MASK   = 32'hFFC0_0000;
    parameter   BIOS_ADDR_MASK  = 32'hFFFF_F000;
    parameter   FLASH_ADDR_MASK = 32'hFFFF_FC00;

    parameter   FLASH_CTRL_MASK = 32'hFFFF_FE00;
    parameter   TIMER_ADDR_MASK = 32'hFFFF_FE04;
    parameter   URX_ADDR_MASK   = 32'hFFFF_FE08;
    parameter   UTX_ADDR_MASK   = 32'hFFFF_FE0C;
    parameter   PS2_ADDR_MASK   = 32'hFFFF_FE10;

    wire gpu_stb    = ((m_addr_i & GPU_ADDR_MASK) == GPU_ADDR_MASK) && (~m_addr_i[12]);
    wire bios_stb   = ((m_addr_i & BIOS_ADDR_MASK) == BIOS_ADDR_MASK) && (~m_addr_i[11]);

    wire flash_data_stb = ((m_addr_i & FLASH_ADDR_MASK) == FLASH_ADDR_MASK) && (~m_addr_i[9]);
    wire flash_ctrl_stb = (m_addr_i == FLASH_CTRL_MASK);
    wire flash_stb  = flash_data_stb || flash_ctrl_stb;

    wire timer_stb  = (m_addr_i == TIMER_ADDR_MASK);

    wire uart_rx_stb    = (m_addr_i == URX_ADDR_MASK);
    wire uart_tx_stb    = (m_addr_i == UTX_ADDR_MASK);
    wire uart_stb   = uart_rx_stb || uart_tx_stb;

    wire ps2_stb    = (m_addr_i == PS2_ADDR_MASK);

    assign  gpu_addr_o      = m_addr_i;
    assign  bios_addr_o     = m_addr_i;
    assign  flash_addr_o    = m_addr_i;
    assign  timer_addr_o    = m_addr_i;
    assign  uart_addr_o     = m_addr_i;
    assign  ps2_addr_o      = m_addr_i;

    assign  gpu_data_o      = m_data_i;
    assign  bios_data_o     = m_data_i;
    assign  flash_data_o    = m_data_i;
    assign  timer_data_o    = m_data_i;
    assign  uart_data_o     = m_data_i;
    assign  ps2_data_o      = m_data_i;

    assign  gpu_sel_o       = m_sel_i;
    assign  bios_sel_o      = m_sel_i;
    assign  flash_sel_o     = m_sel_i;
    assign  timer_sel_o     = m_sel_i;
    assign  uart_sel_o      = m_sel_i;
    assign  ps2_sel_o       = m_sel_i;

    assign  gpu_rd_o    = m_rd_i    && gpu_stb;
    assign  bios_rd_o   = m_rd_i    && bios_stb;
    assign  flash_rd_o  = m_rd_i    && flash_stb;
    assign  timer_rd_o  = m_rd_i    && timer_stb;
    assign  uart_rd_o   = m_rd_i    && uart_stb;
    assign  ps2_rd_o    = m_rd_i    && ps2_stb;

    assign  gpu_we_o    = m_we_i    && gpu_stb;
    assign  bios_we_o   = m_we_i    && bios_stb;
    assign  flash_we_o  = m_we_i    && flash_stb;
    assign  timer_we_o  = m_we_i    && timer_stb;
    assign  uart_we_o   = m_we_i    && uart_stb;
    assign  ps2_we_o    = m_we_i    && ps2_stb;

    assign  m_data_o    = gpu_stb   ?   gpu_data_i      :
                          bios_stb  ?   bios_data_i     :
                          flash_stb ?   flash_data_i    :
                          timer_stb ?   timer_data_i    :
                          uart_stb  ?   uart_data_i     :
                          ps2_stb   ?   ps2_data_i      :
                                        32'b0;
    assign  m_ack_o     = gpu_stb   ?   gpu_ack_i       :
                          bios_stb  ?   bios_ack_i      :
                          flash_stb ?   flash_ack_i     :
                          timer_stb ?   timer_ack_i     :
                          uart_stb  ?   uart_ack_i      :
                          ps2_stb   ?   ps2_ack_i       :
                                        1'b0;

endmodule
