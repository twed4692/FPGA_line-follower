module PWM(input CLOCK50, input [15:0] speed, output PWM_out, output [17:0] LED);

integer counter;
parameter freq = 23'd1000000;		// 50 Hz PWM frequency

initial
begin
	counter = 0;
end

always@(posedge CLOCK50) begin
	
	if (counter < freq)			// counter runs for duration of one 10 kHz period
		counter <= counter + 1;
	else counter <= 0;
end

assign PWM_out = (counter < speed) ? 1:0;		// if inside pulse width, output high to motor

assign LED = speed;

endmodule