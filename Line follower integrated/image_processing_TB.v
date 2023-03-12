/*
 * Image processing testbench template: passes the img_data.mif + img_index.mif source image into the test module 'MY_MODULE_NAME_HERE' as a pixel (24-bit RGB) datastream (1 pixel at a time).
 * Writes the ouput as a bitmap image located at “simulation\modelsim\filter_TB_output.bmp”, captured from the output pixel datastream over the period IMG_CAPTURE_START_TIME to IMG_CAPTURE_START_TIME+IMG_CAPTURE_DURATION.
 * You should add debug $display() statements. An example of how to print the (x,y) coordinates of an object to be detected by your module is supplied.
 */

// Macro statement that lets ModelSim know the precision for the simulation (each delay timestep will be 1 ns, e.g. #40 is 40 ns):
`timescale 1ns/1ps

module image_processing_TB();

    /*  
     *** TODO : Change the following values to the timestep when you would like the output to be captured as an image file and the duration of this capturing (set this to a full frame):
     */ 
    parameter IMG_CAPTURE_START_TIME = 100;
    parameter IMG_CAPTURE_DURATION = 15360000;
    /////////////////////////////////////////////////////////////////////////////////////////////////////


    // DUT signals to connect together:
    reg clk, reset;
	 reg enable = 1;
    reg [16:0] img_addr = 0;
    wire [23:0] pixel_data_in;
	 reg waiting_for_new_frame;
	 
	 wire [11:0] data_in;
	 
	 assign data_in = {pixel_data_in[23:20] , pixel_data_in[15:12] , pixel_data_in[7:4]};
	 
	 
    wire [23:0] pixel_data_out;
    wire detected = 0;
    wire [9:0] detect_x, detect_y;
	 
	 wire [9:0] centroid;
	 
	 wire frame_done;
	wire wr_enable;
	wire [16:0] read_addr;
	wire [16:0] write_addr;
	wire [11:0] data_out;
	wire stop_detect;
	wire [17:0] stop_sum;

    /*  
     *** TODO : Create any additional wire or reg variables that you desire to connect your module/s:
     */ 
    
	 
    /////////////////////////////////////////////////////////////////////////////////////////////////////


	// Instantiates the image SOURCE module to be tested (and 'wire' them together using the wires from above):
	wire [7:0] colour_index;
	img_data	#(.WIDTH(320), .HEIGHT(240))
						 img_data_inst (
						 .address ( img_addr ),
						 .clock ( ~clk ),
						 .q ( colour_index )
	             );
	img_index	    img_index_inst (
						 .address ( colour_index ),
						 .clock ( clk ),
						 .q ( pixel_data_in )
						 );	
	 
    /*
     *** TODO: Change "MY_MODULE_NAME_HERE" to the module that you use for detection. Change the port list to match the inputs and outputs that you use for your module:
     */ 
//    MY_MODULE_NAME_HERE DUT (.clk(clk), .reset(reset), .pixel_data_in(pixel_data_in), .pixel_data_out(pixel_data_out), .detected(detected), .detect_x(detect_x), .detect_y(detect_y));
    /////////////////////////////////////////////////////////////////////////////////////////////////////
	 ed_binarisation_filter DUT (.clk(clk), // done
											.waiting_for_new_frame(waiting_for_new_frame), // ?
											.enable(enable),  // ?
											.data_in(data_in), // ? (pixel size is different)
											.frame_done(frame_done), 
											.wr_enable(wr_enable), 
											.read_addr(read_addr), 
											.write_addr(write_addr), 
											.data_out(data_out),
											.h_centroid(centroid),
											.stop_detect(stop_detect),
											.stop_sum(stop_sum)
											);


    /*  
     *** TODO : Add instantiations (like the above) for any other relevant modules that you would like to test:
     */ 



    /////////////////////////////////////////////////////////////////////////////////////////////////////

    // The img_write module writes a WIDTHxHEIGHT-sized image "detection_output.bmp" into the simulation\modelsim directory.
    reg Write_Start = 0; // Signals the 'image_write' module to start capturing the output pixel datastream.
    reg Write_Done = 0;  // Signals the 'image_write' module to write an image file "detection_output.bmp" into the simulation\modelsim directory.
    image_write img_write (.clk(clk),.input_rgb(pixel_data_out),.addr(img_addr),.Write_Start(Write_Start),.Write_Done(Write_Done));

	 // Clock initial block:
    initial  
    begin 
    clk = 0; 
    forever #10 clk = ~clk; // 50MHz --> clock period T = 20 ns (so 10 ns half-period)
    end 

	 // Reset initial block:
    initial 
    begin 
    reset = 0; 
    #200 reset = 1;  // 10 clock cycles: (20)*10 // Active Low Reset delay
    $display("Time=%0t: Reset inactivated", $time);
    end

    // Increment the image address (row-major order) to progress the input pixel datastream:
    always @(posedge clk) img_addr <= (img_addr+1)%(320*240);

    // Print debug statements: //TODO add your own debugs!
    always @(posedge clk)
    begin
        if (detected)
        begin
            $display("Time=%0t: Object is detected at x=%d, y=%d", $time, detect_x, detect_y);
        end
    end

	 // File Writing ***You will want to change these timings (see top of this file)***
    initial
		 begin
			 waiting_for_new_frame = 1;
			 #200        //(20)*10         // Wait for reset (10 cycles)
			 #IMG_CAPTURE_START_TIME       // Wait for capture start time
			 waiting_for_new_frame = 0;
          Write_Start = 1;
			 #IMG_CAPTURE_DURATION         // Wait for capture duration to elapse
			 Write_Done = 1;               // Signal to the image_write buffer to save its contents to “simulation\modelsim\filter_TB_output.bmp”.
			 #1                            // Wait 1 timestep to allow image_write to write the image file before stopping
          $stop();
		 end
endmodule




/****************** Module for writing .bmp image *************/ 
/**** From https://www.fpga4student.com/2016/11/image-processing-on-fpga-verilog.html*/
// fpga4student.com FPGA projects, Verilog projects, VHDL projects
// Verilog project: Image processing in Verilog
module image_write #(parameter 
WIDTH = 320, // Image width 
HEIGHT = 240, // Image height 
INFILE = "detection_output.bmp", // Output image 
BMP_HEADER_NUM = 54 // Header length for an uncompressed bmp image (< 255)
) 
( 
input clk, reset,
input [23:0] input_rgb,
input [16:0] addr,
input Write_Start, Write_Done 
); 

// fpga4student.com FPGA projects, Verilog projects, VHDL projects
//-----------------------------------// 
//-------Header data for bmp image-----// 
//-------------------------------------// 
// Windows BMP files begin with a 54-byte header
reg [7:0] BMP_header [BMP_HEADER_NUM:0];
integer file_size = BMP_HEADER_NUM + (WIDTH*HEIGHT*24)/8;
initial  begin 
BMP_header[ 0] = 66;              BMP_header[28] =24; 
BMP_header[ 1] = 77;              BMP_header[29] = 0; 
BMP_header[ 2] = file_size[7 :0 ];BMP_header[30] = 0; 
BMP_header[ 3] = file_size[15:8 ];BMP_header[31] = 0;
BMP_header[ 4] = file_size[23:16];BMP_header[32] = 0;
BMP_header[ 5] = file_size[31:24];BMP_header[33] = 0; 
BMP_header[ 6] = 0;               BMP_header[34] = 0; 
BMP_header[ 7] = 0;               BMP_header[35] = 0; 
BMP_header[ 8] = 0;               BMP_header[36] = 0; 
BMP_header[ 9] = 0;               BMP_header[37] = 0; 
BMP_header[10] = BMP_HEADER_NUM;  BMP_header[38] = 0; 
BMP_header[11] = 0;               BMP_header[39] = 0; 
BMP_header[12] = 0;               BMP_header[40] = 0; 
BMP_header[13] = 0;               BMP_header[41] = 0; 
BMP_header[14] = 40;              BMP_header[42] = 0; 
BMP_header[15] = 0;               BMP_header[43] = 0; 
BMP_header[16] = 0;               BMP_header[44] = 0; 
BMP_header[17] = 0;               BMP_header[45] = 0; 
BMP_header[18] = WIDTH[7 :0 ];    BMP_header[46] = 0; 
BMP_header[19] = WIDTH[15:8 ];    BMP_header[47] = 0;
BMP_header[20] = WIDTH[23:16];    BMP_header[48] = 0;
BMP_header[21] = WIDTH[31:24];    BMP_header[49] = 0; 
BMP_header[22] = HEIGHT[7 :0 ];   BMP_header[50] = 0; 
BMP_header[23] = HEIGHT[15:8 ];   BMP_header[51] = 0; 
BMP_header[24] = HEIGHT[23:16];   BMP_header[52] = 0; 
BMP_header[25] = HEIGHT[31:24];   BMP_header[53] = 0; 
BMP_header[26] = 1;               BMP_header[27] = 0; 
end
//---------------------------------------------------------//
//--------------Write .bmp file  ----------------------//
//----------------------------------------------------------//

reg [23:0] out_BMP [WIDTH*HEIGHT:0];

integer fd;
initial begin
    fd = $fopen(INFILE, "wb+");
end

always @(posedge clk) begin
    if (Write_Start) out_BMP[addr] <= input_rgb;
end
integer i, j;
always@(Write_Done) begin // Once the processing is done, the bmp image will be created
    if(Write_Done == 1'b1) begin
        for(i=0; i<BMP_HEADER_NUM; i=i+1) begin
            $fwrite(fd, "%c", BMP_header[i][7:0]); // Write the header
        end
        
        for(i=HEIGHT-1; i>=0; i=i-1) begin // Write the pixels
				for(j=0; j<WIDTH; j=j+1) begin
					$fwrite(fd, "%c", out_BMP[i*WIDTH+j][7:0]);
					$fwrite(fd, "%c", out_BMP[i*WIDTH+j][15:8]);
					$fwrite(fd, "%c", out_BMP[i*WIDTH+j][23:16]);
				end
        end
    end
end
endmodule
