# SPDX-FileCopyrightText: © 2024 Uri Shaked
# SPDX-License-Identifier: Apache-2.0

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from driver import MandelbrotDriver
from mandelbrot import mandelbrot_calc


@cocotb.test()
async def test_mandelbrot(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    mandelbrot = MandelbrotDriver(dut)
    await mandelbrot.reset()

    dut._log.info("Test mandelbrot known points")

    assert await mandelbrot.run(-2 + -2j) == 1
    assert await mandelbrot.run(-1 + -0.5j) == 5
    assert await mandelbrot.run(-2) == 32
    assert await mandelbrot.run(-2.01) == 1
    assert await mandelbrot.run(0) == 32
    assert await mandelbrot.run(1.2 + 1.4j) == 2
    assert await mandelbrot.run(-0.2 + 0.83333333333333j) == 20


@cocotb.test()
async def test_random_points(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    mandelbrot = MandelbrotDriver(dut)
    await mandelbrot.reset()

    dut._log.info("Test 1000 pseudo-random points, up to 100 iterations each")
    rng = random.Random(42)  # Seed the random number generator
    test_iters = 100
    for i in range(1000):
        a = rng.random() * 4 - 2
        b = rng.random() * 4 - 2
        c = complex(a, b)
        result = await mandelbrot.run(c, test_iters)
        assert result == mandelbrot_calc(c, test_iters)
