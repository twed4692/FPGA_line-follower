// File digital_cam_impl1/top_level.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
// vhd2vl settings:
//  * Verilog Module Declaration Style: 2001

// vhd2vl is Free (libre) Software:
//   Copyright (C) 2001 Vincenzo Liguori - Ocean Logic Pty Ltd
//     http://www.ocean-logic.com
//   Modifications Copyright (C) 2006 Mark Gonzales - PMC Sierra Inc
//   Modifications (C) 2010 Shankar Giri
//   Modifications Copyright (C) 2002-2017 Larry Doolittle
//     http://doolittle.icarus.com/~larry/vhd2vl/
//   Modifications (C) 2017 Rodrigo A. Melo
//
//   vhd2vl comes with ABSOLUTELY NO WARRANTY.  Always check the resulting
//   Verilog for correctness, ideally with a formal verification tool.
//
//   You are welcome to redistribute vhd2vl under certain conditions.
//   See the license (GPLv2) file included with the source for details.

// The result of translation follows.  Its copyright status should be
// considered unchanged from the original VHDL.

// cristinel ababei; Jan.29.2015; CopyLeft (CL);
// code name: "digital cam implementation #1";
// project done using Quartus II 13.1 and tested on DE2-115;
//
// this design basically connects a CMOS camera (OV7670 module) to
// DE2-115 board; video frames are picked up from camera, buffered
// on the FPGA (using embedded RAM), and displayed on the VGA monitor,
// which is also connected to the board; clock signals generated
// inside FPGA using ALTPLL's that take as input the board's 50MHz signal
// from on-board oscillator; 
//
// this whole project is an adaptation of Mike Field's original implementation 
// that can be found here:
// http://hamsterworks.co.nz/mediawiki/index.php/OV7670_camera
// no timescale needed

module line_follower
(
	input wire clk_50,
	input wire btn_resend,
	output wire vga_hsync,
	output wire vga_vsync,
	output wire [7:0] vga_r,
	output wire [7:0] vga_g,
	output wire [7:0] vga_b,
	output wire vga_blank_N,
	output wire vga_sync_N,
	output wire vga_CLK,
	input wire ov7670_pclk,
	output wire ov7670_xclk,
	input wire ov7670_vsync,
	input wire ov7670_href,
	input wire [7:0] ov7670_data,
	output wire ov7670_sioc,
	inout wire ov7670_siod,
	output wire ov7670_pwdn,
	output wire ov7670_reset,
	
	output wire [17:0] LEDR,
	output wire [8:1] LEDG,
	
	// LCD related
	inout [7:0] LCD_DATA,
	output LCD_EN,
	output LCD_ON,
	output LCD_BLON,
	output LCD_RS,
	output LCD_RW,
	
	// Motor related
	output [9:2] GPIO,
	
	// Wifi related
	input [1:0]	UART

);

/*--------------------------------------------------------------------------------------------------
Variable declaration
--------------------------------------------------------------------------------------------------*/

//-Clock related------------------------------------------------------------------------------------
wire clk_50_camera;
wire clk_25_vga;
wire reset;		// Reset held active for a short period at beginning to initialise variables

//-Buffer 1 related variables-----------------------------------------------------------------------
wire wren_buf1;
wire [16:0] wraddress_buf1;
wire [11:0] wrdata_buf1;
wire [16:0] rdaddress_buf1;
wire [11:0] rddata_buf1;

reg wren_buf1_reg;
reg [16:0] rdaddress_buf1_reg;

//-Buffer 2 related variables-----------------------------------------------------------------------
wire wren_buf2;
wire [16:0] wraddress_buf2;
wire [11:0] wrdata_buf2;
wire [16:0] rdaddress_buf2;
wire [11:0] rddata_buf2;

reg wren_buf2_reg;
reg [16:0] rdaddress_buf2_reg;

//-Multiplexed buffer related variables-------------------------------------------------------------
wire [16:0] rdaddress_buf12_from_addr_gen;
wire [16:0] rdaddress_buf1_from_do_ED;
wire [16:0] rdaddress_buf2_from_cent;

wire wren_buf1_from_ov7670_capture;
wire wren_buf2_from_do_ED;

//-Camera related-----------------------------------------------------------------------------------
wire done_capture_new_frame;

//-Edge detection related---------------------------------------------------------------------------
wire enable_filter_synchronised;
wire waiting_frame_edge;
wire done_filter_new_frame;
wire enable_filter;

