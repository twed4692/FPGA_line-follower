// This testbench will exercise uart_rx module.
// It checks correct functionality by writing a byte to the serial and checking the driveCMD
//	outputs the correct command based on the byte written
`timescale 1ns/10ps
 
module uart_tb ();
 

	parameter c_CLOCK_PERIOD_NS = 20;
	parameter c_CLKS_PER_BIT    = 5208;
	parameter c_BIT_PERIOD      = 104167;
   
	reg r_Clock = 0;
	reg r_Tx_DV = 0;
	wire w_Tx_Done;
	reg [7:0] r_Tx_Byte = 0;
	reg r_Rx_Serial = 1;
	wire [7:0] w_Rx_Byte;
	wire [1:0] myDriveCMD;
   
 
  // Takes in input byte and serializes it 
task UART_WRITE_BYTE;
	input [7:0] i_Data;
	integer     ii;
	begin
       
	// Send Start Bit
	r_Rx_Serial <= 1'b0;
	#(c_BIT_PERIOD);
	#1000;
       
       
	// Send Data Byte
	for (ii=0; ii<8; ii=ii+1)
	  begin
		 r_Rx_Serial <= i_Data[ii];
		 #(c_BIT_PERIOD);
	  end
       
      // Send Stop Bit
      r_Rx_Serial <= 1'b1;
      #(c_BIT_PERIOD);
     end
  endtask // UART_WRITE_BYTE
   
   
  uart_rx #(.CLKS_PER_BIT(c_CLKS_PER_BIT)) UART_RX_INST
    (.i_Clock(r_Clock),
     .i_Rx_Serial(r_Rx_Serial),
     .o_Rx_DV(),
     .o_Rx_Byte(w_Rx_Byte),
	  .o_DriveCMD(myDriveCMD)
     );
   
   
  always
    #(c_CLOCK_PERIOD_NS/2) r_Clock <= !r_Clock;
 
  // Main Testing:
  initial
    begin
       
      // Send a command to the UART (exercise Rx)
      @(posedge r_Clock);
		//simulate a Drive command (either 48, 49 or 50)
      UART_WRITE_BYTE(8'd50);
      @(posedge r_Clock);
             
      // Check that the correct drive command was received (correspondoing to the appropriate drive command)
      if (myDriveCMD == 2'd2)
        $display("Test Passed - Correct Byte Received");
      else
        $display("Test Failed - Incorrect Byte Received");
       
    end
   
endmodule
