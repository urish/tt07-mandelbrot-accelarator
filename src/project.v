/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_mandelbrot_accel (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  assign uo_out  = {7'b0, unbounded};
  assign uio_oe  = 0;
  assign uio_out = 0;

  wire i_start = ui_in[0];
  wire [3:0] Cr_in = uio_in[3:0];
  wire [3:0] Ci_in = uio_in[7:4];

  reg unbounded;

  reg [31:0] Cr_next;
  reg [31:0] Ci_next;

  reg [31:0] Zr;
  reg [31:0] Zi;
  reg [31:0] Cr;
  reg [31:0] Ci;

  wire [31:0] Rr;
  wire [31:0] Ri;

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

  wire Z_abs_greater_than_2 = ~Z_minus_four[31];  // |Z| > 2

  always @(posedge clk or negedge rst_n)
    if (~rst_n) begin
      Zr <= 0;
      Zi <= 0;
      Cr <= 0;
      Ci <= 0;
      Cr_next <= 0;
      Ci_next <= 0;
      unbounded <= 0;
    end else begin
      if (i_start) begin
        Zr <= 0;
        Zi <= 0;
        Cr <= Cr_next;
        Ci <= Ci_next;
      end else begin
        Zr <= Rr;
        Zi <= Ri;
        Cr_next <= {Cr_in, Cr_next[31:4]};
        Ci_next <= {Ci_in, Ci_next[31:4]};
        unbounded <= Z_abs_greater_than_2;
      end
    end

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in[7:1], 1'b0};

endmodule
