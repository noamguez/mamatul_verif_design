//
// Verilog package my_project16_lib.verif_package
//
// Created:
//          by - gueznoa.UNKNOWN (SHOHAM)
//          at - 17:40:27 02/10/2024
//
// using Mentor Graphics HDL Designer(TM) 2019.2 (Build 5)
//

`resetall
`timescale 1ns/10ps
package verif_package;
//parameters defined for the DUT
parameter int unsigned DATA_WIDTH = 32;  //matrix data elemnet width
parameter int unsigned BUS_WIDTH = 64;	// apb bus width
parameter int unsigned ADDR_WIDTH = 32; // address size
parameter int unsigned MAX_DIM = BUS_WIDTH / DATA_WIDTH;   // MAX_DIM is the maximum matrix dimension
parameter int unsigned SPNTARGETS = 4;
//parameters defined in spec
parameter int unsigned amat_addr=4;
parameter int unsigned bmat_addr=8;
parameter int unsigned scratchpad_addr=16;
parameter int unsigned max_addr_bit=5;
parameter string file_path = "C:/Users/nadav/Desktop/21_02_QUABUM/scripts/data_file.txt";
parameter string golden_path = "C:/Users/nadav/Desktop/21_02_QUABUM/scripts/golden.txt";

//parameters for simulation tb
parameter time CLK_NS = 10ns; //defining the time cycle for the clk tb simulation
parameter int unsigned NUM_OF_TESTS = 200;  //num of multipications  - a serie of tests 
typedef reg[DATA_WIDTH-1:0] matrix_matmul [MAX_DIM-1:0][MAX_DIM-1:0]; 
typedef reg[BUS_WIDTH-1:0] results_matmul [MAX_DIM-1:0][MAX_DIM-1:0]; 
endpackage
