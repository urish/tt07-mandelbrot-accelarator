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

    # Set the clock period to 50 ns (20 MHz)
    clock = Clock(dut.clk, 50, units="ns")
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

    # Check that the number of iterations remains correct, even after some extra clock cycles
    assert mandelbrot.iter == 20
    await ClockCycles(dut.clk, 10)
    assert mandelbrot.iter == 20


@cocotb.test()
async def test_docs_example(dut):
    dut._log.info("Start")

    # Set the clock period to 50 ns (20 MHz)
    clock = Clock(dut.clk, 50, units="ns")
    cocotb.start_soon(clock.start())

    mandelbrot = MandelbrotDriver(dut)
    await mandelbrot.reset()

    dut._log.info("Test the example from docs/info.md")

    # Cr ← 1.2 (0x3f99999a)
    dut.uio_in.value = 0x9A
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0x99
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0x99
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0x3F
    dut.i_load_Cr.value = 1  # Strobe the load signal
    await ClockCycles(dut.clk, 1)
    dut.i_load_Cr.value = 0  # Clear the load signal

    # Ci ← 1.4 (0x3fb33333)
    dut.uio_in.value = 0x33
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0x33
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0xB3
    await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0x3F
    dut.i_load_Ci.value = 1  # Strobe the load signal
    dut.i_start.value = 1  # Strobe the start signal
    await ClockCycles(dut.clk, 1)
    dut.i_load_Ci.value = 0
    dut.i_start.value = 0
    await ClockCycles(dut.clk, 1)

    # We sample on the falling edge, to make sure the result is ready
    await ClockCycles(dut.clk, 1, rising=False)
    assert dut.o_unbounded.value == 0
    await ClockCycles(dut.clk, 1, rising=False)
    assert dut.o_unbounded.value == 1  # Unbounded after 2 iterations


@cocotb.test()
async def test_random_points(dut):
    dut._log.info("Start")

    # Set the clock period to 50 ns (20 MHz)
    clock = Clock(dut.clk, 50, units="ns")
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


@cocotb.test()
async def test_unbounded_stays_high(dut):
    dut._log.info("Start")

    # Set the clock period to 50 ns (20 MHz)
    clock = Clock(dut.clk, 50, units="ns")
    cocotb.start_soon(clock.start())

    mandelbrot = MandelbrotDriver(dut)
    await mandelbrot.reset()

    dut._log.info("Verify that the unbounded signal stays high")
    assert await mandelbrot.run(1.2 + 1.4j) == 2
    for i in range(100):
        await ClockCycles(dut.clk, 1)
        assert dut.o_unbounded.value == 1
