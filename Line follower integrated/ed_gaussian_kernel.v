/*--------------------------------------------------------------------------------------------------
Smoothing Gaussian kernel:

This module is intended to be used as the smoothing kernel is an edge detection filter. It
takes in 3 pixels, which are stogrey in a 3x5 buffer. The filter is then applied to the 1st, 3rd, and
5th pixels in the buffer.

If the current pixel is at an edge, the corresponding edge pixels are set to 0.

Author: Taj Wedutenko
--------------------------------------------------------------------------------------------------*/

module ed_gaussian_kernel
(
	input clk, 
	input at_left,
	input at_right,
	input at_top,
	input at_bottom,
	input [11:0] top_line_in, 
	input [11:0] mid_line_in, 
	input [11:0] bot_line_in, 
	output [11:0] out
);
/*--------------------------------------------------------------------------------------------------
Variable declaration
--------------------------------------------------------------------------------------------------*/

//-Buffer related variables-------------------------------------------------------------------------			 
reg [11:0] top_line[2:0], mid_line[2:0], bot_line[2:0];
integer i;

//-Filter related variables-------------------------------------------------------------------------
integer red[8:0], green[8:0], blue[8:0];
integer red_total, green_total, blue_total;

/*--------------------------------------------------------------------------------------------------
Filtering
--------------------------------------------------------------------------------------------------*/

always@(posedge clk)
begin	
	// Shift values
	begin
		for (i=1;i<3;i=i+1)
		begin
			top_line[i] = top_line[i-1];
			mid_line[i] = mid_line[i-1];
			bot_line[i] = bot_line[i-1];
		end
	end
	
	// Input data into buffer
	begin 
		top_line[0] = top_line_in[11:0];
		mid_line[0] = mid_line_in[11:0];
		bot_line[0] = bot_line_in[11:0];
	end
	
	// Set edge pixels to 0 if necessary
	begin
		if (at_left)
		begin
			top_line[2] = 12'b0;
			mid_line[2] = 12'b0;
			bot_line[2] = 12'b0;
		end
		
		if (at_right)
		begin
			top_line[0] = 12'b0;
			mid_line[0] = 12'b0;
			bot_line[0] = 12'b0;
		end
		
		if (at_top)
		begin
			top_line[0] = 12'b0;
			top_line[1] = 12'b0;
			top_line[2] = 12'b0;
		end
		
		if (at_bottom)
		begin
			bot_line[0] = 12'b0;
			bot_line[1] = 12'b0;
			bot_line[2] = 12'b0;
		end
	end


	// Read pixels in 
	begin
		red[8] 	= 1*top_line[0][11:8];
		red[7] 	= 2*top_line[1][11:8];			
		red[6] 	= 1*top_line[2][11:8];			
		red[5] 	= 2*mid_line[0][11:8];			
		red[4] 	= 4*mid_line[1][11:8];
		red[3] 	= 2*mid_line[2][11:8];			
		red[2] 	= 1*bot_line[0][11:8];			
		red[1] 	= 2*bot_line[1][11:8];			
		red[0] 	= 1*bot_line[2][11:8];	

		green[8] = 1*top_line[0][7:4];
		green[7] = 2*top_line[1][7:4];			
		green[6] = 1*top_line[2][7:4];			
		green[5] = 2*mid_line[0][7:4];			
		green[4] = 4*mid_line[1][7:4];
		green[3] = 2*mid_line[2][7:4];			
		green[2] = 1*bot_line[0][7:4];			
		green[1] = 2*bot_line[1][7:4];			
		green[0] = 1*bot_line[2][7:4];

		blue[8] 	= 1*top_line[0][3:0];
		blue[7] 	= 2*top_line[1][3:0];			
		blue[6] 	= 1*top_line[2][3:0];			
		blue[5] 	= 2*mid_line[0][3:0];			
		blue[4] 	= 4*mid_line[1][3:0];
		blue[3] 	= 2*mid_line[2][3:0];			
		blue[2] 	= 1*bot_line[0][3:0];			
		blue[1] 	= 2*bot_line[1][3:0];			
		blue[0] 	= 1*bot_line[2][3:0];	

	end
end

/*--------------------------------------------------------------------------------------------------
Pixel summation
--------------------------------------------------------------------------------------------------*/

always@(*)
begin
	// Sum totals
	red_total 	= red[0] 	+ red[1] 	+ red[2] 	+ red[3] 	+ red[4] 	+ red[5] 	+ red[6] 	+ red[7] 	+ red[8];
	green_total = green[0] 	+ green[1] 	+ green[2] 	+ green[3] 	+ green[4] 	+ green[5] 	+ green[6] 	+ green[7] 	+ green[8];
	blue_total 	= blue[0] 	+ blue[1] 	+ blue[2] 	+ blue[3] 	+ blue[4] 	+ blue[5] 	+ blue[6] 	+ blue[7] 	+ blue[8];
	
	// Divide by 16
	red_total 	= red_total 	>> 4;
	green_total = green_total 	>> 4;
	blue_total 	= blue_total 	>> 4;

	// Account for out of bounds values
	red_total 	= red_total 	> 255	? 255 : red_total;
	red_total 	= red_total 	< 0	? 0	: red_total;	
	
	green_total = green_total 	> 255	? 255 : green_total;
	green_total = green_total 	< 0	? 0	: green_total;	
	
	blue_total 	= blue_total 	> 255	? 255 : blue_total;
	blue_total 	= blue_total 	< 0	? 0	: blue_total;

	
end

/*--------------------------------------------------------------------------------------------------
Output assignment
--------------------------------------------------------------------------------------------------*/

assign out = {red_total[3:0], green_total[3:0], blue_total[3:0]};
				 
endmodule
