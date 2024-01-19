////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./bimpy.v
// {{{
// Project:	FFT-DEMO, a verilator-based spectrogram display project
//
// Purpose:	A simple 2-bit multiply based upon the fact that LUT's allow
//		6-bits of input.  In other words, I could build a 3-bit
//	multiply from 6 LUTs (5 actually, since the first could have two
//	outputs).  This would allow multiplication of three bit digits, save
//	only for the fact that you would need two bits of carry.  The bimpy
//	approach throttles back a bit and does a 2x2 bit multiply in a LUT,
//	guaranteeing that it will never carry more than one bit.  While this
//	multiply is hardware independent (and can still run under Verilator
//	therefore), it is really motivated by trying to optimize for a
//	specific piece of hardware (Xilinx-7 series ...) that has at least
//	4-input LUT's with carry chains.
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
module	bimpy #(
		// {{{
		parameter	BW=18, // Number of bits in i_b
		localparam	LUTB=2 // Number of bits in i_a for our LUT multiply
		// }}}
	) (
		// {{{
		input	wire			i_clk, i_reset, i_ce,
		input	wire	[(LUTB-1):0]	i_a,
		input	wire	[(BW-1):0]	i_b,
		output	reg	[(BW+LUTB-1):0]	o_r
		// }}}
	);

	// Local declarations
	// {{{
	wire	[(BW+LUTB-2):0]	w_r;
	wire	[(BW+LUTB-3):1]	c;
	// }}}

	assign	w_r =  { ((i_a[1])?i_b:{(BW){1'b0}}), 1'b0 }
				^ { 1'b0, ((i_a[0])?i_b:{(BW){1'b0}}) };
	assign	c = { ((i_a[1])?i_b[(BW-2):0]:{(BW-1){1'b0}}) }
			& ((i_a[0])?i_b[(BW-1):1]:{(BW-1){1'b0}});

	// o_r
	// {{{
	initial o_r = 0;
	always @(posedge i_clk)
	if (i_reset)
		o_r <= 0;
	else if (i_ce)
		o_r <= w_r + { c, 2'b0 };
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

	always @(posedge i_clk)
	if ((!f_past_valid)||($past(i_reset)))
	begin
		`ASSERT(o_r == 0);
	end else if ($past(i_ce))
	begin
		if ($past(i_a)==0)
		begin
			`ASSERT(o_r == 0);
		end else if ($past(i_a) == 1)
			`ASSERT(o_r == $past(i_b));

		if ($past(i_b)==0)
		begin
			`ASSERT(o_r == 0);
		end else if ($past(i_b) == 1)
			`ASSERT(o_r[(LUTB-1):0] == $past(i_a));
	end
`endif
// }}}
endmodule
