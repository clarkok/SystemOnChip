`define HW_RESET        5'd0
`define MMU_PAGE_FAULT  5'd1
`define PS2_INT         5'd2
`define VGA_INT         5'd3
`define UART_INT        5'd4
`define TIMER_INT       5'd5

`define UNALIGNED_INST  5'd8
`define UNALIGNED_DATA  5'd9
`define UNDEFINED_INST  5'd10
`define PRIVILEGE_INST  5'd11
`define PRIVILEGE_ADDR  5'd12
`define OVERFLOW        5'd13
`define SYSCALL         5'd14
`define BREAK           5'd15
