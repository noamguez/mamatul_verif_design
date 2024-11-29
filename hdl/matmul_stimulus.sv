//
// Verilog program my_project16_lib.verif_matmul_stimulus
//
// Created:
//          by - gueznoa.UNKNOWN (SHOHAM)
//          at - 18:31:33 02/10/2024
//
// using Mentor Graphics HDL Designer(TM) 2019.2 (Build 5)
///
`resetall
`timescale 1ns/10ps
module matmul_stimulus
#(parameter string MATRIX_FILE = "")
( matmul_intf.STIMULUS intf);
  
import verif_package::*;
//I/O 
wire clk = intf.clk;
wire rst_n = intf.rst_n;
reg[ADDR_WIDTH-1:0] paddr;  // adress of an writeble target(according to AMBA spec)
reg psel;  				// apb salve chip selector (according to AMBA spec)
reg penable;				//user input write enable (according to AMBA spec)
reg pwrite;					/// 1 if writing 0 if reading (according to AMBA spec)
reg[BUS_WIDTH -1:0] pwdata;	// input buss data  (according to AMBA spec)
reg[MAX_DIM -1:0] pstrb; 	// pstrb data enable vector (according to AMBA spec)
reg read_results_dut;
///assigning the inputs to internal signals and outputs to interface signals
wire pready=intf.pready;				// pready (according to AMBA spec)
wire pslverr=intf.pslverr;				// error signal (according to AMBA spec)
wire[BUS_WIDTH -1:0] prdata=intf.prdata; // data reading output (according to AMBA spec)
assign intf.paddr = paddr;
assign intf.psel= psel;
assign intf.penable=penable;
assign intf.pwrite=pwrite;
assign intf.pwdata=pwdata;
assign intf.pstrb=pstrb;
assign intf.read_results_dut = read_results_dut;
//registers of all the master
reg[BUS_WIDTH-1:0] bus_write;
reg[MAX_DIM -1:0] bus_strb;
reg[ADDR_WIDTH-1:0] bus_addr;


//control_reg values
logic[15:0] control_reg;
logic[1:0] Dimention_N;//bit 8,9
logic[1:0] Dimention_K;//bit 10,11
logic[1:0] Dimention_M;//bit 12,13
logic reload_B, prev_reload_B;
logic reload_A, prev_reload_A;


//defenitions of basic matrix
localparam logic [DATA_WIDTH-1:0] a2on2 [1:0][1:0] = '{'{1,2}, '{3,4}};
logic [DATA_WIDTH-1:0] mata [MAX_DIM-1:0][MAX_DIM-1:0];
logic [DATA_WIDTH-1:0] matb [MAX_DIM-1:0][MAX_DIM-1:0];
results_matmul results;
assign intf.results_dut=results;

logic [BUS_WIDTH-1:0] read_a [MAX_DIM-1:0];
logic [BUS_WIDTH-1:0] read_b [MAX_DIM-1:0];
logic [BUS_WIDTH-1:0] read_control_reg;
logic apb_mutex;
logic [MAX_DIM*MAX_DIM-1:0] flags;
logic flags_detected, flags_location;
//files
integer file_pointer;
string file_line;

////////////////BASIC TASKS FOR APB///////////////////////////////
task apb_write(input reg[ADDR_WIDTH-1:0]  addr ,reg[BUS_WIDTH -1:0] data_write, reg [MAX_DIM -1:0] data_strb); //setup cycle
  apb_mutex = 0;
  @(posedge clk);//first faze of transfare in write (input)
  paddr=addr;//assigning the address
  psel=1'b1;//setting psel
  pwdata=data_write;//assigning the data (input)
  pstrb=data_strb;//assigning the data strobe (input)
  pwrite= 1'b1;//setting pwrite to writing high 1
  @(posedge clk);//wait for second phase,
  penable=1'b1;//setting penable - start acceess phase
  @(posedge pready);//waiting for pready to end  communication
  @(posedge clk);
  psel=1'b0;//puting back psel to normal 0
  penable=1'b0;//putting back penable to normal 0
  apb_mutex = 1;
endtask 

task apb_read(input reg[ADDR_WIDTH-1:0]  addr); //setup cycle
  apb_mutex = 0;
  @(posedge clk);//first faze of transfare in read
  paddr=addr;//assigning the address
  psel=1'b1;//setting psel
  pwrite= 1'b0; //setting pwrite to reading low 0
  @(posedge clk);//second faze,
  penable=1'b1;//setting penable
  @(posedge pready);//waiting for pready to end  communication
  @(posedge clk);
  psel=1'b0;//puting back psel to normal 0
  penable=1'b0;//putting back penable to normal 0
  @(posedge clk);
  apb_mutex = 1;
endtask 


