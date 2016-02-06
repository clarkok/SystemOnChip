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
    input           ps2_ack_i,

    output [31:0]   timer_addr_o,
    input  [31:0]   timer_data_i,
    output [31:0]   timer_data_o,
    output [ 1:0]   timer_sel_o,
    output          timer_rd_o,
    output          timer_we_o,
    input           timer_ack_i
    );

    parameter   GPU_ADDR_MASK   = 32'hFFC0_0000;
    parameter   UART_ADDR_MASK  = 32'hFFFF_F800;
    parameter   PS2_ADDR_MASK   = 32'hFFFF_FC00;
    parameter   TIMER_ADDR_MASK = 32'hFFFF_FC04;

    wire gpu_stb    = ((m_addr_i & GPU_ADDR_MASK) == GPU_ADDR_MASK) && (~m_addr_i[11]);
    wire uart_stb   = ((m_addr_i & UART_ADDR_MASK) == UART_ADDR_MASK) && (~m_addr_i[10]);
    wire ps2_stb    = (m_addr_i == PS2_ADDR_MASK);
    wire timer_stb  = (m_addr_i == TIMER_ADDR_MASK);

    assign  gpu_addr_o      = m_addr_i;
    assign  uart_addr_o     = m_addr_i;
    assign  ps2_addr_o      = m_addr_i;
    assign  timer_addr_o    = m_addr_i;

    assign  gpu_data_o      = m_data_i;
    assign  uart_data_o     = m_data_i;
    assign  ps2_data_o      = m_data_i;
    assign  timer_data_o    = m_data_i;

    assign  gpu_sel_o       = m_sel_i;
    assign  uart_sel_o      = m_sel_i;
    assign  ps2_sel_o       = m_sel_i;
    assign  timer_sel_o     = m_sel_i;

    assign  gpu_rd_o    = m_rd_i    && gpu_stb;
    assign  uart_rd_o   = m_rd_i    && uart_stb;
    assign  ps2_rd_o    = m_rd_i    && ps2_stb;
    assign  timer_rd_o  = m_rd_i    && timer_stb;

    assign  gpu_we_o    = m_we_i    && gpu_stb;
    assign  uart_we_o   = m_we_i    && uart_stb;
    assign  ps2_we_o    = m_we_i    && ps2_stb;
    assign  timer_we_o  = m_we_i    && timer_stb;

    assign  m_data_o    = gpu_stb   ?   gpu_data_i      :
                          uart_stb  ?   uart_data_i     :
                          ps2_stb   ?   ps2_data_i      :
                          timer_stb ?   timer_data_i    :
                                        32'b0;
    assign  m_ack_o     = gpu_stb   ?   gpu_ack_i       :
                          uart_stb  ?   uart_ack_i      :
                          ps2_stb   ?   ps2_ack_i       :
                          timer_stb ?   timer_ack_i     :
                                        1'b0;

endmodule
