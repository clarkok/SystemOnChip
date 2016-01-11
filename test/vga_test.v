`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   13:34:23 12/29/2015
// Design Name:   vga
// Module Name:   C:/Users/c/SoC/vga_test.v
// Project Name:  SoC
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: vga
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module vga_test;

    // Inputs
    reg clk;
    reg clk_vga;
    reg rst;

    // Outputs
    wire [3:0] vga_b;
    wire [3:0] vga_g;
    wire [3:0] vga_r;
    wire vga_hs;
    wire vga_vs;
    wire [19:0] vga_addr;
    wire vga_sel;

    wire [47:0] vga_data;
    wire vga_offset_sel;
    wire vga_valid;

    // Instantiate the Unit Under Test (UUT)
    vga uut (
        .clk(clk), 
        .clk_vga(clk_vga), 
        .rst(rst), 
        .vga_b(vga_b), 
        .vga_g(vga_g), 
        .vga_r(vga_r), 
        .vga_hs(vga_hs), 
        .vga_vs(vga_vs), 
        .vga_addr(vga_addr), 
        .vga_data(vga_data), 
        .vga_sel(vga_sel), 
        .vga_valid(vga_valid),
        .vga_offset_in(20'b0),
        .vga_offset_sel(vga_offset_sel)
    );

    assign vga_data = {vga_addr[7:0], vga_addr, vga_addr};

    initial begin
        // Initialize Inputs
        clk = 0;
        clk_vga = 0;
        rst = 0;

        // Wait 100 ns for global reset to finish
        #100;

        // Add stimulus here
    end

    reg state = 0;
    reg last_state = 0;

    always @(posedge clk) begin
        last_state  <= state;
        state       <= state ? 0 : (vga_sel & ~vga_valid);
    end

    assign vga_valid = last_state;

    initial forever #5 clk = ~clk;
    initial forever #7.7 clk_vga = ~clk_vga;

endmodule

