////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	bench/cpp/testb.h
//
// Project:	vgasim, a Verilator based VGA simulator demonstration
//
// Purpose:	A wrapper for a common interface to a clocked FPGA core
//		begin exercised in Verilator.
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
#ifndef	TESTB_H
#define	TESTB_H

#include <stdio.h>
#include <stdint.h>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "tbclock.h"

#define	TBASSERT(TB,A) do { if (!(A)) { (TB).closetrace(); } assert(A); } while(0);

template <class VA>	class TESTB {
public:
	VA	*m_core;
	bool		m_changed;
	VerilatedVcdC*	m_trace;
	bool		m_done;
	unsigned long	m_time_ps;
	TBCLOCK		m_clk;
	TBCLOCK		m_pixclk;

	TESTB(void) {
		m_core = new VA;
		m_time_ps  = 0ul;
		m_trace    = NULL;
		m_done     = false;
		Verilated::traceEverOn(true);
		m_core->i_clk = 0;
		m_core->i_pixclk = 0;
		eval(); // Get our initial values set properly.
		m_clk.init(10000);	//  100.00 MHz
		m_pixclk.init(6734);	//  148.50 MHz
	}
	virtual ~TESTB(void) {
		if (m_trace)
			m_trace->close();
		delete m_core;
		m_core = NULL;
	}

	virtual	void	opentrace(const char *vcdname) {
		if (!m_trace) {
			m_trace = new VerilatedVcdC;
			m_core->trace(m_trace, 99);
			m_trace->open(vcdname);
			m_trace->spTrace()->set_time_resolution("ps");
			m_trace->spTrace()->set_time_unit("ps");
		}
	}

	void	trace(const char *vcdname) {
		opentrace(vcdname);
	}

	virtual	void	closetrace(void) {
		if (m_trace) {
			m_trace->close();
			delete m_trace;
			m_trace = NULL;
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
		if (m_trace) m_trace->dump(m_time_ps+1);

		m_core->i_clk = m_clk.advance(mintime);
		m_core->i_pixclk = m_pixclk.advance(mintime);

		m_time_ps += mintime;

		eval();
		if (m_trace) {
			m_trace->dump(m_time_ps+1);
			m_trace->flush();
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

