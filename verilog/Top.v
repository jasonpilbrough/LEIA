`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// UNIVERSITY OF CAPE TOWN
//
// Author: Jason Pilbrough and Samantha Ball 
// 
// Create Date: 06.04.2020 19:57:36
// Project Name: LEIA
// Module Name: Top

// Target Devices: Nexys-A7-100T 
// Tool Versions: Vivado WebPack 2018
// Description: 
// 
// Top level module for LEIA lane detection system.
//
// Revision: 1.0 - Final Version
//////////////////////////////////////////////////////////////////////////////////


module Top(
    input CLK100MHZ,		//Clock - 100MHz
    input [4:0] BTN,		//Pushbuttons
    output [7:0] SS_EN,		//Seven segment display enable (anode)
    output [7:0] SS,		//Seven segment display (cathode)
    output [15:0]LED,		//LEDs
    output RGB1[2:0],		//RGB LED 1
    output RGB2[2:0],		//RGB LED 2
    output UART_TXD			//TX data line for UART
    );
    
    parameter[15:0] IMAGE_WIDTH = 16'd520; //image width in pixels
    parameter[17:0] TOTAL_PX = 18'd208000; //total number of pixels in image
    
    /* ============================= UART ================================*/
    reg uart_send = 0; // pulse for one clk cycle, uart_data must already be valid
    reg [7:0] uart_data; // must be valid when uart_send is set high
    wire uart_ready; // low during send, high when ready for next byte
    reg [1:0] image_chan_counter;  //used to send each pixel 3 times for 3 channel RGB color
    
    UART_TX_CTRL uart_tx(uart_send, uart_data, CLK100MHZ, uart_ready, UART_TXD);
    
    /* ========================== MEMORY I/O =============================
        Three image buffers - each image processing step reads from one buffer and then 
        writes the result to the next buffer. First buffer stores 8 bit px intensities,
        second and third store binary px intensities. Dont overwrite values in buffer 1
        as they are used to draw the final image.
    */
    
    // BUFFER 1
    reg ena_1 = 1; //enable line for buffer 1 - always high
    reg wea_1 = 0; //write enable line for buffer 1
    reg [17:0] addra_1=0; // address line for buffer 1
    reg [7:0] dina_1 = 0; // data in line for buffer 1
    wire [7:0] douta_1; // data out line for buffer 1 - NB takes two clock cycles for signal to be valid
    
    image_buffer IMG_BUFF_1 (
      .clka(CLK100MHZ),    // input wire clka
      .ena(ena_1),      // input wire ena
      .wea(wea_1),      // input wire [0 : 0] wea
      .addra(addra_1),  // input wire [17 : 0] addra
      .dina(dina_1),    // input wire [7 : 0] dina
      .douta(douta_1)  // output wire [7 : 0] douta
    );
    
	
	// BUFFER 2
    reg wea_b_2 = 0; //write enable line for buffer 2
    reg [17:0] addra_b_2=0; // address line for buffer 2
    reg dina_b_2 = 0; // data in line for buffer 2
    wire douta_b_2; // data out line forr buffer 2 - NB takes two clock cycles for signal to be valid
    
    binary_image_buffer BIN_IMG_BUFF_2 (
      .clka(CLK100MHZ),    // input wire clka
      .wea(wea_b_2),      // input wire [0 : 0] wea
      .addra(addra_b_2),  // input wire [17 : 0] addra
      .dina(dina_b_2),    // input wire [0 : 0] dina
      .douta(douta_b_2)  // output wire [0 : 0] douta
    );
    
    
    // BUFFER 3
    reg wea_b_3 = 0; //write enable line for buffer 2
    reg [17:0] addra_b_3=0; // address line for buffer 2
    reg dina_b_3 = 0; // data in line for buffer 2
    wire douta_b_3; // data out line forr buffer 2 - NB takes two clock cycles for signal to be valid
    
    binary_image_buffer BIN_IMG_BUFF_3 (
      .clka(CLK100MHZ),    // input wire clka
      .wea(wea_b_3),      // input wire [0 : 0] wea
      .addra(addra_b_3),  // input wire [17 : 0] addra
      .dina(dina_b_3),    // input wire [0 : 0] dina
      .douta(douta_b_3)  // output wire [0 : 0] douta
    );
   
    /* ======================= BUTTON DEBOUNCING =========================*/
    wire btn_send; //debounced line to trigger UART send
    Debounce debouncer1(CLK100MHZ, BTN[1], btn_send);
    wire btn_reset; //debounced line to trigger timer reset
    Debounce debouncer2(CLK100MHZ, BTN[0], btn_reset); 
    
    /* ============================= TIMER ==============================*/
    reg timer1_enable = 0; //set high to start timing, set low to stop timing
    reg timer2_enable = 0; //set high to start timing, set low to stop timing
    //timer output is shown on seven seg display
    Timer timer(CLK100MHZ, btn_reset, timer1_enable, timer2_enable,SS_EN, SS);
    
    /* ============= STEP 1&2: SOBEL FILTER + BINARIZATION ===============*/
    wire[7:0] sobel_in; //input line to sobel filter carrying current input pixel
    wire [7:0] sobel_out; //output line from sobel filter carrying current output pixel
    assign sobel_in[7:0] = douta_1[7:0]; //input to sobel filter comes from image buffer 1
    
    reg sobel_ena = 0;//sobel filter enable
    
    Sobel_Filter #(IMAGE_WIDTH) sobel(CLK100MHZ,sobel_in,btn_reset,sobel_ena, sobel_out);
    reg [2:0] sobel_timer_1 = 3'b000; //delay to account for latency of read from image buffer 1, at start
    reg [2:0] sobel_timer_2 = 3'b000; //delay to account for latency of read from image buffer 1, at end
    

    /* ====================== STEP 3: DILATION ==========================*/
    

    wire dilation_in; //input line to image dilation carrying current input pixel
    wire dilation_out; //output line from image dilation carrying current output pixel
    assign dilation_in = douta_b_2; //input to image dilation comes from image buffer 1
    reg dilation_ena = 0;//image dilation enable
    
    Image_Dilation dilate(CLK100MHZ, dilation_in, btn_reset, dilation_ena, dilation_out);
    reg [2:0] dilation_timer_1 = 3'b000; //delay to account for latency of read from image buffer 1, at start
    reg [2:0] dilation_timer_2 = 3'b000; //delay to account for latency of read from image buffer 1, at end
    
    
    /* ===================== STEP 4: HOUGH TRANSFORM ========================*/
    
    wire HT_pixel;
    assign HT_pixel = douta_b_3; //input pixel to HT comes from image buffer 2
    
    parameter[11:0] HT_y_coord_start = 12'd240; //y-coord to start HT from
    parameter[17:0] HT_addr_start = 18'd124800; //addr in mem to start HT from
    
    reg HT_ROI = 1'b0; // Region of Interest -  ROI_L (ROI=0), ROI_R (ROI=1)
    reg [11:0] HT_x_coord = 12'd0; //x-coord of current pixel
    reg [11:0] HT_y_coord = HT_y_coord_start; //y-coord of current pixel
    
    reg HT_enable = 1'b0;
    reg HT_reset = 1'b0; //resets HT back to initial state - NB takes many clock cycle to reset internals of HT, see HT_reset_complete
    wire HT_reset_complete; //goes high once internal HT has been reset
    reg [1:0] HT_clear_timer = 2'd0; //indicates to HT that a new pixel is ready to be processed
    
    wire HT_done; //signal to indicate voting for current xy coordinate is done
    wire [15:0] m_peak; //m (gradient) output from HT for current ROI - signed fixed point at bit 8
    wire [15:0] b_peak; //b (y-intercept) output from HT for current ROI - signed integer
    wire lane_departure; //indicates lane departure warning
    
    reg [15:0] ROI_L_m; //m (gradient) output from HT for ROI_L - signed fixed point at bit 8
    reg [15:0] ROI_L_b; //b (y-intercept) output from HT for ROI_L - signed integer
    reg [15:0] ROI_R_m; //m (gradient) output from HT for ROI_R - signed fixed point at bit 8
    reg [15:0] ROI_R_b; //b (y-intercept) output from HT for ROI_R - signed integer
    
    reg ROI_L_lane_departure = 1'b0;
    reg ROI_R_lane_departure = 1'b0;
    
    assign LED[15:0] = {14'd0, ROI_L_lane_departure, ROI_R_lane_departure};
    
    Hough_Transform HT(
        CLK100MHZ, HT_reset,
        HT_pixel,
        HT_ROI, HT_x_coord, HT_y_coord,
        |HT_clear_timer, HT_enable,
        HT_reset_complete,HT_done,
        m_peak, b_peak, lane_departure
        );
         
    /* ======================== LINE DRAWING ============================*/
    reg [11:0] LD_x_coord = 12'd0; //x-coord of current pixel
    reg [11:0] LD_y_coord = 12'd0; //y-coord of current pixel
    reg [7:0] LD_px_in = 8'd0; //current output pixel, if this pixel lies on a line, line px will be sent instead
    
    wire ROI_L_ispx; // high if the current pixel on lies on a line in the ROI_L
    wire ROI_R_ispx; // high if the current pixel on lies on a line in the ROI_R
    
    Line_Drawer LD_ROI_L(CLK100MHZ, ROI_L_m, ROI_L_b, LD_x_coord, LD_y_coord, ROI_L_ispx );
    Line_Drawer LD_ROI_R(CLK100MHZ, ROI_R_m, ROI_R_b, LD_x_coord, LD_y_coord, ROI_R_ispx );
    
    /* ========================= STATE MACHINE ==========================
        8 valid states:
        
            0 - BTN_WAIT - idle while waiting for button to start processing
            
            //the following states correspond to the various image processing steps
            1 - SOBEL_FILTER - apply sobel filter on image data from image buffer 1 - write result to image buffer 2
            2 - BINARIZATION - NOT IN USE ANYMORE (binaristation done at same time as sobel)
            3 - DILATION - perform image dilation to smooth any rough edges produced by sobel filter - write result to image buffer 3
            4 - HOUGH_TRANSFORM - apply Hough Transform (HT) to detect traffic lines on a single region of interest (ROI)
            5 - HOUGH_TRANSFORM_RESET - HT internal reset to prepare for processing on second region of interest (ROI_R)
            
            //the following states correspond to line drawing and transmitting the processed image via UART
            6 - UART_MEM_WAIT - wait for first byte to be retieved from image buffer before starting send sequence
            7 - UART_MEM_ACCESS - move next byte from memory to UART data line
            8 - LINE_DRAWING - replace any pixels that lie on the detected line with a blue px for (ROI_L) and a red px for (ROI_R)
            9 - UART_SEND - send each byte to UART module
    */
    reg [3:0]state = 4'd0; 
    reg [1:0]state_machine_timer =0; //delay to account for latency when reading from image buffers before data_access
    
    always @ (posedge CLK100MHZ) begin
    
        //reset button press
        if(btn_reset) begin
            
            //reset UART
            uart_send <= 0;
            uart_data <=0;
            image_chan_counter <= 2'd0;
            
            //reset MEMORY I/O
            ena_1 <= 1; 
            wea_1 <= 0;
            addra_1 <= 8'd0; 
            dina_1 <=  8'd0;  
            wea_b_2 <= 0;
            addra_b_2 <=  0; 
            dina_b_2 <=  0; 
            wea_b_3 <= 0;
            addra_b_3 <=  0; 
            dina_b_3 <=  0; 
            
            //reset TIMER
            timer1_enable <= 0;
            timer2_enable <= 0;
            
            //reset SOBEL FILTER
            sobel_timer_1 <= 3'd0;
            sobel_timer_2 <=  3'd0; 
            sobel_ena <= 0;
            
            //reset IMAGE DILATION
            dilation_timer_1 <= 3'd0;
            dilation_timer_2 <=  3'd0; 
            dilation_ena <= 0;
            
            //reset HOUGH TRANSFORM
            HT_enable <= 1'b0;
            HT_reset <= 1'b0; //internal HT should have already been reset, no need to set HT_reset high
            HT_clear_timer <= 2'd0;
            HT_ROI <= 1'b0;
            HT_x_coord <= 12'd0;
            HT_y_coord <= HT_y_coord_start;
            ROI_L_m <= 16'd0;
            ROI_L_b <= 16'd0;
            ROI_R_m <= 16'd0;
            ROI_R_b <= 16'd0;
            ROI_L_lane_departure <= 1'b0;
            ROI_R_lane_departure <= 1'b0;
            
            //reset LINE DRAWING
            LD_x_coord <= 12'd0; 
            LD_y_coord <= 12'd0; 
            LD_px_in <= 8'd0;
        
            //reset STATE MACHINE
            state <= 4'd0;
            state_machine_timer <= 2'd0;
            
        end
         
        
        case(state)
            4'd0: begin // state 0 - BTN_WAIT
                if(btn_send) begin
                    state <= 4'd1;
                    sobel_ena <= 1'b1;
                    timer1_enable <= 1'b1;
                    timer2_enable <= 1'b1;
                end
            end 
            
            4'd1: begin //state 1 - SOBEL_FILTER
                dina_b_2 <= sobel_out;
                
                if(addra_1 < TOTAL_PX) begin
                    if(sobel_timer_1>= 3'b011) begin
                        if(~wea_b_2) wea_b_2 <= 1;
                        else addra_b_2 <= addra_b_2 + 1'b1;
                    end else begin
                        sobel_timer_1 <= sobel_timer_1 + 1'b1;
                    end
                    addra_1 <= addra_1 + 1'b1;
                end else begin
                    if(sobel_timer_2>= 3'b100) begin
                        state <= 4'd2;
                        addra_1 <= 18'b0;
                        addra_b_2 <= 18'b0;
                        addra_b_3 <= 18'b0;
                        wea_b_2 <= 0;
                        state_machine_timer <= 2'b00;
                    end else begin
                        addra_b_2 <= addra_b_2 + 1'b1;
                        sobel_timer_2 <= sobel_timer_2 + 1'b1;
                    end
                end
            end
            
            4'd2: begin //state 2 - BINARISATION
        		//state not used anymore, proceed to next state
        		
                state <= 4'd3;
                dilation_ena <= 1; //enable dilation module

            end
            
            4'd3: begin //state 3 - DILATION
                dina_b_3 <= dilation_out;
                if(addra_b_2 < TOTAL_PX) begin
                    if(dilation_timer_1>= 3'b010) begin // if(dilation_timer_1>= 3'b011) begin
                        if(~wea_b_3) wea_b_3 <= 1;
                        else addra_b_3 <= addra_b_3 + 1'b1;
                    end else begin
                        dilation_timer_1 <= dilation_timer_1 + 1'b1;
                    end
                    addra_b_2 <= addra_b_2 + 1'b1;
                end else begin
                    if(dilation_timer_2>= 3'b100) begin
                        state <= 4'd4;
                        addra_1 <= 18'b0;
                        addra_b_2 <= 18'b0;
                        addra_b_3 <= HT_addr_start;
                        wea_b_3 <= 0;
                        state_machine_timer <= 2'b00;
                    end else begin
                        addra_b_3 <= addra_b_3 + 1'b1;
                        dilation_timer_2 <= dilation_timer_2 + 1'b1;
                    end
                end
            end
            
            4'd4: begin //state 4 - HOUGH_TRANSFORM
                HT_enable <= 1'b1;
                if(HT_done &&  ~|HT_clear_timer) begin
                    HT_clear_timer <= 2'b1;
                    addra_b_3 <= addra_b_3 + 1'b1;

                    HT_x_coord <= HT_x_coord + 1'b1;
                    if(HT_x_coord>= IMAGE_WIDTH - 1'b1) begin
                        HT_y_coord <= HT_y_coord + 1'b1;
                        HT_x_coord <= 12'd0;
                    end
                    
                end
                
                if(|HT_clear_timer) begin //if the clear_timer has been started, increment until max value is reached
                    HT_clear_timer <= HT_clear_timer + 1'b1;
                end
                
                //HT done - reset interal HT, and prepare for ROI_R or move to UART states for data transfer
                if(addra_b_3 >= TOTAL_PX) begin
                    if(~HT_ROI) begin
                        state <= 4'd5;
                        ROI_L_m <= m_peak;
                        ROI_L_b <= b_peak;
                        ROI_L_lane_departure <= lane_departure;
                    end else begin
                        state <= 4'd6;
                        ROI_R_m <= m_peak;
                        ROI_R_b <= b_peak;
                        ROI_R_lane_departure <= lane_departure;
                    end
                    
                    HT_enable <= 1'b0;
                    addra_1 <= 18'd0;
                    addra_b_2 <= 18'd0;
                    addra_b_3 <= 18'd0;
                    HT_reset <= 1'b1;
                    HT_clear_timer <= 2'd0;
                    HT_x_coord <= 12'd0;
                    HT_y_coord <= HT_y_coord_start;
                end
                
            end
            
            4'd5: begin //state 5 - HOUGH_TRANSFORM_RESET (internal reset before ROI_R)
                 
                 HT_reset <= 1'b0;
                 if(HT_reset_complete) begin
                    HT_ROI <= 1'b1;
                    state <= 4'd4;
                 end
                 
                addra_1 <= 18'd0;
                addra_b_2 <= 18'd0;
                addra_b_3 <= HT_addr_start;
                 
            end  
            
            4'd6 : begin //state 6 - UART_MEM_WAIT
                HT_reset <= 1'b0;
                timer2_enable <= 1'b0;
                state_machine_timer <= state_machine_timer + 1'b1;
                if(&state_machine_timer)  begin
                    state <= 4'd7;
                    image_chan_counter <= 2'd2; //essential for initial pass through next state
                    LD_x_coord <= 12'd0;
                    LD_y_coord <= 12'd0;
                end
            end
            
            4'd7: begin //state 7 - UART_MEM_ACCESS
                image_chan_counter <= image_chan_counter + 1'b1;  //send each pixel 3 times for 3 channel color
                if(image_chan_counter >= 2'd2) begin //after current px sent 3 times, move to next px
                    addra_1 <= addra_1+1'b1;
                    //addra_2 <= addra_2+1'b1;
                    image_chan_counter <= 2'd0;
                    LD_px_in <= douta_1;
                    //LD_px_in <= douta_2;
                    
                    LD_x_coord <= LD_x_coord + 1'b1;
                    if(LD_x_coord>= IMAGE_WIDTH - 1'b1) begin
                        LD_y_coord <= LD_y_coord + 1'b1;
                        LD_x_coord <= 12'd0;
                    end
                end
                
                state <= 4'd8;
                 
            end
            
            4'd8: begin // state 8 - LINE_DRAWING
                if(LD_y_coord<1 || LD_x_coord < 2) begin
                    uart_data <= 8'd0; //black pixels around edges of images
                end else if(ROI_L_ispx) begin //blue px
                    if(image_chan_counter==2) uart_data <= 8'd255; 
                    else uart_data <= 8'd0;
                end else if(ROI_R_ispx) begin //red px
                    if(image_chan_counter==0) uart_data <= 8'd255; 
                    else uart_data <= 8'd0;
                end else begin
                    uart_data <= LD_px_in;
                end
                
                state <= 4'd9;
            
            end
            
            4'd9: begin // state 9 - UART_SEND
                if(!uart_send) begin
                    if(uart_ready) begin
                        uart_send <= 1'b1; 
                    end   
                end
                else begin
                    uart_send <= 1'b0;
                    //if(addra_2<=TOTAL_PX || image_chan_counter) begin
                    if(addra_1<=TOTAL_PX || image_chan_counter) begin
                        state <= 4'd7;
                    end
                    else begin
                        state <= 4'd0;
                        timer1_enable <= 1'b0;
                    end
                end
            end
        endcase 
            
    end
    
    
endmodule

