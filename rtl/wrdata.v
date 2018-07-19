////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rtl/wrdata.v
//
// Project:	FFT-DEMO, a verilator-based spectrogram display project
//
// Purpose:	This is the memory controller that handles writing pixels values
//		from the FFT, and writing them to RAM.  It is designed to
//	support a spectrogram that write a vertical bar of new data to the
//	right of the screen.  To support screen scrolling, the vertical bar
//	is written to two locations in memory, and an output address offset
//	is given for the video controller to read from an adjustable memory
//	starting location.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2018, Gisselquist Technology, LLC
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
module	wrdata(i_clk, i_reset, i_ce, i_pixel, i_sync,
	i_base, i_lw, i_height,
	o_offset,
	o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data, o_wb_sel,
	i_wb_ack, i_wb_stall, i_wb_err);
	parameter	AW=20, DW=32, LW=12;
	//
	input	wire	i_clk, i_reset;
	//
	input	wire			i_ce;
	input	wire	[7:0]		i_pixel;
	input	wire			i_sync;
	//
	input	wire	[AW-1:0]	i_base, i_lw;
	input	wire	[LW-1:0]	i_height;
	//
	output	wire	[AW-1:0]	o_offset;
	//
	output	reg			o_wb_cyc;
	output	wire			o_wb_stb, o_wb_we;
	output	wire	[AW-1:0]	o_wb_addr;
	output	wire	[DW-1:0]	o_wb_data;
	output	wire	[DW/8-1:0]	o_wb_sel;
	//
	input	wire			i_wb_ack, i_wb_stall, i_wb_err;

	reg			fif_ce, last_ce, r_offscreen;
	reg	[AW-1:0]	fif_addr;
	reg	[DW-1:0]	fif_data;
	reg	[DW/8-1:0]	fif_sel;
	//
	reg	[AW+1:0]	r_offset, next_offset;
	reg	[AW-1:0]	r_lw, r_addr;
	reg	[LW-1:0]	lno;
	reg	[LW-1:0]	r_height;

	initial	r_height = 10;
	always @(posedge i_clk)
	if ((i_reset)||((i_ce)&&(i_sync)))
		r_height <= i_height;

// wire	[7:0]	lno_pixel
// assign	lno_pixel = 200 - lno[9:2];

	initial	fif_addr = 0;
	initial	r_lw     = 0;
	initial	r_offset = 0;
	initial	fif_ce   = 0;
	initial last_ce  = 0;
	initial lno      = 0;
	initial r_offscreen = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
	begin
		fif_addr <= i_base;
		r_lw     <= i_lw;
		r_offset <= 0;
		fif_ce   <= 0;
		last_ce  <= 0;
		r_offscreen <= 1'b1;
		lno      <= 0;
	end else if (i_ce)
	begin
		if(i_sync)
		begin
			r_lw   <= i_lw;
			r_offscreen <= 0;
		end else
			r_offscreen <= (lno >= r_height-1);
		fif_ce <= (i_sync)||(!r_offscreen);
		fif_addr <= (i_sync) ? (i_base + next_offset[AW+1:2]) : r_addr;

