////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	subfildown.v
//
// Project:	FFT-DEMO, a verilator-based spectrogram display project
//
// Purpose:	This module implements a fairly generic 1/M downsampler.  The
//		data must comes in at less than M/(Filterlen+1) rate.  The core
//	produces a new o_ce value associated with the data going out at a
//	maximum rate 1/(Filterlen+1).  A downsampling FIR filter is applied in
//	the middle to prevent aliasing.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2018-2019, Gisselquist Technology, LLC
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
//
module	subfildown(i_clk, i_reset, i_wr_tap, i_tap,
		i_ce, i_sample, o_ce, o_result);
	//
	parameter	IW=16,OW=24,TW=12;
	parameter	LGNDOWN=7;
	parameter [LGNDOWN-1:0]	NDOWN=23;
	parameter	LGNTAPS=10;
	parameter [0:0]	FIXED_TAPS = 1'b0;
	parameter	INITIAL_COEFFS = "";
	parameter	SHIFT=2;
	localparam	AW = IW+TW+LGNTAPS;

	input	wire		i_clk, i_reset;
	//
	input	wire		i_wr_tap;
	input	wire [(TW-1):0]	i_tap;
	//
	input	wire		i_ce;
	input	wire [(IW-1):0]	i_sample;
	//
	output	reg		o_ce;
	output	reg [(OW-1):0]	o_result;


	reg	[(TW-1):0]	cmem	[0:((1<<LGNTAPS)-1)];
	reg	[(IW-1):0]	dmem	[0:((1<<LGNTAPS)-1)];

	///////////////////////////////////////////////
	//
	// Adjust the taps we are using
	//
	///////////////////////////////////////////////
	//
	// Generate the decimator via: genfil 1024 decimator 23 0.45
	//
	generate if (FIXED_TAPS)
	begin
		initial $readmemh(INITIAL_COEFFS, cmem);

		// Make Verilator's -Wall happy
		// verilator lint_off UNUSED
		wire	[TW:0]	ignored_inputs;
		assign	ignored_inputs = { i_wr_tap, i_tap };
		// verilator lint_on  UNUSED
	end else begin
		// Coeff memory write index
		reg	[LGNTAPS-1:0]	wr_tap_index;

		initial	wr_tap_index = 0;
		always @(posedge i_clk)
		if (i_reset)
			wr_tap_index <= 0;
		else if (i_wr_tap)
			wr_tap_index <= wr_tap_index+1'b1;

		if (INITIAL_COEFFS != 0)
			initial $readmemh(INITIAL_COEFFS, cmem);
	
		always @(posedge i_clk)
		if (i_wr_tap)
			cmem[wr_tap_index] <= i_tap;

	end endgenerate

	///////////////////////////////////////////////
	//
	// Write data logic
	//
	///////////////////////////////////////////////
	reg	[LGNDOWN-1:0]	countdown;
	reg	[LGNTAPS-1:0]	wraddr;
	reg			first_sample;

	initial	first_sample = 0;
	initial	wraddr    = 0;
	initial	countdown = NDOWN-1;
	always @(posedge i_clk)
	if (i_ce)
	begin
		dmem[wraddr] <= i_sample;
		wraddr <= wraddr + 1'b1;
		countdown <= countdown - 1;
		first_sample <= (countdown == 0);
		if (countdown == 0)
			countdown <= NDOWN-1;
	end

	reg	[LGNTAPS-1:0]	didx, tidx;
	reg			running;
	initial	didx = 0;
	initial	tidx = 0;
	initial running = 0;
	always @(posedge i_clk)
	if ((first_sample)&&(!running)&&(!i_ce))
	begin
		didx <= wraddr;
		tidx <= 0;
		running <= 1'b0;
	end else if ((running)||((first_sample)&&(i_ce)))
	begin
		didx <= didx + 1'b1;
		tidx <= tidx + 1'b1;
		if ((first_sample)&&(i_ce))
			running <= 1'b1;
		else if (&tidx)
			running <= 1'b0;
	end
		
	reg	d_ce;
	reg	signed	[IW-1:0]	dval;
	reg	signed	[TW-1:0]	cval;
	always @(posedge i_clk)
	begin
		d_ce <= (first_sample)&&(i_ce);
		dval <= dmem[didx];
		cval <= cmem[tidx];
	end

	reg	p_run, p_ce;
	initial	p_run = 0;
	initial	p_ce  = 0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		p_run <= 0;
		p_ce  <= 0;
	end else begin
		p_run <= (tidx != 0);
		p_ce  <= d_ce;
	end

	reg	signed [IW+TW-1:0]	product;
	always @(posedge i_clk)
		product <= dval * cval;

	reg	[AW-1:0]	accumulator;
	initial	accumulator = 0;
	always @(posedge i_clk)
	if (i_reset)
		accumulator <= 0;
	else if (p_ce)
		accumulator <= { {(LGNTAPS){product[IW+TW-1]}}, product };
	else if (p_run)
		accumulator <= accumulator
			+ { {(LGNTAPS){product[IW+TW-1]}}, product };

	wire	[AW-1:0]	rounded_result;

	generate if (OW == AW-SHIFT)
	begin
		assign	rounded_result = accumulator[AW-SHIFT-1:AW-SHIFT-OW];
	end else if (AW-SHIFT > OW)
	begin
		wire	[AW-1:0]	prerounded = {accumulator[AW-SHIFT-1:0],
						{(SHIFT){1'b0}} };
		assign	rounded_result = prerounded 
				+ { {(OW){1'b0}}, prerounded[AW-OW-1],
					{(AW-OW-1){!prerounded[AW-OW-1]}}};
	end endgenerate

	initial	o_ce = 1'b0;
	always @(posedge i_clk)
	if (p_ce)
	begin
		o_ce <= 1'b1;
		o_result <= rounded_result[AW-1:AW-OW];
	end else
		o_ce <= 1'b0;

	// Make Verilator happy
	// verilator lint_off UNUSED
	wire	[AW-OW-1:0]	unused;
	assign	unused = rounded_result[AW-OW-1:0];
	// verilator lint_on  UNUSED

`ifdef	FORMAL
`endif // FORMAL
endmodule
