// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
module fp_add_sub (
    input  wire [31:0] a_operand,
    input  wire [31:0] b_operand,
    input  wire op_subtract,
    output reg  [31:0] o_result
);


  add_sub a(
    .in_x(a_operand),
    .in_y(b_operand),
    .operation(op_subtract),
    .round_mode(3'b000),
    .out_z(o_result)
  );

endmodule

module add_sub( 
  input  wire [31:0] in_x,
  input  wire [31:0] in_y,
  input  wire        operation,
  input  wire [2:0]  round_mode,
  output wire [31:0] out_z,
  output wire [4:0]  exceptions);

  wire        sign_x, sign_y;
  wire [7:0]  exp_x, exp_y, exp_a, exp_b, subnorm_exp, norm_exp;
  wire [22:0] mant_x, mant_y, mant_a, mant_b;

  wire        x_is_zero, x_is_inf, x_is_qNaN, x_is_sNaN;
  wire        y_is_zero, y_is_inf, y_is_qNaN, y_is_sNaN;
  wire        a_is_subnorm, b_is_subnorm;
  wire        hd_bit_a, hd_bit_b;

  wire [26:0] arg1, arg2;
  wire [26:0] rt_shift_mant;
  wire [26:0] lt_shft_mant, norm_sum;
  wire [26:0] mant_sum;
  wire [23:0] rounded_mant;
  wire [31:0] inter_result, of_result;

  wire        comp, exp_shft_comp;
  wire        operator_y, subtract;
  wire        cout, cout_check;

  wire [7:0]  exp_diff;
  wire [4:0]  ld_zero_cnt, inc_dec_exp_amt;
  wire [7:0]  inter_shft_amt, shft_amt;
  wire        round_of;

  wire        sign_z;
  wire [7:0]  exp_z;
  wire [22:0] mant_z;
	
  wire        invalid_operation;
  wire        divide_by_zero;
  wire        overflow;
  wire        underflow;
  wire        inexact;
  wire [9:0]  x_check_res, y_check_res;

  // checking inputs for special values
  special_check #(8, 24) check_x (.in(in_x), .result(x_check_res));
  special_check #(8, 24) check_y (.in(in_y), .result(y_check_res));

  assign x_is_zero = x_check_res[3] | x_check_res[4];
  assign x_is_inf  = x_check_res[0] | x_check_res[7];
  assign x_is_qNaN = x_check_res[9];
  assign x_is_sNaN = x_check_res[8];

  assign y_is_zero = y_check_res[3] | y_check_res[4];
  assign y_is_inf  = y_check_res[0] | y_check_res[7];
  assign y_is_qNaN = y_check_res[9];
  assign y_is_sNaN = y_check_res[8];

  // unpacking inputs
  assign sign_x = in_x[31];
  assign sign_y = in_y[31];
  assign exp_x  = in_x[30:23];
  assign exp_y  = in_y[30:23];
  assign mant_x = in_x[22:0];
  assign mant_y = in_y[22:0];

  // comparing both numbers
  assign comp = (exp_y > exp_x) ? 1'b1 : (exp_y != exp_x) ? 1'b0 : (mant_y > mant_x);

  // determining operation to be performed
  assign operator_y = sign_y ^ operation;
  assign subtract   = sign_x ^ operator_y;

  // determining output sign
  assign sign_z = x_is_zero ? (operator_y) : (y_is_zero ? sign_x : 
                  (subtract ? (comp ? operator_y : sign_x) : sign_x));
	
  // swapping operands
  assign {exp_a, mant_a} = comp ? {exp_y, mant_y} : {exp_x, mant_x};
  assign {exp_b, mant_b} = comp ? {exp_x, mant_x} : {exp_y, mant_y};

  // checking for subnormal numbers
  assign a_is_subnorm = (|exp_a == 0);
  assign b_is_subnorm = (|exp_b == 0);

  // checking difference in exponents
  assign exp_diff = (a_is_subnorm | b_is_subnorm) & (exp_a != exp_b) ? (exp_a - exp_b - 1) 
                    : (exp_a - exp_b);

  // generating hidden bits
  assign hd_bit_a = !a_is_subnorm;
  assign hd_bit_b = !b_is_subnorm;
	
  // right shifting mantissa to make exponents equal
  right_shifter exp_equalizer (.mantisa({hd_bit_b, mant_b, 3'b000}), .shift_amount(exp_diff), 
                               .out(rt_shift_mant));
	
  // computing sum of the mantissas
  assign arg1 = {hd_bit_a, mant_a, 3'b0};
  assign arg2 = subtract ? (~rt_shift_mant + 27'b1) : rt_shift_mant;

  assign {cout, mant_sum} = {1'b0,arg1} + {1'b0,arg2};
  assign cout_check       = cout & ~subtract;

  leading_zero norm_dist_checker (.in(mant_sum[26:3]), .out(ld_zero_cnt));
	
  // computing the shift amount
  assign inter_shft_amt = a_is_subnorm ? 8'b0 : {3'b0, ld_zero_cnt};
  assign exp_shft_comp  = (exp_a <= inter_shft_amt);
  assign shft_amt       = exp_shft_comp ? (exp_a - |exp_a) : inter_shft_amt;

  left_shifter #(27) norm_shifter (.mantisa(mant_sum), .shift_amount(shft_amt), 
                             .out(lt_shft_mant));

  // determining the exponent increment/decrement
  assign norm_sum        = cout_check ? {cout, mant_sum[26:2], |mant_sum[1:0]} : lt_shft_mant;
  assign inc_dec_exp_amt = a_is_subnorm ? 5'b0 : cout_check ? 5'b1 : shft_amt;
	
  rounding add_sub_rounder (.sign(sign_z), .mantisa(norm_sum), .round_mode(round_mode), 
                            .rounded_mantisa(rounded_mant), .rounding_overflow(round_of));

  // determine exponent in case of normal numbers
  assign norm_exp = cout_check ? (exp_a + inc_dec_exp_amt + round_of) : 
                    (exp_a - inc_dec_exp_amt + round_of);

  // determine exponent in case of subnormal numbers
  assign subnorm_exp = (rounded_mant[23] & !(|norm_exp)) ? 8'b1 : 
                       (norm_exp - ((hd_bit_a | hd_bit_b) & exp_shft_comp & !rounded_mant[23]));
	
  assign {exp_z, mant_z} = x_is_zero ? {exp_y, mant_y} : (y_is_zero ? {exp_x, mant_x} : 
                           ((mant_x == mant_y) & (exp_x == exp_y) & subtract ? 'd0 : 
                           {subnorm_exp, rounded_mant[22:0]}));

  // result check for special numbers
  assign inter_result = (x_is_qNaN | y_is_qNaN) ? {1'h0, 8'hff, 23'h400000} : 
                        ((x_is_inf | y_is_inf) ? {sign_z, 8'hff, 23'h0} : ((exp_z == 8'hff) ? 
                        {sign_z, exp_z, 23'd0} : {sign_z, exp_z, mant_z}));

  assign invalid_operation = !(x_is_qNaN | y_is_qNaN) & (x_is_inf & y_is_inf & subtract) | 
                               x_is_sNaN | y_is_sNaN;

  // does not occur in addition subtraction
  assign divide_by_zero = 0;

  assign overflow = !(x_is_qNaN | y_is_qNaN) & &exp_z & !(x_is_inf | y_is_inf | x_is_qNaN | 
                      y_is_qNaN | x_is_sNaN | y_is_sNaN);
	
  // determining result in case of overflow
  assign of_result = ({32{(round_mode == 3'h0) | (round_mode == 3'h4)}} & {sign_z, 8'hff, 23'h0}) |
                     ({32{round_mode == 3'h1}} & {sign_z, 8'hfe, 23'h7fffff}) |
                     ({32{round_mode == 3'h2}} & (sign_z ? {1'h1, 8'hff, 23'h0} : 
                                                 {1'h0, 8'hfe, 23'h7fffff})) |
                     ({32{round_mode == 3'h3}} & (sign_z ? {1'h1, 8'hfe, 23'h7fffff} : 
                                                 {1'h0, 8'hff, 23'h0}));

  // does not occur in addition subtraction
  assign underflow = 0;

  assign inexact = !(x_is_qNaN | y_is_qNaN) & (|norm_sum[2:0] | overflow | underflow) & 
                   !(x_is_zero | y_is_zero | x_is_qNaN | y_is_qNaN | x_is_sNaN | y_is_sNaN | 
                     x_is_inf  | y_is_inf);

  assign exceptions = {invalid_operation, divide_by_zero, overflow, underflow, inexact};

  // assign output
  assign out_z = overflow ? of_result : underflow ? 32'd0 : invalid_operation ? 
                 {1'h0, 8'hff, 23'h400000} : inter_result;

endmodule


module left_shifter #(parameter mant = 24) 
(
	input  wire [mant-1:0] mantisa,
	input  wire [7:0] shift_amount,

	output wire [mant-1:0] out
);

	wire [mant-1:0] temp;

	assign temp  = mantisa << shift_amount;
	assign out   = {temp[mant-1:1], mantisa[0]};

endmodule

module right_shifter 
(
  input  wire [26:0] mantisa,
  input  wire [7:0] shift_amount,

  output wire [26:0] out
);

  assign out = ({27{(shift_amount[7:0]==8'd0)}}  &         mantisa)                          |
              ({27{(shift_amount[7:0]==8'd1)}}  & {1'd0,  mantisa[26:2],   |mantisa[1:0]})  |
              ({27{(shift_amount[7:0]==8'd2)}}  & {2'd0,  mantisa[26:3],   |mantisa[2:0]})  |
              ({27{(shift_amount[7:0]==8'd3)}}  & {3'd0,  mantisa[26:4],   |mantisa[3:0]})  |
              ({27{(shift_amount[7:0]==8'd4)}}  & {4'd0,  mantisa[26:5],   |mantisa[4:0]})  |
              ({27{(shift_amount[7:0]==8'd5)}}  & {5'd0,  mantisa[26:6],   |mantisa[5:0]})  |
              ({27{(shift_amount[7:0]==8'd6)}}  & {6'd0,  mantisa[26:7],   |mantisa[6:0]})  |
              ({27{(shift_amount[7:0]==8'd7)}}  & {7'd0,  mantisa[26:8],   |mantisa[7:0]})  |
              ({27{(shift_amount[7:0]==8'd8)}}  & {8'd0,  mantisa[26:9],   |mantisa[8:0]})  |
              ({27{(shift_amount[7:0]==8'd9)}}  & {9'd0,  mantisa[26:10],  |mantisa[9:0]})  |
              ({27{(shift_amount[7:0]==8'd10)}} & {10'd0, mantisa[26:11],  |mantisa[10:0]}) |
              ({27{(shift_amount[7:0]==8'd11)}} & {11'd0, mantisa[26:12],  |mantisa[11:0]}) |
              ({27{(shift_amount[7:0]==8'd12)}} & {12'd0, mantisa[26:13],  |mantisa[12:0]}) |
              ({27{(shift_amount[7:0]==8'd13)}} & {13'd0, mantisa[26:14],  |mantisa[13:0]}) |
              ({27{(shift_amount[7:0]==8'd14)}} & {14'd0, mantisa[26:15],  |mantisa[14:0]}) |
              ({27{(shift_amount[7:0]==8'd15)}} & {15'd0, mantisa[26:16],  |mantisa[15:0]}) |
              ({27{(shift_amount[7:0]==8'd16)}} & {16'd0, mantisa[26:17],  |mantisa[16:0]}) |
              ({27{(shift_amount[7:0]==8'd17)}} & {17'd0, mantisa[26:18],  |mantisa[17:0]}) |
              ({27{(shift_amount[7:0]==8'd18)}} & {18'd0, mantisa[26:19],  |mantisa[18:0]}) |
              ({27{(shift_amount[7:0]==8'd19)}} & {19'd0, mantisa[26:20],  |mantisa[19:0]}) |
              ({27{(shift_amount[7:0]==8'd20)}} & {20'd0, mantisa[26:21],  |mantisa[20:0]}) |
              ({27{(shift_amount[7:0]==8'd21)}} & {21'd0, mantisa[26:22],  |mantisa[21:0]}) |
              ({27{(shift_amount[7:0]==8'd22)}} & {22'd0, mantisa[26:23],  |mantisa[22:0]}) |
              ({27{(shift_amount[7:0]==8'd23)}} & {23'd0, mantisa[26:24],  |mantisa[23:0]}) |
              ({27{(shift_amount[7:0]==8'd24)}} & {24'd0, mantisa[26:25],  |mantisa[24:0]}) |
              ({27{(shift_amount[7:0]==8'd25)}} & {25'd0, mantisa[26],     |mantisa[25:0]}) |
              ({27{(shift_amount[7:0]>=8'd26)}} & {26'd0,                  |mantisa[26:0]});
endmodule


module rounding
(
  input  wire sign,
  input  wire [26:0] mantisa,
  input  wire [2:0] round_mode,

  output wire [23:0] rounded_mantisa,
  output wire rounding_overflow
);
  
  wire [23:0] rne, rtz, rdn, rup, rmm;
  wire rne_overflow, rtz_overflow, rdn_overflow, rup_overflow, rmm_overflow;

  assign {rne_overflow, rne} = mantisa[2] ? (|mantisa[1:0] ? ({1'b0, mantisa[26:3]} + 1'b1) 
                               : ({1'b0, mantisa[26:3]} + mantisa[3])) : {1'b0, mantisa[26:3]};

  assign {rtz_overflow, rtz} = {1'b0, mantisa[26:3]};

  assign {rdn_overflow, rdn} = |mantisa[2:0] ? (sign ? ({1'b0, mantisa[26:3]} + 1'b1) 
                                : {1'b0, mantisa[26:3]}) : {1'b0, mantisa[26:3]};

  assign {rup_overflow, rup} = |mantisa[2:0] ? (sign ? {1'b0, mantisa[26:3]} 
                                  : ({1'b0, mantisa[26:3]} + 1'b1)) : {1'b0, mantisa[26:3]};
  assign {rmm_overflow, rmm} = mantisa[2] ? ({1'b0, mantisa[26:3]} + 1'b1) : {1'b0, mantisa[26:3]};

  assign rounded_mantisa     = ({24{round_mode == 3'b000}} & rne) |
                               ({24{round_mode == 3'b001}} & rtz) |
                               ({24{round_mode == 3'b010}} & rdn) |
                               ({24{round_mode == 3'b011}} & rup) |
                               ({24{round_mode == 3'b100}} & rmm);

  assign rounding_overflow   = ((round_mode == 3'b000) & rne_overflow) |
                               ((round_mode == 3'b001) & rtz_overflow) |
                               ((round_mode == 3'b010) & rdn_overflow) |
                               ((round_mode == 3'b011) & rup_overflow) |
                               ((round_mode == 3'b100) & rmm_overflow);

endmodule

module leading_zero
(
  input  wire [23:0] in,

  output wire [4:0] out
);
  assign out[4:0]       = ({5{(in[22]  & (&(~(in[23]))))}}    & 5'd1)  |			 
 		                      ({5{(in[21]  & (&(~(in[23:22]))))}} & 5'd2)  |
 		                      ({5{(in[20]  & (&(~(in[23:21]))))}} & 5'd3)  |
 		                      ({5{(in[19]  & (&(~(in[23:20]))))}} & 5'd4)  |
 		                      ({5{(in[18]  & (&(~(in[23:19]))))}} & 5'd5)  |
 		                      ({5{(in[17]  & (&(~(in[23:18]))))}} & 5'd6)  |
 		                      ({5{(in[16]  & (&(~(in[23:17]))))}} & 5'd7)  |
 		                      ({5{(in[15]  & (&(~(in[23:16]))))}} & 5'd8)  |
 		                      ({5{(in[14]  & (&(~(in[23:15]))))}} & 5'd9)  |
 		                      ({5{(in[13]  & (&(~(in[23:14]))))}} & 5'd10) |
 		                      ({5{(in[12]  & (&(~(in[23:13]))))}} & 5'd11) |
 		                      ({5{(in[11]  & (&(~(in[23:12]))))}} & 5'd12) |
 		                      ({5{(in[10]  & (&(~(in[23:11]))))}} & 5'd13) |
 		                      ({5{(in[9]   & (&(~(in[23:10]))))}} & 5'd14) |
 		                      ({5{(in[8]   & (&(~(in[23: 9]))))}} & 5'd15) |
 		                      ({5{(in[7]   & (&(~(in[23: 8]))))}} & 5'd16) |
 		                      ({5{(in[6]   & (&(~(in[23: 7]))))}} & 5'd17) |
 		                      ({5{(in[5]   & (&(~(in[23: 6]))))}} & 5'd18) |
 		                      ({5{(in[4]   & (&(~(in[23: 5]))))}} & 5'd19) |
 		                      ({5{(in[3]   & (&(~(in[23: 4]))))}} & 5'd20) |
 		                      ({5{(in[2]   & (&(~(in[23: 3]))))}} & 5'd21) |
 		                      ({5{(in[1]   & (&(~(in[23: 2]))))}} & 5'd22) |
 		                      ({5{(in[0]   & (&(~(in[23: 1]))))}} & 5'd23);

endmodule

module special_check #(parameter  exp_width = 8, parameter mant_width = 24) 
(
  input  wire [(exp_width + mant_width-1):0] in,

  output wire [9:0] result
);

  wire is_pos_zero;
  wire is_neg_zero;
  wire is_pos_inf;
  wire is_neg_inf;
  wire is_pos_subnorm;
  wire is_neg_subnorm;
  wire is_pos_norm;
  wire is_neg_norm;
  wire is_qNaN;
  wire is_sNaN;

  wire                    sign;
  wire [exp_width-1:0]    exp;
  wire [(mant_width-2):0] sig;

  wire exp_zero, exp_one, sig_zero; 


  assign {sign, exp, sig} = in;

  assign exp_zero         = |exp ? 1'b0 : 1'b1;
  assign sig_zero         = |sig ? 1'b0 : 1'b1;     
  assign exp_one          = &exp ? 1'b1 : 1'b0;

  assign is_pos_zero      = !sign     & exp_zero  & sig_zero;
  assign is_neg_zero      =  sign     & exp_zero  & sig_zero;
  assign is_pos_subnorm   = !sign     & exp_zero  & !sig_zero;
  assign is_neg_subnorm   =  sign     & exp_zero  & !sig_zero;
  assign is_pos_inf       = !sign     & exp_one   & sig_zero; 
  assign is_neg_inf       =  sign     & exp_one   & sig_zero; 
  assign is_qNaN          =  exp_one  & !sig_zero & sig[22];
  assign is_sNaN          =  exp_one  & !sig_zero & !sig[22];

  assign is_pos_norm      = (is_pos_zero | is_neg_zero | is_pos_subnorm | is_neg_subnorm | is_pos_inf | is_neg_inf | 
			                      is_qNaN | is_sNaN) ? 1'b0 : ~sign ? 1'b1 : 1'b0;
 
  assign is_neg_norm      = (is_pos_zero | is_neg_zero | is_pos_subnorm | is_neg_subnorm | is_pos_inf | is_neg_inf | 
			                      is_qNaN | is_sNaN) ? 1'b0 : sign ? 1'b1 : 1'b0; 

  assign result           = {is_qNaN, is_sNaN, is_pos_inf, is_pos_norm, is_pos_subnorm, is_pos_zero, is_neg_zero, 
                            is_neg_subnorm, is_neg_norm, is_neg_inf};
endmodule
