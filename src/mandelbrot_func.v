/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/** 
 * This module calculates one iteration of the Mandelbrot set function:
 * R = Z^2 + C
 * 
 * In addition, it checks if the given input Z is not a member of the Mandelbrot set, setting
 * unbounded to 1 when |Z| > 2.
 */
module mandelbrot_func (
    input wire [31:0] Ci,
    input wire [31:0] Cr,
    input wire [31:0] Zr,
    input wire [31:0] Zi,
    output wire [31:0] Rr,
    output wire [31:0] Ri,
    output wire unbounded
);

  // ZrZi = Zr * Zi
  wire [31:0] ZrZi;
  fp_multiply m1 (
      .a_operand(Zr),
      .b_operand(Zi),
      .o_result(ZrZi),
      .o_exception(),
      .o_overflow(),
      .o_underflow()
  );

  // Zr_squared = Zr * Zr
  wire [31:0] Zr_squared;
  fp_multiply m2 (
      .a_operand(Zr),
      .b_operand(Zr),
      .o_result(Zr_squared),
      .o_exception(),
      .o_overflow(),
      .o_underflow()
  );

  // Zi_squared = Zi * Zi
  wire [31:0] Zi_squared;
  fp_multiply m3 (
      .a_operand(Zi),
      .b_operand(Zi),
      .o_result(Zi_squared),
      .o_exception(),
      .o_overflow(),
      .o_underflow()
  );


  wire [31:0] Z2r;
  wire [31:0] Z2i;

  // Z2r = Zr_squared - Zi_squared
  fp_add_sub sub1 (
      .a_operand(Zr_squared),
      .b_operand(Zi_squared),
      .op_subtract(1'b1),
      .o_result(Z2r)
  );

  // Z2i = 2 * Zr * Zi
  fp_add_sub add1 (
      .a_operand(ZrZi),
      .b_operand(ZrZi),
      .op_subtract(1'b0),
      .o_result(Z2i)
  );

  // Rr = Z2r + Cr
  fp_add_sub add2 (
      .a_operand(Z2r),
      .b_operand(Cr),
      .op_subtract(1'b0),
      .o_result(Rr)
  );

  // Ri = Z2i + Ci
  fp_add_sub add3 (
      .a_operand(Z2i),
      .b_operand(Ci),
      .op_subtract(1'b0),
      .o_result(Ri)
  );

  wire [31:0] Z_abs_squared;
  wire [31:0] four_ieee754 = 32'h40800020;  // ~4.0

  // |Z|^2 = Zr^2 + Zi^2
  fp_add_sub add4 (
      .a_operand(Zr_squared),
      .b_operand(Zi_squared),
      .op_subtract(1'b0),
      .o_result(Z_abs_squared)
  );

  wire [31:0] Z_minus_four;
  // calculate |Z|^2 - 4
  fp_add_sub sub3 (
      .a_operand(Z_abs_squared),
      .b_operand(four_ieee754),
      .op_subtract(1'b1),
      .o_result(Z_minus_four)
  );

  assign unbounded = ~Z_minus_four[31];  // |Z| > 2
endmodule
