/*--------------------------------------------------------------------------------------------------
Edge detection top level filter:

This module is a top level binarisation filter that takes data in the form of an RGB pixel and 
binarises it after applying a Gaussian blur.

Author: Taj Wedutenko
--------------------------------------------------------------------------------------------------*/
module ed_binarisation_filter
(
	input clk,
	input waiting_for_new_frame,
	input enable,
	input [11:0] data_in,
	output frame_done,
	output wr_enable,
	output [16:0] read_addr,
	output [16:0] write_addr,
	output [11:0] data_out,
	output [9:0] h_centroid,
	output stop_detect,
	output [17:0] stop_sum
);

/*--------------------------------------------------------------------------------------------------
Variable declaration
--------------------------------------------------------------------------------------------------*/

//-Buffer related variables-------------------------------------------------------------------------
wire [11:0] buffer_out1, buffer_out2, buffer_out3;
wire [8:0]	h_in_pos;
wire [7:0]	v_in_pos;

//-Address related variables------------------------------------------------------------------------
parameter h_max = 9'd320;
parameter v_max = 8'd240;

reg [8:0] h_out_pos;
reg [7:0] v_out_pos;

//-Edge related variables---------------------------------------------------------------------------
wire at_left_smooth;
wire at_right_smooth;
wire at_top_smooth;
wire at_bottom_smooth;

reg at_left_smooth_reg;
reg at_right_smooth_reg;
reg at_top_smooth_reg;
reg at_bottom_smooth_reg;

//-Centroid related variables-----------------------------------------------------------------------
integer h_sum;
integer pix_count;

integer h_centroid_reg;

//-Stop related variables---------------------------------------------------------------------------
parameter r_threshold = 3000;
integer r_sum;

reg stop_detect_reg;

//-Output related variables-------------------------------------------------------------------------
wire [11:0] image_out;
wire started_filter;

reg started_filter_reg;
reg wr_enable_reg;
reg frame_done_reg;
reg [11:0] 	data_out_reg;
reg [16:0]	read_addr_reg;
reg [16:0]	write_addr_reg;

/*--------------------------------------------------------------------------------------------------
Output value determination
--------------------------------------------------------------------------------------------------*/

