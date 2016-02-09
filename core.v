`include "exceptions.vh"

module core_dec(
    input  clk,
    input  rst,

    input  core_run,

    output [INST_ADDR_WIDTH-1:0]    inst_addr_o,
    input  [31:0]                   inst_data_i,
    input                           inst_valid_i,

    input                           hw_interrupt,
    input  [31:0]                   hw_cause,

    input                           dec_pipeline_flush_i,
    input  [INST_ADDR_WIDTH-1:0]    dec_pc_i,

    output reg                          dec_exception_o,
    output reg                          dec_interrupt_o,
    output reg  [31:0]                  dec_cause_o,
    output reg  [INST_ADDR_WIDTH-1:0]   dec_pc_o,
    output reg  [4:0]                   dec_rs_o,
    output reg  [4:0]                   dec_rt_o,
    output reg  [4:0]                   dec_rd_o,
    output reg  [DATA_DATA_WIDTH-1:0]   dec_imm_o,
    output reg  [4:0]                   dec_shamt_o,
    output reg  [1:0]                   dec_pc_we_o,        // 0: always flush, 1: conditional flush, 2: Non
    output reg  [1:0]                   dec_pc_we_sel_o,    // 0: branch, 1: mem_result, 2: syscall, 3: eret
    output reg                          dec_reg_we_o,
    output reg  [2:0]                   dec_reg_we_sel_o,   // 0: alu_out, 1: bus_data, 2: pc + 4, 3: c0, 4: sc
    output reg  [2:0]                   dec_reg_we_dst_o,   // 0: rd, 1: rt, 2: $ra, 3: hi, 4: lo, 5:lohi
    output reg  [3:0]                   dec_alu_op_o,       //  0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15
                                                            //  add sub and slt or  xor nor sll srl sra sltueq  ne  lui mul mulu
    output reg  [2:0]                   dec_alu_a_sel_o,    //  0: rs, 1: rt, 2: exec_result, 3: mem_result, 4: hi, 5: lo, 6: 0, 7: imm
    output reg  [2:0]                   dec_alu_b_sel_o,    //  0: rt, 1: imm, 2: shamt, 3: exec_result, 4: mem_result, 5: 0, 6: rs
    output reg                          dec_load_unsigned_o,
    output reg                          dec_overflow_o,
    output reg  [1:0]                   dec_data_sel_o,     //  0: rt, 1: exec_result, 2: mem_result
    output reg                          dec_mem_rd_o,
    output reg                          dec_mem_we_o,
    output reg                          dec_mem_sc_o,
    output reg                          dec_mem_fc_o,
    output reg  [1:0]                   dec_mem_sel_o,
    output reg                          dec_cp0_we_o,
    output reg                          dec_eret_o,
    output reg                          dec_sc_valid_o
    );

    parameter INST_ADDR_WIDTH = 32;
    parameter DATA_ADDR_WIDTH = 32;
    parameter DATA_DATA_WIDTH = 32;

    localparam  NOP     = 32'h0;

    localparam  I_LB    = 0,
                I_LBU   = 1,
                I_LH    = 2,
                I_LHU   = 3,
                I_LW    = 4,
                I_LL    = 5,
                I_SB    = 6,
                I_SH    = 7,
                I_SW    = 8,
                I_SC    = 9,
                
                I_ADDI  = 10,
                I_ADDIU = 11,
                I_SLTI  = 12,
                I_SLTIU = 13,
                I_ANDI  = 14,
                I_ORI   = 15,
                I_XORI  = 16,
                I_LUI   = 17,

                I_ADD   = 18,
                I_ADDU  = 19,
                I_SUB   = 20,
                I_SUBU  = 21,
                I_SLT   = 22,
                I_SLTU  = 23,
                I_AND   = 24,
                I_OR    = 25,
                I_XOR   = 26,
                I_NOR   = 27,

                I_SLL   = 28,
                I_SRL   = 29,
                I_SRA   = 30,
                I_SLLV  = 31,
                I_SRLV  = 32,
                I_SRAV  = 33,

                I_MULT  = 34,
                I_MULTU = 35,
                I_DIV   = 36,
                I_DIVU  = 37,
                I_MFHI  = 38,
                I_MTHI  = 39,
                I_MFLO  = 40,
                I_MTLO  = 41,

                I_J     = 42,
                I_JAL   = 43,
                I_JR    = 44,
                I_JALR  = 45,

                I_BEQ   = 46,
                I_BNE   = 47,
                I_BLTZ  = 48,
                I_BGEZ  = 49,

                I_SCALL = 50,
                I_BREAK = 51,
                I_ERET  = 52,

                I_MFC0  = 53,
                I_MTC0  = 54,

                I_SYNC  = 55,

                NR_INST = I_SYNC + 1;

    function [NR_INST-1:0] decode;
    input [31:0] inst;
    `define op      (inst[31:26])
    `define func    (inst[ 5: 0])
    `define branch  (inst[20:16])
    begin
        decode[I_ADDIU]     = (`op == 6'b001_001);
        decode[I_ADDI]      = (`op == 6'b001_000);
        decode[I_ADDU]      = (`op == 6'b000_000) && (`func == 6'b100_001);
        decode[I_ADD]       = (`op == 6'b000_000) && (`func == 6'b100_000);
        decode[I_ANDI]      = (`op == 6'b001_100);
        decode[I_AND]       = (`op == 6'b000_000) && (`func == 6'b100_100);
        decode[I_BEQ]       = (`op == 6'b000_100);
        decode[I_BGEZ]      = (`op == 6'b000_001) && (`branch == 5'b00001);
        decode[I_BLTZ]      = (`op == 6'b000_001) && (`branch == 5'b00000);
        decode[I_BNE]       = (`op == 6'b000_101);
        decode[I_BREAK]     = (`op == 6'b000_000) && (`func == 6'b001_010);
        decode[I_DIVU]      = 1'b0;     // unsupported for now
        decode[I_DIV]       = 1'b0;     // unsupported for now
        decode[I_ERET]      = (`op == 6'b010_000) && (`func == 6'b011_000);
        decode[I_JALR]      = (`op == 6'b000_000) && (`func == 6'b001_001);
        decode[I_JAL]       = (`op == 6'b000_011);
        decode[I_JR]        = (`op == 6'b000_000) && (`func == 6'b001_000);
        decode[I_J]         = (`op == 6'b000_010);
        decode[I_LBU]       = (`op == 6'b100_100);
        decode[I_LB]        = (`op == 6'b100_000);
        decode[I_LHU]       = (`op == 6'b100_101);
        decode[I_LH]        = (`op == 6'b100_001);
        decode[I_LL]        = (`op == 6'b110_000);
        decode[I_LUI]       = (`op == 6'b001_111);
        decode[I_LW]        = (`op == 6'b100_011);
        decode[I_MFC0]      = (`op == 6'b010_000) && (`func == 6'b000_000);
        decode[I_MFHI]      = (`op == 6'b000_000) && (`func == 6'b010_000);
        decode[I_MFLO]      = (`op == 6'b000_000) && (`func == 6'b010_010);
        decode[I_MTC0]      = (`op == 6'b010_000) && (`func == 6'b000_100);
        decode[I_MTHI]      = (`op == 6'b000_000) && (`func == 6'b010_001);
        decode[I_MTLO]      = (`op == 6'b000_000) && (`func == 6'b010_011);
        decode[I_MULTU]     = (`op == 6'b000_000) && (`func == 6'b011_001);
        decode[I_MULT]      = (`op == 6'b000_000) && (`func == 6'b011_000);
        decode[I_NOR]       = (`op == 6'b000_000) && (`func == 6'b100_111);
        decode[I_ORI]       = (`op == 6'b001_101);
        decode[I_OR]        = (`op == 6'b000_000) && (`func == 6'b100_101);
        decode[I_SB]        = (`op == 6'b101_000);
        decode[I_SCALL]     = (`op == 6'b000_000) && (`func == 6'b001_100);
        decode[I_SC]        = (`op == 6'b111_000);
        decode[I_SH]        = (`op == 6'b101_001);
        decode[I_SLLV]      = (`op == 6'b000_000) && (`func == 6'b000_100);
        decode[I_SLL]       = (`op == 6'b000_000) && (`func == 6'b000_000);
        decode[I_SLTIU]     = (`op == 6'b001_011);
        decode[I_SLTI]      = (`op == 6'b001_010);
        decode[I_SLTU]      = (`op == 6'b000_000) && (`func == 6'b101_011);
        decode[I_SLT]       = (`op == 6'b000_000) && (`func == 6'b101_010);
        decode[I_SRAV]      = (`op == 6'b000_000) && (`func == 6'b000_111);
        decode[I_SRA]       = (`op == 6'b000_000) && (`func == 6'b000_011);
        decode[I_SRLV]      = (`op == 6'b000_000) && (`func == 6'b000_110);
        decode[I_SRL]       = (`op == 6'b000_000) && (`func == 6'b000_010);
        decode[I_SUBU]      = (`op == 6'b000_000) && (`func == 6'b100_011);
        decode[I_SUB]       = (`op == 6'b000_000) && (`func == 6'b100_010);
        decode[I_SW]        = (`op == 6'b101_011);
        decode[I_SYNC]      = (`op == 6'b000_000) && (`func == 6'b001_111);
        decode[I_XORI]      = (`op == 6'b001_110);
        decode[I_XOR]       = (`op == 6'b000_000) && (`func == 6'b100_110);
    end
    endfunction

    reg  [INST_ADDR_WIDTH-1:0]  the_pc;

    reg  [5:0]                  dec_dst_in_exec;
    reg  [5:0]                  dec_dst_in_mem;

    wire [31:0]                 dec_inst;
    wire [NR_INST-1:0]          dec_decoded;

    reg  load_in_exec;
    wire use_after_load = load_in_exec && (
                            inst_data_i[25:21] == dec_dst_in_exec ||
                            inst_data_i[20:16] == dec_dst_in_exec
                        );
    wire bubble         = use_after_load;

    assign inst_addr_o  = the_pc;
    assign dec_inst     = (inst_valid_i && ~bubble) ? inst_data_i : NOP;
    assign dec_decoded  = decode(dec_inst);

    task dec_init;
    begin
        dec_exception_o     <= 0;
        dec_interrupt_o     <= 0;
        dec_cause_o         <= 0;
        dec_pc_o            <= 0;
        dec_rs_o            <= 0;
        dec_rt_o            <= 0;
        dec_rd_o            <= 0;
        dec_imm_o           <= 0;
        dec_shamt_o         <= 0;
        dec_pc_we_o         <= 2;
        dec_pc_we_sel_o     <= 0;
        dec_reg_we_o        <= 0;
        dec_reg_we_sel_o    <= 0;
        dec_reg_we_dst_o    <= 0;
        dec_alu_op_o        <= 0;
        dec_alu_a_sel_o     <= 0;
        dec_alu_b_sel_o     <= 0;
        dec_load_unsigned_o <= 0;
        dec_overflow_o      <= 0;
        dec_data_sel_o      <= 0;
        dec_mem_rd_o        <= 0;
        dec_mem_we_o        <= 0;
        dec_mem_sc_o        <= 0;
        dec_mem_fc_o        <= 0;
        dec_mem_sel_o       <= 0;
        dec_cp0_we_o        <= 0;
        dec_eret_o          <= 0;
        dec_sc_valid_o      <= 0;

        dec_dst_in_exec     <= 6'b10_0000;
        dec_dst_in_mem      <= 6'b10_0000;
        load_in_exec        <= 1'b0;
        the_pc              <= 32'hFFFF_F001;
    end
    endtask

    initial dec_init();

    wire [INST_ADDR_WIDTH-1:0]  jump_addr   = {the_pc[31:28], dec_inst[25:0], the_pc[1:0]};
    wire [INST_ADDR_WIDTH-1:0]  branch_addr = the_pc + 4 + 
                                            {{(INST_ADDR_WIDTH-18){dec_inst[15]}}, dec_inst[15:0], 2'b00};

    wire dec_sign_ext   = |(dec_decoded[I_SLTIU:I_LB]);

    wire undefined_inst = !dec_decoded;
    wire privilege_inst = ~the_pc[0] && dec_decoded[I_MTC0:I_ERET];
    wire privilege_addr = ~the_pc[0] && the_pc[31];
    wire syscall        =  dec_decoded[I_SCALL];
    wire break          =  dec_decoded[I_BREAK];

    always @(posedge clk) begin
        if (rst) dec_init();
        else if (dec_pipeline_flush_i) begin
            dec_init();
            the_pc  <= dec_pc_i;
        end
        else if (core_run) begin
            if (inst_valid_i && ~bubble)
                case (1)
                    (|dec_decoded[I_JAL:I_J]):                  the_pc <= jump_addr;
                    (|dec_decoded[I_BGEZ:I_BEQ]):               the_pc <= branch_addr;
                    (|dec_decoded[I_JALR:I_JR] || 
                      dec_decoded[I_ERET]):                     the_pc <= the_pc;
                    default:                                    the_pc <= the_pc + 4;
                endcase
            dec_exception_o     <= undefined_inst | privilege_inst | privilege_addr | syscall | break;
            dec_interrupt_o     <= hw_interrupt;
            case (1)
                (hw_interrupt):     dec_cause_o <= hw_cause;
                (undefined_inst):   dec_cause_o <= `UNDEFINED_INST;
                (privilege_inst):   dec_cause_o <= `PRIVILEGE_INST;
                (privilege_addr):   dec_cause_o <= `PRIVILEGE_ADDR;
                (syscall):          dec_cause_o <= `SYSCALL;
                (break):            dec_cause_o <= `BREAK;
                default:            dec_cause_o <= 0;
            endcase
            dec_pc_o            <=  the_pc;

            dec_rs_o            <=  dec_inst[25:21];
            dec_rt_o            <=  dec_inst[20:16];
            dec_rd_o            <=  dec_inst[15:11];
            dec_imm_o           <=  {{16{(dec_sign_ext && dec_inst[15])}}, dec_inst[15: 0]};
            dec_shamt_o         <=  dec_inst[10: 6];
            case (1)
                (|dec_decoded[I_JALR:I_JR]):                dec_pc_we_o <= 0;
                (|dec_decoded[I_BGEZ:I_BEQ]):               dec_pc_we_o <= 1;
                default:                                    dec_pc_we_o <= 2;
            endcase
            case (1)
                (|dec_decoded[I_BGEZ:I_BEQ]):               dec_pc_we_sel_o <= 0;
                (|dec_decoded[I_JALR:I_JR]):                dec_pc_we_sel_o <= 1;
            endcase
            dec_reg_we_o        <=  dec_decoded[I_LL:I_LB] || 
                                    dec_decoded[I_SC] || 
                                    dec_decoded[I_MTLO:I_ADDI] ||
                                    dec_decoded[I_JAL] ||
                                    dec_decoded[I_JALR] ||
                                    dec_decoded[I_MFC0];
            case (1)
                (|dec_decoded[I_MTLO:I_ADDI]):                  dec_reg_we_sel_o <= 0;
                (|dec_decoded[I_LL:I_LB]):                      dec_reg_we_sel_o <= 1;
                (dec_decoded[I_JAL] | (dec_decoded[I_JALR])):   dec_reg_we_sel_o <= 2;
                (dec_decoded[I_MFC0]):                          dec_reg_we_sel_o <= 3;
                (dec_decoded[I_SC]):                            dec_reg_we_sel_o <= 4;
            endcase
            case (1)
                (dec_decoded[I_SRAV:I_ADD] ||
                 dec_decoded[I_JALR] ||
                 dec_decoded[I_MFHI] ||
                 dec_decoded[I_MFLO]): begin
                     dec_reg_we_dst_o <= 0;
                     dec_dst_in_exec[4:0] <= dec_inst[15:11];
                 end

                (dec_decoded[I_LL:I_LB] || 
                 dec_decoded[I_SC] ||
                 dec_decoded[I_LUI:I_ADDI] ||
                 dec_decoded[I_MFC0]): begin
                     dec_reg_we_dst_o <= 1;
                     dec_dst_in_exec[4:0] <= dec_inst[20:16];
                 end

                (dec_decoded[I_JAL]): begin
                     dec_reg_we_dst_o <= 2;
                     dec_dst_in_exec[4:0] <= 5'd31;
                 end

                (dec_decoded[I_MTHI]): begin
                     dec_reg_we_dst_o <= 3;
                     dec_dst_in_exec[4:0] <= 5'b0;
                 end

                (dec_decoded[I_MTLO]): begin
                     dec_reg_we_dst_o <= 4;
                     dec_dst_in_exec[4:0] <= 5'b0;
                 end

                (|dec_decoded[I_DIVU:I_MULT]): begin
                    dec_reg_we_dst_o <= 5;
                    dec_dst_in_exec[4:0] <= 5'b0;
                 end
            endcase
            case (1)
                (|dec_decoded[I_SC:I_LB]):          dec_alu_op_o <= 0;
                (|dec_decoded[I_ADDIU:I_ADDI]):     dec_alu_op_o <= 0;
                (dec_decoded[I_SLTI]):              dec_alu_op_o <= 3;
                (dec_decoded[I_SLTIU]):             dec_alu_op_o <= 10;
                (dec_decoded[I_ANDI]):              dec_alu_op_o <= 2;
                (dec_decoded[I_ORI]):               dec_alu_op_o <= 4;
                (dec_decoded[I_XORI]):              dec_alu_op_o <= 5;
                (dec_decoded[I_LUI]):               dec_alu_op_o <= 13;
                (|dec_decoded[I_ADDU:I_ADD]):       dec_alu_op_o <= 0;
                (|dec_decoded[I_SUBU:I_SUB]):       dec_alu_op_o <= 1;
                (dec_decoded[I_SLT]):               dec_alu_op_o <= 3;
                (dec_decoded[I_SLTU]):              dec_alu_op_o <= 10;
                (dec_decoded[I_AND]):               dec_alu_op_o <= 2;
                (dec_decoded[I_OR]):                dec_alu_op_o <= 4;
                (dec_decoded[I_XOR]):               dec_alu_op_o <= 5;
                (dec_decoded[I_NOR]):               dec_alu_op_o <= 6;
                (dec_decoded[I_SLL]):               dec_alu_op_o <= 7;
                (dec_decoded[I_SRL]):               dec_alu_op_o <= 8;
                (dec_decoded[I_SRA]):               dec_alu_op_o <= 9;
                (dec_decoded[I_SLLV]):              dec_alu_op_o <= 7;
                (dec_decoded[I_SRLV]):              dec_alu_op_o <= 8;
                (dec_decoded[I_SRAV]):              dec_alu_op_o <= 9;
                (dec_decoded[I_MULT]):              dec_alu_op_o <= 14;
                (dec_decoded[I_MULTU]):             dec_alu_op_o <= 15;
                (|dec_decoded[I_MTLO:I_MFHI]):      dec_alu_op_o <= 0;
                (dec_decoded[I_BEQ]):               dec_alu_op_o <= 11;
                (dec_decoded[I_BNE]):               dec_alu_op_o <= 12;
                (dec_decoded[I_BLTZ]):              dec_alu_op_o <= 3;
                (dec_decoded[I_BGEZ]):              dec_alu_op_o <= 3;
                (|dec_decoded[I_MTC0:I_MFC0]):      dec_alu_op_o <= 0;
                default:                            dec_alu_op_o <= 0;
            endcase
            case (1)
                (dec_decoded[I_XORI:I_LB] ||
                 dec_decoded[I_NOR:I_ADD] ||
                 dec_decoded[I_MULTU:I_MULT] ||
                 dec_decoded[I_MTHI] ||
                 dec_decoded[I_MTLO] ||
                 dec_decoded[I_BGEZ:I_BEQ] ||
                 dec_decoded[I_JALR:I_JR]):     dec_alu_a_sel_o <= 
                                                    (dec_inst[25:21] == dec_dst_in_exec) ? 2 :
                                                    (dec_inst[25:21] == dec_dst_in_mem)  ? 3 :
                                                                                           0;
                (dec_decoded[I_SRAV:I_SLL] ||
                 dec_decoded[I_MTC0]):          dec_alu_a_sel_o <= 
                                                    (dec_inst[20:16] == dec_dst_in_exec) ? 2 :
                                                    (dec_inst[20:16] == dec_dst_in_mem)  ? 3 :
                                                                                           1;
                (dec_decoded[I_MFHI]):          dec_alu_a_sel_o <= 4;
                (dec_decoded[I_MFLO]):          dec_alu_a_sel_o <= 5;
                (dec_decoded[I_LUI]):           dec_alu_a_sel_o <= 7;
                default:                        dec_alu_a_sel_o <= 6;
            endcase
            case (1)
                (dec_decoded[I_NOR:I_ADD] ||
                 dec_decoded[I_DIVU:I_MULT] ||
                 dec_decoded[I_BNE:I_BEQ]):     dec_alu_b_sel_o <= 
                                                    (dec_inst[20:16] == dec_dst_in_exec) ? 3 :
                                                    (dec_inst[20:16] == dec_dst_in_mem)  ? 4 : 0;
                (|dec_decoded[I_XORI:I_LB]):    dec_alu_b_sel_o <= 1;
                (|dec_decoded[I_SRA:I_SLL]):    dec_alu_b_sel_o <= 2;
                (|dec_decoded[I_SRAV:I_SLLV]):  dec_alu_b_sel_o <=
                                                    (dec_inst[25:21] == dec_dst_in_exec) ? 3 :
                                                    (dec_inst[25:21] == dec_dst_in_mem)  ? 4 : 6;
                default:                        dec_alu_b_sel_o <= 5;
            endcase
            dec_load_unsigned_o <= (dec_decoded[I_LBU] | dec_decoded[I_LHU]);
            dec_overflow_o      <= (dec_decoded[I_ADD] | dec_decoded[I_ADDI] | dec_decoded[I_SUB]);
            dec_data_sel_o      <= (dec_inst[20:16] == dec_dst_in_exec) ? 1 :
                                   (dec_inst[20:16] == dec_dst_in_mem)  ? 2 :
                                                                          0;
            dec_mem_rd_o        <= (|dec_decoded[I_LL:I_LB]);
            dec_mem_we_o        <= (|dec_decoded[I_SW:I_SB]);
            dec_mem_fc_o        <= (dec_decoded[I_SYNC] | dec_decoded[I_ERET]);
            dec_mem_sc_o        <= (dec_decoded[I_SC]);
            case (1)
                (dec_decoded[I_LBU:I_LB] || dec_decoded[I_SB]): dec_mem_sel_o <= 0;
                (dec_decoded[I_LHU:I_LH] || dec_decoded[I_SH]): dec_mem_sel_o <= 1;
                default:                                        dec_mem_sel_o <= 2;
            endcase
            dec_cp0_we_o        <= (dec_decoded[I_MTC0]);
            dec_eret_o          <= (dec_decoded[I_ERET]);
            dec_sc_valid_o      <= (dec_decoded[I_LL] || (dec_sc_valid_o && ~|dec_decoded[I_SW:I_SB]));

            dec_dst_in_exec[5]  <= ~(dec_decoded[I_LL:I_LB] || 
                                     dec_decoded[I_SC] || 
                                     dec_decoded[I_MTLO:I_MFHI] ||
                                     dec_decoded[I_SRAV:I_ADDI] ||
                                     dec_decoded[I_JAL] ||
                                     dec_decoded[I_JALR] ||
                                     dec_decoded[I_MFC0]);
            dec_dst_in_mem  <= dec_dst_in_exec;
            load_in_exec    <= |dec_decoded[I_LL:I_LB];
        end
    end
endmodule

module core_exe(
    input  clk,
    input  rst,
    input  core_run,

    input  [31:0]   exec_mem_result_i,
    input           exec_pipeline_flush_i,

    input                           dec_exception_o,
    input                           dec_interrupt_o,
    input  [31:0]                   dec_cause_o,
    input  [INST_ADDR_WIDTH-1:0]    dec_pc_o,
    input  [4:0]                    dec_rs_o,
    input  [4:0]                    dec_rt_o,
    input  [4:0]                    dec_rd_o,
    input  [DATA_DATA_WIDTH-1:0]    dec_imm_o,
    input  [4:0]                    dec_shamt_o,
    input  [1:0]                    dec_pc_we_o,
    input  [1:0]                    dec_pc_we_sel_o,
    input                           dec_reg_we_o,
    input  [2:0]                    dec_reg_we_sel_o,
    input  [2:0]                    dec_reg_we_dst_o,
    input  [3:0]                    dec_alu_op_o,
    input  [2:0]                    dec_alu_a_sel_o,
    input  [2:0]                    dec_alu_b_sel_o,
    input                           dec_load_unsigned_o,
    input                           dec_overflow_o,
    input  [1:0]                    dec_data_sel_o,
    input                           dec_mem_rd_o,
    input                           dec_mem_we_o,
    input                           dec_mem_sc_o,
    input                           dec_mem_fc_o,
    input  [1:0]                    dec_mem_sel_o,
    input                           dec_cp0_we_o,
    input                           dec_eret_o,
    input                           dec_sc_valid_o,

    output reg                          exec_exception_o,
    output reg                          exec_interrupt_o,
    output reg  [31:0]                  exec_cause_o,
    output reg  [INST_ADDR_WIDTH-1:0]   exec_pc_o,
    output reg  [4:0]                   exec_rt_o,
    output reg  [4:0]                   exec_rd_o,
    output reg  [1:0]                   exec_pc_we_o,
    output reg  [1:0]                   exec_pc_we_sel_o,
    output reg                          exec_reg_we_o,
    output reg  [2:0]                   exec_reg_we_sel_o,
    output reg  [2:0]                   exec_reg_we_dst_o,
    output reg                          exec_load_unsigned_o,
    output reg                          exec_mem_rd_o,
    output reg                          exec_mem_we_o,
    output reg                          exec_mem_fc_o,
    output reg  [1:0]                   exec_mem_sel_o,
    output reg  [31:0]                  exec_result_o,
    output reg  [63:0]                  exec_lohi_o,
    output reg  [DATA_DATA_WIDTH-1:0]   exec_data_o,
    output reg                          exec_cp0_we_o,
    output reg                          exec_eret_o,
    output reg                          exec_sc_valid_o,

    input  [63:0]                   lohi,
    output [4:0]                    reg_addr_a,
    input  [DATA_DATA_WIDTH-1:0]    reg_data_a,
    output [4:0]                    reg_addr_b,
    input  [DATA_DATA_WIDTH-1:0]    reg_data_b
    );

    parameter INST_ADDR_WIDTH = 32;
    parameter DATA_ADDR_WIDTH = 32;
    parameter DATA_DATA_WIDTH = 32;

    assign  reg_addr_a  = dec_rs_o;
    assign  reg_addr_b  = dec_rt_o;

    task exec_init;
    begin
        exec_exception_o    <= 0;
        exec_interrupt_o    <= 0;
        exec_cause_o        <= 0;
        exec_pc_o           <= 0;
        exec_rt_o           <= 0;
        exec_rd_o           <= 0;
        exec_pc_we_o        <= 2;
        exec_pc_we_sel_o    <= 0;
        exec_reg_we_o       <= 0;
        exec_reg_we_sel_o   <= 0;
        exec_reg_we_dst_o   <= 0;
        exec_load_unsigned_o <= 0;
        exec_mem_rd_o       <= 0;
        exec_mem_we_o       <= 0;
        exec_mem_fc_o       <= 0;
        exec_mem_sel_o      <= 0;
        exec_result_o       <= 0;
        exec_lohi_o         <= 0;
        exec_data_o         <= 0;
        exec_cp0_we_o       <= 0;
        exec_eret_o         <= 0;
        exec_sc_valid_o     <= 0;
    end
    endtask

    initial exec_init();

    wire [DATA_DATA_WIDTH-1:0]  exec_rs = reg_data_a;
    wire [DATA_DATA_WIDTH-1:0]  exec_rt = reg_data_b;

    reg  [DATA_DATA_WIDTH-1:0]  exec_alu_a;
    reg  [DATA_DATA_WIDTH-1:0]  exec_alu_b;
    reg  [DATA_DATA_WIDTH-1:0]  exec_alu_out;

    wire [63:0]                 exec_lohi_out   = dec_alu_op_o[0]
                                                    ? exec_alu_a * exec_alu_b
                                                    : $signed(exec_alu_a) * $signed(exec_alu_b);

    always @* begin
        case (dec_alu_a_sel_o)
            3'h0:   exec_alu_a  = exec_rs;
            3'h1:   exec_alu_a  = exec_rt;
            3'h2:   exec_alu_a  = exec_result_o;
            3'h3:   exec_alu_a  = exec_mem_result_i;
            3'h4:   exec_alu_a  = lohi[63:32];
            3'h5:   exec_alu_a  = lohi[31: 0];
            3'h6:   exec_alu_a  = 0;
            3'h7:   exec_alu_a  = dec_imm_o;
        endcase
    end

    always @* begin
        case (dec_alu_b_sel_o)
            3'h0:   exec_alu_b  = exec_rt;
            3'h1:   exec_alu_b  = dec_imm_o;
            3'h2:   exec_alu_b  = dec_shamt_o;
            3'h3:   exec_alu_b  = exec_result_o;
            3'h4:   exec_alu_b  = exec_mem_result_i;
            3'h5:   exec_alu_b  = 0;
            3'h6:   exec_alu_b  = exec_rs;
        endcase
    end

    wire [32:0] exec_add_res    = (dec_alu_op_o == 4'h0) ? (exec_alu_a + exec_alu_b)    :
                                  (dec_alu_op_o == 4'h1) ? (exec_alu_a - exec_alu_b)    :
                                                           33'b0;
    wire exec_overflow      = (exec_add_res[32] ^ dec_alu_op_o[0]);
    wire exec_overflow_err  = exec_overflow & dec_overflow_o;
    wire exec_no_exception  = ~( exec_exception_o ||
                                (exec_pc_we_o == 2'b0) ||                               // JR
                                (exec_pc_we_o == 2'b1 && exec_result_o == 0) ||         // predict missed
                                (exec_eret_o)
                                );

    always @(posedge clk) begin
        if (rst || exec_pipeline_flush_i) exec_init();
        else if (core_run) begin
            exec_exception_o        <= dec_exception_o | exec_overflow_err;
            exec_interrupt_o        <= dec_interrupt_o;
            exec_cause_o            <= (dec_interrupt_o || dec_exception_o) ? dec_cause_o :
                                       exec_overflow_err ? `OVERFLOW : 0;
            exec_pc_o               <= dec_pc_o;
            exec_rt_o               <= dec_rt_o;
            exec_rd_o               <= dec_rd_o;
            exec_pc_we_o            <= dec_pc_we_o;
            exec_pc_we_sel_o        <= dec_pc_we_sel_o;
            exec_reg_we_o           <= dec_reg_we_o && exec_no_exception;
            exec_reg_we_sel_o       <= dec_reg_we_sel_o;
            exec_reg_we_dst_o       <= dec_reg_we_dst_o;
            exec_load_unsigned_o    <= dec_load_unsigned_o;
            exec_mem_rd_o           <= dec_mem_rd_o && exec_no_exception;
            exec_mem_we_o           <=(dec_mem_we_o || (dec_mem_sc_o && dec_sc_valid_o)) && exec_no_exception;
            exec_mem_fc_o           <= dec_mem_fc_o && exec_no_exception;
            exec_mem_sel_o          <= dec_mem_sel_o;
            case (dec_alu_op_o)
                4'h0:       exec_result_o   <= exec_alu_a + exec_alu_b;
                4'h1:       exec_result_o   <= exec_alu_a - exec_alu_b;
                4'h2:       exec_result_o   <= exec_alu_a & exec_alu_b;
                4'h3:       exec_result_o   <= $signed(exec_alu_a) < $signed(exec_alu_b);
                4'h4:       exec_result_o   <= exec_alu_a | exec_alu_b;
                4'h5:       exec_result_o   <= exec_alu_a ^ exec_alu_b;
                4'h6:       exec_result_o   <= ~(exec_alu_a | exec_alu_b);
                4'h7:       exec_result_o   <= exec_alu_a << exec_alu_b[4:0];
                4'h8:       exec_result_o   <= exec_alu_a >> exec_alu_b[4:0];
                4'h9:       exec_result_o   <= $signed(exec_alu_a) >>> exec_alu_b[4:0];
                4'ha:       exec_result_o   <= exec_alu_a < exec_alu_b;
                4'hb:       exec_result_o   <= exec_alu_a == exec_alu_b;
                4'hc:       exec_result_o   <= exec_alu_a != exec_alu_b;
                4'hd:       exec_result_o   <= {exec_alu_a[15:0], 16'b0};
                default:    exec_result_o   <= 0;
            endcase
            exec_lohi_o             <= exec_lohi_out;
            case (dec_data_sel_o)
                2'h0:   exec_data_o <= exec_rt;
                2'h1:   exec_data_o <= exec_result_o;
                2'h2:   exec_data_o <= exec_mem_result_i;
            endcase
            exec_cp0_we_o           <= dec_cp0_we_o;
            exec_eret_o             <= dec_eret_o;
            exec_sc_valid_o         <= dec_sc_valid_o;
        end
    end
endmodule

module core_mem(
    input  clk,
    input  rst,
    input  core_run,

    input [31:0]                data_data_i,
    input [31:0]                cp0_data_i,
    input                       hw_page_fault,
    input [31:0]                cp0_ehb,
    input [31:0]                cp0_epc,

    input                       exec_exception_o,
    input                       exec_interrupt_o,
    input [31:0]                exec_cause_o,
    input [INST_ADDR_WIDTH-1:0] exec_pc_o,
    input [4:0]                 exec_rt_o,
    input [4:0]                 exec_rd_o,
    input [1:0]                 exec_pc_we_o,
    input [1:0]                 exec_pc_we_sel_o,
    input                       exec_reg_we_o,
    input [2:0]                 exec_reg_we_sel_o,
    input [2:0]                 exec_reg_we_dst_o,
    input                       exec_load_unsigned_o,
    input                       exec_mem_rd_o,
    input                       exec_mem_we_o,
    input                       exec_mem_fc_o,
    input [1:0]                 exec_mem_sel_o,
    input [31:0]                exec_result_o,
    input [63:0]                exec_lohi_o,
    input [DATA_DATA_WIDTH-1:0] exec_data_o,
    input                       exec_cp0_we_o,
    input                       exec_eret_o,
    input                       exec_sc_valid_o,

    output reg  [4:0]                   mem_rt_o,
    output reg  [4:0]                   mem_rd_o,
    output reg                          mem_reg_we_o,
    output reg  [2:0]                   mem_reg_we_dst_o,
    output reg  [31:0]                  mem_result_o,
    output reg  [63:0]                  mem_lohi_o,
    output reg                          mem_exception_o,
    output reg  [31:0]                  mem_cause_o,
    output reg                          mem_eret_o,
    output reg  [INST_ADDR_WIDTH-1:0]   mem_pc_o,
    output reg                          mem_pipeline_flush_o,
    output reg  [INST_ADDR_WIDTH-1:0]   mem_pc_data_o
    );

    parameter INST_ADDR_WIDTH = 32;
    parameter DATA_ADDR_WIDTH = 32;
    parameter DATA_DATA_WIDTH = 32;

    task mem_init;
    begin
        mem_rt_o                <= 0;
        mem_rd_o                <= 0;
        mem_reg_we_o            <= 0;
        mem_reg_we_dst_o        <= 0;
        mem_result_o            <= 0;
        mem_lohi_o              <= 0;
        mem_pipeline_flush_o    <= 0;
        mem_pc_data_o           <= 0;
        mem_exception_o         <= 0;
        mem_cause_o             <= 0;
        mem_eret_o              <= 0;
        mem_pc_o                <= 0;
    end
    endtask

    initial mem_init();

    reg [DATA_DATA_WIDTH-1:0] mem_bus_data;
    always @* begin
        case (exec_mem_sel_o)
            2'b0:       mem_bus_data = {{DATA_ADDR_WIDTH- 8{(~exec_load_unsigned_o) && data_data_i[ 7]}}, data_data_i[ 7:0]};
            2'b1:       mem_bus_data = {{DATA_ADDR_WIDTH-16{(~exec_load_unsigned_o) && data_data_i[15]}}, data_data_i[15:0]};
            default:    mem_bus_data = data_data_i;
        endcase
    end

    always @(posedge clk) begin
        if (rst || mem_pipeline_flush_o) mem_init();
        else if (core_run) begin
            mem_rt_o                <= exec_rt_o;
            mem_rd_o                <= exec_rd_o;
            mem_reg_we_o            <= exec_reg_we_o;
            mem_reg_we_dst_o        <= exec_reg_we_dst_o;
            case (exec_reg_we_sel_o)
                3'h0:   mem_result_o    <= exec_result_o;
                3'h1:   mem_result_o    <= mem_bus_data;
                3'h2:   mem_result_o    <= {exec_pc_o[INST_ADDR_WIDTH-1:2], 2'b00} + 4;
                3'h3:   mem_result_o    <= cp0_data_i;
                3'h4:   mem_result_o    <= exec_sc_valid_o;
            endcase
            mem_lohi_o              <= exec_lohi_o;
            mem_pipeline_flush_o    <= exec_interrupt_o ||
                                       exec_exception_o ||
                                       hw_page_fault ||
                                       exec_eret_o ||
                                      (exec_pc_we_o == 2'b0) ||                             // JR
                                      (exec_pc_we_o == 2'b1 && exec_result_o[31:0] == 0);   // predict missed
            case (1)
                (exec_exception_o ||
                 exec_interrupt_o ||
                 hw_page_fault):        mem_pc_data_o   <= {cp0_ehb[INST_ADDR_WIDTH-1:2], 2'b01};
                (exec_eret_o):          mem_pc_data_o   <=  cp0_epc;
                (exec_pc_we_o == 2'b0): mem_pc_data_o   <= {exec_result_o[INST_ADDR_WIDTH-1:2], exec_pc_o[1:0]};
                default:                mem_pc_data_o   <= exec_pc_o + 4;
            endcase
            mem_exception_o         <= exec_exception_o || hw_page_fault;
            mem_cause_o             <= exec_exception_o ? exec_cause_o : `MMU_PAGE_FAULT;
            mem_eret_o              <= exec_eret_o;
            mem_pc_o                <= exec_pc_o;
        end
    end
endmodule

module core_reg(
    input  clk,
    input  rst,
    input  core_run,

    input  [4:0]                    mem_rt_o,
    input  [4:0]                    mem_rd_o,
    input                           mem_reg_we_o,
    input  [2:0]                    mem_reg_we_dst_o,
    input  [31:0]                   mem_result_o,
    input  [63:0]                   mem_lohi_o,
    input                           mem_exception_o,
    input  [31:0]                   mem_cause_o,
    input                           mem_eret_o,
    input  [INST_ADDR_WIDTH-1:0]    mem_pc_o,

    output reg [63:0]               lohi,
    input  [4:0]                    reg_addr_a,
    output [DATA_DATA_WIDTH-1:0]    reg_data_a,
    input  [4:0]                    reg_addr_b,
    output [DATA_DATA_WIDTH-1:0]    reg_data_b
    );

    parameter INST_ADDR_WIDTH = 32;
    parameter DATA_ADDR_WIDTH = 32;
    parameter DATA_DATA_WIDTH = 32;

    reg [DATA_DATA_WIDTH-1:0]   reg_file [0:31];

    assign reg_data_a   = reg_file[reg_addr_a];
    assign reg_data_b   = reg_file[reg_addr_b];

    task reg_init;
    integer i;
    begin
        lohi                <= 0;
        for (i = 0; i < 32; i = i + 1)
            reg_file[i]     <= 0;
    end
    endtask

    initial reg_init();

    always @(posedge clk) begin
        if (rst) reg_init();
        else if (core_run && mem_reg_we_o) begin
            case (mem_reg_we_dst_o)
                3'h0:   if (mem_rd_o)   reg_file[mem_rd_o]  <= mem_result_o;
                3'h1:   if (mem_rt_o)   reg_file[mem_rt_o]  <= mem_result_o;
                3'h2:                   reg_file[5'b11111]  <= mem_result_o;
                3'h3:                   lohi[63:32]         <= mem_result_o;
                3'h4:                   lohi[31: 0]         <= mem_result_o;
                3'h5:                   lohi                <= mem_lohi_o;
            endcase
        end
    end
endmodule

module core(
    input  clk,
    input  rst,

    output [INST_ADDR_WIDTH-1:0]    inst_addr_o,
    input  [31:0]                   inst_data_i,
    input                           inst_valid_i,

    output [DATA_ADDR_WIDTH-1:0]    data_addr_o,
    input  [DATA_DATA_WIDTH-1:0]    data_data_i,
    output [DATA_DATA_WIDTH-1:0]    data_data_o,
    output [1:0]                    data_sel_o,
    output                          data_we_o,
    output                          data_rd_o,
    input                           data_valid_i,

    output                          mem_fc,
    input                           hw_page_fault,

    input                           hw_interrupt,
    input  [31:0]                   hw_cause,

    output                          exception,
    output [31:0]                   cause,
    output [INST_ADDR_WIDTH-1:0]    epc,
    output                          eret,

    output [4:0]                    cp0_addr_o,
    input  [31:0]                   cp0_data_i,
    output [31:0]                   cp0_data_o,
    output                          cp0_we_o,

    input  [INST_ADDR_WIDTH-1:0]    cp0_ehb,
    input  [INST_ADDR_WIDTH-1:0]    cp0_epc
    );

    parameter INST_ADDR_WIDTH = 32;
    parameter DATA_ADDR_WIDTH = 32;
    parameter DATA_DATA_WIDTH = 32;

    wire core_run   = ~(data_rd_o || data_we_o || mem_fc) || data_valid_i;

    wire [INST_ADDR_WIDTH-1:0]  dec_pc_i;
    wire                        dec_pipeline_flush_i;
    wire                        dec_exception_o;
    wire [31:0]                 dec_cause_o;
    wire [INST_ADDR_WIDTH-1:0]  dec_pc_o;
    wire [4:0]                  dec_rs_o;
    wire [4:0]                  dec_rt_o;
    wire [4:0]                  dec_rd_o;
    wire [DATA_DATA_WIDTH-1:0]  dec_imm_o;
    wire [4:0]                  dec_shamt_o;
    wire [1:0]                  dec_pc_we_o;
    wire [1:0]                  dec_pc_we_sel_o;
    wire                        dec_reg_we_o;
    wire [2:0]                  dec_reg_we_sel_o;
    wire [2:0]                  dec_reg_we_dst_o;
    wire [3:0]                  dec_alu_op_o;
    wire [2:0]                  dec_alu_a_sel_o;
    wire [2:0]                  dec_alu_b_sel_o;
    wire                        dec_load_unsigned_o;
    wire                        dec_overflow_o;
    wire [1:0]                  dec_data_sel_o;
    wire                        dec_mem_rd_o;
    wire                        dec_mem_we_o;
    wire                        dec_mem_sc_o;
    wire                        dec_mem_fc_o;
    wire [1:0]                  dec_mem_sel_o;
    wire                        dec_cp0_we_o;
    wire                        dec_eret_o;
    wire                        dec_sc_valid_o;

    core_dec core_dec(
        .clk(clk),
        .rst(rst),
        .core_run(core_run),
        .inst_addr_o(inst_addr_o),
        .inst_data_i(inst_data_i),
        .inst_valid_i(inst_valid_i),
        .hw_interrupt(hw_interrupt),
        .hw_cause(hw_cause),
        .dec_pc_i(dec_pc_i),
        .dec_pipeline_flush_i(dec_pipeline_flush_i),
        .dec_exception_o(dec_exception_o),
        .dec_cause_o(dec_cause_o),
        .dec_pc_o(dec_pc_o),
        .dec_rs_o(dec_rs_o),
        .dec_rt_o(dec_rt_o),
        .dec_rd_o(dec_rd_o),
        .dec_imm_o(dec_imm_o),
        .dec_shamt_o(dec_shamt_o),
        .dec_pc_we_o(dec_pc_we_o),
        .dec_pc_we_sel_o(dec_pc_we_sel_o),
        .dec_reg_we_o(dec_reg_we_o),
        .dec_reg_we_sel_o(dec_reg_we_sel_o),
        .dec_reg_we_dst_o(dec_reg_we_dst_o),
        .dec_alu_op_o(dec_alu_op_o),
        .dec_alu_a_sel_o(dec_alu_a_sel_o),
        .dec_alu_b_sel_o(dec_alu_b_sel_o),
        .dec_load_unsigned_o(dec_load_unsigned_o),
        .dec_overflow_o(dec_overflow_o),
        .dec_data_sel_o(dec_data_sel_o),
        .dec_mem_rd_o(dec_mem_rd_o),
        .dec_mem_we_o(dec_mem_we_o),
        .dec_mem_sc_o(dec_mem_sc_o),
        .dec_mem_fc_o(dec_mem_fc_o),
        .dec_mem_sel_o(dec_mem_sel_o),
        .dec_cp0_we_o(dec_cp0_we_o),
        .dec_eret_o(dec_eret_o),
        .dec_sc_valid_o(dec_sc_valid_o)
    );

    wire [31:0]                 exec_mem_result_i;
    wire                        exec_exception_o;
    wire [31:0]                 exec_cause_o;
    wire [INST_ADDR_WIDTH-1:0]  exec_pc_o;
    wire [4:0]                  exec_rt_o;
    wire [4:0]                  exec_rd_o;
    wire [1:0]                  exec_pc_we_o;
    wire [1:0]                  exec_pc_we_sel_o;
    wire                        exec_reg_we_o;
    wire [2:0]                  exec_reg_we_sel_o;
    wire [2:0]                  exec_reg_we_dst_o;
    wire                        exec_load_unsigned_o;
    wire                        exec_mem_rd_o;
    wire                        exec_mem_we_o;
    wire                        exec_mem_fc_o;
    wire [1:0]                  exec_mem_sel_o;
    wire [31:0]                 exec_result_o;
    wire [63:0]                 exec_lohi_o;
    wire [DATA_DATA_WIDTH-1:0]  exec_data_o;
    wire                        exec_cp0_we_o;
    wire                        exec_eret_o;
    wire                        exec_sc_valid_o;
    wire [63:0]                 lohi;
    wire [4:0]                  reg_addr_a;
    wire [DATA_DATA_WIDTH-1:0]  reg_data_a;
    wire [4:0]                  reg_addr_b;
    wire [DATA_DATA_WIDTH-1:0]  reg_data_b;

    core_exe core_exe(
        .clk(clk),
        .rst(rst),
        .core_run(core_run),
        .exec_mem_result_i(exec_mem_result_i),
        .exec_pipeline_flush_i(exec_pipeline_flush_i),
        .dec_exception_o(dec_exception_o),
        .dec_cause_o(dec_cause_o),
        .dec_pc_o(dec_pc_o),
        .dec_rs_o(dec_rs_o),
        .dec_rt_o(dec_rt_o),
        .dec_rd_o(dec_rd_o),
        .dec_imm_o(dec_imm_o),
        .dec_shamt_o(dec_shamt_o),
        .dec_pc_we_o(dec_pc_we_o),
        .dec_pc_we_sel_o(dec_pc_we_sel_o),
        .dec_reg_we_o(dec_reg_we_o),
        .dec_reg_we_sel_o(dec_reg_we_sel_o),
        .dec_reg_we_dst_o(dec_reg_we_dst_o),
        .dec_alu_op_o(dec_alu_op_o),
        .dec_alu_a_sel_o(dec_alu_a_sel_o),
        .dec_alu_b_sel_o(dec_alu_b_sel_o),
        .dec_load_unsigned_o(dec_load_unsigned_o),
        .dec_overflow_o(dec_overflow_o),
        .dec_data_sel_o(dec_data_sel_o),
        .dec_mem_rd_o(dec_mem_rd_o),
        .dec_mem_we_o(dec_mem_we_o),
        .dec_mem_sc_o(dec_mem_sc_o),
        .dec_mem_fc_o(dec_mem_fc_o),
        .dec_mem_sel_o(dec_mem_sel_o),
        .dec_cp0_we_o(dec_cp0_we_o),
        .dec_eret_o(dec_eret_o),
        .dec_sc_valid_o(dec_sc_valid_o),
        .exec_exception_o(exec_exception_o),
        .exec_cause_o(exec_cause_o),
        .exec_pc_o(exec_pc_o),
        .exec_rt_o(exec_rt_o),
        .exec_rd_o(exec_rd_o),
        .exec_pc_we_o(exec_pc_we_o),
        .exec_pc_we_sel_o(exec_pc_we_sel_o),
        .exec_reg_we_o(exec_reg_we_o),
        .exec_reg_we_sel_o(exec_reg_we_sel_o),
        .exec_reg_we_dst_o(exec_reg_we_dst_o),
        .exec_load_unsigned_o(exec_load_unsigned_o),
        .exec_mem_rd_o(exec_mem_rd_o),
        .exec_mem_we_o(exec_mem_we_o),
        .exec_mem_fc_o(exec_mem_fc_o),
        .exec_mem_sel_o(exec_mem_sel_o),
        .exec_result_o(exec_result_o),
        .exec_lohi_o(exec_lohi_o),
        .exec_data_o(exec_data_o),
        .exec_cp0_we_o(exec_cp0_we_o),
        .exec_eret_o(exec_eret_o),
        .exec_sc_valid_o(exec_sc_valid_o),
        .lohi(lohi),
        .reg_addr_a(reg_addr_a),
        .reg_data_a(reg_data_a),
        .reg_addr_b(reg_addr_b),
        .reg_data_b(reg_data_b)
    );

    wire [4:0]                  mem_rt_o;
    wire [4:0]                  mem_rd_o;
    wire                        mem_reg_we_o;
    wire [2:0]                  mem_reg_we_dst_o;
    wire [31:0]                 mem_result_o;
    wire [63:0]                 mem_lohi_o;
    wire                        mem_exception_o;
    wire [31:0]                 mem_cause_o;
    wire                        mem_eret_o;
    wire [INST_ADDR_WIDTH-1:0]  mem_pc_o;

    wire                        mem_pipeline_flush_o;
    wire [INST_ADDR_WIDTH-1:0]  mem_pc_data_o;

    core_mem core_mem(
        .clk(clk),
        .rst(rst),
        .core_run(core_run),
        .data_data_i(data_data_i),
        .cp0_data_i(cp0_data_i),
        .hw_page_fault(hw_page_fault),
        .cp0_ehb(cp0_ehb),
        .cp0_epc(cp0_epc),
        .exec_exception_o(exec_exception_o),
        .exec_cause_o(exec_cause_o),
        .exec_pc_o(exec_pc_o),
        .exec_rt_o(exec_rt_o),
        .exec_rd_o(exec_rd_o),
        .exec_pc_we_o(exec_pc_we_o),
        .exec_pc_we_sel_o(exec_pc_we_sel_o),
        .exec_reg_we_o(exec_reg_we_o),
        .exec_reg_we_sel_o(exec_reg_we_sel_o),
        .exec_reg_we_dst_o(exec_reg_we_dst_o),
        .exec_load_unsigned_o(exec_load_unsigned_o),
        .exec_mem_rd_o(exec_mem_rd_o),
        .exec_mem_we_o(exec_mem_we_o),
        .exec_mem_fc_o(exec_mem_fc_o),
        .exec_mem_sel_o(exec_mem_sel_o),
        .exec_result_o(exec_result_o),
        .exec_lohi_o(exec_lohi_o),
        .exec_data_o(exec_data_o),
        .exec_cp0_we_o(exec_cp0_we_o),
        .exec_eret_o(exec_eret_o),
        .exec_sc_valid_o(exec_sc_valid_o),
        .mem_rt_o(mem_rt_o),
        .mem_rd_o(mem_rd_o),
        .mem_reg_we_o(mem_reg_we_o),
        .mem_reg_we_dst_o(mem_reg_we_dst_o),
        .mem_result_o(mem_result_o),
        .mem_lohi_o(mem_lohi_o),
        .mem_exception_o(mem_exception_o),
        .mem_cause_o(mem_cause_o),
        .mem_eret_o(mem_eret_o),
        .mem_pc_o(mem_pc_o),
        .mem_pipeline_flush_o(mem_pipeline_flush_o),
        .mem_pc_data_o(mem_pc_data_o)
    );

    core_reg core_reg(
        .clk(clk),
        .rst(rst),
        .core_run(core_run),
        .mem_rt_o(mem_rt_o),
        .mem_rd_o(mem_rd_o),
        .mem_reg_we_o(mem_reg_we_o),
        .mem_reg_we_dst_o(mem_reg_we_dst_o),
        .mem_result_o(mem_result_o),
        .mem_lohi_o(mem_lohi_o),
        .mem_exception_o(mem_exception_o),
        .mem_cause_o(mem_cause_o),
        .mem_eret_o(mem_eret_o),
        .mem_pc_o(mem_pc_o),
        .lohi(lohi),
        .reg_addr_a(reg_addr_a),
        .reg_data_a(reg_data_a),
        .reg_addr_b(reg_addr_b),
        .reg_data_b(reg_data_b)
    );

    assign dec_pc_i                 = mem_pc_data_o;
    assign exec_mem_result_i        = mem_result_o;
    assign dec_pipeline_flush_i     = mem_pipeline_flush_o;
    assign exec_pipeline_flush_i    = mem_pipeline_flush_o;

    assign data_addr_o  = exec_result_o[DATA_ADDR_WIDTH-1:0];
    assign data_data_o  = exec_data_o;
    assign data_sel_o   = exec_mem_sel_o;
    assign data_we_o    = exec_mem_we_o;
    assign data_rd_o    = exec_mem_rd_o;
    assign mem_fc       = exec_mem_fc_o;

    assign cp0_addr_o   = exec_rd_o;
    assign cp0_data_o   = exec_result_o[31:0];
    assign cp0_we_o     = exec_cp0_we_o;

    assign exception    = mem_exception_o;
    assign cause        = mem_cause_o;
    assign epc          = exec_pc_o;    // FIXME
    assign eret         = mem_eret_o;
endmodule
