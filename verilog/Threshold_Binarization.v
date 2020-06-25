`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// UNIVERSITY OF CAPE TOWN
//
// Author: Samantha Ball
// 
// Create Date: 03.06.2020 14:56:24
// Design Name: LEIA
// Module Name: Threshold_Binarization

// Target Devices: Nexys-A7-100T 
// Tool Versions: Vivado WebPack 2018
// Description: 
// 
// Provides threshold binarisation on input and produces a binary output image.
//
// Revision: 1.0 - Final Version
//////////////////////////////////////////////////////////////////////////////////


module Threshold_Binarization
    (
        input CLK100MHZ,		//input clock
        input [7:0] next_px,	//input px
        input btn_reset,		//reset line
        input ena,				//reset line
        output [7:0]output_px	//output px (255 represents 1 and 0 represents 0)
    );
    
    parameter[7:0] THRESHOLD = 8'd78; //threshold value    
    assign output_px = ((next_px > THRESHOLD) && ena ? 255: 0);

endmodule
