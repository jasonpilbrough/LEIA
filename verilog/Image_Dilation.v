`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// UNIVERSITY OF CAPE TOWN
//
// Author: Samantha Ball 
// 
// Create Date: 03.06.2020 16:40:29
// Project Name: LEIA
// Module Name: Image_Dilation

// Target Devices: Nexys-A7-100T 
// Tool Versions: Vivado WebPack 2018
// Description: 
// 
// Module performs image dilation on input image to smooth rough edges created by sobel
// filter. 
//
// Revision: 1.0 - Final Version
//////////////////////////////////////////////////////////////////////////////////



module Image_Dilation 
	#(parameter[15:0] px_per_row = 16'd520) //default image width is 520px
    (
        input CLK100MHZ,  	//input clock
        input next_px,		//next pixel
        input btn_reset,	//reset line
        input ena,			//enable line
        output output_px	//output pixel
    );
    
    
    /* ========================== ROW BUFFERS (FIFO) ============================= */
    wire [7:0]din_row1; //data input line for row buffer 1
    reg wr_en_1 = 1; // write enable line for row buffer 1
    reg rd_en_1 = 0; //read enable line for row buffer 1
    wire [7:0]dout_row1; // data output line for row buffer 1
    assign din_row1[7:0] = next_px;
    
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
    reg dout_px1 = 1'b0;
    reg dout_px2 = 1'b0;
    
    reg dout_px3 = 1'b0;
    reg dout_px4 = 1'b0;
    
    reg dout_px5 = 1'b0;
    reg dout_px6 = 1'b0;
    
 
    /* ======================= DILATION KERNEL AND OUTPUTS ========================= */
    assign output_px = dout_px1 | dout_px2 | dout_px3 | dout_px4 | dout_px5 | dout_px6 | dout_row1[0] | dout_row2[0] | next_px; 


    always @ (posedge CLK100MHZ) begin
        if(btn_reset)
            begin
            wr_en_1 <= 1;
            rd_en_1 <= 0;
            wr_en_2 <= 0;
            rd_en_2 <= 0;
            
            dout_px1 = 1'd0;
            dout_px2 = 1'd0;
            dout_px3 = 1'd0;
            dout_px4 = 1'd0;
            dout_px5 = 1'd0;
            dout_px6 = 1'd0;
            
            row1_timer = 13'd0;
            row2_timer = 13'd0;
            
            end
        if(ena)
            begin
                //image dilation
                dout_px2 <= dout_px1;
                dout_px1 <= next_px;
            
                dout_px4 <= dout_px3;
                dout_px3 <= dout_row1;
            
                dout_px6 <= dout_px5;
                dout_px5 <= dout_row2;
            
                //initial delay to fill row 1 buffer
                if(!rd_en_1) begin
                    row1_timer <= row1_timer + 1'b1;
                    if(row1_timer > px_per_row - 2'd3) begin
                        rd_en_1 <= 1'b1;
                        wr_en_2 <= 1'b1;
                    end
                end
            
                //initial delay to fill row 2 buffer
                if(!rd_en_2) begin
                    row2_timer <= row2_timer + 1'b1;
                    if(row2_timer > 2*px_per_row - 3'd4) rd_en_2 <= 1'b1; //2^5 - 4 = 28 
                    end
            
            end
        end
        
endmodule
        
