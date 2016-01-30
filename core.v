`include "exceptions.vh"

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
    output                          mem_sc,
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

    input  [INST_ADDR_WIDTH-1:0]    cp0_exception_base
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

    wire dec_pipeline_flush_i;

    reg                         dec_exception_o;
    reg  [31:0]                 dec_cause_o;
    reg  [INST_ADDR_WIDTH-1:0]  dec_pc_o;
    reg  [4:0]                  dec_rs_o;
    reg  [4:0]                  dec_rt_o;
    reg  [4:0]                  dec_rd_o;
    reg  [DATA_DATA_WIDTH-1:0]  dec_imm_o;
    reg  [4:0]                  dec_shamt_o;
    reg  [1:0]                  dec_pc_we_o;        // 0: always flush, 1: conditional flush, 2: Non
    reg  [1:0]                  dec_pc_we_sel_o;    // 0: branch, 1: mem_result, 2: syscall, 3: eret
    reg                         dec_reg_we_o;
    reg  [2:0]                  dec_reg_we_sel_o;   // 0: alu_out, 1: bus_data, 2: pc + 4, 3: c0
    reg  [2:0]                  dec_reg_we_dst_o;   // 0: rd, 1: rt, 2: $ra, 3: hi, 4: lo, 5:lohi
    reg  [3:0]                  dec_alu_op_o;       //  0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15
                                                    //  add sub and slt or  xor nor sll srl sra sltueq  ne  lui mul mulu
    reg  [2:0]                  dec_alu_a_sel_o;    //  0: rs, 1: rt, 2: exec_result, 3: mem_result, 4: hi, 5: lo, 6: 0, 7: imm
    reg  [2:0]                  dec_alu_b_sel_o;    //  0: rt, 1: imm, 2: shamt, 3: exec_result, 4: mem_result, 5: 0, 6: rs
    reg                         dec_load_unsigned_o;
    reg                         dec_overflow_o;
    reg                         dec_mem_rd_o;
    reg                         dec_mem_we_o;
    reg                         dec_mem_fc_o;
    reg                         dec_mem_sc_o;
    reg  [1:0]                  dec_mem_sel_o;
    reg                         dec_cp0_we;

    reg  [INST_ADDR_WIDTH-1:0]  the_pc;

    reg  [5:0]                  dec_dst_in_exec;
    reg  [5:0]                  dec_dst_in_mem;

    wire [INST_ADDR_WIDTH-1:0]  dec_pc_i;

    wire [31:0]                 dec_inst;
    wire [NR_INST-1:0]          dec_decoded;

    assign dec_inst     = inst_valid_i ? inst_data_i : NOP;
    assign dec_decoded  = decode(dec_inst);

    task dec_init;
    begin
        dec_exception_o     <= 0;
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
        dec_mem_rd_o        <= 0;
        dec_mem_we_o        <= 0;
        dec_mem_fc_o        <= 0;
        dec_mem_sc_o        <= 0;
        dec_mem_sel_o       <= 0;

        dec_dst_in_exec     <= 6'b10_0000;
        dec_dst_in_mem      <= 6'b10_0000;
        the_pc              <= 1;
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

    always @(posedge clk) begin
        if (rst) dec_init();
        else if (dec_pipeline_flush_i) begin
            dec_init();
            the_pc  <= dec_pc_i;
        end
        else if (data_valid_i) begin
            case (1)
                (|dec_decoded[I_JAL:I_J]):                  the_pc <= jump_addr;
                (|dec_decoded[I_BGEZ:I_BEQ]):               the_pc <= branch_addr;
                (|dec_decoded[I_JALR:I_JR] || 
                 |dec_decoded[I_ERET:I_SCALL]):             the_pc <= the_pc;
                default:                                    the_pc <= the_pc + 4;
            endcase
            dec_exception_o     <= hw_interrupt | undefined_inst | privilege_inst | privilege_addr;
            case (1)
                (hw_interrupt):     dec_cause_o <= hw_cause;
                (undefined_inst):   dec_cause_o <= `UNDEFINED_INST;
                (privilege_inst):   dec_cause_o <= `PRIVILEGE_INST;
                (privilege_addr):   dec_cause_o <= `PRIVILEGE_ADDR;
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
                (|dec_decoded[I_MTLO:I_ADDI]):                  dec_reg_we_sel_o <= 0;
                (|dec_decoded[I_LL:I_LB] || dec_decoded[I_SC]): dec_reg_we_sel_o <= 1;
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
                (|dec_decoded[I_SRAV:I_SLL]):   dec_alu_a_sel_o <= 
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
            dec_mem_rd_o        <= (|dec_decoded[I_LL:I_LB]);
            dec_mem_we_o        <= (|dec_decoded[I_SW:I_SB]);
            dec_mem_fc_o        <= (|dec_decoded[I_SYNC]);
            dec_mem_sc_o        <= (|dec_decoded[I_SC]);
            case (1)
                (dec_decoded[I_LBU:I_LB] || dec_decoded[I_SB]): dec_mem_sel_o <= 0;
                (dec_decoded[I_LHU:I_LH] || dec_decoded[I_SH]): dec_mem_sel_o <= 1;
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

    // exec part
    wire [63:0]                 exec_mem_result_i;
    wire                        exec_pipeline_flush_i;

    reg                         exec_exception_o;
    reg  [31:0]                 exec_cause_o;
    reg  [INST_ADDR_WIDTH-1:0]  exec_pc_o;
    reg  [4:0]                  exec_rt_o;
    reg  [4:0]                  exec_rd_o;
    reg  [1:0]                  exec_pc_we_o;
    reg  [1:0]                  exec_pc_we_sel_o;
    reg                         exec_reg_we_o;
    reg  [2:0]                  exec_reg_we_sel_o;
    reg  [2:0]                  exec_reg_we_dst_o;
    reg                         exec_load_unsigned_o;
    reg                         exec_mem_rd_o;
    reg                         exec_mem_we_o;
    reg                         exec_mem_fc_o;
    reg                         exec_mem_sc_o;
    reg  [1:0]                  exec_mem_sel_o;
    reg  [63:0]                 exec_result_o;
    reg  [DATA_DATA_WIDTH-1:0]  exec_data_o;

    reg [DATA_DATA_WIDTH-1:0]   reg_file [0:31];
    reg [63:0]                  lohi;

    task exec_reset;
    integer i;
    begin
        exec_exception_o    <= 0;
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
        exec_mem_sc_o       <= 0;
        exec_mem_sel_o      <= 0;
        exec_result_o       <= 64'h0;
        exec_data_o         <= 0;
    end
    endtask

    task exec_init;
    integer i;
    begin
        exec_reset();
        lohi                <= 0;
        for (i = 0; i < 32; i = i + 1)
            reg_file[i]     <= 0;
    end
    endtask

    initial exec_init();

    wire [DATA_DATA_WIDTH-1:0]  exec_rs = reg_file[dec_rs_o];
    wire [DATA_DATA_WIDTH-1:0]  exec_rt = reg_file[dec_rt_o];

    reg  [DATA_DATA_WIDTH-1:0]  exec_alu_a;
    reg  [DATA_DATA_WIDTH-1:0]  exec_alu_b;
    reg  [63:0]                 exec_alu_out;
    reg                         exec_overf_r;

    always @* begin
        case (dec_alu_a_sel_o)
            3'h0:   exec_alu_a  = exec_rs;
            3'h1:   exec_alu_a  = exec_rt;
            3'h2:   exec_alu_a  = exec_result_o[31:0];
            3'h3:   exec_alu_a  = exec_mem_result_i[31:0];
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
            3'h3:   exec_alu_b  = exec_result_o[31:0];
            3'h4:   exec_alu_b  = exec_mem_result_i[31:0];
            3'h5:   exec_alu_b  = 0;
            3'h6:   exec_alu_b  = exec_rs;
        endcase
    end

    always @* begin
        exec_overf_r    = 0;
        exec_alu_out    = 64'h0;
        case (dec_alu_op_o)
            4'h0:   {exec_overf_r, exec_alu_out[31:0]}  = exec_alu_a + exec_alu_b;
            4'h1:   {exec_overf_r, exec_alu_out[31:0]}  = exec_alu_a - exec_alu_b;
            4'h2:   exec_alu_out[31:0]                  = exec_alu_a & exec_alu_b;
            4'h3:   exec_alu_out[31:0]                  = $signed(exec_alu_a) < $signed(exec_alu_b);
            4'h4:   exec_alu_out[31:0]                  = exec_alu_a | exec_alu_b;
            4'h5:   exec_alu_out[31:0]                  = exec_alu_a ^ exec_alu_b;
            4'h6:   exec_alu_out[31:0]                  = ~(exec_alu_a | exec_alu_b);
            4'h7:   exec_alu_out[31:0]                  = exec_alu_a << exec_alu_b[4:0];
            4'h8:   exec_alu_out[31:0]                  = exec_alu_a >> exec_alu_b[4:0];
            4'h9:   exec_alu_out[31:0]                  = $signed(exec_alu_a) >>> exec_alu_b[4:0];
            4'ha:   exec_alu_out[31:0]                  = exec_alu_a < exec_alu_b;
            4'hb:   exec_alu_out[31:0]                  = exec_alu_a == exec_alu_b;
            4'hc:   exec_alu_out[31:0]                  = exec_alu_a != exec_alu_b;
            4'hd:   exec_alu_out[31:0]                  = {exec_alu_a[15:0], 16'b0};
            4'he:   exec_alu_out[31:0]                  = $signed(exec_alu_a) * $signed(exec_alu_b);
            4'hf:   exec_alu_out[31:0]                  = exec_alu_a * exec_alu_b;
        endcase
    end

    wire exec_overflow      = (dec_alu_op_o == 4'h0) ? exec_overf_r : ~exec_overf_r;

    wire exec_overflow_err  = exec_overflow & dec_overflow_o;
    wire exec_no_exception  = ~( exec_exception_o ||
                                (exec_pc_we_o == 2'b0) ||                             // JR
                                (exec_pc_we_o == 2'b1 && exec_result_o[31:0] == 0));   // predict missed

    always @(posedge clk) begin
        if (rst) exec_init();
        else if (exec_pipeline_flush_i) exec_reset();
        else if (data_valid_i) begin
            exec_exception_o        <= dec_exception_o | exec_overflow_err;
            exec_cause_o            <= dec_exception_o ? dec_cause_o :
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
            exec_mem_we_o           <= dec_mem_we_o && exec_no_exception;
            exec_mem_fc_o           <= dec_mem_fc_o && exec_no_exception;
            exec_mem_sc_o           <= dec_mem_sc_o && exec_no_exception;
            exec_mem_sel_o          <= dec_mem_sel_o;
            exec_result_o           <= exec_alu_out;
            exec_data_o             <= exec_rt;
        end
    end

    // mem part
    reg  [4:0]                  mem_rt_o;
    reg  [4:0]                  mem_rd_o;
    reg                         mem_reg_we_o;
    reg  [2:0]                  mem_reg_we_dst_o;
    reg  [63:0]                 mem_result_o;
    reg                         mem_exception_o;
    reg  [31:0]                 mem_cause_o;
    reg  [INST_ADDR_WIDTH-1:0]  mem_pc_o;

    reg  mem_pipeline_flush_o;
    reg  [INST_ADDR_WIDTH-1:0] mem_pc_data_o;

    task mem_init;
    begin
        mem_rt_o                <= 0;
        mem_rd_o                <= 0;
        mem_reg_we_o            <= 0;
        mem_reg_we_dst_o        <= 0;
        mem_result_o            <= 0;
        mem_pipeline_flush_o    <= 0;
        mem_pc_data_o           <= 0;
        mem_exception_o         <= 0;
        mem_cause_o             <= 0;
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
        if (rst) mem_init();
        else if (data_valid_i) begin
            mem_rt_o                <= exec_rt_o;
            mem_rd_o                <= exec_rd_o;
            mem_reg_we_o            <= exec_reg_we_o;
            mem_reg_we_dst_o        <= exec_reg_we_dst_o;
            case (exec_reg_we_sel_o)
                3'h0:   mem_result_o    <= exec_result_o;
                3'h1:   mem_result_o    <= mem_bus_data;
                3'h2:   mem_result_o    <= exec_pc_o + 4;
                3'h3:   mem_result_o    <= cp0_data_i;
            endcase
            mem_pipeline_flush_o    <= exec_exception_o ||
                                       hw_page_fault ||
                                      (exec_pc_we_o == 2'b0) ||                             // JR
                                      (exec_pc_we_o == 2'b1 && exec_result_o[31:0] == 0);   // predict missed

            mem_pc_data_o           <= (exec_exception_o || hw_page_fault) ? cp0_exception_base :
                                       (exec_pc_we_o == 2'b0)              ? exec_result_o[INST_ADDR_WIDTH-1:0] :
                                                                             exec_pc_o + 4;
            mem_exception_o         <= exec_exception_o || hw_page_fault;
            mem_cause_o             <= exec_exception_o ? exec_cause_o : `MMU_PAGE_FAULT;
            mem_pc_o                <= exec_pc_o;
        end
    end

    // wb part
    always @(posedge clk) begin
        if (data_valid_i && mem_reg_we_o) begin
            case (mem_reg_we_dst_o)
                3'h0:   if (mem_rd_o)   reg_file[mem_rd_o]  <= mem_result_o[31:0];
                3'h1:   if (mem_rt_o)   reg_file[mem_rt_o]  <= mem_result_o[31:0];
                3'h2:                   reg_file[5'b11111]  <= mem_result_o[31:0];
                3'h3:                   lohi[63:32]         <= mem_result_o[31:0];
                3'h4:                   lohi[31: 0]         <= mem_result_o[31:0];
                3'h5:                   lohi                <= mem_result_o;
            endcase
        end
    end

    assign dec_pc_i                 = mem_pc_data_o;
    assign exec_mem_result_i        = mem_result_o;
    assign dec_pipeline_flush_i     = mem_pipeline_flush_o;
    assign exec_pipeline_flush_i    = mem_pipeline_flush_o;

    assign inst_addr_o  = the_pc;
    assign data_addr_o  = exec_result_o[DATA_ADDR_WIDTH-1:0];
    assign data_data_o  = exec_data_o;
    assign data_sel_o   = exec_mem_sel_o;
    assign data_we_o    = exec_mem_we_o;
    assign data_rd_o    = exec_mem_rd_o;
    assign mem_fc       = exec_mem_fc_o;
    assign mem_sc       = exec_mem_sc_o;

    assign exception    = mem_exception_o;
    assign cause        = mem_cause_o;
    assign epc          = mem_pc_o;
    // TODO assign eret         = mem_eret_o;
endmodule
