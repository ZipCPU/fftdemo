////////////////////////////////////////////////////////////////////////////////
//
// Filename:	main_tb.cpp
//
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
//
// Copyright (C) 2017-2018, Gisselquist Technology, LLC
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
#include <signal.h>
#include <time.h>
#include <ctype.h>

#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vmain.h"

#include "testb.h"
// #include "twoc.h"
#include "vgasim.h"
#include "micnco.h"

#ifdef	NEW_VERILATOR
#define	VVAR(A)	busmaster__DOT_ ## A
#else
#define	VVAR(A)	v__DOT_ ## A
#endif


// No particular "parameters" need definition or redefinition here.
class	TESTBENCH : public TESTB<Vmain> {
public:
	unsigned long	m_tx_busy_count;
	VGAWIN		m_vga;
	MICNCO		m_micnco;
	bool		m_done;

	TESTBENCH(void) : m_vga(800, 600) {
		//
		m_core->i_reset = 1;
		//
		m_done = false;

		Glib::signal_idle().connect(sigc::mem_fun((*this),
				&TESTBENCH::on_tick));
	}

	void	trace(const char *vcd_trace_file_name) {
		fprintf(stderr, "Opening TRACE(%s)\n", vcd_trace_file_name);
		opentrace(vcd_trace_file_name);
	}

	void	close(void) {
		// TESTB<BASECLASS>::closetrace();
		m_done = true;
	}

	void	tick(void) {
		if (m_done)
			return;

		/*
		if ((m_tickcount & ((1<<28)-1))==0) {
			double	ticks_per_second = m_tickcount;
			time_t	seconds_passed = time(NULL)-m_start_time;
			if (seconds_passed != 0) {
			ticks_per_second /= (double)(time(NULL) - m_start_time);
			printf(" ********   %.6f TICKS PER SECOND\n", 
				ticks_per_second);
			}
		}
		*/

		m_vga((m_core->o_vga_vsync)?0:1, (m_core->o_vga_hsync)?0:1,
			m_core->o_vga_red,
			m_core->o_vga_grn,
			m_core->o_vga_blu);

		m_core->i_adc_miso = m_micnco(m_core->o_adc_sck,
					m_core->o_adc_csn);

		TESTB<Vmain>::tick();

		int	ceflag = 0;

		/*
		if (m_core->adc_ce) {
			printf("ADC CE ");
			ceflag = 1;
		}

		if (m_core->fil_ce) {
			printf("FIL CE ");
			ceflag = 1;
		}

		if (m_core->pre_ce) {
			printf("PRE CE %03x,%04x,%04x->%08x:%02x",
				m_core->adc_sample,
				m_core->fil_sample,
				m_core->pre_sample, m_core->fft_sample,
				(m_core->raw_pixel&0x0ff));
			ceflag = 1;

			if (m_core->pre_frame)
				printf("FRAME! ");
		}

		if ((m_core->pre_ce)&&(m_core->fft_sync)) {
			printf("FFT SYNC ");
			ceflag = 1;
		}

		if (ceflag)
			printf("\n");
		*/
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

	// tb->opentrace("fftdemo.vcd");
	Gtk::Main::run(tb->m_vga);

	exit(0);
}

