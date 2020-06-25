`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// UNIVERSITY OF CAPE TOWN
//
// Author: Jason Pilbrough
// 
// Create Date: 13.04.2020 14:32:04
// Design Name: LEIA
// Module Name: Sobel_Filter

// Target Devices: Nexys-A7-100T 
// Tool Versions: Vivado WebPack 2018
// Description: 
// 
// Module to apply sobel filter to input image. 
//
// Revision: 1.0 - Final Version
//////////////////////////////////////////////////////////////////////////////////


module Sobel_Filter 
	#(parameter[15:0] px_per_row = 16'd520) //default image width is 520px
    (
    input CLK100MHZ,		//input clock
    input [7:0] next_px,	//next px (represented by intensity)
    input btn_reset,		//reset line
    input ena,				//enable line
    output output_px		//output px (binary)
    );
    
    
    /* ========================== ROW BUFFERS (FIFO) ============================= */
    wire [7:0]din_row1; //data input line for row buffer 1
    reg wr_en_1 = 1; // write enable line for row buffer 1
    reg rd_en_1 = 0; //read enable line for row buffer 1
    wire [7:0]dout_row1; // data output line for row buffer 1
    assign din_row1[7:0] = next_px[7:0];
    
    reg [12:0]row1_timer = 13'd0; //initial delay to full row 1 buffer
    
    row_fifo row_fifo_1 (
      .clk(CLK100MHZ & ena),      // input wire clk - NB only advance the clock if ena is high
      .srst(btn_reset),    // input wire srst
      .din(din_row1),      // input wire [7 : 0] din
      .wr_en(wr_en_1),  // input wire wr_en
      .rd_en(rd_en_1),  // input wire rd_en
      .dout(dout_row1),    // output wire [7 : 0] dout
      .full(full1),    // output wire full
      .empty(empty1)  // output wire empty
    );
    
    
    wire [7:0]din_row2; //data input line for row buffer 2
    reg wr_en_2 = 0; // write enable line for row buffer 2
    reg rd_en_2 = 0; //read enable line for row buffer 2
    wire [7:0]dout_row2; //data output line for row buffer 2
    assign din_row2[7:0] = dout_row1[7:0];
    
    reg [12:0]row2_timer = 13'b0000000000000; //initial delay to full row 1 buffer AND row 2 buffer
    
    row_fifo row_fifo_2 (
      .clk(CLK100MHZ & ena),      // input wire clk - NB only advance the clock if ena is high
      .srst(btn_reset),    // input wire srst
      .din(din_row2),      // input wire [7 : 0] din
      .wr_en(wr_en_2),  // input wire wr_en
      .rd_en(rd_en_2),  // input wire rd_en
      .dout(dout_row2),    // output wire [7 : 0] dout
      .full(full2),    // output wire full
      .empty(empty2)  // output wire empty
    );
    
    /* ============================ PIXEL BUFFERS =============================== */
    reg [7:0] dout_px1 = 8'b00000000;
    reg [7:0] dout_px2 = 8'b00000000;
    
    reg [7:0] dout_px3 = 8'b00000000;
    reg [7:0] dout_px4 = 8'b00000000;
    
    reg [7:0] dout_px5 = 8'b00000000;
    reg [7:0] dout_px6 = 8'b00000000;
    
    /* ============== SOBEL KERNEL, BINARIZATION, AND OUTPUTS ================== */
    wire [15:0] filtered_px; //must be more bits than output to allow for divide by 8
     
    reg [15:0] x_kernel = 16'd0; 
    reg [15:0] y_kernel = 16'd0;
    
    wire[7:0] binarization_in; //input line to threshold binarization carrying current input pixel
    wire [7:0] binarization_out; //output line from threshold binarization carrying current output pixel
    Threshold_Binarization bin(CLK100MHZ, binarization_in, btn_reset, ena, binarization_out);
    
    //take absolute value of x and y kernels and then sum
    assign filtered_px[15:0] = (x_kernel[15] ? ~x_kernel + 1'b1 : x_kernel) + (y_kernel[15] ? ~y_kernel + 1'b1 : y_kernel);
    assign binarization_in[7:0] = filtered_px[10:3]; // corresponds to divide by 8
    
    assign output_px = binarization_out[0];
    
    
     always @ (posedge CLK100MHZ) begin
     
        if(btn_reset) begin
            wr_en_1 <= 1;
            rd_en_1 <= 0;
            wr_en_2 <= 0;
            rd_en_2 <= 0;
            
            dout_px1 = 8'd0;
            dout_px2 = 8'd0;
            dout_px3 = 8'd0;
            dout_px4 = 8'd0;
            dout_px5 = 8'd0;
            dout_px6 = 8'd0;
            
            row1_timer = 13'd0;
            row2_timer = 13'd0;
            
            x_kernel <= 16'd0;
            y_kernel <= 16'd0;
            //filtered_px = 16'd0;
        end
        
        if(ena) begin
            dout_px2 <= dout_px1;
            dout_px1 <= next_px;
            
            dout_px4 <= dout_px3;
            dout_px3 <= dout_row1;
            
            dout_px6 <= dout_px5;
            dout_px5 <= dout_row2;
            
            //initial delay to full row 1 buffer
            if(!rd_en_1) begin
                row1_timer <= row1_timer + 1'b1;
                if(row1_timer > px_per_row - 2'd3) begin
                    rd_en_1 <= 1'b1;
                    wr_en_2 <= 1'b1;
                 end
            end
            
            //initial delay to full row 2 buffer
            if(!rd_en_2) begin
                row2_timer <= row2_timer + 1'b1;
                if(row2_timer > 2*px_per_row - 3'd4) rd_en_2 <= 1'b1; //2^5 - 4 = 28 
            end
            
            x_kernel <= dout_px6 + 2*dout_px4 + dout_px2 - (dout_row2 + 2*dout_row1 + next_px);
            y_kernel <= dout_px6 + 2*dout_px5 + dout_row2 - (dout_px2 + 2* dout_px1 + next_px);
            
        
        end
        
     end
    
endmodule
