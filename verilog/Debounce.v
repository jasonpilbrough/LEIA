//////////////////////////////////////////////////////////////////////////////////
// UNIVERSITY OF CAPE TOWN
//
// Author: Keegan Crankshaw (adapted by Jason Pilbrough)
// 
// Project Name: LEIA
// Module Name: Debounce

// Target Devices: Nexys-A7-100T 
// Tool Versions: Vivado WebPack 2018
// Description: 
// 
// Debounces button input
//
// Revision: 1.0 - Final Version
//////////////////////////////////////////////////////////////////////////////////


module Debounce(
input clk,		//input clock
input Button,  //input reset signal (external button)
output reg Flag //output reset signal (delayed)
    );
//--------------------------------------------
reg previous_state;
reg [21:0]Count; //assume count is null on FPGA configuration

//--------------------------------------------
always @(posedge clk) begin  	//activates every clock edge
 //previous_state <= Button;		// localise the reset signal
   if (Button && Button != previous_state && &Count) begin		// reset block
    Flag <= 1'b1;					// reset the output to 1
	 Count <= 0;
	 previous_state <= 1;
  end 
  else if (Button && Button != previous_state) begin
	 Flag <= 1'b0;
	 Count <= Count + 1'b1;
  end 
  else begin
	 Flag <= 1'b0;
	 previous_state <= Button;
  end

end //always
 //--------------------------------------------
endmodule
//---------------------------------------------
