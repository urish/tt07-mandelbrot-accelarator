# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2025, Uri Shaked

import struct
from ttboard.mode import RPMode
import ttboard.util.platform as platform

UI_START = 1 << 0
UI_LOAD_CR = 1 << 1
UI_LOAD_CI = 1 << 2

UO_UNBOUNDED = 1 << 0


class MandelbrotDriver:
    def __init__(self, tt):
        self.tt = tt
        self.tt.shuttle.tt_um_mandelbrot_accel.enable()
        self.tt.mode = RPMode.ASIC_RP_CONTROL
        self.tt.ui_in.value = 0
        self.tt.uio_in.value = 0
        self.tt.uio_oe_pico.value = 0xFF
        self.reset()

    def reset(self):
        self.tt.reset_project(True)
        self.tt.clock_project_once()
        self.tt.reset_project(False)
        self._Cr = None
        self._Ci = None

    def _load_register(self, value: float):
        value_int = int.from_bytes(struct.pack(">f", value), "big")
        platform.write_ui_in_byte(0)
        platform.write_uio_byte(value_int & 0xFF)
        self.tt.clock_project_once()
        platform.write_uio_byte((value_int >> 8) & 0xFF)
        self.tt.clock_project_once()
        platform.write_uio_byte((value_int >> 16) & 0xFF)
        self.tt.clock_project_once()
        platform.write_uio_byte((value_int >> 24) & 0xFF)

    def run(self, Cr: float, Ci: float, max_iter: int = 64) -> int:
        if self._Cr != Cr:
            self._load_register(Cr)
            self._Cr = Cr
            platform.write_ui_in_byte(UI_LOAD_CR)
            self.tt.clock_project_once()

        if self._Ci != Ci:
            self._load_register(Ci)
            self._Ci = Ci
            platform.write_ui_in_byte(UI_LOAD_CI | UI_START)
        else:
            platform.write_ui_in_byte(UI_START)

        self.tt.clock_project_once()

        self.tt.ui_in.value = 0
        for iter in range(max_iter):
            if self.tt.uo_out.value & UO_UNBOUNDED:
                return iter
            self.tt.clock_project_once()

        return max_iter


IMAGE_WIDTH = 256
IMAGE_HEIGHT = 256
X_RANGE = (-2.5, 1.5)
Y_RANGE = (-2.0, 2.0)
MAX_ITER = 64


def export_bitmap(output_file: str = "mandelbrot_out.bin"):
    global mandelbrot
    xmin, xmax = X_RANGE
    ymin, ymax = Y_RANGE

    with open(output_file, "wb") as f:
        row_data = bytearray(IMAGE_WIDTH)
        for py in range(IMAGE_HEIGHT):
            print(f"Row {py} of {IMAGE_HEIGHT}")
            for px in range(IMAGE_WIDTH):
                # Convert pixel coordinate to complex number
                x = xmin + (xmax - xmin) * px / (IMAGE_WIDTH - 1)
                y = ymin + (ymax - ymin) * py / (IMAGE_HEIGHT - 1)

                # Compute the number of iterations
                m = mandelbrot.run(x, y, MAX_ITER)

                # Color mapping
                color = 255 - int(m * 255 / MAX_ITER)
                row_data[px] = color

            f.write(row_data)


mandelbrot = MandelbrotDriver(tt)
print("mandelbrot.run(1.2, 1.4) =", mandelbrot.run(1.2, 1.4))
print("To export the bitmap, type: export_bitmap()")
print("Exporting the bitmap takes about three hours.")
