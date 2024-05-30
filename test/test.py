# SPDX-FileCopyrightText: © 2024 Uri Shaked
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from driver import MandelbrotDriver


@cocotb.test()
async def test_mandelbrot(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test mandelbrot set")

    mandelbrot = MandelbrotDriver(dut)

    # Test some known points
    assert await mandelbrot.run(-2) == 32
    assert await mandelbrot.run(-2.01) == 1
    assert await mandelbrot.run(0) == 32
    assert await mandelbrot.run(1.2 + 1.4j) == 2
