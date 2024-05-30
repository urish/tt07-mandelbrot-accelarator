# SPDX-License-Identifier: Apache-2.0
# Description: Mandelbrot set test function


def mandelbrot_calc(c: complex, max_iters=256):
    z = 0
    n = 0
    while abs(z) <= 2 and n < max_iters:
        z = z * z + c
        n += 1
    return n
