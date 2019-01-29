////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rtl/main.v
//
// Project:	FFT-DEMO, a verilator-based spectrogram display project
//
// Purpose:	This is the top level simulatable HDL component.  To truly
//		simulate this design, though, you'll need to provide two
//	clocks, i_clk at 100MHz and i_pixclk at (IIRC) 56MHz.  To build this
//	within an FPGA, you'll need to modify the port list and add an external
//	memory since most FPGA's don't have 2MB+ of block RAM.
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
// `define	HIRESOLUTION
//
module	main(i_clk, i_reset, i_pixclk,
		o_adc_csn, o_adc_sck, i_adc_miso,
`define	VOUT
		o_vga_vsync, o_vga_hsync, o_vga_red, o_vga_grn, o_vga_blu
		, hsync, vsync, state, state_counter, vguard, dguard, vpre, dpre, s, hsync_count
		);
	input	wire		i_clk;
	// Verilator lint_off SYNCASYNCNET
	input	wire		i_reset;
	// Verilator lint_on  SYNCASYNCNET
	input	wire		i_pixclk;
	output	wire		o_adc_csn, o_adc_sck;
	input	wire		i_adc_miso;
	output	wire		o_vga_vsync, o_vga_hsync;
	output	wire	[7:0]	o_vga_red, o_vga_grn, o_vga_blu;

	// Verilator lint_off UNUSED
	(* keep *)	input	wire		hsync, vsync;
	(* keep *)	input	wire		vguard, dguard;
	(* keep *)	input	wire		vpre, dpre;
	(* keep *)	input	wire	[4:0]	s;
	(* keep *)	input	wire	[3:0]	state;
	(* keep *)	input	wire	[19:0]	state_counter;
	(* keep *)	input	wire	[19:0]	hsync_count;
	// Verilator lint_on  UNUSED

	//
	//
	wire				dat_cyc, dat_stb, video_cyc, video_stb,
					mem_cyc, mem_stb,
					dat_we, mem_we;
		wire	[AW-1:0]	video_addr, mem_addr;
	//
	`VOUT	wire	[AW-1:0]	dat_addr;
	`VOUT	wire	[31:0]		dat_pix;
	`VOUT	wire	[3:0]		dat_sel;
	//
	wire	[31:0]		mem_in, mem_data;
	wire			dat_stall, video_stall, mem_stall,
				dat_ack, video_ack, mem_ack,
				dat_err, video_err, mem_err;
	wire	[3:0]		mem_sel;


	reg			adc_start;
	reg	[6:0]		adc_divider;
	initial	adc_start = 1;
	initial	adc_divider = 0;
	always @(posedge i_clk)
	if (adc_divider == 7'd99)
	begin
		adc_divider <= 0;
		adc_start <= 1;
	end else begin
		adc_divider <= adc_divider+1;
		adc_start <= 0;
	end

	wire			adc_ign;
	`VOUT	wire		adc_ce;
	`VOUT	wire	[11:0]	adc_sample;
	pmic adc(i_clk, adc_start, 1'b1, 1'b1, o_adc_csn, o_adc_sck, i_adc_miso,
			{ adc_ign, adc_ce, adc_sample });

	`VOUT	wire		fil_ce;
	`VOUT	wire	[19:0]	fil_sample;
	subfildown #(.IW(12), .OW(20), .TW(12), .NDOWN(23), .LGNTAPS(10),
			.INITIAL_COEFFS("subfildown.hex"))
		fil(i_clk, i_reset, 1'b0, 12'h0, adc_ce, adc_sample[11:0],
			fil_ce, fil_sample);


	reg		alt_ce;
	reg	[4:0]	alt_countdown;

	initial	alt_countdown = 0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		alt_ce <= 1'b0;
		alt_countdown <= 5'd22;
	end else if (fil_ce)
	begin
		alt_countdown <= 5'd22;
		alt_ce <= 1'b0;
	end else if (alt_countdown > 0)
	begin
		alt_countdown <= alt_countdown - 1'b1;
		alt_ce <= (alt_countdown <= 1);
	end else
		alt_ce <= 1'b0;

	`VOUT	wire		pre_frame, pre_ce;
	`VOUT	wire	[11:0]	pre_sample;	
`ifdef	HIRESOLUTION
	localparam	XMPY = 5;
	wire	[12+XMPY-1:0]	big_sample;
	hires #(
		.IW(12), .OW(12+XMPY), .TW(12), .LGNFFT(10), .LGFLEN(3),
			.OPT_FIXED_TAPS(1'b1),
		// .INITIAL_COEFFS("f3.txt")
		.INITIAL_COEFFS("f6.txt")
		) hiresi(i_clk, i_reset, 1'b0, 0,
			fil_ce, fil_sample[11:0], alt_ce,
			pre_frame, pre_ce, big_sample);
	assign	pre_sample = big_sample[11:0];
	// verilator lint_off UNUSED
	wire	[XMPY-1:0]	unused_pre;
	assign unused_pre = big_sample[12+XMPY-1:12];
	// verilator lint_on  UNUSED
`else

	windowfn #(.IW(12), .OW(12), .TW(12), .LGNFFT(10),
		.OPT_FIXED_TAPS(1'b1),
		.INITIAL_COEFFS("hanning.hex")) wndw(i_clk, i_reset,
			1'b0, 0, fil_ce, fil_sample[11:0], alt_ce,
			pre_frame, pre_ce, pre_sample);	

`endif

	`VOUT	wire		fft_sync;
	`VOUT	wire	[31:0]	fft_sample;

	fftmain fftmaini(i_clk, i_reset, pre_ce, { pre_sample, 12'h0 },
			fft_sample, fft_sync);

	`VOUT	wire		raw_sync;
	`VOUT	wire	[7:0]	raw_pixel;

	logfn logi(i_clk, i_reset,
			pre_ce, fft_sync, fft_sample[31:16], fft_sample[15:0],
			raw_pixel, raw_sync);
	localparam	LGMEM=21, LGDW=5, AW=LGMEM-2;
	localparam	FW=13, LW=12;
	// Horizontal/Vertical video parameters
	localparam [FW-1:0]	HWIDTH=800, HPORCH=840, HSYNC=868, HRAW=1056;
	localparam [LW-1:0]	LHEIGHT=600,LPORCH=601, LSYNC=605, LRAW=628;
	localparam [AW-1:0]	BASEADDR=0,
				LINEWORDS = 200; //  HWIDTH/(1<<(LGMEM-AW));
	//
	//
	wire	[AW-1:0]	baseoffset;
	wire	[AW-1:0]	last_line_addr;
	assign	last_line_addr = BASEADDR
			+ LINEWORDS * ({{(AW-LW-1){1'b0}}, LHEIGHT, 1'b0}-1);
	wrdata	#(.AW(AW), .LW(LW)) data2mem(i_clk, i_reset,
			pre_ce, raw_pixel, raw_sync,
			last_line_addr,LINEWORDS,LHEIGHT, baseoffset,
			dat_cyc, dat_stb, dat_we, dat_addr, dat_pix, dat_sel,
				dat_ack, dat_stall, dat_err);
	
	wbpriarbiter #(.AW(AW)) arb(i_clk,
		dat_cyc, dat_stb, dat_we, dat_addr, dat_pix, dat_sel,
			dat_ack, dat_stall, dat_err,
		video_cyc, video_stb, 1'b0, video_addr, dat_pix, dat_sel,
			video_ack, video_stall, video_err,
		mem_cyc, mem_stb, mem_we, mem_addr,mem_in, mem_sel,
			mem_ack, mem_stall, mem_err);

	memdev #(LGMEM) memi(i_clk, i_reset,
		mem_cyc, mem_stb, mem_we, mem_addr, mem_in, mem_sel,
				mem_ack, mem_stall, mem_data);
	assign	mem_err = 1'b0;

	wire	video_refresh;

	wire	[AW-1:0]	read_offset;
	assign	read_offset = baseoffset; // LINEWORDS - baseoffset;

	wbvgaframe #(.ADDRESS_WIDTH(AW), .FW(FW), .LW(LW)
		) vgai(i_clk, i_pixclk, i_reset, 1'b1,
		BASEADDR + read_offset, LINEWORDS[FW:0],
		HWIDTH,  HPORCH, HSYNC, HRAW,	// Horizontal mode
		LHEIGHT, LPORCH, LSYNC, LRAW,	// Vertical mode
		// Wishbone
		video_cyc, video_stb, video_addr,
			video_ack, video_err, video_stall, mem_data,
		o_vga_vsync, o_vga_hsync, o_vga_red, o_vga_grn, o_vga_blu,
		video_refresh);

	// Make Verilator happy
	// verilator lint_off UNUSED
	wire	[10:0]	unused;
	assign	unused = { fil_sample[19:12], pre_frame, adc_ign, video_refresh };
	// verilator lint_on  UNUSED		
endmodule
