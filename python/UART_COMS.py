#====================================================================================
# UNIVERSITY OF CAPE TOWN
#
# Author: Jason Pilbrough and Samantha Ball
# 
# Create Date: 21.04.2020 18:42:46
# Project Name: LEIA
#
# Description: 
# 
# Monitors serial port to receive data sent by FPGA over UART
#
# Revision: 1.0 - Final Version
#====================================================================================


import serial
import time
from serial.tools import list_ports
from PIL import Image
import numpy as np


global SERIAL_CHANNEL; SERIAL_CHANNEL = "COM4"
global BAUD_RATE; BAUD_RATE =  8064000  #high baud rates must be a multiple of 115200
global TIMEOUT; TIMEOUT = 20
global IMAGE_HEIGHT; IMAGE_HEIGHT = 400 #160
global IMAGE_WIDTH; IMAGE_WIDTH = 520
global NUM_CHANNELS; NUM_CHANNELS = 3 #number of color channels in the image (greyscale=1, color = 3)
global BYTES_TO_READ; BYTES_TO_READ = IMAGE_HEIGHT * IMAGE_WIDTH * NUM_CHANNELS
global OUPUT_IMAGE_FILENAME; OUPUT_IMAGE_FILENAME = "output.jpg"


def receive_serial_data():
	print("Listening on serial channel" , SERIAL_CHANNEL, "... ( timeout =", TIMEOUT, "sec, baud =", BAUD_RATE,")")
	serial_coms = serial.Serial(SERIAL_CHANNEL, BAUD_RATE, timeout=TIMEOUT)
	data_raw = np.frombuffer(serial_coms.read(BYTES_TO_READ), dtype=np.uint8)

	
	if(len(data_raw)==0):
		serial_coms.flushInput()
		serial_coms.flushOutput()
		time.sleep(1)
		print("Serial timeout.\n")
		return 0;

	print("Recieved",len(data_raw),"bytes of data.")

	data_clean = (data_raw[0:BYTES_TO_READ]).reshape(IMAGE_HEIGHT,IMAGE_WIDTH, NUM_CHANNELS)


	print("Writing image to file...")
	
	im = Image.fromarray(data_clean, mode="RGB")
	im.save(OUPUT_IMAGE_FILENAME)
	
	serial_coms.flushInput()
	serial_coms.flushOutput()
	time.sleep(1)
	
	print("Done.\n")
	return 1;
 

def list_available_ports():
	print("Available ports:")
	ports = serial.tools.list_ports.comports()

	for port in ports:
		print(" *", port[0])



#list_available_ports();
cont = 1
while(cont):
	cont = receive_serial_data();
	
	