reg enable_filter_reg;
reg waiting_frame_edge_reg;

//-RGB----------------------------------------------------------------------------------------------
wire resend;
wire [11:0] data_to_rgb;
wire nBlank;
wire vSync;
wire [7:0] red; wire [7:0] green; wire [7:0] blue;
wire activeArea;

reg [11:0] data_to_rgb_reg;

//-State related variables--------------------------------------------------------------------------
reg [2:0] state;

//-LCD related variables----------------------------------------------------------------------------
wire [8:0] h_test;
wire [7:0] v_test;

reg [8:0] h_test_reg;
reg [7:0] v_test_reg;

//-Centroid related variables-----------------------------------------------------------------------
wire [9:0] h_centroid;

wire done_cent_new_frame;
wire waiting_frame_cent;
reg waiting_frame_cent_reg;

wire stop_detect;

//-Motor controller related variables---------------------------------------------------------------
wire [15:0] pulse_R;
wire [15:0] pulse_L;
wire [15:0] reverse_R;
wire [15:0] reverse_L;
wire [17:0] void;
parameter speed = 8'd50;

//-Wifi variables-----------------------------------------------------------------------------------
wire [7:0] Rx_DV, Rx_Byte; 	// change the [] if this is a different size
wire [1:0] myDriveCMD;

wire stop;
wire resume;
wire reverse;


parameter resume_dly = 25'd25000000;
reg [24:0] resume_count;
reg resume_wait_done;
reg resume_ready;
reg dly_restart;
reg resume_prev;
reg reverse_prev;
reg resume_wait;
reg stop_mux_reg;
wire stop_mux;

/*--------------------------------------------------------------------------------------------------
State machine cycle
--------------------------------------------------------------------------------------------------*/

always@(posedge clk_25_vga)
begin
	if (!reset)
	begin
		enable_filter_reg <= 1'b0;
		state 				<= 3'd0;
	end
	
	else
	begin
		
		case (state)
		
		// Frame capture from camera
		0:
		begin
			// Only move to next state if we have captured a whole new frame
			if (done_capture_new_frame)
			begin
				state <= 3'd1;
			end
			
			data_to_rgb_reg <= rddata_buf2;
			
			enable_filter_reg <= 1'b0;
			waiting_frame_edge_reg <= 1'b1; // Edge detection reset signal
			waiting_frame_cent_reg <= 1'b1;
			
			// Buffer 1 signals
			wren_buf1_reg 		<= wren_buf1_from_ov7670_capture;
			rdaddress_buf1_reg<= rdaddress_buf12_from_addr_gen[16:0];
			
			// Buffer 2 signals
			wren_buf2_reg 		<= 1'b0;	// Disabled
			rdaddress_buf2_reg<= rdaddress_buf12_from_addr_gen[16:0];
			
		end
		
		// Edge detection reset
		1:
		begin
			state <= 3'd2;
			
			data_to_rgb_reg <= rddata_buf2;
			
			enable_filter_reg <= 1'b0;
			waiting_frame_edge_reg <= 1'b1;
			waiting_frame_cent_reg <= 1'b1;
			
			// Buffer 1 signals
			wren_buf1_reg <= 1'b0;
			rdaddress_buf1_reg<= rdaddress_buf1_from_do_ED[16:0];
			
			// Buffer 2 signals
			wren_buf2_reg <= 1'b0;
			rdaddress_buf2_reg<= rdaddress_buf12_from_addr_gen[16:0];
		end
		
		// Binarisation and centroid finding
		2:
		begin
			// Only move to next state if we have filtered a whole frame
			if (done_filter_new_frame)
			begin
				state <= 3'd0;
			end
			
			data_to_rgb_reg <= rddata_buf2;
			
			enable_filter_reg <= 1'b1;
			waiting_frame_edge_reg <= 1'b0;
			waiting_frame_cent_reg <= 1'b1;
			
			// Buffer 1 signals
			wren_buf1_reg 		<= 1'b0;	// Disabled
			rdaddress_buf1_reg<= rdaddress_buf1_from_do_ED[16:0];
			
			// Buffer 2 signals
			wren_buf2_reg 		<= wren_buf2_from_do_ED;
			rdaddress_buf2_reg<= rdaddress_buf12_from_addr_gen[16:0];
		end		
		endcase
	end
end	

