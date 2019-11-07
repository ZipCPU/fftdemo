////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	bench/cpp/testb.h
//
// Project:	FFT-DEMO, a verilator-based spectrogram display project
//
// Purpose:	A wrapper for a common interface to a clocked FPGA core
//		begin exercised in Verilator.  This particular version of the
//	interface is designed to work with two separate clocks: a pixel clock
//	and a master system clock, with the pixel clock running at 100MHz
//	(10ns), and the pixel clock at ... whatever speed the pixel clock is
//	running at.  In particular, the pixel clock speed is set and adjusted
//	elsewhere.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2017-2019, Gisselquist Technology, LLC
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
#ifndef	TESTB_H
#define	TESTB_H

#include <stdio.h>
#include <stdint.h>
#include <verilated_vcd_c.h>
#include "tbclock.h"

#define	TBASSERT(TB,A) do { if (!(A)) { (TB).closetrace(); } assert(A); } while(0);
#define	TRACE_VCD

template <class VA>	class TESTB {
public:
	VA		*m_core;
	bool		m_changed;
	VerilatedVcdC*	m_trace_vcd;
	bool		m_done;
	unsigned long	m_time_ps;
	TBCLOCK		m_clk;
	TBCLOCK		m_pixclk;

	TESTB(void) {
		m_core = new VA;
		m_time_ps   = 0ul;
		m_trace_vcd = NULL;
		m_done      = false;
		Verilated::traceEverOn(true);
		m_core->i_clk = 0;
		m_core->i_pixclk = 0;
		eval(); // Get our initial values set properly.
		m_clk.init(10000);	//  100.00 MHz
		m_pixclk.init(6734);	//  148.50 MHz
	}
	virtual ~TESTB(void) {
		if (m_trace_vcd)
			m_trace_vcd->close();
		delete m_core;
		m_core = NULL;
	}

	virtual	void	openvcd(const char *vcdname) {
		if (!m_trace_vcd) {
			m_trace_vcd = new VerilatedVcdC;
			m_core->trace(m_trace_vcd, 99);
			m_trace_vcd->open(vcdname);
			m_trace_vcd->spTrace()->set_time_resolution("ps");
			m_trace_vcd->spTrace()->set_time_unit("ps");
		}
	}

	virtual	void	closetrace(void) {
		if (m_trace_vcd) {
			m_trace_vcd->close();
			delete m_trace_vcd;
			m_trace_vcd = NULL;
		}
	}

	virtual	void	eval(void) {
		m_core->eval();
	}

	virtual	void	tick(void) {
		unsigned	mintime = m_clk.time_to_edge();

		if (m_pixclk.time_to_edge() < mintime)
			mintime = m_pixclk.time_to_edge();

		assert(mintime > 1);

		eval();
		if (m_trace_vcd) m_trace_vcd->dump(m_time_ps+1);

		m_core->i_clk = m_clk.advance(mintime);
		m_core->i_pixclk = m_pixclk.advance(mintime);

		m_time_ps += mintime;

		eval();
		if (m_trace_vcd) {
			m_trace_vcd->dump(m_time_ps+1);
			m_trace_vcd->flush();
		}

		if (m_clk.falling_edge()) {
			m_changed = true;
			sim_clk_tick();
		}
		if (m_pixclk.falling_edge()) {
			m_changed = true;
			sim_pixclk_tick();
		}
	}

	virtual	void	sim_clk_tick(void) {
			// Your test fixture should over-ride this method.
			// If you change any of the inputs to the design
			// (i.e. w/in main.v), then set m_changed to true.
			m_changed = false;
		}
	virtual	void	sim_pixclk_tick(void) {
			// Your test fixture should over-ride this method.
			// If you change any of the inputs to the design
			// (i.e. w/in main.v), then set m_changed to true.
			m_changed = false;
		}
	virtual bool	done(void) {
		if (m_done)
			return true;

		if (Verilated::gotFinish())
			m_done = true;

		return m_done;
	}

	virtual	void	reset(void) {
		m_core->i_reset = 1;
		tick();
		m_core->i_reset = 0;
		// printf("RESET\n");
	}
};

#endif	// TESTB

