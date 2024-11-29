//
// Verilog program my_project16_lib.verif_matmul_tb
//
// Created:
//          by - gueznoa.UNKNOWN (SHOHAM)
//          at - 18:33:32 02/10/2024
//
// using Mentor Graphics HDL Designer(TM) 2019.2 (Build 5)
//
`resetall
`timescale 1ns/10ps

module matmul_tb;

import verif_package::*;
// Internal signal declarations
logic clk = 1'b0, rst_n=1'b1;
// Interface instantiation
matmul_intf intf(.clk(clk), .rst_n(rst_n));

initial forever 
	begin
	#(CLK_NS/2) clk = ~clk;
	end
// Init reset process
initial begin: TOP_RST
	rst_n = 1'b0; // Assert reset
	@(posedge clk) rst_n = 1'b1;
end
//connecting stimulus
matmul_stimulus #(.MATRIX_FILE(file_path)) stim(.intf(intf));
matmul_golden #(.golden_path(golden_path)) gold(.intf(intf));

//connecting DUT
matmul #(.DATA_WIDTH(DATA_WIDTH), .BUS_WIDTH(BUS_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .SPNTARGETS(SPNTARGETS))
DUT (.clk_i(clk),  //clocl
 .rst_ni(rst_n), //reset
 .paddr_i(intf.paddr), // adress of an writeble target(according to AMBA spec)
 .psel_i(intf.psel),					// apb salve chip selector (according to AMBA spec)
 .penable_i(intf.penable),				//user input write enable (according to AMBA spec)
 .pwrite_i(intf.pwrite),					/// 1 if writing 0 if reading (according to AMBA spec)
 .pwdata_i(intf.pwdata),	// input buss data  (according to AMBA spec)
 .pstrb_i(intf.pstrb), 	// pstrb data enable vector (according to AMBA spec)
 .pready_o(intf.pready),				// pready (according to AMBA spec)
 .pslverr_o(intf.pslverr),				// error signal (according to AMBA spec)
 .prdata_o(intf.prdata), // // data reading output (according to AMBA spec)
 .busy_o(intf.busy)
 ///
);



endmodule
