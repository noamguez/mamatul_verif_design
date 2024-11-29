//
// Verilog Module my_project16_lib.matmul
//
// Created:
//          by - roznadav.UNKNOWN (SHOHAM)
//          at - 12:51:25 01/21/2024
//
// using Mentor Graphics HDL Designer(TM) 2019.2 (Build 5)
//
`resetall // for simulation
`timescale 1ns/10ps // for simulation


module matmul  // start matmul prod
#(parameter DATA_WIDTH = 16,//can be any of the values: 8, 16, 32//the parameter data width indicates what is the size of a given word
 parameter BUS_WIDTH = 32,//can be any of the values: 16, 32, 64//the parameter bus width indicates the width of the apb bus of data
 parameter ADDR_WIDTH = 32,//can be any of the values: 16, 24, 32//the parameter address width indicates the width of the apb bus of addresses
 parameter SPNTARGETS = 4, //can be any of the values: 1, 2, 4//this parameter defines how big will be the scrarchpad matrixs
 localparam MAX_DIM = BUS_WIDTH / DATA_WIDTH//can be any of the values: 2, 4//this parameter indicates whats the maximal dimention for //the moltiplication. it tells us as well how many words of data can we get in each bus iteration
 )
(input wire  clk_i,  //clocl
 input wire rst_ni, //reset
 input wire[ADDR_WIDTH-1:0] paddr_i, // adress of an writeble target(according to AMBA spec)
 input  wire psel_i,					// apb salve chip selector (according to AMBA spec)
 input  wire penable_i,				//user input write enable (according to AMBA spec)
 input wire pwrite_i,					/// 1 if writing 0 if reading (according to AMBA spec)
 input wire[BUS_WIDTH -1:0] pwdata_i,	// input buss data  (according to AMBA spec)
 input wire[MAX_DIM -1:0] pstrb_i, 	// pstrb_i data enable vector (according to AMBA spec)
 output wire pready_o,				// pready_o (according to AMBA spec)
 output wire pslverr_o,				// error signal (according to AMBA spec)
 output wire[BUS_WIDTH -1:0] prdata_o, // // data reading output (according to AMBA spec)
 output wire busy_o // indicates if matmul is calculating for master
 ///
);


localparam CONTROL_SIZE = 16;  // size of control register
localparam NUM_OF_FIFOS = 2*MAX_DIM;   // number of fifos in the design (number of units that feed the pe)

/////DESIGN SPEC REGISTERS///
reg[CONTROL_SIZE-1:0] control_reg;  //control register
reg flags [MAX_DIM-1:0][MAX_DIM-1:0];  //overflow flags regs matrix
reg [BUS_WIDTH -1:0] scratchpad [SPNTARGETS-1:0][MAX_DIM-1:0][MAX_DIM-1:0]; //scrarchpad matrixes
//////////////////////////////
reg [BUS_WIDTH -1:0] matrixc [MAX_DIM-1:0][MAX_DIM-1:0];        // matrix c reg
wire [BUS_WIDTH -1:0] result_mat [MAX_DIM-1:0][MAX_DIM-1:0];   // result matrix without flags
wire flags_wire [MAX_DIM-1:0][MAX_DIM-1:0];
reg [BUS_WIDTH-1:0] flags_read;

