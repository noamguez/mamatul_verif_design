//
// Verilog program my_project16_lib.verif_matmul_checker
//
// Created:
//          by - gueznoa.UNKNOWN (SHOHAM)
//          at - 14:21:03 02/11/2024
//
// using Mentor Graphics HDL Designer(TM) 2019.2 (Build 5)
//

`resetall
`timescale 1ns/10ps
module matmul_checker (
    verif_matmul_intf.CHECKCOV intf
);
import verif_package::*;

	logic psel = intf.psel;
	logic penable= intf.penable;
	logic pready = intf.pready;
	logic pclk= intf.pclk;
	logic pwrite = intf.pwrite;
	logic [BUS_WIDTH -1:0] prdata= intf.prdata;
	logic [BUS_WIDTH -1:0] pwdata= intf.pwdata;
	logic pslverr= intf.pslverr;
	logic [ADDR_WIDTH-1:0] paddr= intf.paddr;
	logic [MAX_DIM-1:0] pstrb = intf.pstrb;
	


  // APB Protocol checks
  // Check for proper start of transaction
  property p_start_of_transaction;
    @(posedge pclk) psel && !penable;
  endproperty

  assert property (p_start_of_transaction) else
    $error("APB Protocol Violation: Transaction must start with psel high and penable low");

  // Check for transaction completion
  property p_transaction_complete;
    @(posedge pclk) (psel && penable && pready) |-> ##1 !psel; //maybe not working
  endproperty

  assert property (p_transaction_complete) else
    $error("APB Protocol Violation: Transaction didn't complete properly");

  // Check for write transactions
  property p_write_transaction;
    @(posedge pclk) psel && penable && pwrite && pready;
  endproperty
//???
  //assert property (p_write_transaction) implies (pwdata !== 'x) else
  //  $error("APB Protocol Violation: Write data is undefined during a write transaction");

  // Check for read transactions and ensure data is stable
  property p_read_transaction;
    @(posedge pclk) psel && penable && !pwrite && pready |=> prdata !== 'x;
  endproperty

  assert property (p_read_transaction) else
    $error("APB Protocol Violation: Read data is undefined during a read transaction");

  // Check for slave error handling
  property p_slave_error;
    @(posedge pclk) psel && penable && pslverr |=> prdata === 'x;
  endproperty

  assert property (p_slave_error) else
    $error("APB Protocol Violation: Slave error not handled properly");

 // Ensure that psel can only be asserted when the bus is idle (penable is low)
  property p_sel_only_when_idle;
    @(posedge pclk) psel && !penable |=> !psel[*0:$] ##1 psel;
  endproperty

  assert property (p_sel_only_when_idle) else
    $error("APB Protocol Violation: psel asserted when bus is not idle");

  // Check that psel, paddr, pwrite, pwdata, and pstrb remain stable when penable is high
  property p_stable_signals_on_enable;
    @(posedge pclk) (psel && penable) |=> ($stable(psel) && $stable(paddr) && $stable(pwrite) && $stable(pwdata) && $stable(pstrb));
  endproperty

  assert property (p_stable_signals_on_enable) else
    $error("APB Protocol Violation: Control signals must remain stable when penable is high");

  // Ensure pready is eventually asserted after penable is asserted indicating the slave is ready
  property p_pready_eventually_asserted;
    @(posedge pclk) (psel && penable) |-> ##[1:$] pready;
  endproperty

  assert property (p_pready_eventually_asserted) else
    $error("APB Protocol Violation: pready was not asserted eventually after penable was asserted");

  // Ensure pslverr is only asserted when psel and penable are high
  property p_pslverr_assertion_condition;
    @(posedge pclk) pslverr |-> (psel && penable);
  endproperty

  assert property (p_pslverr_assertion_condition) else
    $error("APB Protocol Violation: pslverr asserted under invalid conditions");

  // Check for proper bus idle condition after transaction
  property p_bus_idle_after_transaction;
    @(posedge pclk) (psel && penable && pready) |=> ##1 (!psel && !penable);
  endproperty

  assert property (p_bus_idle_after_transaction) else
    $error("APB Protocol Violation: Bus not idle after transaction completion");

  // Ensure penable must be asserted for at least one clock cycle after psel is asserted
  property p_penable_asserted_after_psel;
    @(posedge pclk) psel && !penable |=> ##1 penable;
  endproperty

  assert property (p_penable_asserted_after_psel) else
    $error("APB Protocol Violation: penable must be asserted for at least one clock cycle after psel");

endmodule

/*
property write_a_matrix; 
    @(posedge intf.clk) disable iff(intf.rst)
        apb_write_access &&  ;
endproperty
*/
