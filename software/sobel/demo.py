import os
import serial
import sys
import time

import numpy as np
from PIL import Image

# Windows
if os.name == 'nt':
    ser = serial.Serial()
    ser.baudrate = 115200
    ser.port = 'COM11' # CHANGE THIS COM PORT
    ser.open()
else:
    ser = serial.Serial('/dev/ttyUSB0')
    ser.baudrate = 115200

# jump to IMem space to start the sobel program
command = "\n\rjal 10000000\r\n"
print("Sending command: {}".format(command))
for char in command:
    ser.write(bytearray([ord(char)]))
    time.sleep(0.01)

# capture output image from UART Rx
img_data = []
output_begin = False
output_end   = False
while output_end is False:
    serial_rx_data = ser.readline().decode("utf-8").rstrip()

    if serial_rx_data == "output_end":
        output_end = True
        print("Done!")

    # store image data
    if output_begin is True and output_end is False:
        img_data.append(int(serial_rx_data, 16))

    if serial_rx_data == "output_begin":
        output_begin = True
        print("Sending output data ...")

    # print benchmarking and checksum result
    if output_begin is False:
        print(serial_rx_data)

# Save output data to numpy array, and convert to image
img_np = np.reshape(np.array(img_data, dtype=np.uint8), (64, -1))
im = Image.fromarray(img_np)
im.save("output.jpg")

