////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	./longbimpy.v
//
// Project:	A General Purpose Pipelined FFT Implementation
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
//
// Copyright (C) 2015-2019, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
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
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
module	longbimpy(i_clk, i_ce, i_a_unsorted, i_b_unsorted, o_r);
	parameter	IAW=8,	// The width of i_a, min width is 5
			IBW=12,	// The width of i_b, can be anything
			// The following three parameters should not be changed
			// by any implementation, but are based upon hardware
			// and the above values:
			OW=IAW+IBW;	// The output width
	localparam	AW = (IAW<IBW) ? IAW : IBW,
			BW = (IAW<IBW) ? IBW : IAW,
			IW=(AW+1)&(-2),	// Internal width of A
			LUTB=2,	// How many bits we can multiply by at once
			TLEN=(AW+(LUTB-1))/LUTB; // Nmbr of rows in our tableau
	input	wire			i_clk, i_ce;
	input	wire	[(IAW-1):0]	i_a_unsorted;
	input	wire	[(IBW-1):0]	i_b_unsorted;
	output	reg	[(AW+BW-1):0]	o_r;

	//
	// Swap parameter order, so that AW <= BW -- for performance
	// reasons
	wire	[AW-1:0]	i_a;
	wire	[BW-1:0]	i_b;
	generate if (IAW <= IBW)
	begin : NO_PARAM_CHANGE
		assign i_a = i_a_unsorted;
		assign i_b = i_b_unsorted;
	end else begin : SWAP_PARAMETERS
		assign i_a = i_b_unsorted;
		assign i_b = i_a_unsorted;
	end endgenerate

	reg	[(IW-1):0]	u_a;
	reg	[(BW-1):0]	u_b;
	reg			sgn;

	reg	[(IW-1-2*(LUTB)):0]	r_a[0:(TLEN-3)];
	reg	[(BW-1):0]		r_b[0:(TLEN-3)];
	reg	[(TLEN-1):0]		r_s;
	reg	[(IW+BW-1):0]		acc[0:(TLEN-2)];
	genvar k;

	// First step:
	// Switch to unsigned arithmetic for our multiply, keeping track
	// of the along the way.  We'll then add the sign again later at
	// the end.
	//
	// If we were forced to stay within two's complement arithmetic,
	// taking the absolute value here would require an additional bit.
	// However, because our results are now unsigned, we can stay
	// within the number of bits given (for now).
	initial u_a = 0;
	generate if (IW > AW)
	begin : ABS_AND_ADD_BIT_TO_A
		always @(posedge i_clk)
			if (i_ce)
				u_a <= { 1'b0, (i_a[AW-1])?(-i_a):(i_a) };
	end else begin : ABS_A
		always @(posedge i_clk)
			if (i_ce)
				u_a <= (i_a[AW-1])?(-i_a):(i_a);
	end endgenerate

	initial sgn = 0;
	initial u_b = 0;
	always @(posedge i_clk)
	if (i_ce)
	begin : ABS_B
		u_b <= (i_b[BW-1])?(-i_b):(i_b);
		sgn <= i_a[AW-1] ^ i_b[BW-1];
	end

	wire	[(BW+LUTB-1):0]	pr_a, pr_b;

	//
	// Second step: First two 2xN products.
	//
	// Since we have no tableau of additions (yet), we can do both
	// of the first two rows at the same time and add them together.
	// For the next round, we'll then have a previous sum to accumulate
	// with new and subsequent product, and so only do one product at
	// a time can follow this--but the first clock can do two at a time.
	bimpy	#(BW) lmpy_0(i_clk,i_ce,u_a[(  LUTB-1):   0], u_b, pr_a);
	bimpy	#(BW) lmpy_1(i_clk,i_ce,u_a[(2*LUTB-1):LUTB], u_b, pr_b);

	initial r_s    = 0;
	initial r_a[0] = 0;
	initial r_b[0] = 0;
	always @(posedge i_clk)
		if (i_ce) r_a[0] <= u_a[(IW-1):(2*LUTB)];
	always @(posedge i_clk)
		if (i_ce) r_b[0] <= u_b;
	always @(posedge i_clk)
		if (i_ce) r_s <= { r_s[(TLEN-2):0], sgn };

	initial acc[0] = 0;
	always @(posedge i_clk) // One clk after p[0],p[1] become valid
	if (i_ce) acc[0] <= { {(IW-LUTB){1'b0}}, pr_a}
		  +{ {(IW-(2*LUTB)){1'b0}}, pr_b, {(LUTB){1'b0}} };

	generate // Keep track of intermediate values, before multiplying them
	if (TLEN > 3) for(k=0; k<TLEN-3; k=k+1)
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
	end endgenerate

	generate // The actual multiply and accumulate stage
	if (TLEN > 2) for(k=0; k<TLEN-2; k=k+1)
	begin : GENSTAGES
		wire	[(BW+LUTB-1):0] genp;

		// First, the multiply: 2-bits times BW bits
		bimpy #(BW) genmpy(i_clk,i_ce,r_a[k][(LUTB-1):0],r_b[k], genp);

		// Then the accumulate step -- on the next clock
		initial acc[k+1] = 0;
		always @(posedge i_clk)
		if (i_ce)
			acc[k+1] <= acc[k] + {{(IW-LUTB*(k+3)){1'b0}},
				genp, {(LUTB*(k+2)){1'b0}} };
	end endgenerate

	wire	[(IW+BW-1):0]	w_r;
	assign	w_r = (r_s[TLEN-1]) ? (-acc[TLEN-2]) : acc[TLEN-2];

	initial o_r = 0;
	always @(posedge i_clk)
	if (i_ce)
		o_r <= w_r[(AW+BW-1):0];

	generate if (IW > AW)
	begin : VUNUSED
		// verilator lint_off UNUSED
		wire	[(IW-AW)-1:0]	unused;
		assign	unused = w_r[(IW+BW-1):(AW+BW)];
		// verilator lint_on UNUSED
	end endgenerate

endmodule
