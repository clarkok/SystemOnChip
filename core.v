module CoreIFDC(
    input clk,
    input rst,

    input stall,

    input  interrupt,
    input  [DATA_WIDTH-1:0] cause,
    output exception_o,
    output [DATA_WIDTH-1:0] cause_o,

    output [ADDR_WIDTH-1:0] inst_addr,
    input  [DATA_WIDTH-1:0] inst_in,
    input  inst_valid,

    output reg [DATA_WIDTH-1:0] inst,
    output reg [ADDR_WIDTH-1:0] pc_out,

    output pc_we,
    output [2:0] pc_we_sel,     // 0: branch, 1: reg, 2: syscall, 3: eret, 4: MEM_RESULT
    output reg_we,
    output [2:0] reg_we_sel,    // 0: alu_out, 1: bus_data, 2: pc + 4, 3: alu_out << 16
                                // 4: c0
    output [1:0] reg_we_dst,    // 0: rd, 1: rt, 2: $31

    /*
    * 0: add
    * 1: sub
    * 2: and
    * 3: slt
    * 4: or
    * 5: xor
    * 6: nor
    * 7: sll
    * 8: srl
    * 9: sra
    * 10: sltu
    * 11: eq
    * 12: ne
     */
    output [4:0] alu_op,
    output [1:0] alu_a_sel,     // 0: rs, 1: rt, 2: 0, 3: MEM_RESULT
    output [1:0] alu_b_sel,     // 0: rt, 1: imm, 2: shamt, 3: MEM_RESULT
    output sign_ext,
    output c0_r,
    output c0_w,
    output mem_r,
    output mem_w,
    output mem_f,
    output [3:0] mem_sel,

    input  pc_we_i,
    input  [ADDR_WIDTH-1:0] pc_in
    );

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter NOOP       = 32'h00000000;    // sll $0, $0, 0

    reg  [ADDR_WIDTH-1:0] pc;
    wire [4:0] dst_in_exec;
    reg  [4:0] dst_in_mem;
    reg  [4:0] dst_in_wb;
    wire pc_in_exec;
    reg  pc_in_mem;
    reg  pc_in_wb;

    wire [ADDR_WIDTH-1:0] pc_next;
    wire [ 5:0] opcode  = inst[31:26];
    wire [ 5:0] func    = inst[ 5: 0];
    wire [25:0] addr    = inst[25: 0];
    wire [ 4:0] rs      = inst[25:21];
    wire [ 4:0] rt      = inst[20:16];
    wire [ 4:0] rd      = inst[15:11];

    wire i_add      = (opcode == 6'b000000) && (func == 6'b100000),
         i_addu     = (opcode == 6'b000000) && (func == 6'b100001),
         i_sub      = (opcode == 6'b000000) && (func == 6'b100010),
         i_subu     = (opcode == 6'b000000) && (func == 6'b100011),
         i_and      = (opcode == 6'b000000) && (func == 6'b100100),
         i_or       = (opcode == 6'b000000) && (func == 6'b100101),
         i_xor      = (opcode == 6'b000000) && (func == 6'b100110),
         i_nor      = (opcode == 6'b000000) && (func == 6'b100111),
         i_slt      = (opcode == 6'b000000) && (func == 6'b101010),
         i_sltu     = (opcode == 6'b000000) && (func == 6'b101011),
         i_sll      = (opcode == 6'b000000) && (func == 6'b000000),
         i_srl      = (opcode == 6'b000000) && (func == 6'b000010),
         i_sra      = (opcode == 6'b000000) && (func == 6'b000011),
         i_sllv     = (opcode == 6'b000000) && (func == 6'b000100),
         i_srlv     = (opcode == 6'b000000) && (func == 6'b000110),
         i_srav     = (opcode == 6'b000000) && (func == 6'b000111),
         i_jr       = (opcode == 6'b000000) && (func == 6'b001000),
         i_jalr     = (opcode == 6'b000000) && (func == 6'b001001),
         i_syscall  = (opcode == 6'b000000) && (func == 6'b001100),
         i_eret     = (opcode == 6'b010000) && (func == 6'b011000),
         i_mfco     = (opcode == 6'b010000) && (func == 6'b000000),
         i_mtco     = (opcode == 6'b010000) && (func == 6'b000100),
         i_addi     = (opcode == 6'b001000),
         i_addiu    = (opcode == 6'b001001),
         i_andi     = (opcode == 6'b001100),
         i_ori      = (opcode == 6'b001101),
         i_xori     = (opcode == 6'b001110),
         i_lui      = (opcode == 6'b001111),
         i_lw       = (opcode == 6'b100011),
         i_lh       = (opcode == 6'b100001),
         i_lb       = (opcode == 6'b100000),
         i_sw       = (opcode == 6'b101011),
         i_sh       = (opcode == 6'b101001),
         i_sb       = (opcode == 6'b101000),
         i_beq      = (opcode == 6'b000100),
         i_bne      = (opcode == 6'b000101),
         i_slti     = (opcode == 6'b001010),
         i_sltiu    = (opcode == 6'b001011),
         i_j        = (opcode == 6'b000010),
         i_jal      = (opcode == 6'b000011);

    assign pc_we        = i_jr || i_jalr || i_beq || i_bne || i_eret,
           pc_we_sel    = i_beq || i_bne    ? 3'h0  :
                          i_jr  || i_jalr   ? ((rs != 0 && rs == dst_in_wb) ? 3'h4 : 3'h1)  :
                          i_syscall         ? 3'h2  :
                                              3'h3,
           reg_we       = i_add || i_addu   || i_sub    || i_subu   || i_and    || 
                          i_or  || i_xor    || i_nor    || i_slt    || i_sltu   ||
                          i_sll || i_srl    || i_sra    || i_sllv   || i_srlv   ||
                          i_srav||
                          i_jalr|| i_mfco   || i_addi   || i_addiu  || i_andi   ||
                          i_ori || i_xori   || i_lui    || i_lw     || i_lh     ||
                          i_lb  || i_slti   || i_sltiu  || i_jal    || i_jalr,
           reg_we_sel   = (
                          i_add || i_addu   || i_sub    || i_subu   || i_and    ||
                          i_or  || i_xor    || i_nor    || i_slt    || i_sltu   ||
                          i_sll || i_srl    || i_sra    || i_sllv   || i_srlv   ||
                          i_srav|| i_addi   || i_addiu  || i_andi   || i_ori    ||
                          i_xori
                        ) ? 3'h0 :
                          ( i_lw  || i_lh     || i_lb ) ? 3'h1 :
                          ( i_jal || i_jalr )           ? 3'h2 :
                          ( i_lui )                     ? 3'h3 :
                                                          3'h4,
           reg_we_dst   = (
                          i_add || i_addu   || i_sub    || i_subu   || i_and    ||
                          i_or  || i_xor    || i_nor    || i_slt    || i_sltu   ||
                          i_sll || i_srl    || i_sra    || i_sllv   || i_srlv   ||
                          i_srav|| i_jalr
                        ) ? 3'h0 :
                          (
                          i_addi|| i_addiu  || i_andi   || i_ori    || i_xori   ||
                          i_mfco|| i_lw     || i_lh     || i_lb     || i_slti   ||
                          i_lui ||
                          i_sltiu
                        ) ? 3'h1 :
                            3'h2,
           alu_op       = ( i_add || i_addu || i_addi   || i_addiu  || i_lw     ||
                            i_lh  || i_lb   || i_sw     || i_sh     || i_sb     ||
                            i_mtco|| i_syscall
                          )    ? 5'h00 :
                          ( i_sub || i_subu )                           ? 5'h01 :
                          ( i_and || i_andi )                           ? 5'h02 :
                          ( i_slt || i_slti )                           ? 5'h03 :
                          ( i_or  || i_ori  || i_jr     || i_jalr )     ? 5'h04 :
                          ( i_xor || i_xori || i_lui )                  ? 5'h05 :
                          ( i_nor )                                     ? 5'h06 :
                          ( i_sll || i_sllv )                           ? 5'h07 :
                          ( i_srl || i_srlv )                           ? 5'h08 :
                          ( i_sra || i_srav )                           ? 5'h09 :
                          ( i_sltu|| i_sltiu )                          ? 5'h0A :
                          ( i_beq )                                     ? 5'h0B :
                                                                          5'h0C,
           alu_a_sel    = i_lui                        ? 2'h2 :
                          (i_sll || i_srl    || i_sra) ? ((rt != 0 && rt == dst_in_wb) ? 2'h3 : 2'h1) :
                                                         ((rs != 0 && rs == dst_in_wb) ? 2'h3 : 2'h0),
           alu_b_sel    = (
                          i_add || i_addu   || i_sub    || i_subu   || i_and    ||
                          i_or  || i_xor    || i_nor    || i_slt    || i_sltu   ||
                          i_sllv|| i_srlv   || i_srav   || i_beq    || i_bne    ||
                          i_mtco|| i_syscall
                        ) ? ((rt != 0 && rt == dst_in_wb) ? 2'h3 : 2'h0) :
                          (
                          i_addi|| i_addiu  || i_andi   || i_ori    || i_xori   ||
                          i_mfco|| i_lw     || i_lh     || i_lb     || i_sw     ||
                          i_sh     || i_sb     || i_slti   ||
                          i_lui ||
                          i_sltiu
                        ) ? 2'h1 : 2'h2,
           sign_ext     = (
                          i_addi|| i_lw     || i_lh     || i_lb     || i_beq    ||
                          i_bne || i_sw     || i_sh     || i_sb     || i_slti
                        ),
           c0_r         = i_mfco,
           c0_w         = i_mtco,
           mem_r        = (i_lw || i_lh     || i_lb),
           mem_w        = (i_sw || i_sh     || i_sb),
           mem_f        = (rt != 0 && rt == dst_in_wb),
           mem_sel      = (
                          (i_lw || i_sw) ?  4'b1111 : 
                          (i_lh || i_sh) ?  4'b0011 :
                                            4'b0001
                        ),
           inst_addr    = pc,
           exception_o  = interrupt || i_syscall,
           cause_o      = interrupt ? cause : 32;

    wire [ 5:0] n_opcode  = inst_in[31:26];
    wire [ 5:0] n_func    = inst_in[ 5: 0];
    wire [25:0] n_addr    = inst_in[25: 0];
    wire [ 4:0] n_rs      = inst_in[25:21];
    wire [ 4:0] n_rt      = inst_in[20:16];
    wire [ 4:0] n_rd      = inst_in[15:11];

    wire n_add      = (n_opcode == 6'b000000) && (n_func == 6'b100000),
         n_addu     = (n_opcode == 6'b000000) && (n_func == 6'b100001),
         n_sub      = (n_opcode == 6'b000000) && (n_func == 6'b100010),
         n_subu     = (n_opcode == 6'b000000) && (n_func == 6'b100011),
         n_and      = (n_opcode == 6'b000000) && (n_func == 6'b100100),
         n_or       = (n_opcode == 6'b000000) && (n_func == 6'b100101),
         n_xor      = (n_opcode == 6'b000000) && (n_func == 6'b100110),
         n_nor      = (n_opcode == 6'b000000) && (n_func == 6'b100111),
         n_slt      = (n_opcode == 6'b000000) && (n_func == 6'b101010),
         n_sltu     = (n_opcode == 6'b000000) && (n_func == 6'b101011),
         n_sll      = (n_opcode == 6'b000000) && (n_func == 6'b000000),
         n_srl      = (n_opcode == 6'b000000) && (n_func == 6'b000010),
         n_sra      = (n_opcode == 6'b000000) && (n_func == 6'b000011),
         n_sllv     = (n_opcode == 6'b000000) && (n_func == 6'b000100),
         n_srlv     = (n_opcode == 6'b000000) && (n_func == 6'b000110),
         n_srav     = (n_opcode == 6'b000000) && (n_func == 6'b000111),
         n_jr       = (n_opcode == 6'b000000) && (n_func == 6'b001000),
         n_jalr     = (n_opcode == 6'b000000) && (n_func == 6'b001001),
         n_syscall  = (n_opcode == 6'b000000) && (n_func == 6'b001100),
         n_eret     = (n_opcode == 6'b010000) && (n_func == 6'b011000),
         n_mfco     = (n_opcode == 6'b010000) && (n_func == 6'b000000),
         n_mtco     = (n_opcode == 6'b010000) && (n_func == 6'b000100),
         n_addi     = (n_opcode == 6'b001000),
         n_addiu    = (n_opcode == 6'b001001),
         n_andi     = (n_opcode == 6'b001100),
         n_ori      = (n_opcode == 6'b001101),
         n_xori     = (n_opcode == 6'b001110),
         n_lui      = (n_opcode == 6'b001111),
         n_lw       = (n_opcode == 6'b100011),
         n_lh       = (n_opcode == 6'b100001),
         n_lb       = (n_opcode == 6'b100000),
         n_sw       = (n_opcode == 6'b101011),
         n_sh       = (n_opcode == 6'b101001),
         n_sb       = (n_opcode == 6'b101000),
         n_beq      = (n_opcode == 6'b000100),
         n_bne      = (n_opcode == 6'b000101),
         n_slti     = (n_opcode == 6'b001010),
         n_sltiu    = (n_opcode == 6'b001011),
         n_j        = (n_opcode == 6'b000010),
         n_jal      = (n_opcode == 6'b000011);

    wire bubble_inst_not_valid      = !inst_valid;
    wire bubble_pc_not_valid        = pc_in_exec || pc_in_mem || pc_in_wb;
    wire bubble_rs_not_valid        = (n_rs != 0) && (n_rs == dst_in_exec);
    wire bubble_rt_not_valid        = (n_rt != 0) && (n_rt == dst_in_exec);
    wire bubble_use_rs              = (
                      n_add || n_addu   || n_sub    || n_subu   || n_and    ||
                      n_or  || n_xor    || n_nor    || n_slt    || n_sltu   ||
                      n_sll || n_srl    || n_sra    || n_sllv   || n_srlv   ||
                      n_srav|| n_addi   || n_addiu  || n_andi   || n_ori    ||
                      n_xori|| n_jr     || n_jalr   || n_lw     ||
                      n_lh  || n_lb     || n_sw     || n_sh     || n_sb     ||
                      n_beq || n_bne
                    );
    wire bubble_use_rt              = (
                      n_add || n_addu   || n_sub    || n_subu   || n_and    ||
                      n_or  || n_xor    || n_nor    || n_slt    || n_sltu   ||
                      n_sllv|| n_srlv   || n_srav   || n_sll    || n_srl    ||
                      n_sra || n_sw     || n_sh     || n_sb     || n_beq    ||
                      n_bne || n_mtco   || n_syscall
                    );
    wire bubble_oprand_not_valid    = (
                        (bubble_use_rs && bubble_rs_not_valid) || (bubble_use_rt && bubble_rt_not_valid)
                    );
    wire bubble     = bubble_inst_not_valid ||
                      bubble_pc_not_valid ||
                      bubble_oprand_not_valid;

    wire n_pc_wait      = n_jr || n_jalr || n_beq || n_bne || n_eret;
    wire pc_freeze      = (bubble || n_pc_wait) && !pc_we_i;

    assign pc_next  = (rst)             ? 32'b0 :
                      (pc_we_i)         ? pc_in : 
                      (n_j || n_jal)    ? {pc[31:28], n_addr, 2'b00} :
                      (pc + 4);
    assign dst_in_exec  = (!reg_we)            ? 5'b0 :
                          (reg_we_dst == 0)    ? rd :
                          (reg_we_dst == 1)    ? rt :
                                                 5'd31;
    assign pc_in_exec   = i_jr || i_jalr || i_beq || i_bne || i_eret;

    task init;
    begin
        inst        <= NOOP;
        pc          <= 0;
        pc_out      <= 0;
        dst_in_mem  <= 0;
        dst_in_wb   <= 0;
        pc_in_mem   <= 0;
        pc_in_wb    <= 0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else if (!stall) begin
            inst        <= bubble ? NOOP : inst_in;
            pc          <= pc_freeze ? pc : pc_next;
            pc_out      <= pc;
            dst_in_mem  <= dst_in_exec;
            dst_in_wb   <= dst_in_mem;
            pc_in_mem   <= pc_in_exec;
            pc_in_wb    <= pc_in_mem;
        end
    end
endmodule

module CoreEXEC(
    input clk,
    input rst,

    input stall,

    input exception,
    input [DATA_WIDTH-1:0] cause,
    output reg exception_o,
    output [DATA_WIDTH-1:0] cause_o,

    input [DATA_WIDTH-1:0] inst,
    input [ADDR_WIDTH-1:0] pc,

    input pc_we,
    input [2:0] pc_we_sel,
    input reg_we,
    input [2:0] reg_we_sel,
    input [1:0] reg_we_dst,
    input [4:0] alu_op,
    input [1:0] alu_a_sel,
    input [1:0] alu_b_sel,
    input sign_ext,
    input c0_r,
    input c0_w,
    input mem_r,
    input mem_w,
    input mem_f,
    input [3:0] mem_sel,
    input [DATA_WIDTH-1:0] mem_result,

    output reg [DATA_WIDTH-1:0] inst_o,
    output reg [ADDR_WIDTH-1:0] pc_o,
    output reg pc_we_o,
    output reg [2:0] pc_we_sel_o,
    output reg reg_we_o,
    output reg [2:0] reg_we_sel_o,
    output reg [1:0] reg_we_dst_o,
    output reg c0_r_o,
    output reg c0_w_o,
    output reg mem_r_o,
    output reg mem_w_o,
    output reg [3:0] mem_sel_o,
    output reg [DATA_WIDTH-1:0] exec_result,
    output reg [DATA_WIDTH-1:0] rt_data,

    output [4:0] reg_addra,
    input  [DATA_WIDTH-1:0] reg_dataa,
    output [4:0] reg_addrb,
    input  [DATA_WIDTH-1:0] reg_datab
    );

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;

    assign reg_addra    = inst[25:21],
           reg_addrb    = inst[20:16],
           cause_o      = (cause == 32) ? exec_result : cause;

    wire sign = sign_ext ? inst[15] : 1'b0;
    wire [DATA_WIDTH-1:0] imm = {{16{sign}}, inst[15:0]};

    wire [DATA_WIDTH-1:0] alu_a = (alu_a_sel == 0) ? reg_dataa  :
                                  (alu_a_sel == 1) ? reg_datab  :
                                  (alu_a_sel == 2) ? 32'b0      :
                                                     mem_result;
    wire [DATA_WIDTH-1:0] alu_b = (alu_b_sel == 0) ? reg_datab :
                                  (alu_b_sel == 1) ? imm :
                                  (alu_b_sel == 2) ? {27'b0, inst[10:6]} :
                                  mem_result;

    task init;
    begin
        exception_o     <= 0;
        inst_o          <= 0;
        pc_o            <= 0;
        pc_we_o         <= 0;
        pc_we_sel_o     <= 0;
        reg_we_o        <= 0;
        reg_we_sel_o    <= 0;
        reg_we_dst_o    <= 0;
        c0_r_o          <= 0;
        c0_w_o          <= 0;
        mem_r_o         <= 0;
        mem_w_o         <= 0;
        mem_sel_o       <= 0;
        exec_result     <= 0;
        rt_data         <= 0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else if (!stall) begin
            exception_o         <= exception;
            inst_o              <= inst;
            pc_o                <= pc;
            pc_we_o             <= pc_we;
            pc_we_sel_o         <= pc_we_sel;
            reg_we_o            <= reg_we;
            reg_we_sel_o        <= reg_we_sel;
            reg_we_dst_o        <= reg_we_dst;
            c0_r_o              <= c0_r;
            c0_w_o              <= c0_w;
            mem_r_o             <= mem_r;
            mem_w_o             <= mem_w;
            mem_sel_o           <= mem_sel;
            rt_data             <= mem_f ? mem_result : reg_datab;

            case (alu_op)
                5'h00:  exec_result     <= alu_a + alu_b;
                5'h01:  exec_result     <= alu_a - alu_b;
                5'h02:  exec_result     <= alu_a & alu_b;
                5'h03:  exec_result     <= $signed(alu_a) < $signed(alu_b);
                5'h04:  exec_result     <= alu_a | alu_b;
                5'h05:  exec_result     <= alu_a ^ alu_b;
                5'h06:  exec_result     <= ~(alu_a | alu_b);
                5'h07:  exec_result     <= alu_a << alu_b[4:0];
                5'h08:  exec_result     <= alu_a >> alu_b[4:0];
                5'h09:  exec_result     <= $signed(alu_a) >>> alu_b[4:0];
                5'h0A:  exec_result     <= alu_a < alu_b;
                5'h0B:  exec_result     <= alu_a == alu_b;
                5'h0C:  exec_result     <= alu_a != alu_b;
            endcase
        end
    end
endmodule

module CoreMEM(
    input clk,
    input rst,

    input stall,

    input exception,
    input [DATA_WIDTH-1:0] cause,
    output reg exception_o,
    output reg [DATA_WIDTH-1:0] cause_o,

    input [DATA_WIDTH-1:0] inst,
    input [ADDR_WIDTH-1:0] pc,

    input pc_we,
    input [2:0] pc_we_sel,
    input reg_we,
    input [2:0] reg_we_sel,
    input [1:0] reg_we_dst,
    input mem_r,
    input mem_w,
    input [3:0] mem_sel,
    input [DATA_WIDTH-1:0] exec_result,
    input [DATA_WIDTH-1:0] rt_data,
    input c0_r,
    input c0_w,

    output reg [DATA_WIDTH-1:0] inst_o,
    output reg reg_we_o,
    output reg [1:0] reg_we_dst_o,
    output reg [DATA_WIDTH-1:0] mem_result,
    output reg pc_we_o,
    output reg [ADDR_WIDTH-1:0] pc_o,

    output [ADDR_WIDTH-1:0] data_addr,
    input  [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out,
    output data_we,
    output data_rd,
    output [3:0] data_sel,

    output [4:0] cp0_addr_r,
    input  [DATA_WIDTH-1:0] cp0_data_r,
    output cp0_we,
    output [4:0] cp0_addr_w,
    output [DATA_WIDTH-1:0] cp0_data_w
    );

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;

    assign data_addr    = exec_result,
           data_out     = rt_data,
           data_we      = mem_w,
           data_rd      = mem_r,
           data_sel     = mem_sel,
           cp0_addr_r   = inst[15:11],
           cp0_we       = c0_w,
           cp0_addr_w   = inst[15:11],
           cp0_data_w   = exec_result;

    wire [ADDR_WIDTH-1:0] pc_offset = {{14{inst[15]}}, inst[15:0], 2'b00};

    wire [DATA_WIDTH-1:0] next_mem_result = (reg_we_sel == 0) ? exec_result :
                                            (reg_we_sel == 1) ? data_in     :
                                            (reg_we_sel == 2) ? pc + 4      :
                                            (reg_we_sel == 3) ? {exec_result[15:0], 16'b0}  :
                                                                cp0_data_r;

    task init;
    begin
        exception_o     <= 0;
        cause_o         <= 0;
        inst_o          <= 0;
        reg_we_o        <= 0;
        reg_we_dst_o    <= 0;
        mem_result      <= 0;
        pc_we_o         <= 0;
        pc_o            <= 0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else if (!stall) begin
            exception_o     <= exception;
            cause_o         <= cause;
            inst_o          <= inst;
            reg_we_o        <= reg_we;
            reg_we_dst_o    <= reg_we_dst;
            pc_we_o         <= pc_we;
            mem_result      <= next_mem_result;

            case (pc_we_sel)
                0: pc_o     <= pc + 4 + (exec_result ? pc_offset : 0);
                1: pc_o     <= exec_result;
                4: pc_o     <= next_mem_result;
                // TODO
            endcase
        end
    end
endmodule

module CoreWB(
    input clk,
    input rst,

    input [DATA_WIDTH-1:0] inst,

    input reg_we,
    input [1:0] reg_we_dst,
    input [DATA_WIDTH-1:0] mem_result,

    output reg_we_o,
    output [4:0] reg_addrw,
    output [DATA_WIDTH-1:0] reg_dataw
    );

    parameter DATA_WIDTH = 32;

    assign reg_we_o     = reg_we,
           reg_addrw    = (reg_we_dst == 0) ? inst[15:11] :
                          (reg_we_dst == 1) ? inst[20:16] :
                                              5'd31,
           reg_dataw    = mem_result;
endmodule

module CoreRegFile(
    input clk,
    input rst,

    input  [4:0] addra,
    input  [4:0] addrb,
    output [DATA_WIDTH-1:0] dataa,
    output [DATA_WIDTH-1:0] datab,

    input  [4:0] addrw,
    input  [DATA_WIDTH-1:0] dataw,
    input  we
    );

    parameter DATA_WIDTH = 32;

    reg [DATA_WIDTH-1:0] rf [1:31];

    assign dataa = (addra == 0) ? 32'b0 : rf[addra];
    assign datab = (addrb == 0) ? 32'b0 : rf[addrb];

    task init;
    integer i;
    begin
        for (i = 1; i < 32; i = i + 1)
            rf[i] <= 32'b0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else if (we && (addrw != 0)) rf[addrw] <= dataw;
    end
endmodule

module Core(
    input  clk,
    input  rst,

    output [ADDR_WIDTH-1:0] inst_addr,
    input  [DATA_WIDTH-1:0] inst_in,
    input  inst_valid,

    input  interrupt,
    input  [4:0] int_device,

    output [ADDR_WIDTH-1:0] data_addr,
    input  [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out,
    output data_we,
    output data_rd,
    output [3:0] data_sel,
    input  data_ready
    );

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    wire stall = ~data_ready;

    wire                    ifdc_exception;
    wire [DATA_WIDTH-1:0]   ifdc_cause;
    wire [DATA_WIDTH-1:0]   ifdc_inst;
    wire [ADDR_WIDTH-1:0]   ifdc_pc;
    wire                    ifdc_pc_we;
    wire [2:0]              ifdc_pc_we_sel;
    wire                    ifdc_reg_we;
    wire [2:0]              ifdc_reg_we_sel;
    wire [1:0]              ifdc_reg_we_dst;
    wire [4:0]              ifdc_alu_op;
    wire [1:0]              ifdc_alu_a_sel;
    wire [1:0]              ifdc_alu_b_sel;
    wire                    ifdc_sign_ext;
    wire                    ifdc_c0_r;
    wire                    ifdc_c0_w;
    wire                    ifdc_mem_r;
    wire                    ifdc_mem_w;
    wire [3:0]              ifdc_mem_sel;

    wire                    exec_exception;
    wire [DATA_WIDTH-1:0]   exec_cause;
    wire [DATA_WIDTH-1:0]   exec_inst;
    wire [ADDR_WIDTH-1:0]   exec_pc;
    wire                    exec_pc_we;
    wire [2:0]              exec_pc_we_sel;
    wire                    exec_reg_we;
    wire [2:0]              exec_reg_we_sel;
    wire [1:0]              exec_reg_we_dst;
    wire [DATA_WIDTH-1:0]   exec_result;
    wire [DATA_WIDTH-1:0]   exec_rt_data;
    wire [4:0]              exec_reg_addra;
    wire [DATA_WIDTH-1:0]   exec_reg_dataa;
    wire [4:0]              exec_reg_addrb;
    wire [DATA_WIDTH-1:0]   exec_reg_datab;
    wire                    exec_c0_r;
    wire                    exec_c0_w;
    wire                    exec_mem_r;
    wire                    exec_mem_w;
    wire [3:0]              exec_mem_sel;

    wire                    mem_exception;
    wire [DATA_WIDTH-1:0]   mem_cause;
    wire [DATA_WIDTH-1:0]   mem_inst;
    wire                    mem_reg_we;
    wire [1:0]              mem_reg_we_dst;
    wire [DATA_WIDTH-1:0]   mem_result;
    wire                    mem_pc_we;
    wire [ADDR_WIDTH-1:0]   mem_pc;
    wire [4:0]              mem_cp0_addr_r;
    wire [DATA_WIDTH-1:0]   mem_cp0_data_r;
    wire                    mem_cp0_we;
    wire [4:0]              mem_cp0_addr_w;
    wire [DATA_WIDTH-1:0]   mem_cp0_data_w;

    wire [4:0]              wb_addrw;
    wire [DATA_WIDTH-1:0]   wb_dataw;
    wire                    wb_we;

    wire [4:0]              cp0_device = int_device;
    wire                    cp0_interrupt;

    CoreIFDC core_ifdc(
        .clk(clk),
        .rst(rst || mem_exception),
        .stall(stall),
        .interrupt(cp0_interrupt || interrupt),
        .cause({27'b0, cp0_device}),
        .exception_o(ifdc_exception),
        .cause_o(ifdc_cause),
        .inst_addr(inst_addr),
        .inst_in(inst_in),
        .inst_valid(inst_valid),
        .inst(ifdc_inst),
        .pc_out(ifdc_pc),
        .pc_we(ifdc_pc_we),
        .pc_we_sel(ifdc_pc_we_sel),
        .reg_we(ifdc_reg_we),
        .reg_we_sel(ifdc_reg_we_sel),
        .reg_we_dst(ifdc_reg_we_dst),
        .alu_op(ifdc_alu_op),
        .alu_a_sel(ifdc_alu_a_sel),
        .alu_b_sel(ifdc_alu_b_sel),
        .sign_ext(ifdc_sign_ext),
        .c0_r(ifdc_c0_r),
        .c0_w(ifdc_c0_w),
        .mem_r(ifdc_mem_r),
        .mem_w(ifdc_mem_w),
        .mem_sel(ifdc_mem_sel),
        .pc_we_i(mem_pc_we),
        .pc_in(mem_pc)
        );

    CoreEXEC core_exec(
        .clk(clk),
        .rst(rst || mem_exception),
        .stall(stall),
        .exception(ifdc_exception),
        .cause(ifdc_cause),
        .exception_o(exec_exception),
        .cause_o(exec_cause),
        .inst(ifdc_inst),
        .pc(ifdc_pc),
        .pc_we(ifdc_pc_we),
        .pc_we_sel(ifdc_pc_we_sel),
        .reg_we(ifdc_reg_we),
        .reg_we_sel(ifdc_reg_we_sel),
        .reg_we_dst(ifdc_reg_we_dst),
        .alu_op(ifdc_alu_op),
        .alu_a_sel(ifdc_alu_a_sel),
        .alu_b_sel(ifdc_alu_b_sel),
        .sign_ext(ifdc_sign_ext),
        .c0_r(ifdc_c0_r),
        .c0_w(ifdc_c0_w),
        .mem_r(ifdc_mem_r),
        .mem_w(ifdc_mem_w),
        .mem_sel(ifdc_mem_sel),
        .mem_result(mem_result),
        .rt_data(exec_rt_data),

        .inst_o(exec_inst),
        .pc_o(exec_pc),
        .pc_we_o(exec_pc_we),
        .pc_we_sel_o(exec_pc_we_sel),
        .reg_we_o(exec_reg_we),
        .reg_we_sel_o(exec_reg_we_sel),
        .reg_we_dst_o(exec_reg_we_dst),
        .c0_r_o(exec_c0_r),
        .c0_w_o(exec_c0_w),
        .mem_r_o(exec_mem_r),
        .mem_w_o(exec_mem_w),
        .mem_sel_o(exec_mem_sel),
        .exec_result(exec_result),
        .reg_addra(exec_reg_addra),
        .reg_dataa(exec_reg_dataa),
        .reg_addrb(exec_reg_addrb),
        .reg_datab(exec_reg_datab)
        );

    CoreMEM core_mem(
        .clk(clk),
        .rst(rst),
        .exception(exec_exception),
        .cause(exec_cause),
        .exception_o(mem_exception),
        .cause_o(mem_cause),
        .stall(stall),
        .inst(exec_inst),
        .pc(exec_pc),
        .pc_we(exec_pc_we),
        .pc_we_sel(exec_pc_we_sel),
        .reg_we(exec_reg_we),
        .reg_we_sel(exec_reg_we_sel),
        .reg_we_dst(exec_reg_we_dst),
        .c0_r(exec_c0_r),
        .c0_w(exec_c0_w),
        .mem_r(exec_mem_r),
        .mem_w(exec_mem_w),
        .mem_sel(exec_mem_sel),
        .exec_result(exec_result),
        .rt_data(exec_rt_data),

        .inst_o(mem_inst),
        .reg_we_o(mem_reg_we),
        .reg_we_dst_o(mem_reg_we_dst),
        .mem_result(mem_result),
        .pc_we_o(mem_pc_we),
        .pc_o(mem_pc),

        .data_addr(data_addr),
        .data_in(data_in),
        .data_out(data_out),
        .data_we(data_we),
        .data_rd(data_rd),
        .data_sel(data_sel),

        .cp0_addr_r(mem_cp0_addr_r),
        .cp0_data_r(mem_cp0_data_r),
        .cp0_we(mem_cp0_we),
        .cp0_addr_w(mem_cp0_addr_w),
        .cp0_data_w(mem_cp0_data_w)
        );

    CoreWB core_wb(
        .clk(clk),
        .rst(rst),
        .inst(mem_inst),
        .reg_we(mem_reg_we),
        .reg_we_dst(mem_reg_we_dst),
        .mem_result(mem_result),
        .reg_we_o(wb_we),
        .reg_addrw(wb_addrw),
        .reg_dataw(wb_dataw)
        );

    CoreRegFile core_regfile(
        .clk(clk),
        .rst(rst),
        .addra(exec_reg_addra),
        .addrb(exec_reg_addrb),
        .dataa(exec_reg_dataa),
        .datab(exec_reg_datab),
        .addrw(wb_addrw),
        .dataw(wb_dataw),
        .we(wb_we)
        );

    CoProcessor0 core_cp0(
        .clk(clk),
        .rst(rst),
        .cp0_addr_r(mem_cp0_addr_r),
        .cp0_data_r(mem_cp0_data_r),
        .cp0_we(mem_cp0_we),
        .cp0_addr_w(mem_cp0_addr_w),
        .cp0_data_w(mem_cp0_data_w),
        .exception(mem_exception),
        .cause(mem_cause),
        .pc(exec_pc),
        .int_device(cp0_device),
        .int_permit(cp0_interrupt)
        );

endmodule
