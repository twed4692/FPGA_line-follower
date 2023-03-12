/*--------------------------------------------------------------------------------------------------
Edge detection generic buffer:

This module is intended to be used as a generic line buffer in an edge detection filter. It takes
data input in the form of a 24-bit RGB pixel. 

Each time a new pixel is provided, all pixels in the  buffer are shifted over by 1 and the new 
pixel is placed at the start of the buffer. 

Author: Taj Wedutenko
--------------------------------------------------------------------------------------------------*/
module ed_generic_buffer
(
	input clk, 
	input enable,
	input [11:0] data_in, 
	output [11:0] out
);

/*--------------------------------------------------------------------------------------------------
Variable declaration
--------------------------------------------------------------------------------------------------*/

//-Horizontal image size----------------------------------------------------------------------------
parameter h_size = 320;

//-Buffer related variables-------------------------------------------------------------------------
reg [11:0] shiftRegister[319:0];
integer i;

//-Output related variables-------------------------------------------------------------------------
reg [11:0] 	data_out;	

/*--------------------------------------------------------------------------------------------------
Buffering
--------------------------------------------------------------------------------------------------*/
							
always@(posedge clk)
begin
	// Shift all data over by 1
	if (enable)
	begin
		begin
			for (i = 1; i < h_size; i = i+1) 
			begin
				shiftRegister[i] <= shiftRegister[i-1];
			end
		end
		// Read input data into buffer and set output
		begin
			shiftRegister[0] <= data_in;
			data_out <= shiftRegister[319];
		end
	end
end

/*--------------------------------------------------------------------------------------------------
Output assignment
--------------------------------------------------------------------------------------------------*/

assign out = data_out;  

endmodule
