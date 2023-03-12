module	LCD_TEST (	//	Host Side
					iCLK,iRST_N, H_CENTROID,
					//	LCD Side
					LCD_DATA,LCD_RW,LCD_EN,LCD_RS	);
//	Host Side
input			iCLK,iRST_N;
input [31:0] H_CENTROID;

//	LCD Side
output	[7:0]	LCD_DATA;
output			LCD_RW,LCD_EN,LCD_RS;
//	Internal Wires/Registers

reg	[7:0]	LUT_INDEX;
reg	[7:0] SELECT;
reg	[8:0]	LUT_DATA;

reg	[5:0]	mLCD_ST;
reg	[5:0] mRST_ST;

reg	[17:0]mDLY;
reg			mLCD_Start;
reg	[7:0]	mLCD_DATA;
reg			mLCD_RS;

integer h_cen;
integer h_cen_thou;
integer h_cen_huns;
integer h_cen_tens;

reg	[5:0] h_thou;	
reg	[5:0]	h_huns;	
reg	[5:0]	h_tens;
reg	[5:0]	h_ones;

reg			NEXT_VAL;	

wire		mLCD_Done;


parameter	LCD_INTIAL	=	0;
parameter	LCD_LINE1	=	5;
parameter	SELECT_INIT = 	0;
parameter	SELECT_NUM	=	5;
parameter	SELECT_ALT	=	15;

parameter	DRM_Start	=	9'h080;		// Instruction to set cursor to start pos
parameter	DRM_End		= 	9'h08F;		// Instruction to set cursor to end pos
parameter	DSP_Reset	=	9'h001;		// Instruction to reset display
parameter	DLY_5ms		=	18'h3FFFE;	// 5.24 ms delay
parameter	DLY_105ms	=	23'd5242840;	// 104.8 ms delay
parameter	DLY_500ms	=  25'h17D7840;// Half second delay

