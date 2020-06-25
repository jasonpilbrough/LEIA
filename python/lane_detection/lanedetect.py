#====================================================================================
# UNIVERSITY OF CAPE TOWN
#
# Author: Jason Pilbrough and Samantha Ball
# 
# Create Date: 03.04.2020 11:41:21
# Project Name: LEIA
#
# Description: 
# 
# Golden measure implementation of lane detection
#
# Revision: 1.0 - Final Version
#====================================================================================



# IMPORTS
from scipy.ndimage import filters
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image
import cv2  
import time;

START_TIME = time.time()

# GLOBAL VARIBALES

FILENAME = "road4.jpg"
H_WINDOW = 1
DIALATION_KERNEL_SIZE = 3


# READ IN IMAGES

img_original= Image.open(FILENAME).convert('L')
img_original = np.array(img_original.convert(mode='RGB')) # convert to 3 channel grey scale


img_lane_output = Image.open(FILENAME).convert('L')
img_lane_output = np.array(img_lane_output.convert(mode='RGB')) # convert to 3 channel grey scale

# input image as greyscale
img_original_grey = np.array(Image.open(FILENAME).convert('L'))


# CROP IMAGE
height,width = img_original_grey.shape[:2]
h_offset = int((1-H_WINDOW)*height)
img_grey_cropped = img_original_grey[h_offset:, :]


# ================= LIBRARY IMPLMENTATION =================

# SOBEL FILTERING
imx = np.zeros(img_grey_cropped.shape)
imy = np.zeros(img_grey_cropped.shape)
filters.sobel(img_grey_cropped,1,imx,cval=0.0)  # axis 1 is x
filters.sobel(img_grey_cropped,0,imy, cval=0.0) # axis 0 is y
#img_sobel = np.sqrt(imx**2+imy**2)
img_sobel = np.uint8((abs(imx)+abs(imy))/4)

#cv2.imwrite('image1_1.png', img_sobel)

# OTSU THRESHOLD BINARIZATION  
# applying Otsu thresholding as an extra flag in binary thresholding      
ret, img_thresh = cv2.threshold(img_sobel, 20, 255, cv2.THRESH_BINARY)

# IMAGE DIALATION
# Taking a matrix of size DIALATION_KERNEL_SIZE as the kernel 
kernel = np.ones((DIALATION_KERNEL_SIZE,DIALATION_KERNEL_SIZE), np.uint8) 
img_dilation = cv2.dilate(img_thresh, kernel, iterations=1)


# HOUGH TRANSFORM
middle_div = int(width/2)
HT_offset_h = int(round(3*height/5))
img_dilation_cropped = img_dilation[HT_offset_h:, :]

img_ROI_L = img_dilation_cropped#[:, 0:middle_div]
img_ROI_R = img_dilation_cropped#[:, middle_div:]

lines_left = cv2.HoughLines(img_ROI_L,1,np.pi/180,110)
end_now = False
for current_line in lines_left:
    if(end_now):
        break
    for rho,theta in current_line:
        if(theta*180/np.pi<1 or theta*180/np.pi>65):
            continue
        plot_line(img_lane_output, rho, theta, 0, HT_offset_h,'b')        
        print("lib - rho_L={0:.2f}, theta_L={1:.2f}".format(rho, np.rad2deg(theta)))
        end_now = True
        


lines_right = cv2.HoughLines(img_ROI_R,1,np.pi/180,110)
end_now = False
for current_line in lines_right:
    if(end_now):
        break
    for rho,theta in current_line:
        if(theta*180/np.pi<115 or theta*180/np.pi>179):
            continue
        plot_line(img_lane_output, rho, theta, 0, HT_offset_h,'r') 
        print("lib - rho_R={0:.2f}, theta_R={1:.2f}".format(rho, np.rad2deg(theta)))
        end_now = True
        

print("Runtime OpenCV [ms]:",(time.time() - START_TIME)*1000)


START_TIME = time.time()

# PREPARE OUTPUTS

output = np.concatenate((img_original[:int(h_offset/1.5), :], img_lane_output[int(h_offset/1.5):, :]), axis=0)


fig = plt.figure(figsize=(6,7))
plt.subplots_adjust(left=0.05, right=0.95, top=0.95, bottom=0.05)

ax0 = fig.add_subplot(321)
ax0.axis('off')
ax0.set_title('Original Image')
ax0.imshow(img_original_grey, cmap='gray')

ax1_l = fig.add_subplot(322)
ax1_l.axis('off')
ax1_l.set_title('1. Sobel Filter ')
ax1_l.imshow(img_sobel, cmap='gray')

ax2_l = fig.add_subplot(323)
ax2_l.axis('off')
ax2_l.set_title('2. Threshold Binarization ')
ax2_l.imshow(img_thresh, cmap='gray')


ax3_l = fig.add_subplot(324)
ax3_l.axis('off')
ax3_l.set_title('3. Image Dilation ')
ax3_l.imshow(img_dilation, cmap='gray')


ax4_l = fig.add_subplot(325)
ax4_l.axis('off')
ax4_l.set_title('4. Lane Detection ')
ax4_l.imshow(output)


plt.show()

