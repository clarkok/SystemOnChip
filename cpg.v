module coprocessor_gpu(
    input  clk,
    input  rst,

    input  [19:0] addr_0,
    input  [47:0] data_in_0,
    output [47:0] data_out_0,
    input         data_sel_0,
    input         data_we_0,
    output        data_ready_0,

    input  [19:0] addr_1,
    input  [47:0] data_in_1,
    output [47:0] data_out_1,
    input         data_sel_1,
    input         data_we_1,
    output        data_ready_1,

    input             vga_offset_sel,
    output reg [47:0] vga_offset,
    output reg [47:0] interrupt
    );

    reg [47:0] gpu_command;
    reg [47:0] frame_counter;

    // 0: vga_offset
    // 1: gpu_number
    // 2: cpu_interrupt
    // 3: gpu_command
    // 4: frame_counter

    assign data_out_0 = (addr_0 == 20'h0) ? vga_offset  :
                        (addr_0 == 20'h1) ? 48'b0       :
                        (addr_0 == 20'h2) ? interrupt   :
                        (addr_0 == 20'h3) ? gpu_command :
                        (addr_0 == 20'h4) ? frame_counter :
                                            48'b0;
    assign data_ready_0 = 1'b1;
    assign data_out_1 = (addr_1 == 20'h0) ? vga_offset  :
                        (addr_1 == 20'h1) ? 48'b1       :
                        (addr_1 == 20'h2) ? interrupt   :
                        (addr_1 == 20'h3) ? gpu_command :
                        (addr_0 == 20'h4) ? frame_counter :
                                            48'b0;
    assign data_ready_1 = 1'b1;

    task init;
    begin
        vga_offset  <= 48'b0;
        interrupt   <= 48'b0;
        gpu_command <= 48'b0;
        frame_counter <= 48'b0;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            if (data_sel_0 && data_we_0) begin
                case (addr_0)
                    20'h0: vga_offset   <= data_in_0;
                    20'h2: interrupt    <= data_in_0;
                    20'h3: gpu_command  <= data_in_0;
                endcase
            end

            if (data_sel_1 && data_we_1) begin
                case (addr_1)
                    20'h0: vga_offset   <= data_in_1;
                    20'h2: interrupt    <= data_in_1;
                    20'h3: gpu_command  <= data_in_1;
                endcase
            end

            if (vga_offset_sel) begin
                frame_counter <= frame_counter + 48'h1;
            end
        end
    end

endmodule
