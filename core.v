`include "exceptions.vh"

module Core(
    input  clk,
    input  rst,

    output [INST_ADDR_WIDTH-1:0]    inst_addr_o,
    input  [31:0]                   inst_data_i,
    input                           inst_valid,

    output [DATA_ADDR_WIDTH-1:0]    data_addr_o,
    input  [DATA_DATA_WIDTH-1:0]    data_data_i,
    output [DATA_DATA_WIDTH-1:0]    data_data_o,
    output [1:0]                    data_sel_o,
    output                          data_we_o,
    output                          data_rd_o,
    input                           data_valid_i,

    input                           hw_interrupt,
    input  [31:0]                   hw_cause
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
                I_ERET  = 51,
                I_BREAK = 52,

                I_MFC0  = 53,
                I_MTC0  = 54,

                I_SYNC  = 55,

                NR_INST = I_SYNC + 1;

    // decode part
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

    wire pipeline_flush;

    reg                         dec_exception_o;
    reg  [31:0]                 dec_cause_o;
    reg  [INST_ADDR_WIDTH-1:0]  dec_pc_o;
    reg  [4:0]                  dec_rs_o;
    reg  [4:0]                  dec_rt_o;
    reg  [4:0]                  dec_rd_o;
    reg  [4:0]                  dec_imm_o;
    reg  [4:0]                  dec_shamt_o;
    reg  [1:0]                  dec_pc_we_o;        // 0: always flush, 1: conditional flush, 2: Non
    reg  [1:0]                  dec_pc_we_sel_o;    // 0: branch, 1: mem_result, 2: syscall, 3: eret
    reg                         dec_reg_we_o;
    reg  [2:0]                  dec_reg_we_sel_o;   // 0: alu_out, 1: bus_data, 2: pc + 4, 3: c0
    reg  [2:0]                  dec_reg_we_dst_o;   // 0: rd, 1: rt, 2: $ra, 3: hi, 4: lohi
    reg  [3:0]                  dec_alu_op_o;       //  0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15
                                                    //  add sub and slt or  xor nor sll srl sra sltueq  ne  lui mul mulu
    reg  [2:0]                  dec_alu_a_sel_o;    //  0: rs, 1: rt, 2: exec_result, 3: mem_result, 4: hi, 5: lo, 6: 0, 7: imm
    reg  [2:0]                  dec_alu_b_sel_o;    //  0: rt, 1: imm, 2: shamt, 3: exec_result, 4: mem_result, 5: 0
    reg                         dec_sign_ext_o;
    reg                         dec_load_unsigned_o;
    reg                         dec_mem_rd_o;
    reg                         dec_mem_we_o;
    reg                         dec_mem_fc_o;
    reg                         dec_mem_sc_o;
    reg  [1:0]                  dec_mem_sel_o;

    reg  [5:0]                  dec_dst_in_exec;
    reg  [5:0]                  dec_dst_in_mem;

    wire [INST_ADDR_WIDTH-1:0]  dec_pc_i;

    wire [31:0]                 dec_inst;
    wire [NR_INST-1:0]          dec_decoded;

    assign dec_inst     = inst_valid ? inst_data_i : NOP;
    assign dec_decoded  = decode(dec_inst);

    task dec_init;
    begin
        dec_exception_o     <= 0;
        dec_cause_o         <= 0;
        dec_pc_o            <= pipeline_flush ? dec_pc_i : 0;
        dec_rs_o            <= 0;
        dec_rt_o            <= 0;
        dec_rd_o            <= 0;
        dec_imm_o           <= 0;
        dec_shamt_o         <= 0;
        dec_pc_we_o         <= 0;
        dec_pc_we_sel_o     <= 0;
        dec_reg_we_o        <= 0;
        dec_reg_we_sel_o    <= 0;
        dec_reg_we_dst_o    <= 0;
        dec_alu_op_o        <= 0;
        dec_alu_a_sel_o     <= 0;
        dec_alu_b_sel_o     <= 0;
        dec_sign_ext_o      <= 0;
        dec_load_unsigned_o <= 0;
        dec_mem_rd_o        <= 0;
        dec_mem_we_o        <= 0;
        dec_mem_fc_o        <= 0;
        dec_mem_sc_o        <= 0;
        dec_mem_sel_o       <= 0;

        dec_dst_in_exec     <= 6'b10_0000;
        dec_dst_in_mem      <= 6'b10_0000;
    end
    endtask

    initial dec_init();

    wire [INST_ADDR_WIDTH-1:0]  jump_addr   = {dec_pc_o[31:28], dec_inst[25:0], 2'b00};
    wire [INST_ADDR_WIDTH-1:0]  branch_addr = dec_pc_o + 4 + {{(INST_ADDR_WIDTH-18){dec_inst[15]}}, dec_inst[15:0], 2'b00};

    always @(posedge clk) begin
        if (rst || pipeline_flush) dec_init();
        else if (data_valid_i) begin
            dec_exception_o     <=  hw_interrupt | (!dec_decoded);   // inst invalid
            dec_cause_o         <=  hw_interrupt ? hw_cause : `INVALID_INST;
            case (1)
                (dec_decoded[I_JAL:I_J]):                   dec_pc_o    <= jump_addr;
                (dec_decoded[I_BGEZ:I_BEQ]):                dec_pc_o    <= branch_addr;
                (dec_decoded[I_JALR:I_JR] || 
                 dec_decoded[I_BREAK:I_SCALL]):             dec_pc_o    <= dec_pc_o;
                default:                                    dec_pc_o    <= dec_pc_o + 4;
            endcase
            dec_rs_o            <=  dec_inst[25:21];
            dec_rt_o            <=  dec_inst[20:16];
            dec_rd_o            <=  dec_inst[15:11];
            dec_imm_o           <=  dec_inst[15: 0];
            dec_shamt_o         <=  dec_inst[10: 6];
            case (1)
                (dec_decoded[I_JR:I_JALR]):                 dec_pc_we_o <= 0;
                (dec_decoded[I_BGEZ:I_BEQ]):                dec_pc_we_o <= 1;
                default:                                    dec_pc_we_o <= 2;
            endcase
            case (1)
                (dec_decoded[I_BGEZ:I_BEQ]):                dec_pc_we_sel_o <= 0;
                (dec_decoded[I_JALR:I_JR]):                 dec_pc_we_sel_o <= 1;
                (dec_decoded[I_SCALL]):                     dec_pc_we_sel_o <= 2;
                (dec_decoded[I_ERET]):                      dec_pc_we_sel_o <= 3;
            endcase
            dec_reg_we_o        <=  dec_decoded[I_LL:I_LB] || 
                                    dec_decoded[I_SC] || 
                                    dec_decoded[I_MTLO:I_ADDI] ||
                                    dec_decoded[I_JAL] ||
                                    dec_decoded[I_JALR] ||
                                    dec_decoded[I_MFC0];
            case (1)
                (dec_decoded[I_MTLO:I_ADDI]):                   dec_reg_we_sel_o <= 0;
                (dec_decoded[I_LL:I_LB]):                       dec_reg_we_sel_o <= 1;
                (dec_decoded[I_JAL] | (dec_decoded[I_JALR])):   dec_reg_we_sel_o <= 2;
                (dec_decoded[I_MFC0]):                          dec_reg_we_sel_o <= 3;
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

                (dec_decoded[I_DIVU:I_MULT] ||
                 dec_decoded[I_MTLO]): begin
                    dec_reg_we_dst_o <= 4;
                    dec_dst_in_exec[4:0] <= 5'b0;
                 end
            endcase
            case (1)
                (dec_decoded[I_SC:I_LB]):           dec_alu_op_o <= 0;
                (dec_decoded[I_ADDIU:I_ADDI]):      dec_alu_op_o <= 0;
                (dec_decoded[I_SLTI]):              dec_alu_op_o <= 3;
                (dec_decoded[I_SLTIU]):             dec_alu_op_o <= 10;
                (dec_decoded[I_ANDI]):              dec_alu_op_o <= 2;
                (dec_decoded[I_ORI]):               dec_alu_op_o <= 4;
                (dec_decoded[I_XORI]):              dec_alu_op_o <= 5;
                (dec_decoded[I_LUI]):               dec_alu_op_o <= 13;
                (dec_decoded[I_ADDU:I_ADD]):        dec_alu_op_o <= 0;
                (dec_decoded[I_SUBU:I_SUB]):        dec_alu_op_o <= 1;
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
                (dec_decoded[I_MTLO:I_MFHI]):       dec_alu_op_o <= 0;
                (dec_decoded[I_BEQ]):               dec_alu_op_o <= 11;
                (dec_decoded[I_BNE]):               dec_alu_op_o <= 12;
                (dec_decoded[I_BLTZ]):              dec_alu_op_o <= 3;
                (dec_decoded[I_BGEZ]):              dec_alu_op_o <= 3;
                (dec_decoded[I_MTC0:I_MFC0]):       dec_alu_op_o <= 0;
                default:                            dec_alu_op_o <= 0;
            endcase
            case (1)
                (dec_decoded[I_NOR:I_ADD] ||
                 dec_decoded[I_MULTU:I_MULT] ||
                 dec_decoded[I_MTHI] ||
                 dec_decoded[I_MTLO] ||
                 dec_decoded[I_BGEZ:I_BEQ] ||
                 dec_decoded[I_JALR:I_JR]):     dec_alu_a_sel_o <= 
                                                    (dec_inst[25:21] == dec_dst_in_exec) ? 2 :
                                                    (dec_inst[25:21] == dec_dst_in_mem)  ? 3 :
                                                                                           0;
                (dec_decoded[I_XORI:I_LB] ||
                 dec_decoded[I_MTC0] ||
                 dec_decoded[I_SRAV:I_SLL]):    dec_alu_a_sel_o <= 
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
                (dec_decoded[I_XORI:I_LB]):     dec_alu_b_sel_o <= 1;
                (dec_decoded[I_SRA:I_SLL]):     dec_alu_b_sel_o <= 2;
                default:                        dec_alu_b_sel_o <= 5;
            endcase
            dec_sign_ext_o      <= (dec_decoded[I_SLTIU:I_LB]);
            dec_load_unsigned_o <= (dec_decoded[I_LBU] | dec_decoded[I_LHU]);
            dec_mem_rd_o        <= (dec_decoded[I_LL:I_LB]);
            dec_mem_we_o        <= (dec_decoded[I_SW:I_SB]);
            dec_mem_fc_o        <= (dec_decoded[I_SYNC]);
            dec_mem_sc_o        <= (dec_decoded[I_SC]);
            case (1)
                (dec_decoded[I_LBU:I_LB] | dec_decoded[I_SB]):  dec_mem_sel_o <= 0;
                (dec_decoded[I_LHU:I_LH] | dec_decoded[I_SH]):  dec_mem_sel_o <= 1;
                default:                                        dec_mem_sel_o <= 2;
            endcase

            dec_dst_in_exec[5]  <= ~(dec_decoded[I_LL:I_LB] || 
                                     dec_decoded[I_SC] || 
                                     dec_decoded[I_MTLO:I_ADDI] ||
                                     dec_decoded[I_JAL] ||
                                     dec_decoded[I_JALR] ||
                                     dec_decoded[I_MFC0]);
            dec_dst_in_mem  <= dec_dst_in_exec;
        end
    end

endmodule
