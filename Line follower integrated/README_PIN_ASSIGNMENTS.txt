The pin assignments for the relevant pins that should be connected to the OV7670 have been assigned to the 'ov7670_pclk', 'ov7670_xclk', 'ov7670_vsync', 'ov7670_href', [7:0] 'ov7670_data', 'ov7670_sioc', 'ov7670_siod', 'ov7670_pwdn' and 'ov7670_reset' input/output port variables. These are defined in the top_level.v file's 'digital_cam_impl1' module. These pin assignments can be imported from the VerilogCam.qsf file. In particular, lines 1120-1135 from this file are very enlightening:

"""
set_location_assignment PIN_AE22 -to ov7670_data[7]
set_location_assignment PIN_AF21 -to ov7670_data[6]
set_location_assignment PIN_AF25 -to ov7670_data[5]
set_location_assignment PIN_AC22 -to ov7670_data[4]
set_location_assignment PIN_AF24 -to ov7670_data[3]
set_location_assignment PIN_AE21 -to ov7670_data[2]
set_location_assignment PIN_AD19 -to ov7670_data[1]
set_location_assignment PIN_AF15 -to ov7670_data[0]
set_location_assignment PIN_AD25 -to ov7670_href
set_location_assignment PIN_AF22 -to ov7670_pclk
set_location_assignment PIN_AF16 -to ov7670_pwdn
set_location_assignment PIN_AC19 -to ov7670_reset
set_location_assignment PIN_AH25 -to ov7670_sioc
set_location_assignment PIN_AE25 -to ov7670_siod
set_location_assignment PIN_AG25 -to ov7670_vsync
set_location_assignment PIN_AD22 -to ov7670_xclk
"""

The PIN_XXXX labels above are featured in DE2_115_User_manual.pdf on p46 section "4.8 Using the Expansion Header". Specifically, Figure 4-15 "GPIO Pin Arrangement" shows the pinout of this GPIO header.