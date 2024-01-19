////////////////////////////////////////////////////////////////////////////////
//
// Filename:	ddr_tb.cpp
// {{{
// Project:	FFT-DEMO, a verilator-based spectrogram display project
//
// Purpose:	This is the main test bench class that holds all the pieces
//		together.  In this case, the test bench consists of little
//	more than a video simulator.
//
//	This file was drawn from the vgasim project, and then modified
//	to include the MICNCO simulator from the wbpmic project.
//
//	This also illustrates how a design can be debugged via either printf(),
//	or VCD methods.  (The VCD files tend to be *HUGE*, so use that approach
//	sparingly.)
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2018-2024, Gisselquist Technology, LLC
// {{{
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
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
// }}}
#include <signal.h>
#include <time.h>
#include <ctype.h>

// #define	VL_THREADED
// #define	TRACE_FST

#include "verilated.h"
#ifdef	TRACE_VCD
#include "verilated_vcd_c.h"
#endif
#ifdef	TRACE_FST
#include "verilated_fst_c.h"
#endif

#include "Vhdmiddr.h"

#include "testb.h"
// #include "twoc.h"
#include "hdmisim.h"
#include "vgasim.h"
#include "micnco.h"
#include "memsim.h"

#ifdef	NEW_VERILATOR
#define	VVAR(A)	busmaster__DOT_ ## A
#else
#define	VVAR(A)	v__DOT_ ## A
#endif


// No particular "parameters" need definition or redefinition here.
#define	BASE	Vhdmiddr

class	TESTBENCH : public TESTB<BASE> {
public:
	unsigned long	m_tx_busy_count;
	HDMIWIN		m_hdmi;
	MICNCO		m_micnco;
	MEMSIM		m_ddr;
	bool		m_done;

	TESTBENCH(void) : m_hdmi(800, 600), m_ddr((1<<25), 27) {
		//
		m_core->i_reset = 1;
		//
		m_done = false;

		TESTB<BASE>::m_pixclk.set_frequency_hz(m_hdmi.clocks_per_frame() * 60);
		Glib::signal_idle().connect(sigc::mem_fun((*this),
				&TESTBENCH::on_tick));
	}

#ifdef	TRACE_VCD
	void	tracevcd(const char *vcd_trace_file_name) {
		fprintf(stderr, "Opening TRACE(%s)\n", vcd_trace_file_name);
		openvcd(vcd_trace_file_name);
	}
#endif

#ifdef	TRACE_FST
	void	tracefst(const char *fst_trace_file_name) {
		fprintf(stderr, "Opening TRACE(%s)\n", fst_trace_file_name);
		openfst(fst_trace_file_name);
	}
#endif

	void	close(void) {
		// TESTB<BASECLASS>::closetrace();
		m_done = true;
	}

	void	sim_clk_tick(void) {
		m_core->i_adc_miso = m_micnco(m_core->o_adc_sck,
					m_core->o_adc_csn);

		m_ddr.apply(m_core->o_sdram_cyc,
				m_core->o_sdram_stb,
				m_core->o_sdram_we,
				m_core->o_sdram_addr,
				m_core->o_sdram_data,
				m_core->o_sdram_sel,
				m_core->i_sdram_ack,
				m_core->i_sdram_stall,
				m_core->i_sdram_data);
	}

	void	sim_pixclk_tick(void) {
		m_hdmi( m_core->o_hdmi_blu, m_core->o_hdmi_grn,
			m_core->o_hdmi_red);
	}

	void	tick(void) {
		if (m_done)
			return;

		TESTB<BASE>::tick();

		if (gbl_nframes > 180) {
			exit(EXIT_SUCCESS);
			m_done = true;
		}
	}

	bool	on_tick(void) {
		for(int i=0; i<32; i++)
			tick();
		return !m_done;
	}
};

TESTBENCH	*tb;

int	main(int argc, char **argv) {
	Gtk::Main	main_instance(argc, argv);
	Verilated::commandArgs(argc, argv);

	tb = new TESTBENCH();
	tb->reset();

	// tb->tracevcd("fftdemo.vcd");
	Gtk::Main::run(tb->m_hdmi);

	exit(0);
}