always@(posedge iCLK or negedge iRST_N)
begin
	if(!iRST_N)
	begin
		LUT_INDEX	<=	0;
		
		mLCD_ST		<=	0;
		mRST_ST		<= 0;
		
		mDLY			<=	0;
		mLCD_Start	<=	0;
		mLCD_DATA	<=	0;
		mLCD_RS		<=	0;
		
		NEXT_VAL		<= 1;
	end
	else
	begin
	   // State machine :
		if (LUT_INDEX < LCD_LINE1+6+1)
		begin
			NEXT_VAL <= 0;
			
			case(mLCD_ST)
			0:	begin                               // What does state 0 do?
					mLCD_DATA	<=	LUT_DATA[7:0];
					mLCD_RS		<=	LUT_DATA[8];
					mLCD_Start	<=	1;
					mLCD_ST		<=	1;
				end
			1:	begin                               // What does state 1 do?
					if(mLCD_Done)
					begin
						mLCD_Start	<=	0;
						mLCD_ST		<=	2;					
					end
				end
			2:	begin                               // What does state 2 do?
					if(mDLY<18'h3FFFE)
					begin
						mDLY	<=	mDLY+1;
					end
					else
					begin
						mDLY	<=	0;
						mLCD_ST	<=	3;
					end
				end
			3:	begin                               // What does state 3 do?
					LUT_INDEX <= LUT_INDEX+1;
					mLCD_ST	<=	0;
				end
			endcase
			
		end
		
		// Reset display
		else
		begin
			// Ready to take new data
			NEXT_VAL <= 1;
		
			case(mRST_ST)
			// Wait for a short period before clearing
			0: begin
					if (mDLY < DLY_5ms)
					begin
						mDLY 			<= mDLY + 1;
					end
					else
					begin
						mDLY 			<= 0;
						mRST_ST 		<= mRST_ST + 1;
					end
				end
			// Clear the display (send to LCD controller)
			1:	begin
					mLCD_DATA		<=	DSP_Reset[7:0];
					mLCD_RS			<=	DSP_Reset[8];
					mLCD_Start		<=	1;
					mRST_ST			<=	mRST_ST + 1;
				end
			// Wait for LCD controller to finish
			2: begin
					if (mLCD_Done)
					begin
						mLCD_Start	<= 0;
						mRST_ST		<=	mRST_ST + 1;					
					end
				end
			// Wait 5.24 ms
			3: begin
					if (mDLY < DLY_5ms)
					begin
						mDLY			<=	mDLY + 1;
					end
					else
					begin
						mDLY			<=	0;
						mRST_ST		<=	mRST_ST + 1;
					end
				end
			// Reset state machine and start printing again
			4: begin
					LUT_INDEX 		<= LCD_LINE1;
					mRST_ST			<= 0;
				end
			endcase					
		end
	end
end

/*--------------------------------------------------------------------------------------------------
Read in new numbers when ready, determine digit values
--------------------------------------------------------------------------------------------------*/

always @(posedge iCLK)
begin
	
	h_cen  = H_CENTROID;
	h_thou = 0;
	h_huns = h_cen/100;	
	h_tens = (h_cen-h_huns*100)/10;
	h_ones = (h_cen-h_huns*100-h_tens*10);
	
end

/*--------------------------------------------------------------------------------------------------
Determine output to LCD
--------------------------------------------------------------------------------------------------*/

always @(*)
begin
	case(LUT_INDEX)
	//	Initialise :
	LCD_INTIAL+0:	SELECT <= SELECT_INIT+0;
	LCD_INTIAL+1:	SELECT <= SELECT_INIT+1;
	LCD_INTIAL+2:	SELECT <= SELECT_INIT+2;
	LCD_INTIAL+3:	SELECT <= SELECT_INIT+3;
	LCD_INTIAL+4:	SELECT <= SELECT_INIT+4;
	
	// Select numbers
	LCD_LINE1+0:	SELECT <= SELECT_NUM+h_thou;
	LCD_LINE1+1:	SELECT <= SELECT_NUM+h_huns;
	LCD_LINE1+2:	SELECT <= SELECT_NUM+h_tens; 
	LCD_LINE1+3:	SELECT <= SELECT_NUM+h_ones; 

	default:		   SELECT <= SELECT_INIT+1;
	endcase
end

/*--------------------------------------------------------------------------------------------------
Number selection
--------------------------------------------------------------------------------------------------*/

always @(*)
begin 
	case(SELECT)
	
	SELECT_INIT+0:	LUT_DATA	<=	9'h038;
	SELECT_INIT+1:	LUT_DATA	<=	9'h00C;
	SELECT_INIT+2:	LUT_DATA	<=	DSP_Reset;
	SELECT_INIT+3:	LUT_DATA	<=	9'h006;
	SELECT_INIT+4:	LUT_DATA	<=	DRM_Start;
		
	SELECT_NUM+0:	LUT_DATA	<=	9'h130;
	SELECT_NUM+1:	LUT_DATA	<=	9'h131; 
	SELECT_NUM+2:	LUT_DATA	<=	9'h132; 
	SELECT_NUM+3:	LUT_DATA	<=	9'h133; 
	SELECT_NUM+4:	LUT_DATA	<=	9'h134; 
	SELECT_NUM+5:	LUT_DATA	<=	9'h135;
	SELECT_NUM+6:	LUT_DATA	<=	9'h136;
	SELECT_NUM+7:	LUT_DATA	<=	9'h137;
	SELECT_NUM+8:	LUT_DATA <= 9'h138;
	SELECT_NUM+9:	LUT_DATA <= 9'h139;
	
	SELECT_ALT+0:	LUT_DATA	<=	9'h120;
	
	default : LUT_DATA	<=	9'h00C;
	endcase
end


LCD_Controller 		u0	(	//	Host Side
							.iDATA(mLCD_DATA),
							.iRS(mLCD_RS),
							.iStart(mLCD_Start),
							.oDone(mLCD_Done),
							.iCLK(iCLK),
							.iRST_N(iRST_N),
							//	LCD Interface
							.LCD_DATA(LCD_DATA),
							.LCD_RW(LCD_RW),
							.LCD_EN(LCD_EN),
							.LCD_RS(LCD_RS)	);

endmodule