/*--------------------------------------------------------------------------------------------------
Resume delay - in order to stop on red after resuming, need to trigger a posedge on resume (IR/WiFi
signal) after exiting red in order to set resume_ready to 0.
--------------------------------------------------------------------------------------------------*/

initial
begin
	resume_count <= 0;
	resume_wait_done <= 0;
	resume_ready <= 0;
end

// Delay to allow line follower to resume after detecting red
always@(posedge clk_25_vga)
begin
	// Restart the counter if we have waited sufficient time to leave red line ( 1 s delay)
	if (resume_count >= resume_dly)
	begin
		resume_count <= 0;
		resume_ready <= 0;
	end
	
	// Only start counting if we are at a rising edge on resume or reverse, i.e. receive a new command
	// AND we are stopped at a red line
	else if (((resume && !resume_prev) || (reverse && !reverse_prev)) && stop_detect)
	begin
		resume_count <= 1;
		resume_wait <= 1;
	end
	
	// If we have started counting, continue
	else if (resume_count > 0)
	begin
		resume_count <= resume_count + 1;
		resume_wait <= 1;
	end
end

// Store the previous value of resume and reverse to determine a rising edge
always@(negedge clk_25_vga)
begin
	resume_prev <= resume;
	reverse_prev <= reverse;
end
		
// Stop multiplex
always@(posedge clk_25_vga)
begin

	// User controlled stop takes precedent
	if (stop)
	begin 
		stop_mux_reg <= 1;
	end
	
	// 
	else if (resume_ready)
	begin
		stop_mux_reg <= 0;
	end
	
	else if (stop_detect)
	begin 
		stop_mux_reg <= 1;
	end
	
	else
	begin
		stop_mux_reg <= 0;
	end
end


/*--------------------------------------------------------------------------------------------------
Output assignment
--------------------------------------------------------------------------------------------------*/

assign stop_mux = stop_mux_reg;

assign h_test = h_test_reg;

assign data_to_rgb = data_to_rgb_reg[11:0];

//assign LEDR[17:0] = h_centroid[17:0];

assign waiting_frame_edge = waiting_frame_edge_reg;
assign waiting_frame_cent = waiting_frame_cent_reg;

assign wren_buf1 = wren_buf1_reg;
assign rdaddress_buf1 = rdaddress_buf1_reg[16:0];

assign wren_buf2 = wren_buf2_reg;
assign rdaddress_buf2 = rdaddress_buf2_reg[16:0];

// Synchronise filtering with the start of a new frame, i.e. when vSync == 0
assign enable_filter = enable_filter_reg;
assign enable_filter_synchronised = enable_filter_reg && !vSync;

assign vga_r = red[7:0];
assign vga_g = green[7:0];
assign vga_b = blue[7:0];

// take the inverted push button because KEY0 on DE2-115 board generates
// a signal 111000111; with 1 with not pressed and 0 when pressed/pushed;
assign resend =  ~btn_resend;
assign vga_vsync = vSync;
assign vga_blank_N = nBlank;

// LCD related
assign h_test = h_test_reg;
assign v_test = v_test_reg;

assign LCD_ON   = 1'b1;   // Keep LCD on
assign LCD_BLON = 1'b0;   // Unimplemented

// Motor related
assign GPIO[9:8] = stop_mux ? 2'b00 : 2'b11; // EN_A, EN_B, HBR_A1, HBR_B1, HBR_A2, HBR_B2

assign GPIO[7:4] = reverse ? 4'b0011 : 4'b1100;

// Wifi
assign stop = myDriveCMD == 2 ? 1'b1 : 1'b0;
assign resume = myDriveCMD == 1 ? 1'b1 : 1'b0;
assign reverse = myDriveCMD == 0 ? 1'b1 : 1'b0;

assign LEDG[2:1] = myDriveCMD;

/*--------------------------------------------------------------------------------------------------
Module instantiation
--------------------------------------------------------------------------------------------------*/

//---------------------------------------------------------------------------------------
//-Reset delay--------------------------------------------------------------------------------------
Reset_Delay	Inst_reset_delay
(
	.iCLK(clk_50),
	.oRESET(reset)
);

//-Clock generation---------------------------------------------------------------------------------
my_altpll Inst_vga_pll
(
	.inclk0(clk_50),
	.c0(clk_50_camera),
	.c1(clk_25_vga)
);