always@(posedge clk)
begin
// If waiting for a new frame, reset values
	
	if (waiting_for_new_frame)
	begin
		
		started_filter_reg = 1'b0;
		wr_enable_reg	= 1'b0;
		read_addr_reg	= 17'b0;
		write_addr_reg	= 17'b0;
		frame_done_reg	= 1'b0;
		h_sum = 0;
		pix_count = 0;
		r_sum = 0;
		data_out_reg	= 12'hx;
	end
	

	// Only start filtering when we have received a synchronised enable signal
	if (enable || started_filter_reg)
	begin
		
		started_filter_reg = 1'b1;
		
		// We are ready to start filtering if our data_in position is >= to v3,h640, as this 
		// corresponds to a data_out position >= to v1,h1
		if ((v_in_pos == 8'd2 && h_in_pos == h_max) || v_in_pos >= 8'd3)
		begin
			// Determine data_out position
			h_out_pos = h_in_pos;// <= 9'd19 ? 8'd320-h_in_pos : h_in_pos - 9'd19;
			v_out_pos = v_in_pos;// <= 9'd19 ? v_in_pos - 8'd1 : v_in_pos - 8'd2;
			
			// Determine edge cases
			at_left_smooth_reg 	= h_out_pos == 9'd1 	? 1'b1 : 1'b0;
			at_right_smooth_reg 	= h_out_pos == h_max ? 1'b1 : 1'b0;
			at_top_smooth_reg		= v_out_pos == 8'd1	? 1'b1 : 1'b0;
			at_bottom_smooth_reg	= v_out_pos == v_max	? 1'b1 : 1'b0;
			
			// Output data, determine read/write address value and if frame finished
			wr_enable_reg	= 1'b1;	
			
			// Yellow, red, black
			
			// Yellow -> ~ R:14-15 G:13-14 B:7-8
			if (image_out[11:8] > 9 && image_out[7:4] > 8 && image_out[3:0] > 4)
			begin
				data_out_reg = {{8{1'b1}}, {4{1'b0}}};
				h_sum = h_sum + h_out_pos;
				pix_count = pix_count + 1;
			end
			
			// Red -> R:13-14 G:8-9 B:5-6
			else if (image_out[11:8] > 10 && image_out[7:4] < 10)
			begin
				data_out_reg = {{4{1'b1}}, {8{1'b0}}};
				r_sum = r_sum + 1;
			end
			
			// Background -> R:6-8 G:7-8 B:4-5
			else 
			begin
				data_out_reg = {12{1'b0}};
			end

			
			
			// 
//			data_out_reg	= (image_out[11:8] > 10) ? {12{1'b1}} : {12{1'b0}};
			
			write_addr_reg = (v_out_pos-8'd1)*h_max + h_out_pos;	
			read_addr_reg	= (v_in_pos-8'd1)*h_max + h_in_pos;
			
			// Check if frame is done
			if ((h_out_pos == h_max && v_out_pos == v_max) || v_out_pos > v_max)
			begin
				frame_done_reg = 1'b1;
				h_centroid_reg = pix_count > 0 ? (h_sum / pix_count) : 0;
				stop_detect_reg = r_sum > r_threshold ? 1'b1 : 1'b0;
			end
			
			else
			begin
				frame_done_reg = 1'b0;
			end			
		end

		// Otherwise, not ready to start filtering
		else 
		begin
			wr_enable_reg	= 1'b0;
			frame_done_reg = 1'b0;
			read_addr_reg	= (v_in_pos-8'd1)*h_max + h_in_pos;
			write_addr_reg	= 17'b0;
			data_out_reg 	= 12'hx;
		end
	end
end

/*--------------------------------------------------------------------------------------------------
Output assignment
--------------------------------------------------------------------------------------------------*/

assign at_left_smooth 	= at_left_smooth_reg;
assign at_right_smooth 	= at_right_smooth_reg;
assign at_top_smooth 	= at_top_smooth_reg;
assign at_bottom_smooth = at_bottom_smooth_reg;

assign started_filter = started_filter_reg;

assign wr_enable	= wr_enable_reg;
assign write_addr = write_addr_reg[16:0];
assign read_addr  = read_addr_reg[16:0];
assign frame_done = frame_done_reg;

assign h_centroid = h_centroid_reg[9:0];

assign data_out 	= data_out_reg[11:0];

assign stop_sum = r_sum[17:0];

assign stop_detect = stop_detect_reg;

/*--------------------------------------------------------------------------------------------------
Module instantiation
--------------------------------------------------------------------------------------------------*/

//-First buffer-------------------------------------------------------------------------------------
ed_first_buffer Inst_line1
(
	.clk(clk), 
	.reset(waiting_for_new_frame),
	.enable(started_filter),
	.data_in(data_in[11:0]), 
	.out(buffer_out1), 
	.h_pos(h_in_pos),
	.v_pos(v_in_pos)
);

//-Smoothing buffers--------------------------------------------------------------------------------
ed_generic_buffer Inst_line2 (.clk(clk), .data_in(buffer_out1), .out(buffer_out2), .enable(started_filter));
ed_generic_buffer Inst_line3 (.clk(clk), .data_in(buffer_out2), .out(buffer_out3), .enable(started_filter));

//-Smoothing kernel---------------------------------------------------------------------------------
ed_gaussian_kernel Inst_ed_gaus_kernel
(
	.clk(clk),
	.at_left(at_left_smooth),
	.at_right(at_right_smooth),
	.at_top(at_top_smooth),
	.at_bottom(at_bottom_smooth),
	.bot_line_in(buffer_out1), 
	.mid_line_in(buffer_out2), 
	.top_line_in(buffer_out3), 
	.out(image_out[11:0])
);


endmodule