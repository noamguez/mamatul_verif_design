//
// Verilog Module matmul_lib.fifo
//
// Created:
//          by - gueznoa.UNKNOWN (SHOHAM)
//          at - 13:34:18 01/21/2024
//
// using Mentor Graphics HDL Designer(TM) 2019.2 (Build 5)
//

`resetall     		  /// for simulation
`timescale 1ns/10ps   /// for simulation
module fifo #(       //start fifo module
   parameter BUS_WIDTH = 32,//can be any of the values: 16, 32, 64//the parameter bus width indicates the width of the apb bus of data
   parameter DATA_WIDTH = 16,  //matrix data elemnet width
   parameter MAX_DIM=4         // MAX_DIM is the maximum matrix dimension
)

( input wire clk,    // clock signal 
   input wire reset, //reset low trigger
   input wire start,  // control_reg[0] which define to start the calculation
   input wire enable_write,  /// writing enbale for this fifo 
   input wire[BUS_WIDTH-1:0] data_in,   // data to write for this fifo 
   input wire [MAX_DIM/2-1:0] placementin, //at what line/collum is fifo at [0,3] for adding 0s to the queue
   input reassign_en, reassign,
   output reg[DATA_WIDTH-1:0]  data_out       /// data out from the fifo for PE elements     
) ;

  reg [2*MAX_DIM*DATA_WIDTH-1:0] queue,queue_save ;	/// fifo data reg element
  reg copied;
  always @(posedge clk, negedge reset) begin: processing_queue  //// fifo logic 
    if (!reset) begin //reset low level trigger
      data_out<= {DATA_WIDTH{1'b0}};   // reset data out
      queue<={2*MAX_DIM*DATA_WIDTH{1'b0}};  /// reset fifo data reg
	  copied<=0;
    end // end if
    else if (start == 1'b1) begin         /// matrix multipication is strating 
		if (copied==0) begin
			queue_save<=queue;
			copied=1;
		end
        data_out <= queue[DATA_WIDTH-1:0]; /// pop out top element in fifo
        queue<=queue >> DATA_WIDTH;			/// shift left one data elemnt
	end
	else if(reassign && reassign_en && !start) begin
		queue<=queue_save;
		copied<=1;
    end// end if
    
    else if (start == 1'b0 && enable_write==1) begin  /// BEFORE matrix multipication - init fifo with it's relevent data
		queue[(placementin)*DATA_WIDTH+BUS_WIDTH-1-:BUS_WIDTH] <= data_in;    /// write in current index								/// update init counter
    end  //end else if
	else copied<=0;
  end // end always
endmodule // end fifo module
