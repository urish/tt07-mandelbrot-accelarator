# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2025, Uri Shaked

import os
from PIL import Image


IMAGE_WIDTH = 256
IMAGE_HEIGHT = 256
SCRIPT_DIR = os.path.dirname(__file__)
BITMAP_FILE = os.path.join(SCRIPT_DIR, "mandelbrot_out.bin")

if not os.path.exists(BITMAP_FILE):
    print(f"Error: {os.path.relpath(BITMAP_FILE)} does not exist!")
    print(
        "Please run mandelbrot.py on your Tiny Tapeout Demo board to generate it, "
        + "and then copy the file to this directory."
    )
    exit(1)

with open(BITMAP_FILE, "rb") as f:
    data = f.read()

image = Image.new("RGB", (IMAGE_WIDTH, IMAGE_HEIGHT))

for py in range(IMAGE_HEIGHT):
    for px in range(IMAGE_WIDTH):
        offset = py * IMAGE_WIDTH + px
        color = data[offset] if offset < len(data) else 0
        image.putpixel((px, py), (color, color, color))

image.save(os.path.join(SCRIPT_DIR, "mandelbrot_out.png"))
