# Mandelbrot Set Accelerator Bringup

Run the [mandelbrot.py](mandelbrot.py) script on the Tiny Tapeout Demo board.

Then execute the `export_bitmap()` function in the MicroPython REPL to start exporting a 256x256 bitmap of the Mandelbrot set using the accelerator on the Tiny Tapeout 7 chip.

Exporting the bitmap takes about 24 minutes, mainly due to MicroPython's slow execution speed - we could speed it up by using the PIO peripheral in conjunction with DMA.

Once the bitmap is exported, copy the `mandelbrot_out.bin` file to your computer, and then run the [export_png.py](export_png.py) script to convert the bitmap to a PNG image.

The final image should look like this:

![Mandelbrot set](mandelbrot_out.png)
