`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   22:11:24 12/28/2015
// Design Name:   GCore
// Module Name:   C:/Users/c/SoC/gcore_test.v
// Project Name:  SoC
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: GCore
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module gcore_test;

    // Inputs
    reg clk;
    reg rst;
    reg inst_valid;
    reg [47:0] data_in;
    reg data_ready;
    wire [31:0] inst_in;

    // Outputs
    wire [31:0] inst_addr;
    wire [19:0] data_addr;
    wire [47:0] data_out;
    wire data_we;
    wire data_rd;
    wire [3:0] data_sel;

    reg  [31:0] inst_rom [0:63];

    // Instantiate the Unit Under Test (UUT)
    GCore uut (
        .clk(clk), 
        .rst(rst), 
        .inst_addr(inst_addr), 
        .inst_in(inst_in), 
        .inst_valid(inst_valid), 
        .data_addr(data_addr), 
        .data_in(data_in), 
        .data_out(data_out), 
        .data_we(data_we), 
        .data_rd(data_rd), 
        .data_sel(data_sel), 
        .data_ready(data_ready)
    );

    assign inst_in = inst_rom[inst_addr[7:2]];

    initial begin
        $readmemh("gcore.hex", inst_rom);
        // Initialize Inputs
        clk = 0;
        rst = 0;
        inst_valid = 1;
        data_in = 0;
        data_ready = 1;

        // Wait 100 ns for global reset to finish
        #100;
        
        // Add stimulus here

    end

    initial forever #5 clk = ~clk;
      
endmodule

