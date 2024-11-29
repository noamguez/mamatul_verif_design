//
// Verilog Module my_project16_lib.apb_slave
//
// Created:
//          by - roznadav.UNKNOWN (SHOHAM)
//          at - 14:26:33 01/16/2024
//
// using Mentor Graphics HDL Designer(TM) 2019.2 (Build 5)
//
//`include "apb_slave_writer.v"

`resetall            /// for sim
`timescale 1ns/10ps //// for sim
module apb_slave   /// module start

#(parameter DATA_WIDTH = 16,  //matrix data elemnet width
 parameter BUS_WIDTH = 32,	// apb bus width
 parameter ADDR_WIDTH = 32, // address size
 parameter MAX_DIM = BUS_WIDTH / DATA_WIDTH,   // MAX_DIM is the maximum matrix dimension
 parameter SPNTARGETS = 4, //can be any of the values: 1, 2, 4//this parameter defines how big will be the scrarchpad matrixs
 parameter NUM_OF_FIFOS = 8      //There are 8 fifos feeding the systolic arch (explained in pdf)
 
 )

(input wire  pclk,  // clock signal (according to AMBA spec)
 input wire preset,  // reset        (according to AMBA spec)
 input wire[ADDR_WIDTH-1:0] paddr,  // adress of an writeble target(according to AMBA spec)
 input  wire psel,  				// apb salve chip selector (according to AMBA spec)
 input  wire penable,				//user input write enable (according to AMBA spec)
 input wire pwrite,					/// 1 if writing 0 if reading (according to AMBA spec)
 input wire[BUS_WIDTH -1:0] pwdata,	// input buss data  (according to AMBA spec)
 input wire[MAX_DIM -1:0] pstrb, 	// pstrb data enable vector (according to AMBA spec)
 
 //external outputs to the apb slave
 output reg pready,				// pready (according to AMBA spec)
 output wire pslverr,				// error signal (according to AMBA spec)
 output wire[BUS_WIDTH -1:0] prdata_out, // data reading output (according to AMBA spec)
 ///internal inputs and outputs to the matmul module
 input wire start_bit,
 input wire[BUS_WIDTH -1:0] read_data,
 input wire error_write,
 output reg[8:0] locals_enable_vec, // NUM_OF_FIFOS = 8. This 1 - hot chip selector vector
 output reg[BUS_WIDTH-1:0] wdata_out,              // data elemnet out twoards inner matmul desgin writable components.
 output reg global_en_wr_out
);


//internal parameters for writing A and B static matrix for reading


//matrix a and b and their assignings

reg[BUS_WIDTH -1:0] prdata;
reg error_apb;
assign prdata_out = prdata;
assign pslverr= start_bit | error_apb | error_write; // need to change
integer i;

localparam [1:0] IDLE = 2'b00,
SETUP = 2'b01,
ACCESS = 2'b10;


reg [1:0] state, next;

 
always @(posedge pclk or negedge preset) begin /// FSM of one always
  if (!preset) begin
		state <= IDLE;
		pready <= 0;
  end

  else begin
  case (state)
	IDLE: begin
		error_apb <=0;
		pready <= 0;
		if(psel == 1) state <= SETUP;
		else state<=IDLE;
	end
	SETUP: begin
		if (paddr[1:0] !=0) begin
			error_apb <=1;
			$display("An illegal address. \n");
			state<=IDLE;
		end
		else if (pstrb==0)	begin 
			error_apb <=1;
			$display("An illegal strobe. \n");
			state<=IDLE;
			
			end
		else if(psel == 1 && penable == 1) begin
			state <= ACCESS;
			pready <= 1;
			end
		else if (psel == 1) state <= SETUP;
		else state<=IDLE;
	end
	ACCESS: begin
		pready <= 0;
		if(psel == 1 && penable == 0) state <= SETUP;
		else if (psel == 0 && penable == 0) state <= IDLE;
	end
	
	default: state <= IDLE;
  endcase
  end
end


///reading process
always @(posedge pclk, negedge preset) begin:reading
  if(preset==0) begin
	prdata<= {BUS_WIDTH{1'b0}};
	end
  else if (!pwrite && state== ACCESS) begin //reading
    prdata<= read_data;
 end
end

always @(posedge pclk , negedge preset) begin: WRITE
  if(preset==0) begin                // if reset is low
    wdata_out <={BUS_WIDTH{1'b0}};   /// clear bus buffer register when rst
	global_en_wr_out<=0;
  end  // end if
    else if (state== ACCESS && pwrite==1) begin     /// When in AMBA APB access phase of the transaction
		for (i = 0; i< MAX_DIM; i= i+1) begin 
			if (pstrb[i]==1)
				wdata_out[(1+i)*DATA_WIDTH-1 -:DATA_WIDTH] <= pwdata[(1+i)*DATA_WIDTH -1-:DATA_WIDTH];   /// Emit the LSB data element on the bus buffer register
		end
		global_en_wr_out<=1;
    end   // end elseif 1      
    else begin	/// When NOT in AMBA APB access phase of the transaction
	 global_en_wr_out<=0;
	 wdata_out <= {BUS_WIDTH{1'b0}};               /// reset out data
    end  // end elseif 2
 end    // end always


/////// decider for fifos + control addresses////
always @* begin: ADDR_DECODE
if (state == SETUP) begin 
  case (paddr[6:0]) 								//according to paddr
    7'B00_00100: locals_enable_vec = 9'b0_0000_0001;  /// local enable fifo_0 
    7'B01_00100: locals_enable_vec = 9'b0_0000_0010;  /// local enable fifo_1 
    7'B10_00100: locals_enable_vec = 9'b0_0000_0100;  /// local enable fifo_2 
    7'B11_00100: locals_enable_vec = 9'b0_0000_1000;  /// local enable fifo_3 
    7'B00_01000: locals_enable_vec = 9'b0_0001_0000;  /// local enable fifo_4 
    7'B01_01000: locals_enable_vec = 9'b0_0010_0000;  /// local enable fifo_5 
    7'B10_01000: locals_enable_vec = 9'b0_0100_0000;  /// local enable fifo_6 
    7'B11_01000: locals_enable_vec = 9'b0_1000_0000;  /// local enable fifo_7 
    7'H0: locals_enable_vec = 9'b1_0000_0000; /// local enable control register 
    default: locals_enable_vec = 9'b0;   // on an unreleven adderss put zeroes
 
	endcase
  end
end// end async always
endmodule // end module



/*
always @(posedge pclk or negedge preset) begin /// sequentisl part of the fsm
	if (!preset)
		state <= IDLE;
	else
		state <= next;
end

always @* begin/// combi part of the fsm
  case (state)
	IDLE: begin
		pready = 0;
		if(psel == 1) next = SETUP;
		else next=IDLE;
	end
	SETUP: begin 
		if(psel == 1 && penable == 1) begin
			next = ACCESS;
			pready = 1;
			end
		else if (psel == 1) next = SETUP;
		else next=IDLE;
	end
	ACCESS: begin
		
		if(psel == 1 && penable == 0) begin
			next = SETUP;
			pready = 1;
			end
		else if (psel == 0 && penable == 0) begin
		next = IDLE;
		pready = 1;
		end
	end
	
	default: next = IDLE;
  endcase
end
*/