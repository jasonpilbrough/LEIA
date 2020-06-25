`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// UNIVERSITY OF CAPE TOWN
//
// Author: Jason Pilbrough
// 
// Create Date: 27.05.2020 20:31:31
// Project Name: LEIA
// Module Name: Line_Drawer

// Target Devices: Nexys-A7-100T 
// Tool Versions: Vivado WebPack 2018
// Description: 
// 
// Indicates if current px in image belongs to one of the detected lanes
//
// Revision: 1.0 - Final Version
//////////////////////////////////////////////////////////////////////////////////



module Line_Drawer(
        input CLK100MHZ,		//input clock
        input signed [15:0] m, // gradient of line (signed real number - fixed point at index 8)
        input signed [15:0] b, // y-intercept of line (signed integer)
        input [15:0] x_coord, // x-coordinate of px in image
        input [15:0] y_coord, // y-coordinate of px in image
        output reg px_on_line //true if current (x,y) coord lies on the line
    );
    
    parameter [3:0] LINE_WIDTH = 4'd2;
    
    wire signed [15:0] y_hat;
    
    wire[31:0] m_extended;
    wire[31:0] b_extended;
    wire[31:0] x_coord_extended;
    assign m_extended [31:0] = ((m<<16)>>>16); // extend with correct sign
    assign b_extended [31:0] = ((b<<16)>>>16); // extend with correct sign
    assign x_coord_extended [31:0] = ((x_coord<<16)>>>16); // extend with correct sign
    
    wire [31:0] y_hat_extended; 
    assign y_hat_extended [31:0] = (((m_extended*x_coord_extended))+(b_extended<<8)); //NB multipy results in fixed point number at bit 8
    assign  y_hat[15:0] = y_hat_extended[23:8]; //remove fixed point part and only use integer part
    
    always @ (posedge CLK100MHZ) begin
    
        if( y_hat - y_coord <= LINE_WIDTH || y_coord-y_hat <= LINE_WIDTH) begin
            px_on_line <= 1'b1;
        end else begin
            px_on_line <= 1'b0;
        end
    end
     
endmodule
