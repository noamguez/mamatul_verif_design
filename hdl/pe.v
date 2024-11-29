//
// Verilog Module PE.pe
//
// Created:
//          by - gueznoa.UNKNOWN (SHOHAM)
//          at - 11:20:34 01/15/2024
//
// using Mentor Graphics HDL Designer(TM) 2019.2 (Build 5)
//

`resetall              //for simulation
`timescale 1ns/10ps   // for simulation

//inputs/outputs explained:
module pe #(  /// start module
	parameter BUS_WIDTH = 8,
   parameter DATA_WIDTH = 16 // a parameter given from the user for reuse 
)
( 
   input   wire    [DATA_WIDTH-1:0]  ain,         // ain wire [DATA_WIDTH-1:0] the a(i) object
   input   wire    [DATA_WIDTH-1:0]  bin,         // bin wire [DATA_WIDTH-1:0] the b(i) object
   input   wire                      reset,       // getting the operation to stop, delete the progress and setting to start again
   input   wire                      clk,         //the clock of matmul
   input   wire                      start,       // control_reg[0] which define to start the calculation
   input   wire                      mode,        //defines if there is a bias input or there isnt
   input   wire    [BUS_WIDTH-1:0]  cin,         //reg [DATA_WIDTH-1:0] the nias input
   output  reg     [DATA_WIDTH-1:0]  aout,        // aout reg [DATA_WIDTH-1:0] the a(i-1) object
   output  reg     [DATA_WIDTH-1:0]  bout,        // bout reg [DATA_WIDTH-1:0] the b(i-1) object
   output  reg     [BUS_WIDTH-1:0]  result_out,   // result reg [2*DATA_WIDTH-1:0] with the result of the computed answer
   output  wire 				  flag_o      //overflow/underflow indication
);

//getting errors now couse i didnt used all inputs and outputs
// Internal Declarations
reg [BUS_WIDTH-1:0] result, mul;//result adder before bias C
reg [BUS_WIDTH-1:0] result_w_bias;
reg [BUS_WIDTH-1:0] a_in_se, b_in_se; //sign extend for inputs 
reg flag,flag_temp, msb_mul, flag_bias;     //msb of current mul for overflow/underflow indication
reg msb_res;   //msb of accumolator for overflow/underflow indication
assign flag_o = flag;

always @(posedge clk, negedge reset) begin: ACCOMULATOR // the accomulator of the result y+=a*b
if(reset==0) begin //low trigger of reset
  result<=0;//setting the adder to be 0
  mul <= 0;
  flag <=0;
  flag_bias<=0;
  flag_temp <=0;
end //end if for reset

else if(start==1) begin//starting the accomulation 
  mul <= a_in_se *  b_in_se;
  msb_mul <= mul[BUS_WIDTH-1];
  msb_res <= result[BUS_WIDTH-1];
  result <= result+ mul;//y+=a*b
  result_w_bias<=result+cin;
  if(msb_mul==msb_res)
    flag_temp <= result[BUS_WIDTH-1]^(msb_mul&msb_res);
  if (mode && cin[BUS_WIDTH-1]==result[BUS_WIDTH-1])
      flag_bias <= result_w_bias[BUS_WIDTH-1]^(result[BUS_WIDTH-1]);
  flag <= flag | flag_temp | flag_bias;
end//end of else if
else begin
  result<=0;//setting the adder to be 0
  mul <= 0;
  flag <=0;
  flag_temp <=0;
  end
end//end of always

always @(posedge clk, negedge reset) begin: register_for_AB // always for the registers of aout and bout
if(reset==0) begin//low trigger of reset
  aout<=0;//empty reg
  bout<= 0;//empty reg
end
else if(start==1) begin//makes the flipflop assignment
  aout<=ain;//assign aout to be the register ai-1
  bout<=bin;// assign bout to be the register bi-1
end//else end
end//always end

always @* begin
  a_in_se[DATA_WIDTH-1:0]<=ain;//assign aout to be the register ai-1
  b_in_se[DATA_WIDTH-1:0]<=bin;// assign bout to be the register bi-1
  a_in_se[BUS_WIDTH-1:DATA_WIDTH]<={(BUS_WIDTH-DATA_WIDTH){ain[DATA_WIDTH-1]}};
  b_in_se[BUS_WIDTH-1:DATA_WIDTH]<={(BUS_WIDTH-DATA_WIDTH){bin[DATA_WIDTH-1]}};
end//always end

always @* begin: addbias //mux in the end to add bias to the result if mode 1 and this is output result_out
  case(mode)
      1'b1: result_out = result_w_bias; //adking bias if mode1
    default: result_out = result;    /// otherwise without bias
  endcase //endcase
  end//biasadder
endmodule // end module
