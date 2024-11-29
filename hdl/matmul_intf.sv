//
// Verilog interface my_project16_lib.verif_matmul_intf
//
// Created:
//          by - gueznoa.UNKNOWN (SHOHAM)
//          at - 17:28:42 02/10/2024
//
// using Mentor Graphics HDL Designer(TM) 2019.2 (Build 5)
//
`resetall
`timescale 1ns/10ps

interface matmul_intf(input logic clk, input logic rst_n);

import verif_package::*;


///I/O signals for apb communication between stimulus and DUT
wire[ADDR_WIDTH-1:0] paddr;  // adress of an writeble target(according to AMBA spec)
wire psel;  				// apb salve chip selector (according to AMBA spec)
wire penable;				//user input write enable (according to AMBA spec)
wire pwrite;					/// 1 if writing 0 if reading (according to AMBA spec)
wire[BUS_WIDTH -1:0] pwdata;	// input buss data  (according to AMBA spec)
wire[MAX_DIM -1:0] pstrb; 	// pstrb data enable vector (according to AMBA spec)
wire pready;				// pready (according to AMBA spec)
wire pslverr;				// error signal (according to AMBA spec)
wire[BUS_WIDTH -1:0] prdata; // data reading output (according to AMBA spec)
wire busy;
wire read_results_dut;
results_matmul results_dut;

/////////////////////////////////////////////////////////////////

//defining modports of tb_top
modport DEVICE (input paddr, psel, penable, pwrite, pwdata, pstrb, output pready, pslverr, prdata, busy );//modport for matmul
modport STIMULUS (output paddr, psel, penable, pwrite, pwdata, pstrb, results_dut,read_results_dut, input clk,rst_n, pready, pslverr, prdata, busy);//modport for stimulus
modport CHECKOF (input paddr, psel, penable, pwrite, pwdata, pstrb, pready, pslverr, prdata, results_dut,read_results_dut, rst_n );//modport for checker, golden, coverage
endinterface

