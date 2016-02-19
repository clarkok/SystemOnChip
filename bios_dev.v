module bios_dev(
    input  clk,
    input  rst,

    input  [31:0]   addr_i,
    output [31:0]   data_o,
    input  [31:0]   data_i,
    input  [ 1:0]   sel_i,
    input           rd_i,
    input           we_i,
    output          ack_o,

    input  [31:0]   inst_addr_i,
    output [31:0]   inst_data_o
    );

    wire [31:0] data_r_o;
    reg  [31:0] data_r;

    assign data_o   = data_r;
    assign ack_o    = 1'b1;

    bios_rom bios_rom(
        .clk(clk),
        .a(inst_addr_i[11:2]),
        .d(32'b0),
        .dpra(addr_i[11:2]),
        .spo(inst_data_o),
        .dpo(data_r_o),
        .we(1'b0)
    );

    always @* begin
        case (sel_i)
            2'h0: begin
                case (addr_i[1:0])
                    2'd0: data_r = {24'b0, data_r_o[ 7: 0]};
                    2'd1: data_r = {24'b0, data_r_o[15: 8]};
                    2'd2: data_r = {24'b0, data_r_o[23:16]};
                    2'd3: data_r = {24'b0, data_r_o[31:24]};
                endcase
            end
            2'h1: begin
                data_r  = addr_i[1] 
                                ? {16'b0, data_r_o[31:16]}
                                : {16'b0, data_r_o[15: 0]};
            end
            2'h2: begin
                data_r  = data_r_o;
            end
        endcase
    end

endmodule