//-VGA related--------------------------------------------------------------------------------------
VGA Inst_VGA
(
	.CLK25(clk_25_vga),
	.clkout(vga_CLK),
	.Hsync(vga_hsync),
	.Vsync(vSync),
	.Nblank(nBlank),
	.Nsync(vga_sync_N),
	.activeArea(activeArea)
);


//-Camera controller--------------------------------------------------------------------------------
ov7670_controller Inst_ov7670_controller
(
	.clk(clk_50_camera),
	.resend(resend),
	.config_finished(led_config_finished),
	.sioc(ov7670_sioc),
	.siod(ov7670_siod),
	.reset(ov7670_reset),
	.pwdn(ov7670_pwdn),
	.xclk(ov7670_xclk)
);

//-Camera capture-----------------------------------------------------------------------------------
ov7670_capture Inst_ov7670_capture
(
	.pclk(ov7670_pclk),
	.vsync(ov7670_vsync),
	.href(ov7670_href),
	.d(ov7670_data),
	.addr(wraddress_buf1),
	.dout(wrdata_buf1),
	.we(wren_buf1_from_ov7670_capture),
	.end_of_frame(done_capture_new_frame)
);

//-Camera frame buffer------------------------------------------------------------------------------
frame_buffer Inst_frame_buffer_1
(
	.rdaddress(rdaddress_buf1),
	.rdclock(clk_25_vga),
	.q(rddata_buf1),
	.wrclock(clk_25_vga),
	.wraddress(wraddress_buf1),
	.data(wrdata_buf1),
	.wren(wren_buf1)
);

//-Edge filter frame buffer-------------------------------------------------------------------------
frame_buffer Inst_frame_buffer_2
(
	.rdaddress(rdaddress_buf2),
	.rdclock(clk_25_vga),
	.q(rddata_buf2),
	.wrclock(clk_25_vga),
	.wraddress(wraddress_buf2),
	.data(wrdata_buf2),
	.wren(wren_buf2)
);


//-Edge detection filter----------------------------------------------------------------------------
ed_binarisation_filter Inst_ED_filter
(
	.clk(clk_25_vga),
	.waiting_for_new_frame(waiting_frame_edge),
	.enable(enable_filter_synchronised),
	.data_in(rddata_buf1),
	.frame_done(done_filter_new_frame),
	.wr_enable(wren_buf2_from_do_ED),
	.read_addr(rdaddress_buf1_from_do_ED),
	.write_addr(wraddress_buf2),
	.data_out(wrdata_buf2),
	.h_centroid(h_centroid),
	.stop_detect(stop_detect),
	.stop_sum(LEDR[17:0])
);


//-RGB related--------------------------------------------------------------------------------------
RGB Inst_RGB
(
	.Din(data_to_rgb),
	.Nblank(activeArea),
	.R(red),
	.G(green),
	.B(blue)
);

//-Address generator--------------------------------------------------------------------------------
Address_Generator Inst_Address_Generator
(
	.CLK25(clk_25_vga),
	.enable(activeArea),
	.vsync(vSync),
	.address(rdaddress_buf12_from_addr_gen)
);

//-LCD controller-----------------------------------------------------------------------------------
LCD_TEST Inst_LCD_TEST	
(
	.iCLK(clk_50_camera),
	.iRST_N(reset),
	.H_CENTROID(h_centroid),
	.LCD_DATA(LCD_DATA),
	.LCD_RW(LCD_RW),
	.LCD_EN(LCD_EN),
	.LCD_RS(LCD_RS)
);

//-PID controller-----------------------------------------------------------------------------------
controller Inst_controller 
(
	.clk(clk_50_camera),
	.centroid(h_centroid),
	.speed(speed),
	.pulse_L(pulse_L[15:0]),
	.pulse_R(pulse_R[15:0]),
	.reverse(reverse)
);

//-PWM motor controllers----------------------------------------------------------------------------
PWM Inst_motor_R		
(			
	.CLOCK50(clk_50_camera), 	
	.speed(pulse_R[15:0]),
	.PWM_out(GPIO[3]),
);

PWM Inst_motor_L		
(			
	.CLOCK50(clk_50_camera),  
	.speed(pulse_L[15:0]),
	.PWM_out(GPIO[2])
);

//-Serial communication-----------------------------------------------------------------------------
serial Inst_UART_rx 		
(			
	.i_Clock(clk_50_camera),
	.i_Rx_Serial(UART[0]), // and put in UART rx pn here too
	.o_Rx_DV(Rx_DV),
	.o_DriveCMD(myDriveCMD)
);


endmodule