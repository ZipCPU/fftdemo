////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	./longbimpy.v
// {{{
// Project:	FFT-DEMO, a verilator-based spectrogram display project
//
// Purpose:	A portable shift and add multiply, built with the knowledge
//	of the existence of a six bit LUT and carry chain.  That knowledge
//	allows us to multiply two bits from one value at a time against all
//	of the bits of the other value.  This sub multiply is called the
//	bimpy.
//
//	For minimal processing delay, make the first parameter the one with
//	the least bits, so that AWIDTH <= BWIDTH.
//
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
// {{{
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
// }}}
module	longbimpy #(
		// {{{
		parameter	IAW=8,	// The width of i_a, min width is 5
				IBW=12,	// The width of i_b, can be anything
			// The following three parameters should not be changed
			// by any implementation, but are based upon hardware
			// and the above values:
			// OW=IAW+IBW;	// The output width
		localparam	AW = (IAW<IBW) ? IAW : IBW,
				BW = (IAW<IBW) ? IBW : IAW,
				IW=(AW+1)&(-2),	// Internal width of A
				LUTB=2,	// How many bits to mpy at once
				TLEN=(AW+(LUTB-1))/LUTB // Rows in our tableau
		// }}}
	) (
		// {{{
		input	wire			i_clk, i_ce,
		input	wire	[(IAW-1):0]	i_a_unsorted,
		input	wire	[(IBW-1):0]	i_b_unsorted,
		output	reg	[(AW+BW-1):0]	o_r

`ifdef	FORMAL
		, output	wire	[(IAW-1):0]	f_past_a_unsorted,
		output	wire	[(IBW-1):0]	f_past_b_unsorted
`endif
		// }}}
	);
	// Local declarations
	// {{{
	// Swap parameter order, so that AW <= BW -- for performance
	// reasons
	wire	[AW-1:0]	i_a;
	wire	[BW-1:0]	i_b;
	generate begin : PARAM_CHECK
	if (IAW <= IBW)
	begin : NO_PARAM_CHANGE_I
		assign i_a = i_a_unsorted;
		assign i_b = i_b_unsorted;
	end else begin : SWAP_PARAMETERS_I
		assign i_a = i_b_unsorted;
		assign i_b = i_a_unsorted;
	end end endgenerate

	reg	[(IW-1):0]	u_a;
	reg	[(BW-1):0]	u_b;
	reg			sgn;

	reg	[(IW-1-2*(LUTB)):0]	r_a[0:(TLEN-3)];
	reg	[(BW-1):0]		r_b[0:(TLEN-3)];
	reg	[(TLEN-1):0]		r_s;
	reg	[(IW+BW-1):0]		acc[0:(TLEN-2)];
	genvar k;

	wire	[(BW+LUTB-1):0]	pr_a, pr_b;
	wire	[(IW+BW-1):0]	w_r;
	// }}}

	// First step:
	// Switch to unsigned arithmetic for our multiply, keeping track
	// of the along the way.  We'll then add the sign again later at
	// the end.
	//
	// If we were forced to stay within two's complement arithmetic,
	// taking the absolute value here would require an additional bit.
	// However, because our results are now unsigned, we can stay
	// within the number of bits given (for now).

	// u_a
	// {{{
	initial u_a = 0;
	generate begin : ABS
	if (IW > AW)
	begin : ABS_AND_ADD_BIT_TO_A
		always @(posedge i_clk)
		if (i_ce)
			u_a <= { 1'b0, (i_a[AW-1])?(-i_a):(i_a) };
	end else begin : ABS_A
		always @(posedge i_clk)
		if (i_ce)
			u_a <= (i_a[AW-1])?(-i_a):(i_a);
	end end endgenerate
	// }}}

	// sgn, u_b
	// {{{
	initial sgn = 0;
	initial u_b = 0;
	always @(posedge i_clk)
	if (i_ce)
	begin : ABS_B
		u_b <= (i_b[BW-1])?(-i_b):(i_b);
		sgn <= i_a[AW-1] ^ i_b[BW-1];
	end
	// }}}

	//
	// Second step: First two 2xN products.
	//
	// Since we have no tableau of additions (yet), we can do both
	// of the first two rows at the same time and add them together.
	// For the next round, we'll then have a previous sum to accumulate
	// with new and subsequent product, and so only do one product at
	// a time can follow this--but the first clock can do two at a time.
	bimpy	#(
		.BW(BW)
	) lmpy_0(
		// {{{
		.i_clk(i_clk),.i_reset(1'b0),.i_ce(i_ce),
		.i_a(u_a[(  LUTB-1):   0]),
		.i_b(u_b),
		.o_r(pr_a)
		// }}}
	);
	bimpy	#(
		.BW(BW)
	) lmpy_1(
		// {{{
		.i_clk(i_clk),.i_reset(1'b0),.i_ce(i_ce),
		.i_a(u_a[(2*LUTB-1):LUTB]),
		.i_b(u_b),
		.o_r(pr_b)
		// }}}
	);

	// r_s, r_a[0], r_b[0]
	// {{{
	initial r_s    = 0;
	initial r_a[0] = 0;
	initial r_b[0] = 0;
	always @(posedge i_clk)
	if (i_ce)
	begin
		r_a[0] <= u_a[(IW-1):(2*LUTB)];
		r_b[0] <= u_b;
		r_s <= { r_s[(TLEN-2):0], sgn };
	end
	// }}}

	// acc[0]
	// {{{
	initial acc[0] = 0;
	always @(posedge i_clk) // One clk after p[0],p[1] become valid
	if (i_ce)
		acc[0] <= { {(IW-LUTB){1'b0}}, pr_a}
		  +{ {(IW-(2*LUTB)){1'b0}}, pr_b, {(LUTB){1'b0}} };
	// }}}

	// r_a[TLEN-3:1], r_b[TLEN-3:1]
	// {{{
	generate begin : COPY
	// Keep track of intermediate values, before multiplying them
	if (TLEN > 3) begin : FOR
	for(k=0; k<TLEN-3; k=k+1)
	begin : GENCOPIES

		initial r_a[k+1] = 0;
		initial r_b[k+1] = 0;
		always @(posedge i_clk)
		if (i_ce)
		begin
			r_a[k+1] <= { {(LUTB){1'b0}},
				r_a[k][(IW-1-(2*LUTB)):LUTB] };
			r_b[k+1] <= r_b[k];
		end
	end end end endgenerate
	// }}}

	// acc[TLEN-2:1]
	// {{{
	generate begin : STAGES
	// The actual multiply and accumulate stage
	if (TLEN > 2) begin : FOR
	for(k=0; k<TLEN-2; k=k+1)
	begin : GENSTAGES
		wire	[(BW+LUTB-1):0] genp;

		// First, the multiply: 2-bits times BW bits
		bimpy #(
			.BW(BW)
		) genmpy(
			// {{{
			.i_clk(i_clk),.i_reset(1'b0),.i_ce(i_ce),
			.i_a(r_a[k][(LUTB-1):0]),
			.i_b(r_b[k]),
			.o_r(genp)
			// }}}
		);

		// Then the accumulate step -- on the next clock
		initial acc[k+1] = 0;
		always @(posedge i_clk)
		if (i_ce)
			acc[k+1] <= acc[k] + {{(IW-LUTB*(k+3)){1'b0}},
				genp, {(LUTB*(k+2)){1'b0}} };
	end end end endgenerate
	// }}}

	assign	w_r = (r_s[TLEN-1]) ? (-acc[TLEN-2]) : acc[TLEN-2];

	// o_r
	// {{{
	initial o_r = 0;
	always @(posedge i_clk)
	if (i_ce)
		o_r <= w_r[(AW+BW-1):0];
	// }}}

	// Make Verilator happy
	// {{{
	generate begin : GUNUSED
	if (IW > AW)
	begin : VUNUSED
		// verilator lint_off UNUSED
		wire	unused;
		assign	unused = &{ 1'b0, w_r[(IW+BW-1):(AW+BW)] };
		// verilator lint_on UNUSED
	end end endgenerate
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal property section
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

`define	ASSERT	assert
`ifdef	LONGBIMPY

	always @(posedge i_clk)
	if (!$past(i_ce))
		assume(i_ce);

`endif

	reg	[AW-1:0]	f_past_a	[0:TLEN];
	reg	[BW-1:0]	f_past_b	[0:TLEN];
	reg	[TLEN+1:0]	f_sgn_a, f_sgn_b;

	initial	f_past_a[0] = 0;
	initial	f_past_b[0] = 0;
	initial	f_sgn_a = 0;
	initial	f_sgn_b = 0;
	always @(posedge i_clk)
	if (i_ce)
	begin
		f_past_a[0] <= u_a;
		f_past_b[0] <= u_b;
		f_sgn_a[0] <= i_a[AW-1];
		f_sgn_b[0] <= i_b[BW-1];
	end

	generate for(k=0; k<TLEN; k=k+1)
	begin : F_PAST
		initial	f_past_a[k+1] = 0;
		initial	f_past_b[k+1] = 0;
		initial	f_sgn_a[k+1] = 0;
		initial	f_sgn_b[k+1] = 0;
		always @(posedge i_clk)
		if (i_ce)
		begin
			f_past_a[k+1] <= f_past_a[k];
			f_past_b[k+1] <= f_past_b[k];

			f_sgn_a[k+1]  <= f_sgn_a[k];
			f_sgn_b[k+1]  <= f_sgn_b[k];
		end
	end endgenerate

	always @(posedge i_clk)
	if (i_ce)
	begin
		f_sgn_a[TLEN+1] <= f_sgn_a[TLEN];
		f_sgn_b[TLEN+1] <= f_sgn_b[TLEN];
	end

	always @(posedge i_clk)
	begin
		assert(sgn == (f_sgn_a[0] ^ f_sgn_b[0]));
		assert(r_s[TLEN-1:0] == (f_sgn_a[TLEN:1] ^ f_sgn_b[TLEN:1]));
		assert(r_s[TLEN-1:0] == (f_sgn_a[TLEN:1] ^ f_sgn_b[TLEN:1]));
	end

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(i_ce)))
	begin
		if ($past(i_a)==0)
		begin
			`ASSERT(u_a == 0);
		end else if ($past(i_a[AW-1]) == 1'b0)
			`ASSERT(u_a == $past(i_a));

		if ($past(i_b)==0)
		begin
			`ASSERT(u_b == 0);
		end else if ($past(i_b[BW-1]) == 1'b0)
			`ASSERT(u_b == $past(i_b));
	end

	generate begin : F_ASSERT_ZERO
	// Keep track of intermediate values, before multiplying them
	if (TLEN > 3) begin : FOR
	for(k=0; k<TLEN-3; k=k+1)
	begin : ASSERT_GENCOPY
		always @(posedge i_clk)
		if (i_ce)
		begin
			if (f_past_a[k]==0)
			begin
				`ASSERT(r_a[k] == 0);
			end else if (f_past_a[k]==1)
				`ASSERT(r_a[k] == 0);
			`ASSERT(r_b[k] == f_past_b[k]);
		end
	end end end endgenerate

	generate begin : F_ACC
	// The actual multiply and accumulate stage
	if (TLEN > 2) begin : FOR
	for(k=0; k<TLEN-2; k=k+1)
	begin : ASSERT_GENSTAGE
		always @(posedge i_clk)
		if ((f_past_valid)&&($past(i_ce)))
		begin
			if (f_past_a[k+1]==0)
				`ASSERT(acc[k] == 0);
			if (f_past_a[k+1]==1)
				`ASSERT(acc[k] == f_past_b[k+1]);
			if (f_past_b[k+1]==0)
				`ASSERT(acc[k] == 0);
			if (f_past_b[k+1]==1)
			begin
				`ASSERT(acc[k][(2*k)+3:0]
						== f_past_a[k+1][(2*k)+3:0]);
				`ASSERT(acc[k][(IW+BW-1):(2*k)+4] == 0);
			end
		end
	end end end endgenerate

	wire	[AW-1:0]	f_past_a_neg = - f_past_a[TLEN];
	wire	[BW-1:0]	f_past_b_neg = - f_past_b[TLEN];

	wire	[AW-1:0]	f_past_a_pos = f_past_a[TLEN][AW-1]
					? f_past_a_neg : f_past_a[TLEN];
	wire	[BW-1:0]	f_past_b_pos = f_past_b[TLEN][BW-1]
					? f_past_b_neg : f_past_b[TLEN];

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(i_ce)))
	begin
		if ((f_past_a[TLEN]==0)||(f_past_b[TLEN]==0))
		begin
			`ASSERT(o_r == 0);
		end else if (f_past_a[TLEN]==1)
		begin
			if ((f_sgn_a[TLEN+1]^f_sgn_b[TLEN+1])==0)
			begin
				`ASSERT(o_r[BW-1:0] == f_past_b_pos[BW-1:0]);
				`ASSERT(o_r[AW+BW-1:BW] == 0);
			end else begin // if (f_sgn_b[TLEN+1]) begin
				`ASSERT(o_r[BW-1:0] == f_past_b_neg);
				`ASSERT(o_r[AW+BW-1:BW]
					== {(AW){f_past_b_neg[BW-1]}});
			end
		end else if (f_past_b[TLEN]==1)
		begin
			if ((f_sgn_a[TLEN+1] ^ f_sgn_b[TLEN+1])==0)
			begin
				`ASSERT(o_r[AW-1:0] == f_past_a_pos[AW-1:0]);
				`ASSERT(o_r[AW+BW-1:AW] == 0);
			end else begin
				`ASSERT(o_r[AW-1:0] == f_past_a_neg);
				`ASSERT(o_r[AW+BW-1:AW]
					== {(BW){f_past_a_neg[AW-1]}});
			end
		end else begin
			`ASSERT(o_r != 0);
			if (!o_r[AW+BW-1:0])
			begin
				`ASSERT((o_r[AW-1:0] != f_past_a[TLEN][AW-1:0])
					||(o_r[AW+BW-1:AW]!=0));
				`ASSERT((o_r[BW-1:0] != f_past_b[TLEN][BW-1:0])
					||(o_r[AW+BW-1:BW]!=0));
			end else begin
				`ASSERT((o_r[AW-1:0] != f_past_a_neg[AW-1:0])
					||(! (&o_r[AW+BW-1:AW])));
				`ASSERT((o_r[BW-1:0] != f_past_b_neg[BW-1:0])
					||(! (&o_r[AW+BW-1:BW]!=0)));
			end
		end
	end

	generate begin : F_ABS
	if (IAW <= IBW)
	begin : NO_PARAM_CHANGE_II
		assign f_past_a_unsorted = (!f_sgn_a[TLEN+1])
					? f_past_a[TLEN] : f_past_a_neg;
		assign f_past_b_unsorted = (!f_sgn_b[TLEN+1])
					? f_past_b[TLEN] : f_past_b_neg;
	end else begin : SWAP_PARAMETERS_II
		assign f_past_a_unsorted = (!f_sgn_b[TLEN+1])
					? f_past_b[TLEN] : f_past_b_neg;
		assign f_past_b_unsorted = (!f_sgn_a[TLEN+1])
					? f_past_a[TLEN] : f_past_a_neg;
	end end endgenerate
`ifdef	BUTTERFLY
	// The following properties artificially restrict the inputs
	// to this long binary multiplier to only those values whose
	// absolute value is 0..7.  It is used by the formal proof of
	// the BUTTERFLY to artificially limit the scope of the proof.
	// By the time the butterfly sees this code, it will be known
	// that the long binary multiply works.  At issue will no longer
	// be whether or not this works, but rather whether it works in
	// context.  For that purpose, we'll need to check timing, not
	// results.  Checking against inputs of +/- 1 and 0 are perfect
	// for that task.  The below assumptions (yes they are assumptions
	// just go a little bit further.
	//
	// THEREFORE, THESE PROPERTIES ARE NOT NECESSARY TO PROVING THAT
	// THIS MODULE WORKS, AND THEY WILL INTERFERE WITH THAT PROOF.
	//
	// This just limits the proof for the butterfly, the parent.
	// module that calls this one
	//
	// Start by assuming that all inputs have an absolute value less
	// than eight.
	always @(*)
		assume(u_a[AW-1:3] == 0);
	always @(*)
		assume(u_b[BW-1:3] == 0);

	// If the inputs have these properties, then so too do many of
	// our internal values.  ASSERT therefore that we never get out
	// of bounds
	generate begin : F_PAST_ZERO
	for(k=0; k<TLEN; k=k+1)
	begin : F
		always @(*)
		begin
			assert(f_past_a[k][AW-1:3] == 0);
			assert(f_past_b[k][BW-1:3] == 0);
		end
	end end endgenerate

	generate begin : F_ACC_ZERO
	for(k=0; k<TLEN-1; k=k+1)
	begin : F
		always @(*)
			assert(acc[k][IW+BW-1:6] == 0);
	end end endgenerate

	generate begin : F_RBZ
	for(k=0; k<TLEN-2; k=k+1)
	begin : F
		always @(*)
			assert(r_b[k][BW-1:3] == 0);
	end end endgenerate
`endif	// BUTTERFLY
`endif	// FORMAL
// }}}
endmodule