/*
		if ((i_sync)&&(next_offset[0]))
			fif_data <= {(4){8'h20}};
		else if (lno[11:9]==0)
			fif_data <= {(4){lno[8:1]}};
		else
			fif_data <= {(4){i_pixel}};
		//	fif_data <= {(4){i_pixel}};
		//	fif_data <= {(4){8'h80}};
			fif_data <= {(4){lno[8:1]}};
*/
		fif_data <= {(4){i_pixel}};
		case((i_sync)?next_offset[1:0]:r_offset[1:0])
			2'b00: fif_sel <= 4'b1111;
			2'b01: fif_sel <= 4'b0111;
			2'b10: fif_sel <= 4'b0011;
			2'b11: fif_sel <= 4'b0001;
		endcase
		last_ce <= (i_sync)||(!r_offscreen);

		if (i_sync)
			lno <= 0;
		else
			lno <= lno + 1'b1;
		// if ((!i_sync)&&(lno >= r_height))
			// assert(r_offscreen);
		if (i_sync)
			r_addr <= i_base + next_offset[AW+1:2];
		else // if (r_offset[AW+1:0] == {r_lw, 2'b00} - 1)
			r_addr <= r_addr - r_lw - r_lw;

	end else if (last_ce)
	begin
		fif_ce <= 1'b1;
		fif_addr <= fif_addr + r_lw;
		last_ce <= 1'b0;
	end else
		fif_ce <= 1'b0;

	initial	next_offset = 0;
	always @(posedge i_clk)
	if (i_reset)
		next_offset <= 0;
	else if ((r_offset[1:0]==2'b11)&&(r_offset[AW+1:2] == r_lw-1))
		next_offset <= 0;
	else
		next_offset <= r_offset + 1;

	always @(posedge i_clk)
	if (i_reset)
		r_offset <= 0;
	else if ((i_ce)&&(i_sync))
		r_offset <= next_offset;

	always @(posedge i_clk)
	if (i_reset)
		o_offset <= 0;
	else if ((i_ce)&&(i_sync))
		o_offset <= r_offset[AW+1:2]+2;

	wire	fif_wfull, fif_rempty, fif_err;

`ifdef	FORMAL
	sfifo	#(AW+DW+(DW/8), 2)
`else
	sfifo	#(AW+DW+(DW/8), 5)
`endif
		memfifoi(i_clk,i_reset, fif_ce, { fif_addr, fif_data, fif_sel },
			fif_wfull,
			(o_wb_stb)&&(!i_wb_stall),
				{ o_wb_addr, o_wb_data, o_wb_sel },
				fif_rempty, fif_err);

	reg	r_wb_stb, last_ack;

	initial	o_wb_cyc = 0;
	initial	r_wb_stb = 0;
	always @(posedge i_clk)
	if ((i_reset)||((o_wb_cyc)&&(i_wb_err)))
	begin
		o_wb_cyc <= 1'b0;
		r_wb_stb <= 1'b0;
	end else if ((!o_wb_cyc)&&(!fif_rempty))
	begin
		o_wb_cyc <= 1'b1;
		r_wb_stb <= 1'b1;
	end else if (o_wb_cyc) begin
		if (((r_wb_stb)&&(fif_rempty))||(wb_full))
			r_wb_stb <= 1'b0;
		if ((!r_wb_stb)&&(i_wb_ack)&&(last_ack))
			o_wb_cyc <= 1'b0;
	end
		
`ifdef	FORMAL
	localparam	WB_DEPTH = 2;
`else
	localparam	WB_DEPTH = 5;
`endif

	reg	[WB_DEPTH-1:0]	pending;
	reg		wb_full;

	initial	pending  = 0;
	initial	wb_full  = 0;
	initial	last_ack = 0;
	always @(posedge i_clk)
	if ((i_reset)||(!o_wb_cyc)||(i_wb_err))
	begin
		pending <= 0;
		wb_full <= 0;
		last_ack<= 1'b1;
	end else case({(o_wb_stb)&&(!i_wb_stall), i_wb_ack})
		2'b01: begin
			pending <= pending - 1;
			wb_full <= 1'b0;
			last_ack<= (pending <= 2);
			end
		2'b10: begin
			pending <= pending + 1;
			wb_full <= &pending[WB_DEPTH-1:1];
			last_ack<= (pending == 0);
			end
		default: begin end
		endcase

	assign	o_wb_stb = (r_wb_stb)&&(!fif_rempty)&&(!wb_full);
	assign	o_wb_we  = 1'b1;

	// verilator lint_off UNUSED
	wire	[1:0] unused;
	assign	unused = { fif_wfull, fif_err };
	// verilator lint_on  UNUSED

`ifdef	FORMAL
	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	initial	assume(i_reset);
	always @(*)
	if (!f_past_valid)
		assume(i_reset);

	wire	[WB_DEPTH:0]	f_nreqs, f_nacks, f_outstanding;

	fwb_master #( .AW(AW), .DW(DW), .F_MAX_STALL(2), .F_MAX_ACK_DELAY(2),
			.F_LGDEPTH(WB_DEPTH+1), .F_OPT_SOURCE(1'b1)
		) fwb(i_clk, i_reset,
			o_wb_cyc, o_wb_stb, o_wb_we, o_wb_we, o_wb_data,
			   o_wb_sel, i_wb_ack, i_wb_stall, 32'h0, i_wb_err,
			f_nreqs, f_nacks, f_outstanding);

	always @(*)
		assume(i_height == 800);
	always @(*)
		assert(lno < r_height);

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_wb_err))&&(o_wb_cyc))
		assert(f_outstanding == {1'b0,pending});

	always @(*)
		assert(f_outstanding < {1'b1,{(WB_DEPTH){1'b0}}});

	always @(*)
	if (o_wb_cyc)
		assert(last_ack == (pending <= 6'h1));

	always @(*)
	if (&pending)
		assert(wb_full);

	always @(*)
	if (r_wb_stb)
		assert(o_wb_cyc);

	always @(*)
	if (fif_ce)
		assert(fif_sel[0]);

	always @(*)
	if (!fif_rempty)
		assume(o_wb_sel[0]);
`endif
endmodule
