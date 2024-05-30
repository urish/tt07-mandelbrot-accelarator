// The following module was generated by GPT-4o. Prompt:
// 
// ```
// module fp_multiply (
//     input wire [31:0] a_operand,
//     input wire [31:0] b_operand,
//     output reg o_exception,
//     output reg o_overflow,
//     output reg o_underflow,
//     output reg [31:0] o_result
// );
// 
// Implement IEEE-754 floating point multiplication.
// ```

`default_nettype none

module fp_multiply (
    input wire [31:0] a_operand,
    input wire [31:0] b_operand,
    output reg o_exception,
    output reg o_overflow,
    output reg o_underflow,
    output reg [31:0] o_result
);

  // Split the inputs into sign, exponent, and mantissa
  wire sign_a, sign_b, sign_result;
  wire [7:0] exponent_a, exponent_b, exponent_result;
  wire [23:0] mantissa_a, mantissa_b, mantissa_result;

  assign sign_a = a_operand[31];
  assign sign_b = b_operand[31];
  assign exponent_a = a_operand[30:23];
  assign exponent_b = b_operand[30:23];
  assign mantissa_a = {1'b1, a_operand[22:0]};
  assign mantissa_b = {1'b1, b_operand[22:0]};

  // Calculate the result sign
  assign sign_result = sign_a ^ sign_b;

  // Calculate the result exponent
  assign exponent_result = exponent_a + exponent_b - 8'd127;

  // Multiply the mantissas
  wire [47:0] product_mantissa;
  assign product_mantissa = mantissa_a * mantissa_b;

  // Normalize the result mantissa and adjust the exponent if necessary
  wire [22:0] normalized_mantissa;
  wire [ 7:0] adjusted_exponent;

  assign adjusted_exponent = (product_mantissa[47]) ? (exponent_result + 1) : exponent_result;
  assign normalized_mantissa = (product_mantissa[47]) ? product_mantissa[46:24] : product_mantissa[45:23];

  // Handle special cases
  always @(*) begin
    o_exception = 0;
    o_overflow = 0;
    o_underflow = 0;
    o_result = 32'd0;

    // Check for NaN and Infinity
    if ((exponent_a == 8'd255 && mantissa_a[22:0] != 0) || (exponent_b == 8'd255 && mantissa_b[22:0] != 0)) begin
      // NaN
      o_exception = 1;
      o_result = 32'h7FC00000;  // Quiet NaN
    end else if (exponent_a == 8'd255 || exponent_b == 8'd255) begin
      // Infinity
      o_result = {sign_result, 8'd255, 23'd0};
    end else if (exponent_a == 0 || exponent_b == 0) begin
      // Zero
      o_result = {sign_result, 8'd0, 23'd0};
    end else begin
      // Normal case
      if (adjusted_exponent >= 8'd255) begin
        // Overflow
        o_overflow = 1;
        o_result   = {sign_result, 8'd255, 23'd0};
      end else if (adjusted_exponent <= 8'd0) begin
        // Underflow
        o_underflow = 1;
        o_result = {sign_result, 8'd0, 23'd0};
      end else begin
        o_result = {sign_result, adjusted_exponent[7:0], normalized_mantissa[22:0]};
      end
    end
  end

endmodule