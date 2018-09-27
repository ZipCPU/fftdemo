////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	hdmiframe.v
//
// Project:	vgasim, a Verilator based VGA simulator demonstration
//
// Purpose:	
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
module	hdmiframe(i_clk, i_pixclk,
		// Command and control
		i_reset, i_en,
		//
		i_base_addr, i_line_words,
		i_hm_width, i_hm_porch, i_hm_synch, i_hm_raw,
		i_vm_height, i_vm_porch, i_vm_synch, i_vm_raw,
		// Wishbone interface
		o_wb_cyc, o_wb_stb, o_wb_addr,
			i_wb_ack, i_wb_err, i_wb_stall, i_wb_data,
		// HDMI output
		o_hdmi_red, o_hdmi_grn, o_hdmi_blu,
		// Offer frame interrupts to ... whoever's interested.
		o_interrupt);
	parameter	ADDRESS_WIDTH=24,
			BUS_DATA_WIDTH=32;
	parameter	BITS_PER_COLOR = 8;
	parameter	FW=13, LW=12;
	//
	localparam	AW=ADDRESS_WIDTH;
	localparam	BPC = BITS_PER_COLOR,
			DW=BUS_DATA_WIDTH,
			LGF=FW;
	input	wire			i_clk, i_pixclk, i_reset;
	input	wire			i_en;
	//
	input	wire	[(AW-1):0]	i_base_addr;
	input	wire	[FW:0]		i_line_words;
	//
	input	wire	[(FW-1):0] i_hm_width, i_hm_porch, i_hm_synch, i_hm_raw;
	input	wire	[(LW-1):0] i_vm_height, i_vm_porch, i_vm_synch, i_vm_raw;
	//
	output	wire			o_wb_cyc, o_wb_stb;
	output	wire	[(AW-1):0]	o_wb_addr;
	input	wire			i_wb_ack, i_wb_err, i_wb_stall;
	input	wire	[(DW-1):0]	i_wb_data;
	//
	output	wire [9:0]		o_hdmi_red, o_hdmi_grn, o_hdmi_blu;
	//
	output	wire			o_interrupt;

	wire	hdmi_newline, hdmi_newframe, hdmi_rd;
	wire	[(3*BPC-1):0]	pixel;

	wire	[31:0]	fifo_word;
	wire		fifo_err, fifo_valid;

	reg		cmap_valid;
	reg	[31:0]	cmap_data;
	reg	[2:0]	cmap_fill;

	wire	cmap_rd;
	assign	cmap_rd = (!cmap_valid)||(cmap_fill == 0)
				||((cmap_fill == 1)&&(hdmi_rd));

	imgfifo #(.ADDRESS_WIDTH(AW),
		.BUSW(DW), .LGFLEN(LGF), .LW(LW))
		readmem(i_clk, i_pixclk,
			(i_reset)||(!i_en),(hdmi_newframe),
				i_base_addr,
				{{(AW-LGF-2){1'b0}},i_line_words[LGF:0], 1'b0 },
				i_line_words[LGF:0],
				i_vm_height[LW-1:0],
				o_wb_cyc, o_wb_stb, o_wb_addr,
					i_wb_ack, i_wb_err, i_wb_stall, i_wb_data,
				cmap_rd, fifo_valid, fifo_word, fifo_err);

	always @(posedge i_pixclk)
	if (hdmi_newframe)
	begin
		cmap_data  <= 0;
		cmap_fill  <= 0;
		cmap_valid <= 1'b0;
	end else if (cmap_rd)
	begin
		cmap_data  <= fifo_word;
		cmap_fill  <= (fifo_valid) ? 4:0;
		cmap_valid <= (fifo_valid);
	end else if (hdmi_rd)
	begin
		cmap_data <= { cmap_data[23:0], 8'h0 };
		cmap_fill <= cmap_fill - 1'b1;
	end

	colormap cmap(i_pixclk, 3'h4, cmap_data[31:24],
			pixel[23:16], pixel[15:8], pixel[7:0] );

	// verilator lint_off UNUSED
	wire	[((DW-3*BPC)+3-1):0]	unused_wbfifo;
	assign	unused_wbfifo = { fifo_word[(DW-1):(3*BPC)],
				hdmi_newline, fifo_err, fifo_valid };
	// verilator lint_on  UNUSED

	// Actually control the VGA hardware, produce the sync's, and output
	// the color data given
	genhdmi	#(.HW(FW),.VW(LW))
		hdmihw(i_pixclk, (i_reset), pixel[(3*BPC-1):0],
				i_hm_width, i_hm_porch, i_hm_synch, i_hm_raw,
				i_vm_height, i_vm_porch, i_vm_synch, i_vm_raw,
				hdmi_rd, hdmi_newline, hdmi_newframe,
				o_hdmi_red, o_hdmi_grn, o_hdmi_blu);

	transferstb newframe(i_pixclk, i_clk, hdmi_newframe, o_interrupt);
	// assign	o_interrupt = vga_newframe;

	// Make verilator happy
	// verilator lint_off UNUSED
	// wire	[33:0] unused;
	// assign	unused = { read_err, imdec_err, pal_val };
	// verilator lint_on  UNUSED
endmodule
