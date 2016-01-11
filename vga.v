`include "functions.vh"

module vga(
    input  clk,
    input  clk_vga,
    input  rst,

    output reg [3:0]  vga_b,
    output reg [3:0]  vga_g,
    output reg [3:0]  vga_r,
    output reg        vga_hs,
    output reg        vga_vs,

    output reg [19:0] vga_addr,
    input      [47:0] vga_data,
    output reg        vga_sel,
    input             vga_valid,

    input      [19:0] vga_offset_in,
    output            vga_offset_sel
    );

    /*
    // 800x600@72
    // 50MHz
    localparam H_VISIBLE    = 800;
    localparam H_FRONT      = 56;
    localparam H_SYNC       = 120;
    localparam H_BACK       = 64;
    localparam H_WHOLE      = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam V_VISIBLE    = 600;
    localparam V_FRONT      = 37;
    localparam V_SYNC       = 6;
    localparam V_BACK       = 23;
    localparam V_WHOLE      = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;
    */

    // 1024x768@60
    // 65MHz
    localparam H_VISIBLE    = 1024;
    localparam H_FRONT      = 24;
    localparam H_SYNC       = 136;
    localparam H_BACK       = 160;
    localparam H_WHOLE      = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam V_VISIBLE    = 768;
    localparam V_FRONT      = 3;
    localparam V_SYNC       = 6;
    localparam V_BACK       = 29;
    localparam V_WHOLE      = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    localparam COUNTER_WIDTH    = `GET_WIDTH(H_WHOLE);

    reg    [47:0] disp_reg;
    reg    [47:0] disp_reg_next;

    reg    [COUNTER_WIDTH:0] h_counter;
    reg    [COUNTER_WIDTH:0] v_counter;
    reg    [COUNTER_WIDTH:0] line_offset;
    wire   [COUNTER_WIDTH:0] h_counter_next;
    wire   [COUNTER_WIDTH:0] v_counter_next;
    wire   [COUNTER_WIDTH:0] line_offset_next;

    wire   [11:0] pixel_data;

    wire   [19:0] vga_addr_next;

    reg    vga_should_read_r;
    wire   vga_should_read  = h_counter >= (H_SYNC+H_BACK-4) && h_counter < (H_SYNC+H_BACK+H_VISIBLE-4) && 
                              v_counter >= (V_SYNC+V_BACK) && v_counter < (V_SYNC+V_BACK+V_VISIBLE) &&
                              line_offset[1:0] == 3;
    assign v_counter_next = (h_counter == H_WHOLE-1) ? (v_counter == V_WHOLE-1 ? 0 : v_counter + 1) : v_counter;
    assign h_counter_next = (h_counter == H_WHOLE-1) ? 0                                            : h_counter + 1;

    assign line_offset_next = h_counter_next - (H_SYNC+H_BACK);
    assign pixel_data     = (h_counter >= (H_SYNC+H_BACK) && h_counter < (H_SYNC+H_BACK+H_VISIBLE) &&
                             v_counter >= (V_SYNC+V_BACK) && v_counter < (V_SYNC+V_BACK+V_VISIBLE))
                                ? (
                                    line_offset_next[1:0] == 0 ? disp_reg[11: 0] :
                                    line_offset_next[1:0] == 1 ? disp_reg[23:12] :
                                    line_offset_next[1:0] == 2 ? disp_reg[35:24] :
                                                                 disp_reg[47:36]
                                )
                                : 12'b0;
    assign vga_addr_next            = (h_counter == (H_SYNC+H_BACK-1) && v_counter == (V_SYNC+V_BACK+V_VISIBLE-1)) 
                                            ? vga_offset_in : vga_addr + 20'b1;
    assign vga_offset_sel           = (h_counter == (H_SYNC+H_BACK+H_VISIBLE-4) && v_counter == (V_SYNC+V_BACK+V_VISIBLE-1));

    task init_vga;
    begin
        v_counter               <= 0;
        h_counter               <= 0;
        line_offset             <= 0;
        disp_reg                <= 48'b0;
        {vga_r, vga_g, vga_b}   <= 12'b0;
        vga_hs                  <= 1'b0;
        vga_vs                  <= 1'b0;
    end
    endtask

    task init;
    begin
        disp_reg_next   <= 48'b0;
        vga_sel         <= 1'b0;
        vga_addr        <= 20'b0;
        vga_should_read_r   <= 1'b0;
    end
    endtask

    initial begin
        init_vga();
        init();
    end

    always @(posedge clk_vga) begin
        if (rst) init_vga();
        else begin
            {vga_r, vga_g, vga_b}   <= pixel_data;
            vga_hs                  <= (h_counter >= H_SYNC);
            vga_vs                  <= (v_counter >= V_SYNC);
            h_counter               <= h_counter_next;
            v_counter               <= v_counter_next;
            line_offset             <= line_offset_next;
            if (line_offset[1:0] == 3) begin
                disp_reg <= disp_reg_next;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) init();
        else begin
            vga_should_read_r   <= vga_should_read;
            if (vga_sel) begin
                if (vga_valid) begin
                    disp_reg_next <= vga_data;
                    vga_sel       <= 1'b0;
                end
            end
            else if (vga_should_read_r) begin
                vga_addr    <= vga_addr_next;
                vga_sel     <= 1'b1;
            end
        end
    end

endmodule
