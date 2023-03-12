// This testbench will exercise the PWM module with a different speeds 
`timescale 1ns/10ps
 
module PWM_tb ();

//initalise variables
reg r_Clock = 0;
reg [15:0] i_speed;
wire o_PWM;
wire [17:0] o_LED; 
 
   
//Instatiae a PWM module for testing
PWM DUT(.CLOCK50(r_Clock),
			.speed(i_speed), 
			.PWM_out(o_PWM), 
			.LED(o_LED)
			);
 
 
// Create a mock clock cycle
initial
begin
	forever #100 r_Clock = ~r_Clock;
end

// Change the speeds and hold them for a constant time
initial
	begin
	i_speed = 1000; 
	#10000
	i_speed = 1000;
	#10000
	i_speed = 10000; 
	#10000
	i_speed = 100000; 
	end
endmodule

   

