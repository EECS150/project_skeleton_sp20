import numpy as np
from matplotlib.image import imread
from PIL import Image

img_np = imread('lena.jpg')

height, width, _ = img_np.shape

img_gray_np = np.zeros((height, width), dtype=np.uint8)

print("static uint32_t img_data[{}] =".format(height * width))
print("{")
for y in range(height):
  for x in range(width):
    r = float(img_np[y][x][0] / 255)
    g = float(img_np[y][x][1] / 255)
    b = float(img_np[y][x][2] / 255)

    gs = 0.2989 * r + 0.5870 * g + 0.1140 * b
    gs = int(gs * 255)
    img_gray_np[y][x] = gs
    if y == height - 1 and x == width - 1:
        print("{}".format(gs))
    else:
        print("{},".format(gs))

print("};")

#im = Image.fromarray(img_gray_np)
#im.save("gray.jpg")