integer k,t,s,w,l,m; ///indexes for for loops
genvar i,j; ///indexes for for loops
wire start_bit =  control_reg[0];  // start bit of  calc from control register
wire mode_bit =  control_reg[1];    // mode bit of  calc from control register 
wire[1:0] write_target =  control_reg[3:2]; // write target bits of  calc from control register 
wire[1:0] read_target =  control_reg[5:4];	// read target bits of  calc from control register 
wire[1:0] dimension_n =  control_reg[9:8];  // dim_n target bits of  calc from control register 
wire[1:0] dimension_k =  control_reg[11:10]; // dim_k target bits of  calc from control register 
wire[1:0] dimension_m =  control_reg[13:12]; // dim_m target bits of  calc from control register 
////enables for wirting//
wire [8:0] local_enables;   ///local enable vector for 1 control reg and 8 fifos
wire [8-1:0] writeto_fifos_localenable_vec = local_enables[8-1:0]; ///local enable vector for 8 fifos
wire write_ctr_en = local_enables[8]; // local enable bit to control register
wire global_write_en; // global write enable from apb_slave
reg reassign_fifo;
wire reassigning_afifo=control_reg[14];
wire reassigning_bfifo=control_reg[15];
reg error_write; // looking for errors while writing
////signals for reading//
wire [1:0] i_subaddr= paddr_i[6:5];//this is the i index for the reading the results matrix
wire [1:0] j_subaddr= paddr_i[8:7];//this is the j index for the reading the results matrix
reg [BUS_WIDTH-1:0] read_data;
reg [BUS_WIDTH-1:0] amatrix [MAX_DIM-1:0];
reg [BUS_WIDTH-1:0] bmatrix [MAX_DIM-1:0];
/////////////////////////
wire [BUS_WIDTH -1:0] writing_data; //writing data recived from apb
wire [DATA_WIDTH -1:0] pe_A_inputs[MAX_DIM-1:0][MAX_DIM:0]; //matrix A arguments (used for reading only)
wire [DATA_WIDTH -1:0] pe_B_inputs[MAX_DIM:0][MAX_DIM-1:0]; //matrix B arguments (used for reading only)
reg[6:0] cycle_counter;
/////outputs assigning
assign busy_o= start_bit;
///////////LOGIC///////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge clk_i, negedge rst_ni) begin: CTR_WRITE  /// writing data to control register
  if(rst_ni == 0) control_reg <= {CONTROL_SIZE{1'b0}};   // if reset
  else if (write_ctr_en & global_write_en ) control_reg <= pwdata_i[15:0];     // if control local write enable & global_write_en are set - take from bus
  else if(cycle_counter == (dimension_n+1)*(dimension_k+1)*(dimension_m+1))
    control_reg[0]<=1'b0;
end
//& !error_write
always @(posedge clk_i, negedge rst_ni) begin: counterof_calcul  
  if(rst_ni == 0) begin 
  cycle_counter <= {5{1'b0}};   // if reset
  reassign_fifo<=0;
  end
  else if(cycle_counter == (dimension_n+1)*(dimension_k+1)*(dimension_m+1)) begin
    cycle_counter<={5{1'b0}};
	reassign_fifo<=1;
  end
  else if(start_bit ==1) begin
    cycle_counter<= cycle_counter+1;     // if ctr write enable is set then write
	reassign_fifo<=0;
  end
end


//////////////////logic of scratchpad
always @ (posedge clk_i, negedge rst_ni) begin: assigning_cmat //cmat reg assigned from scarchpad once the control  is being wrriten
  if (rst_ni==0) begin    									  //when reset
        for (l = 0; l < MAX_DIM; l = l + 1) begin   ///rows for loop
          for (m = 0; m < MAX_DIM; m = m + 1) begin  // coulms for loop 
          matrixc[l][m]<={BUS_WIDTH{1'b0}};			//reset matrixc register
        end // end for
      end // end for
  end // end if
  else if (write_ctr_en & global_write_en == 1) begin    /// if control register is being wrriten
    for (l = 0; l < MAX_DIM; l = l + 1) begin : assigning_cmata  		 ///rows for loop
        for (m = 0; m < MAX_DIM; m = m + 1) begin : assigning_cmatb // coulms for loop 
          matrixc[l][m]<=scratchpad[read_target][l][m];  //asssigning matrixc from scarchpad
        end // end for
      end // end for
    end // end else if
end  // end always



always @ (posedge clk_i, negedge rst_ni) begin: assigning_results // assigning result matrix to scrarchpad
    if (rst_ni==0) begin //when reset
      flags_read<={BUS_WIDTH{1'b0}};
        for (t = 0; t < MAX_DIM; t = t + 1) begin : assigning_resultsa_reset  //rows for loop
          for (s = 0; s < MAX_DIM; s = s + 1) begin : assigning_reesultsb_reset // coulms for loop 
			for (k = 0; k < SPNTARGETS; k = k + 1) // for loop for matrixes in scarchpad
            scratchpad[k][t][s]<={(2*DATA_WIDTH){1'b0}};
			end // end for
			flags[t][s]<=0;
      end // end for
    end  // end for
  else if (start_bit==1) begin   // if start bit is on  - update scarchpad's target matrix continouesly
    for (t = 0; t <= dimension_n; t = t + 1) begin : assigning_resultsa //rows for loop
        for (s = 0; s <= dimension_m; s = s + 1) begin : assigning_reesultsb // coulms for loop 
          scratchpad[write_target][t][s]<=result_mat[t][s]; // assigning result matrix to scrarchpad
		  flags[t][s]<= flags_wire[t][s];
		  flags_read[t*MAX_DIM+s]<=flags_wire[t][s];
		end // end for
      end// end for
    end // end else if
end // end always

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//reading from scratchpad or control reg
always @ (posedge clk_i, negedge rst_ni) begin: reading 
    if (rst_ni==0)                     read_data<={BUS_WIDTH{1'b0}}; //if reset put 0 in read reg
   else if(!pwrite_i && psel_i ) begin
		case (paddr_i[4:0]) // 2 bid subindex for a and b and 5 bid address
    5'b00000: read_data <= control_reg;
    5'B10000: read_data <= scratchpad[write_target][i_subaddr][j_subaddr]; //for scratchpad
	5'B00100:read_data <= amatrix[i_subaddr];   /// fifo 0 address
	5'B01000:read_data <= bmatrix[i_subaddr];	/// fifo 4 address
	5'b01100:read_data <= flags_read;
    //fifo_A0_add: prdata_o<=amatrix[0];
    default: read_data <=0;//for now not supporting reading from a b and flags matrix
	endcase
   end
   else
	read_data <=0;
 end
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////



apb_slave #(.DATA_WIDTH(DATA_WIDTH), .BUS_WIDTH(BUS_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .MAX_DIM(MAX_DIM), .SPNTARGETS(SPNTARGETS)) apb // instance of apb slave
              ( .pclk(clk_i), 	// clock signal (according to AMBA spec)
                .preset(rst_ni), // reset        (according to AMBA spec)
                .paddr(paddr_i), // adress of an writeble target(according to AMBA spec)
                .psel(psel_i),    // apb salve chip selector (according to AMBA spec)
                .penable(penable_i), //user input write enable (according to AMBA spec)
                .pwrite(pwrite_i),  /// 1 if writing 0 if reading (according to AMBA spec)
                .pwdata(pwdata_i),  // input buss data  (according to AMBA spec)
                .pstrb(pstrb_i),   // pstrb_i data enable vector (according to AMBA spec)
                .pready(pready_o),  // pready_o (according to AMBA spec)
                .pslverr(pslverr_o), // error signal (according to AMBA spec)
                .prdata_out(prdata_o), // data reading output (according to AMBA spec)
                .start_bit(start_bit),
                .read_data(read_data),
				.error_write(error_write),
                .locals_enable_vec(local_enables),  // NUM_OF_FIFOS = 8. This 1 - hot chip selector vector
                .wdata_out(writing_data),     // data elemnet out twoards inner matmul desgin writable components.
                .global_en_wr_out(global_write_en)  // global write enable for inner matmul desgin writable components.
              ); // end of instance declaration


genvar q1, q2;  ///for loop indexes
generate  // begin rows fifos generate (fifos 0,1,2,3)
    for (q1 = 0; q1 < NUM_OF_FIFOS/2; q1 = q1 + 1) begin : create_fifos_aside  // for every row fifo (there are 4)
      fifo #(.BUS_WIDTH(BUS_WIDTH), .DATA_WIDTH(DATA_WIDTH), .MAX_DIM(MAX_DIM))fa(    /// fifo instance declaration
        .clk(clk_i),     //clock
        .reset(rst_ni), //reset
        .start(start_bit), // matmul start bit
        .enable_write(writeto_fifos_localenable_vec[q1] & global_write_en & pwrite_i), // enable writing to fifo - global & local (according to address)
        .data_in(writing_data),                      // data comming from apb to the fifo 
        .placementin(q1[MAX_DIM/2-1:0]),  					//zeros placement according to systolic location of the fifo (which pe it's feeding)
        .reassign_en(reassigning_afifo), //is it defined in the control reg that the fifo should be reassigned
		.reassign(reassign_fifo),	//the time when the fifo should reassign itself
		.data_out(pe_A_inputs[q1][0])                             // data out from  fifo going to  PE
      ); // end fifo instance declaration
    end // end forloop
endgenerate // end rows fifos generate
generate   // begin coloumns fifos generate  (fifos 4,5,6,7)
    for (i = 0; i < NUM_OF_FIFOS/2; i = i + 1) begin : create_fifos_bside // for every coloumn fifo (there are 4)
      fifo #(.BUS_WIDTH(BUS_WIDTH), .DATA_WIDTH(DATA_WIDTH), .MAX_DIM(MAX_DIM))fb (  /// fifo instance declaration
        .clk(clk_i),     //clock
        .reset(rst_ni), //reset
        .start(start_bit), // matmul start bit
        .enable_write(writeto_fifos_localenable_vec[i+4] & global_write_en & pwrite_i), // enable writing to fifo - global & local (according to address)
        .data_in(writing_data),                  // data comming from apb to the fifo 
        .placementin(i[MAX_DIM/2-1:0]),       //zeros placement according to systolic location of the fifo (which pe it's feeding)
        .reassign_en(reassigning_bfifo), //is it defined in the control reg that the fifo should be reassigned
		.reassign(reassign_fifo),	//the time when the fifo should reassign itself
		.data_out(pe_B_inputs[0][i])                             // data out from  fifo going to  PE
      );
    end // end for loop
endgenerate // end coloumns fifos generate

generate  // begin PE's generate
    for (i = 0; i < MAX_DIM; i = i + 1) begin : create_pe_aside  ///rows for loop
      for (j = 0; j < MAX_DIM; j = j + 1) begin : create_pe_bside  ///coloumns for loop
      
      pe   #(.BUS_WIDTH(BUS_WIDTH),.DATA_WIDTH(DATA_WIDTH)) d11  // PE instance creation
			(.ain(pe_A_inputs[i][j]),   // ain wire [DATA_WIDTH-1:0] the a(i) object
              .bin(pe_B_inputs[i][j]),  // bin wire [DATA_WIDTH-1:0] the b(i) object
              .reset(rst_ni), 			// getting the operation to stop, delete the progress and setting to start again
              .clk(clk_i), 				//the clock of matmul
              .start(start_bit), 		// control_reg[0] which define to start the calculation
              .mode(mode_bit & (i<=dimension_n) & (j<=dimension_m)), //can be a dissaster			 //defines if there is a bias input or there isnt
              .cin(matrixc[i][j]),		//reg [DATA_WIDTH-1:0] the bias input
              .aout(pe_A_inputs[i][j+1]),  // aout reg [DATA_WIDTH-1:0] the a(i-1) object
              .bout(pe_B_inputs[i+1][j]),   // bout reg [DATA_WIDTH-1:0] the b(i-1) object
              .result_out(result_mat[i][j]), // The result of the computed answer - to the relevent place in the result matrix
              .flag_o(flags_wire[i][j])
			  ); //end  PE instance creation
        end // end for 
    end  // end for
endgenerate  // end PE's generate



//writing to static memory a,b
always @(posedge clk_i, negedge rst_ni) begin:writing_to_amat_bmat
  if (rst_ni==0) begin
    for (w = 0; w< MAX_DIM; w= w+1) begin
        amatrix[w]<= {BUS_WIDTH{1'b0}};
        bmatrix[w]<= {BUS_WIDTH{1'b0}};
    end
  end
  else if ( pwrite_i && psel_i && penable_i) begin
  case (paddr_i[4:0]) 								//according to paddr_i
    5'B00100:amatrix[i_subaddr]<=pwdata_i;   /// fifo 0 address
	5'B01000:bmatrix[i_subaddr]<=pwdata_i;	/// fifo 4 address  
    default: ;
 endcase
 end
end

//error ditector
always@* begin: error_for_write_handler
if (write_ctr_en & global_write_en) begin //the control value is on the bus. validating it
	if (pwdata_i[13:12] > MAX_DIM || pwdata_i[11:10] > MAX_DIM || pwdata_i[9:8] > MAX_DIM) //dimentions of matrix are bigger than MAX_DIM
		error_write<=1;
	else if (pwdata_i[5:4] > SPNTARGETS || pwdata_i[3:2] > SPNTARGETS)//write and read targets are bigger than scrarchpad size
		error_write<=1;
	end
	else error_write<=0;
end

endmodule // end matmul module
