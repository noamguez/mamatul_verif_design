////
//Noam Guez


















//Nadav Rozenfeld
////

`resetall
`timescale 1ns/10ps
module matmul_golden

////////parameters////////////////////////////////////////////////
#(parameter string golden_path = "")
( matmul_intf.CHECKOF intf);


////////////////variables declarations and assignments/////////////

import verif_package::*;


results_matmul golden_results, dut_results;  ///a GOLDEN MATRIX and a DUT matrix

integer fd; // file descriptor
int n_golden, m_golden; /// n  and that are read from golden.txt
logic [4:0] elements_count;  /// a temp that is counting the number of elements that are equal. Only if this number is N * M  the test is considered a success.
logic [15:0] golden_control_reg;  // control reg of the control
integer succ_count;  ///NUMBER SUCCESS OF TESTS 
integer test_index;  //test index 
logic [NUM_OF_TESTS -1:0] tests_indicators;  // A SUCCESS INDICATOR ARRAY OF TESTS

assign dut_results = intf.results_dut;


/////////////////functions and tasks/////////////////////////////////
task reset_global_signals();
	succ_count = 0;
	tests_indicators = 0;
	test_index = 0;
	elements_count = 0;
endtask

task compare_res_matrixes (results_matmul mat1, results_matmul mat2, int n, int m);
	/* This task compares 2 matrices - mat1 and mat2. 
	It does so by counting the number of elements that are equal. 
	it resets 'elements_count' and then counts the amount of element that are equal.
	*/
	int i,j;
	//logic[4:0] elements_count;
	elements_count = 0;   //// init elements_count which is the returned value
	$display("n:%d m: %d/n", n,m);
	$display("-------start of test %d-------\n", test_index);
	for(i = 0; i <= n; i++) begin
		for(j = 0; j <= m; j++) begin
			$display(" i = %d, j = %d\ngolden: %h | dut: %h \n",i,j ,mat1[i][j], mat2[i][j]);
			if(mat1[i][j] == mat2[i][j]) elements_count = elements_count + 1;   ///count equal elements
		end
	end
	$display("EQ elements %h \n", elements_count);
	///return elements_count;
endtask

task open_file(string golden_path); 
		fd = $fopen(golden_path, "r");
		if(fd == 0) $fatal(1, $sformatf("Failed to open %s", golden_path));
endtask

task read_one_goldenmat(integer fd);
	string topline, bottomline;
	if($fscanf(fd, "%s\n", topline) != 1)   //read the label '#control' that indicates of a new reslut matrix
      $fatal(1, "Failed to read the control line of golden.txt");
	if($fscanf(fd, "%d", golden_control_reg) != 1) ///read control register from golden model
      $fatal(1, "Failed to read the control register of golden.txt");
	
	n_golden = golden_control_reg[9:8];    /// read n value from control register.
	m_golden = golden_control_reg[13:12];  /// read m value from control register.
	for(int i=0; i<=n_golden; i++) begin   /// read results matrix values
		for(int j=0; j<=m_golden; j++) begin
			if($fscanf(fd, "%d", golden_results[i][j]) != 1) 
				$fatal(1, "Failed to read the goldenmat a at place [%d][%d]",i,j);
		end //end for
	end //end for
	
	if ($fscanf(fd, "%s\n", bottomline) != 1)  //throwing the end line
		$fatal(1, "Failed to read the END");	
endtask


////////////////////initials///////////////////////////////////////////

initial begin: main_initial
	reset_global_signals();   /// reset 
	wait(!intf.rst_n);		/// wait for DUT reset to finish
	@(posedge intf.rst_n);
	$display("Golden started after reset\n");
	open_file(golden_path);   ///open .txt file of the results (from golden model)
	$display("Golden file is opened\n");
	while (!$feof(fd)) begin   /// while there still result matrices in golden.txt file
		$display("Test index: %d  \n", test_index);
		$display("Teadfdsfsfsd %h  \n", intf.read_results_dut);
		wait(intf.read_results_dut);  /// indicates that the Stimulus is finished reading a result matrix from the DUT
		$display("DUT FINISHED READING A MATRIX \n");
		read_one_goldenmat(fd);  /// read one matix from golden.txt
		compare_res_matrixes(golden_results, dut_results, n_golden, m_golden);  /// compare then
		if (elements_count == (n_golden+1) * (m_golden+1)) begin  /// if all the elemnts of the 2 matrices are the equal
			succ_count += 1;					//count a success 
			tests_indicators[test_index] += 1;  // indicates a success test
			$display("Numb////er of success: %h and the test indicator is %h \n", succ_count, tests_indicators);
		end
		$display("/////end of test %d/////////\n\n\n", test_index);
		test_index +=1;
		wait(!intf.read_results_dut);
	end
	$display("Number of success: %h and the test indicator is %h \n", succ_count, tests_indicators);
end
endmodule