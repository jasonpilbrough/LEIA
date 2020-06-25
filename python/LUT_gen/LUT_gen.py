#====================================================================================
# UNIVERSITY OF CAPE TOWN
#
# Author: Jason Pilbrough and Samantha Ball
# 
# Create Date: 012.04.2020 12:11:51
# Project Name: LEIA
#
# Description: 
# 
# Create .coe files required for FPGA
#
# Revision: 1.0 - Final Version
#====================================================================================


# IMPORTS
from scipy.ndimage import filters
import numpy as np
from PIL import Image
import cv2  



# GLOBAL VARIBALES
FILENAME = "road_night.jpg"
H_WINDOW = 1

# READ IN IMAGES

#read original color image for plotting
img_original_color = np.array(Image.open(FILENAME))

# input image as greyscale
img_original_grey = np.array(Image.open(FILENAME).convert('L'))

# CROP IMAGE
height,width = img_original_grey.shape[:2]
h_offset = int((1-H_WINDOW)*height)
img_grey_cropped = img_original_grey[h_offset:, :]

print(img_grey_cropped.shape)

f = open("LUT_image_3_520x400.coe", "w")
f.write("memory_initialization_radix=10;\n")
f.write("memory_initialization_vector=")

for i in range(0, img_grey_cropped.shape[0]):
    for j in range(0, img_grey_cropped.shape[1]):
        val = str(img_grey_cropped[i][j])+","
        f.write(val)

f.write(";")

f.close()


f_start = 1 #in deg
f_end = 65 #in deg
f_step = 1 #in deg
nbits = 11 # excluding the sign bit

w = np.arange(f_start*np.pi/180,f_end*np.pi/180, f_step*np.pi/180)
sin_w = np.sin(w)
sin_quantised = (sin_w * 2**nbits)//1
cos_w = np.cos(w)
cos_quantised = (cos_w * 2**nbits)//1
#sin_unquantised = sin_quantised / (2**nbits)

cot_w = cos_w/sin_w 
sin_inv = 1/sin_w
cot_quantised = (cot_w * 2**8)//1
sin_inv_quantised = (sin_inv * 2**8)//1

for i in range(0, len(sin_quantised)):
    if(sin_quantised[i]<0):
        sin_quantised[i] = (2**(nbits+1))+sin_quantised[i]


for i in range(0, len(cos_quantised)):
    if(cos_quantised[i]<0):
        cos_quantised[i] = (2**(nbits+1))+cos_quantised[i]


print("SINE LUT")
print(sin_quantised)

print("COS LUT")
print(cos_quantised)

f = open("LUT_sin.coe", "w")
f.write("memory_initialization_radix=10;\n")
f.write("memory_initialization_vector=")

for i in range(0, len(sin_quantised)):
        val = str(int(sin_quantised[i]))+"," 
        f.write(val)

f.write(";")
f.close()


f = open("LUT_cos.coe", "w")
f.write("memory_initialization_radix=10;\n")
f.write("memory_initialization_vector=")

for i in range(0, len(cos_quantised)):
        val = str(int(cos_quantised[i]))+"," 
        f.write(val)

f.write(";")
f.close()

f = open("LUT_cot.coe", "w")
f.write("memory_initialization_radix=10;\n")
f.write("memory_initialization_vector=")

for i in range(0, len(cot_quantised)):
        val = str(int(cot_quantised[i]))+"," 
        f.write(val)

f.write(";")
f.close()

f = open("LUT_sin_inv.coe", "w")
f.write("memory_initialization_radix=10;\n")
f.write("memory_initialization_vector=")

for i in range(0, len(sin_inv_quantised)):
        val = str(int(sin_inv_quantised[i]))+"," 
        f.write(val)

f.write(";")
f.close()



