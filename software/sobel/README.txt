# Sobel Edge Detection Demo

# Given an input image I, we would like to generate an output image that has the edges
# strengthened. As a first step, Sobel edge detection performs two convolutions
using two different 3x3 kernels which results to the matrices Gx and Gy.
# Next, the output image is computed as follows:

sqrt(Gx * Gx + Gy * Gy)

# We will use our conv2D accelerator to do the first step, and let the CPU
# do the second step.

# For this demo, we don't need to open "screen" to interface with UART.
# Instead, we use Python package PySerial to communicate with UART.

# To generate a MIF file to load to the FPGA, run "make conv=HW" if you want to
# use conv2D accelerator to run the convolution operations. If you want to test
# with just software code, run "make"

# Send the MIF file to FPGA. It will take a while to send all the bytes to the FPGA
../../script/hex_to_serial sobel.mif 30000000

# Once the MIF file is loaded, run the demo using the following command.
# The script captures the output from the UART and convert it to the image "output.jpg".
# Check if it indeed performs edge detection on the given input image!

python3 demo.py

# The expected checksum is 00078c0a
