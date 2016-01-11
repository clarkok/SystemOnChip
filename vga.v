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

    localparam COUNTER_WIDTH    = `GET_WIDTH(`MAX(H_WHOLE, V_WHOLE));
    localparam LINE_ADDR_COUNT  = H_VISIBLE / 4;
    localparam LINE_ADDR_WIDTH  = `GET_WIDTH(LINE_ADDR_COUNT);

    // cross area
    reg  [47:0]             line_buffer[0:H_VISIBLE-1];
    wire                    new_line_clk_vga;
    wire                    new_line_clk;

    async_flag async_flag(
        .clk_src(clk_vga),
        .flag_src(new_line_clk_vga),
        .clk_dst(clk),
        .flag_dst(new_line_clk)
    );

    // clk_vga domain
    reg  [COUNTER_WIDTH:0]  h_counter;
    reg  [COUNTER_WIDTH:0]  v_counter;

    wire [COUNTER_WIDTH:0]  h_counter_next;
    wire [COUNTER_WIDTH:0]  v_counter_next;
    wire [COUNTER_WIDTH:0]  line_offset;
    wire [47:0]             pixel_block;
    reg  [11:0]             pixel_data;
    wire                    inside_display;
    wire                    vga_hs_next;
    wire                    vga_vs_next;

    assign h_counter_next   = (h_counter == H_WHOLE - 1) ? 0 : h_counter + 1;
    assign v_counter_next   = (h_counter == H_WHOLE - 1) ? (v_counter == V_WHOLE - 1 ? 0 : v_counter + 1) : v_counter;
    assign line_offset      = h_counter - (H_SYNC + H_BACK);
    assign pixel_block      = line_buffer[line_offset[COUNTER_WIDTH:2]];
    assign inside_display   = h_counter >= (H_SYNC + H_BACK) && h_counter < (H_SYNC + H_BACK + H_VISIBLE) &&
                              v_counter >= (V_SYNC + V_BACK) && v_counter < (V_SYNC + V_BACK + V_VISIBLE);
    assign vga_hs_next      = h_counter >= H_SYNC;
    assign vga_vs_next      = v_counter >= V_SYNC;
    assign new_line_clk_vga = h_counter == (H_SYNC + H_BACK + H_VISIBLE) &&
                              v_counter >= (V_SYNC + V_BACK - 1) && v_counter < (V_SYNC + V_BACK + V_VISIBLE - 1);

    always @(*) begin
        if (inside_display) begin
            case (line_offset[1:0])
                2'b00: pixel_data = pixel_block[11: 0];
                2'b01: pixel_data = pixel_block[23:12];
                2'b10: pixel_data = pixel_block[35:24];
                2'b11: pixel_data = pixel_block[47:36];
            endcase
        end
        else
            pixel_data = 12'b0;
    end

    task init_vga;
    begin
        {vga_b, vga_g, vga_r}   <= 0;
        vga_hs                  <= 0;
        vga_vs                  <= 0;
        h_counter               <= 0;
        v_counter               <= 0;
    end
    endtask

    initial init_vga();

    always @(posedge clk_vga) begin
        if (rst) init_vga();
        else begin
            {vga_r, vga_g, vga_b}   <= pixel_data;
            vga_hs                  <= vga_hs_next;
            vga_vs                  <= vga_vs_next;
            h_counter               <= h_counter_next;
            v_counter               <= v_counter_next;
        end
    end

    // clk domain
    localparam S_WAITING    = H_VISIBLE / 4;

    reg  [COUNTER_WIDTH:0]  line_counter;
    reg  [COUNTER_WIDTH:0]  state;

    wire [COUNTER_WIDTH:0]  line_counter_next;
    wire [COUNTER_WIDTH:0]  state_next;
    wire [19:0]             vga_addr_next;
    wire                    vga_sel_next;

    assign line_counter_next    = new_line_clk ? (line_counter == V_VISIBLE - 1 ? 0 : line_counter + 1) : line_counter;
    assign state_next           = state == S_WAITING
                                    ? (new_line_clk ? 0 : S_WAITING)
                                    : (vga_valid ? state + 1 : state);
    assign vga_offset_sel       = new_line_clk && (line_counter == 0);
    assign vga_addr_next        = vga_offset_sel ? vga_offset_in : (vga_valid ? vga_addr + 1 : vga_addr);
    assign vga_sel_next         = state_next != S_WAITING;

    task init;
    begin
        vga_addr        <= 0;
        vga_sel         <= 0;
        line_counter    <= 0;
        state           <= S_WAITING;
    end
    endtask

    initial init();

    always @(posedge clk) begin
        if (rst) init();
        else begin
            vga_addr        <= vga_addr_next;
            vga_sel         <= vga_sel_next;
            line_counter    <= line_counter_next;
            state           <= state_next;

            if (vga_valid) begin
                line_buffer[state]  <= vga_data;
            end
        end
    end
endmodule
