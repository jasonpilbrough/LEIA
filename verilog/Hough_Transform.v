`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// UNIVERSITY OF CAPE TOWN
//
// Author: Jason Pilbrough 
// 
// Create Date: 22.04.2020 10:45:46
// Project Name: LEIA
// Module Name: Hough_Transform

// Target Devices: Nexys-A7-100T 
// Tool Versions: Vivado WebPack 2018
// Description: 
// 
// Computes Hough Transform on input image. Performs accumulation in Hough Space to identify
// best pair of line parameters
//
// Revision: 1.0 - Final Version
//////////////////////////////////////////////////////////////////////////////////


module Hough_Transform(
    input CLK100MHZ,
    input reset, 		// reset line 
    input pixel, 		// binary pixel input for transformation
    input ROI, 			// ROI_L (ROI=0), ROI_R (ROI=1)
    input [11:0]x_coord,// x-coordinate of px in image
    input [11:0]y_coord,// y-coordinate of px in image
    input clear, 		// indicate a new xy coordinate is ready for processing
    input enable,		//enable line
    output reset_complete, //indicates that reset is complete
    output done_flag, 	//line to indicate voting for current xy coordinate is done
    output [15:0]m, 	//m line parameter: signed real number - fixed point at index 8
    output [15:0]b, 	//b line parameter: signed integer
    output lane_departure // high if detected lane is very upright - indicating vehicle ahout to change lanes
    );
    
    //threshold to activate lane departure warning in degrees (THRESH+1 for ROI_L and 179-THRESH for ROI_R)
    parameter [5:0] LANE_DEPARTURE_THRESH = 6'd20; 
    
    /* =================== SIN AND COS LOOK-UP-TABLES (LUT) =====================
        Only value for angles in the range of 1->64 are stored.
        All required outputs can be calcuated from these values using symmetry
    */
    
    reg [5:0] theta = 6'b0; //index in SIN and COS LUT
    reg lut_en = 1'b1; //enable for SIN and COS LUT
    wire [5:0] lut_sin_addra; 
    wire [11:0]lut_sin_dout; //interpret as fixed point number at bit 11 (first bit is a sign bit) range -1->1
    
    //angles for ROI_L 1->64deg, ROI_R 115->179deg. Note that sin(1)=sin(179), hence the ~theta[5:0] for ROI_R
    assign lut_sin_addra[5:0] = (ROI ? ~theta[5:0] : theta[5:0]);
    
    //Look-up-table for SIN: index 0 = sin(1), index 63 = sin(64)
    LUT_sin LUT_SIN (
      .clka(CLK100MHZ),    // input wire clka
      .ena(lut_en),      // input wire ena
      .addra(lut_sin_addra),  // input wire [5 : 0] addra
      .douta(lut_sin_dout)  // output wire [11 : 0] douta
    );
    
    
    wire [5:0]lut_cos_addra;
    wire [11:0]lut_cos_dout; //interpret as fixed point number at bit 11 (first bit is a sign bit) range -1->1
    wire [11:0]lut_cos_dout_sign; //output from LUT is positive, correct sign if theta > 90deg
    
    //angles for ROI_L 1->64deg, ROI_R 115->179deg. Note that cos(1)=-cos(179), hence the ~theta[5:0] for ROI_R and two's complment
    //on lut_cos_dout[11:0] 
    assign lut_cos_addra[5:0] = (ROI ? ~theta[5:0] : theta[5:0]);
    assign lut_cos_dout_sign[11:0] = (ROI ?  ~lut_cos_dout[11:0] + 1'b1 : lut_cos_dout[11:0]);
    
    //Look-up-table for COS: index 0 = cos(1), index 63 = cos(64)
    LUT_cos LUT_COS (
      .clka(CLK100MHZ),    // input wire clka
      .ena(lut_en),      // input wire ena
      .addra(lut_cos_addra),  // input wire [5 : 0] addra
      .douta(lut_cos_dout)  // output wire [11 : 0] douta
    );
    
    /* ======================== RHO CALCULATION ============================*/
    wire [23:0] P_1; //output of y * sin(theta)
    wire [23:0] P_2; //output of x * cos(theta)
    
    //multiplies two 12 bit inputs, output is 24 bits fixed point at bit 11
    mult_gen_0 mult1 (
      .CLK(CLK100MHZ),  // input wire CLK
      .A(y_coord),      // input wire [11 : 0] A ----- OLD y
      .B(lut_sin_dout),      // input wire [11 : 0] B
      .P(P_1)      // output wire [23 : 0] P
    );
    
    //multiplies two 12 bit inputs, output is 24 bits fixed point at bit 11
    mult_gen_0 mult2 (
      .CLK(CLK100MHZ),  // input wire CLK
      .A(x_coord),      // input wire [11 : 0] A ----------OLD x
      .B(lut_cos_dout_sign),      // input wire [11 : 0] B
      .P(P_2)      // output wire [23 : 0] P
    );
    
    wire [23:0]HT_calc_out; //sum of multiply outputs
    wire [10:0]rho; //convert HT_calc_out to signed integer 
    assign HT_calc_out[23:0] = P_1 + P_2;
    assign rho[10:0] = HT_calc_out[21:11];
    
    
    /* ======================== ACCUMULATOR AND VOTING ============================
        Voting is done by incrementing the value at a given address by one.  
        Address is combination of current theta and calculated rho.
        Must account for delay of 2 clock cylces when reading from memory before incrementing.
    */
    
    reg resetting_accum = 1'b0; //reg to indicate if the HS accumulator is currently being reset (takes many clock cycles)
    reg done_resetting = 1'b1; //reg to indicate if HS accumulator has finished resetting (takes many clock cycles)
    assign reset_complete = done_resetting;
    
    wire [16:0]accum_addr; //address to increment in accumulator based on rho and theta
    //must subtract 3 from theta to account for delay of memory access and multiply
    assign accum_addr[16:0] = {rho[10:0] , theta[5:0] - 3'd3}; 
    
    //stores accum address in the previous clock cycle to write into accumulator
    reg [16:0] prev_accum_addr = 17'd0;
    //stores accum address from two clock cycle ago to write into accumulator
    reg [16:0] prev_prev_accum_addr = 17'd0;
    
    //reg [7:0] prev_accum_val = 8'd0;
    //reg [7:0] prev_prev_accum_val = 8'd0;
    
    wire [7:0] HS_accum_doutb; //output of accumulator
    reg HS_accum_wea = 1'b0; //write enable for accumulator
    reg [2:0] HS_accum_wea_timer = 3'd0; //initial delay to enable accumulator write to accout for memory access delay
    wire [7:0] HS_accum_din; //input to accumulator
    
    //increment current address by 1
    assign HS_accum_din[7:0] = (resetting_accum ? 8'd0 : HS_accum_doutb + 1'b1); //write 0 if currently resetting accum
 
    //accumulator to store the number of votes for each combination of rho and theta
    HS_accumulator HS_accum (
      .clka(CLK100MHZ),    // input wire clka
      .wea(HS_accum_wea),      // input wire [0 : 0] wea
      .addra(prev_prev_accum_addr),  // input wire [16 : 0] addra
      .dina(HS_accum_din),    // input wire [7 : 0] dina
      .clkb(CLK100MHZ),    // input wire clkb
      .addrb(accum_addr),  // input wire [16 : 0] addrb
      .doutb(HS_accum_doutb)  // output wire [7 : 0] doutb
    );
    
    reg done = 1'b0; //signal to indicate voting for current xy coordinate is done
    assign done_flag = done;
    reg [2:0] done_timer = 3'd0; //timer to allow to voting to finish after final theta is reached
    
    
    
    /* ======================== PEAK DETECTOR ============================ 
        Keeps track of the address with the most number of votes.
        The address is the combination of rho and theta
    */
    wire [10:0]rho_peak;
    wire [5:0]theta_peak;
    
    reg [16:0]peak_addr = 17'd0;
    reg [7:0]peak_val = 8'd0; //number of votes for the most voted combo of rho and theta
    assign rho_peak [10:0] = peak_addr[16:6];
    assign theta_peak [5:0] = (ROI ? ~peak_addr[5:0] : peak_addr[5:0]); //must undo mapping of theta if ROI_R
    //assign theta_peak [5:0] = peak_addr[5:0]; //must undo mapping of theta if ROI_R
    
    assign lane_departure = theta_peak < LANE_DEPARTURE_THRESH;
    
    /* ========================= INVERSE HT ============================== */
    
    wire [15:0]m_uncorrected; //signed real number - fixed point at index 8
    //wire [15:0]b; //signed integer
    LUT_cot LUT_COT (
      .clka(CLK100MHZ),    // input wire clka
      .addra(theta_peak),  // input wire [5 : 0] addra
      .douta(m_uncorrected)  // output wire [15 : 0] douta
    );
    
    //assign m[15:0] = ~m_uncorrected[15:0] + 1'b1; //for some reason the line drawer needs the gradient m to be negated
    assign m[15:0] = (ROI ? m_uncorrected[15:0] : ~m_uncorrected[15:0]+1'b1) ; 
    
    wire [15:0] one_oversin_out;
    
    LUT_1oversin LUT_1OVERSIN (
      .clka(CLK100MHZ),    // input wire clka
      .addra(theta_peak),  // input wire [5 : 0] addra
      .douta(one_oversin_out)  // output wire [15 : 0] douta
    );
    
    wire [31:0] mult3_out;
    
    mult_16b_gen_1 mult3 (
      .CLK(CLK100MHZ),  // input wire CLK
      .A(one_oversin_out),      // input wire [15 : 0] A
      .B(rho_peak[10:0]),      // input wire [10 : 0] B
      .P(mult3_out)      // output wire [26 : 0] P
    );
    
    assign b[15:0] = {mult3_out[26], mult3_out[22:8]}; //preserve sign bit - this prob isnt nesessary
    

    always @ (posedge CLK100MHZ) begin
    
        if (reset) begin 
            prev_accum_addr <= 17'd0;
            HS_accum_wea_timer <= 3'd0;
            theta <= 6'd0;
            done_timer <= 3'd0;
            done <= 2'd0;
            
            peak_addr <= 17'd0;
            peak_val <= 8'd0; 
            
            //resetting the HS accumulator BRAM takes many clock cycles - the next few lines initilise this process
            resetting_accum <= 1'b1;
            done_resetting <= 1'b0;
            HS_accum_wea <= 1'b1;
            prev_prev_accum_addr <= 17'd0;
         
        end else if (resetting_accum) begin
            //resetting the HS accumulator BRAM takes many clock cycles as must write 0 to each address one by one
            prev_prev_accum_addr <= prev_prev_accum_addr + 1'b1;
            if(&prev_prev_accum_addr) begin
                done_resetting <= 1'b1;
                resetting_accum <= 1'b0;
                HS_accum_wea <= 1'b0;
                prev_prev_accum_addr <= 17'd0;
            end
            
        end else if(clear) begin
            HS_accum_wea_timer <= 3'd0;
            theta <= 6'd0;
            done_timer <= 3'd0;
            done <= 2'd0;
            
        end else if (enable) begin

            if(~pixel) begin
                done <= 1'b1;
            end else if(&theta ||  done_timer >0 ) begin
                if(done_timer >= 3'd5) begin 
                    done <= 1'b1;
                    HS_accum_wea <= 1'b0;
                end
                else done_timer <= done_timer + 1'b1;
                
                theta <= theta +1'b1;
                
            end else begin
                 if(HS_accum_wea_timer >= 3'd4) HS_accum_wea <= 1'b1;
                 else HS_accum_wea_timer <= HS_accum_wea_timer + 1'b1;
                 
                 theta <= theta +1'b1;
            end
    
            if(!done) begin
                prev_accum_addr <= accum_addr;
                prev_prev_accum_addr <= prev_accum_addr;
            
                //prev_accum_val <= HS_accum_doutb;
                //prev_prev_accum_val <= prev_accum_val;
                
                //if((prev_prev_accum_val + 1'b1 > peak_val) && HS_accum_wea) begin
                if((HS_accum_doutb + 1'b1 > peak_val) && HS_accum_wea) begin
                    //peak_val <= prev_prev_accum_val + 1'b1;
                    peak_val <= HS_accum_doutb + 1'b1;
                    peak_addr <= prev_prev_accum_addr;
                end
            end
         end

    end
    
    
endmodule










