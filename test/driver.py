import struct
from cocotb.triggers import ClockCycles


def tofloat(val: int, rounding=None):
    value = struct.unpack(">f", val.to_bytes(4, "big"))[0]
    if rounding:
        return round(value, rounding)
    return value


def float_to_int(f):
    return int.from_bytes(struct.pack(">f", f), "big")


class MandelbrotDriver:
    def __init__(self, dut):
        self._dut = dut
        self.round = 6

    async def set_cr_ci(self, cr: float, ci: float):
        cr = float_to_int(cr)
        ci = float_to_int(ci)
        for i in range(8):
            ci_bits = (ci >> (i * 4)) & 0xF
            cr_bits = (cr >> (i * 4)) & 0xF
            self._dut.uio_in.value = (ci_bits << 4) | cr_bits
            await ClockCycles(self._dut.clk, 1)

    async def start(self):
        self._dut.ui_in.value = 1
        await ClockCycles(self._dut.clk, 1)
        self._dut.ui_in.value = 0
        await ClockCycles(self._dut.clk, 1)

    async def run(self, c: complex, iter: int = 32):
        await self.set_cr_ci(c.real, c.imag)
        await self.start()
        for i in range(iter):
            await ClockCycles(self._dut.clk, 1)
            if self.unbounded:
                return i
        return iter

    @property
    def unbounded(self):
        return self._dut.uo_out.value.integer & 0x1

    # All the signals below are internal and are only available during RTL simulation
    @property
    def Cr(self):
        return tofloat(self._dut.user_project.Cr.value.integer, self.round)

    @property
    def Ci(self):
        return tofloat(self._dut.user_project.Ci.value.integer, self.round)

    @property
    def Zr(self):
        return tofloat(self._dut.user_project.Zr.value.integer, self.round)

    @property
    def Zi(self):
        return tofloat(self._dut.user_project.Zi.value.integer, self.round)

    @property
    def Zr_squared(self):
        return tofloat(self._dut.user_project.Zr_squared.value.integer, self.round)

    @property
    def Zi_squared(self):
        return tofloat(self._dut.user_project.Zi_squared.value.integer, self.round)

    @property
    def ZrZi(self):
        return tofloat(self._dut.user_project.ZrZi.value.integer, self.round)

    @property
    def Rr(self):
        return tofloat(self._dut.user_project.Rr.value.integer, self.round)

    @property
    def Ri(self):
        return tofloat(self._dut.user_project.Ri.value.integer, self.round)

    @property
    def Z_abs_squared(self):
        return tofloat(self._dut.user_project.Z_abs_squared.value.integer, self.round)

    @property
    def Z_minus_four(self):
        return tofloat(self._dut.user_project.Z_minus_four.value.integer, self.round)
