`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// UNIVERSITY OF CAPE TOWN
//
// Author: Jason Pilbrough
// 
// Create Date: 08.04.2020 18:28:44
// Project Name: LEIA
// Module Name: Timer
//
// Target Devices: Nexys-A7-100T 
// Tool Versions: Vivado WebPack 2018
// Description: 
// 
// Timer used for benchmarking FPGA design. Provides two independent timers. Outputs to
// SS display.
//
// Revision: 1.0 - Final Version
//////////////////////////////////////////////////////////////////////////////////


module Timer(
    input CLK100MHZ,	//input clock
    input btn_reset,	//reset line
    input t1_ena,		//enable line for timer 1
    input t2_ena,		//enable line for timer 2
    output [7:0] SS_EN,	//Seven segment display enable (anode)
    output [7:0] SS 	//Seven segment display (cathode)
    );
    
    reg [19:0] clkdiv_1; //0.001s div -> 0.01/(1/100MHz) = 100000
    reg [3:0] milli_ones_1=0;
    reg [3:0] milli_tens_1=0;
    reg [3:0] milli_hundreds_1=0;
    reg [3:0] sec_ones_1=0;
    
    reg [19:0] clkdiv_2; //0.001s div -> 0.01/(1/100MHz) = 100000
    reg [3:0] milli_ones_2=0;
    reg [3:0] milli_tens_2=0;
    reg [3:0] milli_hundreds_2=0;
    reg [3:0] sec_ones_2=0;


    SS_Driver ss_driver1 (CLK100MHZ, btn_reset,
                          sec_ones_1, milli_hundreds_1, milli_tens_1, milli_ones_1,
                          sec_ones_2, milli_hundreds_2, milli_tens_2, milli_ones_2,
                          SS_EN, SS);
    
    
    always @ (posedge CLK100MHZ) begin
    
        if(btn_reset) begin
            clkdiv_1 <= 0;
            milli_ones_1 <=0;  
            milli_tens_1 <= 0;
            milli_hundreds_1 <= 0;
            sec_ones_1 <=0;    
            
            clkdiv_2 <= 0;
            milli_ones_2 <=0;  
            milli_tens_2 <= 0;
            milli_hundreds_2 <= 0;
            sec_ones_2 <=0;  
        end
    
        if(t1_ena) begin
            clkdiv_1 <= clkdiv_1 + 1'b1;
            
            if(clkdiv_1>=100000) begin
                clkdiv_1 <= 0;
                milli_ones_1 <= milli_ones_1 + 1'b1;
                if(milli_ones_1>=9) begin
                    milli_ones_1 <= 0;
                    milli_tens_1 <= milli_tens_1 + 1'b1;
                    if(milli_tens_1>=9) begin
                        milli_tens_1 <= 0;
                        milli_hundreds_1 <= milli_hundreds_1 + 1'b1;
                        if(milli_hundreds_1>=9) begin
                            milli_hundreds_1 <= 0;
                            sec_ones_1 <= sec_ones_1 + 1'b1;
                            if(sec_ones_1>=9) begin
                                sec_ones_1 <= 0;
                            end
                        end
                    end
                 end
            end
            
            if(t2_ena) begin
                clkdiv_2 <= clkdiv_2 + 1'b1;
                
                if(clkdiv_2>=100000) begin
                    clkdiv_2 <= 0;
                    milli_ones_2 <= milli_ones_2 + 1'b1;
                    if(milli_ones_2>=9) begin
                        milli_ones_2 <= 0;
                        milli_tens_2 <= milli_tens_2 + 1'b1;
                        if(milli_tens_2>=9) begin
                            milli_tens_2 <= 0;
                            milli_hundreds_2 <= milli_hundreds_2 + 1'b1;
                            if(milli_hundreds_2>=9) begin
                                milli_hundreds_2 <= 0;
                                sec_ones_2 <= sec_ones_2 + 1'b1;
                                if(sec_ones_2>=9) begin
                                    sec_ones_2 <= 0;
                                end
                            end
                        end
                    end
                end
            end
        end
        
    end
    
    
    
    
    
endmodule
