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

  assign uo_out  = {o_iter, o_unbounded};
  assign uio_oe  = 0;
  assign uio_out = 0;

  wire i_start = ui_in[0];
  wire i_load_Cr = ui_in[1];
  wire i_load_Ci = ui_in[2];
  wire [7:0] data_in = uio_in;

  reg o_unbounded;
  reg [6:0] o_iter;

  reg [23:0] data_in_reg;
  wire [31:0] data_in_word = {data_in, data_in_reg};

  reg [31:0] Cr_next;
  reg [31:0] Ci_next;

  reg [31:0] Zr;
  reg [31:0] Zi;
  reg [31:0] Cr;
  reg [31:0] Ci;
  wire [31:0] Rr;
  wire [31:0] Ri;
  wire unbounded;

  mandelbrot_func mandelbrot (
      .Ci(Ci),
      .Cr(Cr),
      .Zr(Zr),
      .Zi(Zi),
      .Rr(Rr),
      .Ri(Ri),
      .unbounded(unbounded)
  );

  always @(posedge clk or negedge rst_n)
    if (~rst_n) begin
      Zr <= 0;
      Zi <= 0;
      Cr <= 0;
      Ci <= 0;
      Cr_next <= 0;
      Ci_next <= 0;
      o_unbounded <= 0;
      data_in_reg <= 0;
      o_iter <= 0;
    end else begin
      if (i_load_Cr) begin
        Cr_next <= data_in_word;
      end
      if (i_load_Ci) begin
        Ci_next <= data_in_word;
      end
      if (i_start) begin
        Zr <= i_load_Cr ? data_in_word : Cr_next;
        Zi <= i_load_Ci ? data_in_word : Ci_next;
        Cr <= i_load_Cr ? data_in_word : Cr_next;
        Ci <= i_load_Ci ? data_in_word : Ci_next;
        o_unbounded <= 0;
        o_iter <= 1;
      end else begin
        Zr <= Rr;
        Zi <= Ri;
        data_in_reg <= {data_in, data_in_reg[23:8]};
        if (unbounded) begin
          o_unbounded <= 1;
        end else if (!o_unbounded) begin
          o_iter <= o_iter + 1;
        end
      end
    end

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in[7:3], 1'b0};

endmodule
