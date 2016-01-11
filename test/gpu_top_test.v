`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   14:31:18 12/29/2015
// Design Name:   soc
// Module Name:   C:/Users/c/SoC/gpu_top_test.v
// Project Name:  SoC
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: soc
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module gpu_top_test;

    // Inputs
    reg clk;
    reg rstn;

    // Outputs
    wire [2:0] tri_led0;
    wire [2:0] tri_led1;
    wire seg_clk;
    wire seg_clr;
    wire seg_do;
    wire seg_pen;
    wire led_clk;
    wire led_clr;
    wire led_do;
    wire led_pen;
    wire [19:0] sram_addr;
    wire sram_ce;
    wire sram_oen;
    wire sram_wen;
    wire [3:0] vga_b;
    wire [3:0] vga_g;
    wire [3:0] vga_r;
    wire vga_hs;
    wire vga_vs;

    // Bidirs
    wire [47:0] sram_dq;

    // Instantiate the Unit Under Test (UUT)
    soc uut (
        .clk(clk), 
        .rstn(rstn), 
        .tri_led0(tri_led0), 
        .tri_led1(tri_led1), 
        .seg_clk(seg_clk), 
        .seg_clr(seg_clr), 
        .seg_do(seg_do), 
        .seg_pen(seg_pen), 
        .led_clk(led_clk), 
        .led_clr(led_clr), 
        .led_do(led_do), 
        .led_pen(led_pen), 
        .sram_addr(sram_addr), 
        .sram_dq(sram_dq), 
        .sram_ce(sram_ce), 
        .sram_oen(sram_oen), 
        .sram_wen(sram_wen), 
        .vga_b(vga_b), 
        .vga_g(vga_g), 
        .vga_r(vga_r), 
        .vga_hs(vga_hs), 
        .vga_vs(vga_vs)
    );

    initial begin
        // Initialize Inputs
        clk = 0;
        rstn = 1;

        // Wait 100 ns for global reset to finish
        #100;

        // Add stimulus here

    end

    initial forever #5 clk = ~clk;

endmodule

