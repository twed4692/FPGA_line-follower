/*--------------------------------------------------------------------------------------------------
Edge detection first buffer:

This module is intended to be used as the first line buffer in an edge detection filter. It takes
data input in the form of a 24-bit RGB pixel. 

Each time a new pixel is provided, all pixels in the  buffer are shifted over by 1 and the new 
pixel is placed at the start of the buffer. Before being placed, the new pixel is also converted
to greyscale. Since all buffers derive input from this buffer, all buffers will contain greyscale
values.

The buffer also keeps count of the current pixel's horizontal and vertical position; this is used
to determine whether buffers are full, if we are at an edge, or if a frame is completed.

Author: Taj Wedutenko
--------------------------------------------------------------------------------------------------*/

module ed_first_buffer
(
	input clk, 
	input reset, 
	input enable,
	input [11:0] data_in, 
	output [11:0] out, 
	output [8:0] h_pos,
	output [7:0] v_pos
);

/*--------------------------------------------------------------------------------------------------
Variable declaration
--------------------------------------------------------------------------------------------------*/

//-Horizontal image size----------------------------------------------------------------------------
parameter h_size = 9'd320;

//-Horizontal, vertical counters--------------------------------------------------------------------
reg [8:0] h_count;
reg [7:0] v_count;

//-Buffer related variables-------------------------------------------------------------------------
reg [11:0] shiftRegister[319:0];
reg [11:0] greyscale_pix;
integer  i;

//-Output related variables-------------------------------------------------------------------------
reg [11:0] data_out;			

/*--------------------------------------------------------------------------------------------------
Buffering
--------------------------------------------------------------------------------------------------*/

always@(posedge clk)
begin
	// Reset values to default, called at each new frame
	if(reset)
	begin
		h_count				<= 0;	// Start at column 0 as column 1 is reached on first call
		v_count 				<= 1;	// Start at row 1
		data_out 			<= 12'hx;
	end
	
	// Perform buffering as usual
	else if (enable)
	begin
		// Shift all data over by 1, increment horizontal counter
		begin
			h_count = h_count + 9'd1;
			for (i=1; i < h_size; i = i+1) 
			begin
				shiftRegister[i] = shiftRegister[i-1];
			end
		end
		
		// Determine if at newline, perform greyscale conversion
		begin
			// If exceeded horizontal max, at newline
			if (h_count > h_size) 
			begin
				h_count = 9'd1;
				v_count = v_count + 8'd1;
			end
			
			// Convert input pixel to greyscale
			//greyscale_pix = (data_in[11:8]+data_in[7:4]+data_in[3:0])/3;
		end
		
		// Read input data into buffer and set output
		begin
			shiftRegister[0] = data_in;
			data_out = shiftRegister[319];
		end
	end
end

/*--------------------------------------------------------------------------------------------------
Output assignment
--------------------------------------------------------------------------------------------------*/

assign out = data_out;  
assign h_pos = h_count;
assign v_pos = v_count;

endmodule
