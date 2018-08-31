////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	tmdsdecode.v
//
// Project:	VideoZip, a ZipCPU SoC supporting video functionality
//
// Purpose:	
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
module	tmdsdecode(i_clk, i_word, o_pv, o_pix, o_sync);
	input	wire	i_clk;
	input	wire	[9:0]	i_word;
	output	wire		o_pv;
	output	wire	[13:0]	o_pix;
	output	wire	[1:0]	o_sync;


	reg	[7:0]	r_pix;
	wire	[9:0]	first_midp;
	assign	first_midp = {
			((i_word[0]) ? (~i_word[9:2]) : (i_word[9:2])),
			i_word[1:0] };
	always @(posedge i_clk)
	begin
		if (first_midp[1])
		begin
			r_pix[0] <= !(first_midp[9]);
			r_pix[1] <= !(first_midp[8] ^ first_midp[9]);
			r_pix[2] <= !(first_midp[7] ^ first_midp[8]);
			r_pix[3] <= !(first_midp[6] ^ first_midp[7]);
			r_pix[4] <= !(first_midp[5] ^ first_midp[6]);
			r_pix[5] <= !(first_midp[4] ^ first_midp[5]);
			r_pix[6] <= !(first_midp[3] ^ first_midp[4]);
			r_pix[7] <= !(first_midp[2] ^ first_midp[3]);
		end else begin
			r_pix[0] <= first_midp[9];
			r_pix[1] <= first_midp[8] ^ first_midp[9];
			r_pix[2] <= first_midp[7] ^ first_midp[8];
			r_pix[3] <= first_midp[6] ^ first_midp[7];
			r_pix[4] <= first_midp[5] ^ first_midp[6];
			r_pix[5] <= first_midp[4] ^ first_midp[5];
			r_pix[6] <= first_midp[3] ^ first_midp[4];
			r_pix[7] <= first_midp[2] ^ first_midp[3];
		end
	end

	wire	[9:0]	brev_word;
	genvar	k;
	generate for(k=0; k<10; k=k+1)
		assign brev_word[k] = i_word[9-k];
	endgenerate

	reg		r_pv;
	reg	[5:0]	apix;
	reg	[1:0]	r_sync;
	always @(posedge i_clk)
	begin
		r_pv   <= 1'b0;
		apix   <= 6'h0;
		r_sync <= 2'b00;
		//
		case(brev_word)
		// 2-bit control period coding
		10'h354: begin apix <= 6'h00; r_sync <= 2'h0; end
		10'h0ab: begin apix <= 6'h01; r_sync <= 2'h1; end
		10'h154: begin apix <= 6'h02; r_sync <= 2'h2; end
		10'h2ab: begin apix <= 6'h03; r_sync <= 2'h3; end
		// TERC4 coding
		10'h29c: begin apix <= 6'h10; r_sync <= 2'h0; end
		10'h263: begin apix <= 6'h11; r_sync <= 2'h1; end
		10'h2e4: begin apix <= 6'h12; r_sync <= 2'h2; end
		10'h2e2: begin apix <= 6'h13; r_sync <= 2'h3; end
		10'h171: begin apix <= 6'h14; r_sync <= 2'h0; end
		10'h11e: begin apix <= 6'h15; r_sync <= 2'h1; end
		10'h18e: begin apix <= 6'h16; r_sync <= 2'h2; end
		10'h13c: begin apix <= 6'h17; r_sync <= 2'h3; end
		// This next pixel is also a guard pixel
		10'h2cc: begin apix <= 6'h38; r_sync <= 2'h0; end
		//
		10'h139: begin apix <= 6'h19; r_sync <= 2'h1; end
		10'h19c: begin apix <= 6'h1a; r_sync <= 2'h2; end
		10'h2c6: begin apix <= 6'h1b; r_sync <= 2'h3; end
		10'h28e: begin apix <= 6'h1c; r_sync <= 2'h0; end
		10'h271: begin apix <= 6'h1d; r_sync <= 2'h1; end
		10'h163: begin apix <= 6'h1e; r_sync <= 2'h2; end
		10'h2c3: begin apix <= 6'h1f; r_sync <= 2'h3; end
		// Guard band characters
		//10'h2cc:apix<= 8'h38; // done above
		10'h133: begin apix <= 6'h21; r_sync <= 2'h0; end
		default: r_pv <= 1'b1;
		endcase
	end

	assign	o_pv   = r_pv;
	assign	o_pix  = { apix, r_pix };
	assign	o_sync = r_sync;

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = first_midp[0];
	// verilator lint_on  UNUSED
endmodule