task write_apb_matrix_ab(input matrix_matmul matrixa,matrixb);//type def matrix_matmul defined in package
  /////////Send matrix A://///////
   //$display("Sending matrix A now: \n");
   //$display("reload a is: %0h and prev_reload a is: %0h\n",reload_A,prev_reload_A);
   read_results_dut=0;
   if (prev_reload_A==0) begin
	  for(int i=0; i<=Dimention_N; i++) begin //for amat
		bus_write = {BUS_WIDTH*(1'b0)};  // init bus
		for(int j=0; j<=Dimention_K; j++) begin
		  //$display("elemnt %0d,%0d of matrix A: 0x%0h \n" , i,j, matrixa[i][j]);
		  bus_write[((1+j)*DATA_WIDTH-1)-:DATA_WIDTH] =matrixa[i][j];//assign elemnt j of  line i 
		  //$display("The APB data bus is: 0x%0h \n" ,bus_write);
		  if(bus_write[((1+j)*DATA_WIDTH-1)-:DATA_WIDTH]!= {DATA_WIDTH*(1'b0)})//assigning strob if the bus place assigned isnt 0
			bus_strb[j]=1;
		  else bus_strb[j]=0;
		end
		bus_addr[max_addr_bit-1:0]=amat_addr;//puting 5 lsb as amat
		bus_addr[max_addr_bit+1-:2]=i;       //put sub adrress
		apb_write(bus_addr,bus_write,bus_strb);
		wait(apb_mutex); 
	  end
	end
	bus_write = {BUS_WIDTH*(1'b0)};  // init bus 
  /////////Send matrix B://///////
  //$display("reload b is: %0h and prev_reload b is: %0h \n",reload_B,prev_reload_B);
	if (prev_reload_B==0) begin
	  for(int i=0; i<=Dimention_M; i++) begin //for bmat
		for(int j=0; j<=Dimention_K; j++) begin
		  //$display("elemnt %0d,%0d of matrix B: 0x%0h \n" , j,i, matrixb[j][i]);
		  bus_write[((1+j)*DATA_WIDTH-1)-:DATA_WIDTH]=matrixb[j][i];//assign the  collum i bus will be {B[3][i],B[2][i],B[1][i],B[0][i]}
		  //$display("The APB data bus is: 0x%0h \n" ,bus_write);
		  if(bus_write[((1+j)*DATA_WIDTH-1)-:DATA_WIDTH]!= {DATA_WIDTH*(1'b0)})//assigning strob if the bus place assigned isnt 0
			bus_strb[j]=1;
		end
		bus_addr[max_addr_bit-1:0]=bmat_addr;//puting 5 lsb as bmat
		bus_addr[max_addr_bit+1-:2]=i;//put sub adrress
		apb_write(bus_addr,bus_write,bus_strb);
		wait(apb_mutex);
	  end
	end
endtask

task assign_control(logic start,logic mode, logic[1:0] w_target, logic[1:0] r_target);
  control_reg[0]=start;
  control_reg[1]=mode;
  control_reg[3:2]=w_target;
  control_reg[5:4]=r_target;
  control_reg[7:6]=2'b01; //dataFlow
  control_reg[9:8]= Dimention_N;
  control_reg[11:10]= Dimention_K;
  control_reg[13:12]= Dimention_M;
  control_reg[15:14]= 2'b00;
endtask

task write_control();
  //bus_write[BUS_WIDTH-1:0]=0;//washing the bus
  bus_write[15:0]=control_reg;//puting control_reg on the bus
  bus_addr=0;
  bus_strb=1;
  apb_write(bus_addr,bus_write,bus_strb);  
  wait(apb_mutex);
endtask

task read_results();
  for(int i=0; i<=Dimention_N; i++) begin //for amat
    for(int j=0; j<=Dimention_M; j++) begin
      bus_addr[max_addr_bit-1:0]=scratchpad_addr;//puting 5 lsb as scratchpad
      bus_addr[max_addr_bit+1-:2]=i;//put sub adrress
	  bus_addr[max_addr_bit+3-:2]=j;//put sub adrress
	  //address bus now looks like that: [[0s][2'b of collum][2'b of line][5'b of scratchpad]]
      apb_read(bus_addr);
	  wait(apb_mutex);
	  results[i][j]=prdata;
    end
  end
  //$display("finissssh apb read \n");
  read_results_dut=1; //signing to the golden model checker that the results are valid
  //$display("finissssh 2 apb read \n");
endtask

task read_matrix_a();
  for(int i=0; i<=Dimention_N; i++) begin //for amat
      bus_addr[max_addr_bit-1:0]=5'B00100;//puting 5 lsb as scratchpad
      bus_addr[max_addr_bit+1-:2]=i;//put sub adrress
	  //address bus now looks like that: [[0s][2'b of collum][2'b of line][5'b of scratchpad]]
      apb_read(bus_addr);
	  wait(apb_mutex);
	  read_a[i]=prdata;
	  
  end
endtask

task read_matrix_b();
  for(int i=0; i<=Dimention_N; i++) begin //for amat
      bus_addr[max_addr_bit-1:0]=5'B01000;//puting 5 lsb as scratchpad
      bus_addr[max_addr_bit+1-:2]=i;//put sub adrress
	  //address bus now looks like that: [[0s][2'b of collum][2'b of line][5'b of scratchpad]]
      apb_read(bus_addr);
	  wait(apb_mutex);
	  read_b[i]=prdata;
	  
  end
endtask

task read_control();
	bus_addr=0;
	apb_read(bus_addr);
	wait(apb_mutex);
	read_control_reg=prdata;
endtask

task read_flags();
	bus_addr=12;
	apb_read(bus_addr);
	wait(apb_mutex);
	flags=prdata;
	flags_detected=0;
	flags_location=0;
	for (int i=0; i<MAX_DIM*MAX_DIM; i++) begin
		if( flags[i]==1) begin
			flags_detected=1;
			flags_location=i;
			$display("flags noticed at location %h", flags_location);
			end
	end
endtask

task open_file();  //opens the file and assigning the file pointer to a global integer
		file_pointer = $fopen(MATRIX_FILE, "r");
		if(file_pointer == 0) $fatal(1, $sformatf("Failed to open %s", MATRIX_FILE));
endtask


task read_file(integer file_pointer); 
	string topline, bottomline;
	if($fscanf(file_pointer, "%s\n", topline) != 1) begin 
      $fatal(1, "Failed to read the control line of MATRIX_FILE");
	end //end if
	if($fscanf(file_pointer, "%d", control_reg) != 1) begin
      $fatal(1, "Failed to read the control line of MATRIX_FILE");
	end // end if
	Dimention_N = control_reg[9:8];
	Dimention_K = control_reg[11:10];
	Dimention_M = control_reg[13:12];
	prev_reload_A<=reload_A;
	prev_reload_B<=reload_B;
	reload_A <= control_reg[14];
	reload_B <= control_reg[15];
	if($fscanf(file_pointer, "%s\n", topline) != 1) begin //reading A comment
      $fatal(1, "Failed to read the control line of MATRIX_FILE");
	end // end if
	//if(prev_reload_A==0) begin //for now reading matrixes from file even though were not sending them
		for(int i=0; i<=Dimention_N; i++) begin
			for(int j=0; j<=Dimention_K; j++) begin
				if($fscanf(file_pointer, "%d", mata[i][j]) != 1) begin
					$fatal(1, "Failed to read the mat a ant place [%d][%d]",i,j);
				end //end if
			end //end for
		end //end for
	//end
	if($fscanf(file_pointer, "%s\n", topline) != 1) begin//reading B comment
      $fatal(1, "Failed to read the control line of MATRIX_FILE");
	end //end if
	//if(prev_reload_B==0) begin //for now reading matrixes from file even though were not sending them
		for(int i=0; i<=Dimention_K; i++) begin
			for(int j=0; j<=Dimention_M; j++) begin
				if($fscanf(file_pointer, "%d", matb[i][j]) != 1) begin
					$fatal(1, "Failed to read the mat b ant place [%d][%d]",i,j);
				end //end if
			end //end for
		end //end for
	//end
	if ($fscanf(file_pointer, "%s\n", bottomline) != 1) begin //throwing the end line
		$fclose(file_pointer);
		$fatal(1, "Failed to read the matrix a line");
	end //end if
	
endtask

////////////////////initials//////////////////////////////
initial forever begin: reset
	$display("wait for reset \n");
	@(negedge rst_n);
	bus_write=0;
	bus_strb=0;
	bus_addr=0;
	read_control_reg=0;
	for(int i=0; i<MAX_DIM; i++) begin //for amat
	read_a[i]=0;
	read_b[i]=0;
		for(int j=0; j<MAX_DIM; j++) begin
		  results[i][j]=0;
		end
	end
	prev_reload_A<=0;
	prev_reload_B<=0;
	reload_A<=0;
	reload_B<=0;
	read_results_dut=0; 
	flags=0;
	flags_detected=0;
	flags_location=0;
	$display("Done resseting... \n");
end
	
	
initial begin: apb_master
  /*//super basic test
  @(posedge rst_n);
  Dimention_N = 2; Dimention_K = 2; Dimention_M = 2; 
  write_apb_matrix_ab(a2on2,a2on2);
  assign_control(1,0,1,0);*/
  //real test
  //$display("Starting stimulus...\n");
  @(posedge rst_n);
  
  open_file();
  //$display("stimuly opened file \n");
  while (!$feof(file_pointer)) begin
	  read_file(file_pointer); //reading a section of mat multiplications from the file
	  #5;
	  write_apb_matrix_ab(mata,matb);//sending the matrixes to the matmul using apb master
	  write_control();//sending the control register with 1 in start bit.
	  @(posedge intf.busy);// now starts the calculation of the accelerator
	  @(negedge intf.busy);//the matmul finished the calculation
	  read_results(); //reading the results from scratchpad for sending them to golden model check
	  #5;
	  /*//not important tests bus possible and capable
	  read_matrix_a(); //reading the a matrix from DUT to check capability	 
	  read_matrix_b(); //reading the b matrix from DUT to check capability	
	  read_control(); //reading the control reg from DUT to check capability*/	
  end //continue to read to the next matrix in file until the file ends
  $fclose(file_pointer); 
end
endmodule