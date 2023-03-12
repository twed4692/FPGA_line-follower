//--------------overarching PID controller------------------

module controller(input clk, input [15:0] centroid, input [7:0] speed, output [15:0] pulse_L, output [15:0] pulse_R, input reverse);

reg [15:0] error;
reg [15:0] adjustment;
wire [15:0] P, I, D;
reg [15:0] speed_R, speed_L, out_R, out_L;
reg [15:0] max;
reg direction;
parameter base_pulse = 16'd10000;
parameter target = 8'd159;

proportional _proportional(.clk(clk), .error(error), .P(P));
integral _integral(.clk(clk), .error(error), .I(I));
derivative _derivative(.clk(clk), .error(error), .D(D));

always @ (posedge clk) begin

	if (centroid < target) begin
		error = target - centroid;
		direction = 0;		//left
	end
	else begin
		error = centroid - target;
		direction = 1;		// right
	end	
		
	adjustment = P + I + D;				// adjustment based on proportional, integral, derivative gains
	
	if (direction == 0) begin			// if centroid is to the left, increase right wheel speed to turn that way
		speed_R = speed + adjustment;
		speed_L = speed - adjustment;
	end
	else begin
		speed_R = speed - adjustment;		// left wheel go vroom if centroid is to right
		speed_L = speed + adjustment;
	end
	
	if (!reverse) begin				// adjustment is applied the oppostite way is we are reversing
		out_R = speed_R;
		out_L = speed_L;
	end
	else begin
		out_R = speed_L;
		out_L = speed_R;
	end
	
	
	speed_R = speed_R < 16'd0 ? 16'd0 : speed_R;		//overflow and underflow detection
	speed_R = speed_R > 16'd100 ? 16'd100 : speed_R;
	
	
	speed_L = speed_L < 16'd0 ? 16'd0 : speed_L;
	speed_L = speed_L > 16'd100 ? 16'd100 : speed_L;		
end

assign pulse_R = base_pulse + 500*out_R;			// one unit of speed is equivalent to a 500 count pulse
assign pulse_L = base_pulse + 500*out_L;			// ie 50000000/500 = 0.01ms 
	
endmodule


//--------------proportional controller------------------
module proportional(input clk, input [15:0] error, output [15:0] P);

integer KP, adjustment_P;

initial begin		// KP is actually 1/Kp, we divide and store as an 
	KP <= 4; 	// integer to avoid having floating point numbers
end			// (hence larger KP => smaller gain)
			
always @ (posedge clk) begin
	
	adjustment_P <= error/KP;
end

assign P = adjustment_P;
	
endmodule

//--------------integral controller------------------
// unlike the D controller, this could be useful, but turns out we didnt
// need it so KI = 0 for now. Operates on the same principle that
// the variable KI is actually 1/Ki the actual gain to keep in integers

// keep in mind, something would need to be added to account for anti-reset
// windup, probably by pausing the counter when no centroid is detected
module integral(input clk, input [15:0] error, output [15:0] I);

integer KI, adjustment_I, sum_error, last_error;

initial begin
	KI <= 0;
	sum_error <= 0;
	last_error <= 0;
end

always @ (posedge clk) begin
	sum_error <= sum_error + (error-last_error)/2;		
	adjustment_I <= sum_error/KI;
	last_error <= error;		
end

assign I = adjustment_I;

endmodule

//--------------derivative controller------------------
// this should probably not be used (hence why Kd = 0), but has been
// left in just in case 
module derivative(input clk, input [15:0] error, output [15:0] D);

integer KD, adjustment_D, last_error;

initial begin
	KD <= 0;
	last_error <= 0;
end

always @ (posedge clk) begin
	
	adjustment_D <= (error-last_error)/KD;
	last_error <= error;			
end

assign D = adjustment_D;

endmodule
