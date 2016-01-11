`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   01:36:12 12/29/2015
// Design Name:   sram
// Module Name:   C:/Users/c/SoC/sram_test.v
// Project Name:  SoC
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: sram
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module sram_test;

	// Inputs
	reg clk;
	reg rst;
	reg [19:0] vga_addr;
	reg vga_sel;
	reg [19:0] gpu_addr;
	reg [47:0] gpu_data_i;
	reg gpu_sel;
	reg gpu_we;

	// Outputs
	wire [19:0] sram_addr;
	wire sram_ce;
	wire sram_oen;
	wire sram_wen;
	wire [47:0] vga_data;
	wire vga_valid;
	wire [47:0] gpu_data_o;
	wire gpu_valid;

	// Bidirs
	wire [47:0] sram_dq;

	// Instantiate the Unit Under Test (UUT)
	sram uut (
		.clk(clk), 
		.rst(rst), 
		.sram_addr(sram_addr), 
		.sram_dq(sram_dq), 
		.sram_ce(sram_ce), 
		.sram_oen(sram_oen), 
		.sram_wen(sram_wen), 
		.vga_addr(vga_addr), 
		.vga_data(vga_data), 
		.vga_sel(vga_sel), 
		.vga_valid(vga_valid), 
		.gpu_addr(gpu_addr), 
		.gpu_data_o(gpu_data_o), 
		.gpu_data_i(gpu_data_i), 
		.gpu_sel(gpu_sel), 
		.gpu_we(gpu_we), 
		.gpu_valid(gpu_valid)
	);

    async_1Mx16 async_0 (
        .CE1_b(sram_ce),
        .CE2(~sram_ce),
        .WE_b(sram_wen),
        .OE_b(sram_oen),
        .BHE_b(1'b0),
        .BLE_b(1'b0),
        .A(sram_addr),
        .DQ(sram_dq[15:0])
    );

	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 0;

		vga_addr = 0;
		vga_sel = 0;
		gpu_addr = 0;
		gpu_data_i = 0;
		gpu_sel = 0;
		gpu_we = 0;

		// Wait 100 ns for global reset to finish
		#105;
        
		// Add stimulus here

        vga_sel = 1;
        #10;
        vga_sel = 0;

        #10;
        gpu_sel = 1;
        gpu_we = 1;
        gpu_addr = 0;
        gpu_data_i = 48'h0123456789AB;
        #10;
        gpu_sel = 1;
        gpu_we = 0;
	end

    initial forever #5 clk = ~clk;
      
endmodule

