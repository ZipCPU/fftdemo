////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	MICNCO.cpp
// {{{
// Project:	FFT-DEMO, a verilator-based spectrogram display project
//
// Purpose:	To provide a simulated A/D input for testing
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2019-2024, Gisselquist Technology, LLC
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
// }}}
#include <stdio.h>
#include <math.h>
#include <assert.h>
#include "micnco.h"

#define	ADC_BITS	12
MICNCO::MICNCO() {
	m_phase = 0;
	m_step = 1;
	m_last_sck = 1;
	m_bomb = false;

	double	initial_step = 1.0/23/1024.0;
	initial_step *= (1<<30)*4.;
	m_step = (unsigned)initial_step;

	double	initial_sweep = 1.0/23./1024.0;
	initial_sweep *= initial_sweep;
	initial_sweep *= (1<<30)*4.;
	m_dstep = (unsigned)initial_sweep;

printf("MICNCO: STEP:DSTEP = 0x%08x:%08x\n", m_step, m_dstep);
}

void	MICNCO::step(unsigned s) { m_step = s; }
int MICNCO::operator()(int sck, int csn) {
	int	ov;

	m_ticks++;
	if (m_ticks > 20)
		m_ticks = 20;
	if (csn) {
		if (!sck) {
			m_bomb = true; // assert(sck == 1);
			fprintf(stderr, "MICNCO-BOMB: SCK low while CSn is high\n");
		}
		m_state = 0;
		m_oreg  = 0;
		ov = 0;
	} else {
		if ((m_last_sck)&&(!sck)) {
			if (m_ticks < 6) {
				fprintf(stderr, "MICNCO-BOMB: Clock too short, m_tics = %d\n", m_ticks);
				m_bomb = true; // assert(m_ticks > 6);
			}
			m_ticks = 0;
			m_state++;
			if (m_state == 5) {
				m_phase += m_step;
				m_step  += m_dstep;

				double	cv;
				cv = cos(2.0*M_PI*m_phase/(1<<30)/4.);
				cv *= (1<<(ADC_BITS-1));
				if (cv >= (1<<(ADC_BITS-1)))
					cv = (1<<(ADC_BITS-1))-1.0;
				else if (cv < -(1<<(ADC_BITS-1)))
					cv = -(1<<(ADC_BITS-1));
				m_oreg = ((int)(cv))&((1<<ADC_BITS)-1);
				if (m_oreg < (1<<(ADC_BITS-1)-3))
					m_oreg +=2;
				if (false) {
					static int lastoreg = 0;
					if (lastoreg != m_oreg) {
						lastoreg = m_oreg;
						printf("MICNCO: V = %02x\n",
							m_oreg);
					}
				}
			} else
				m_oreg <<= 1;
		} ov = (m_oreg>>(ADC_BITS-1))&1;
	}
	m_last_sck = sck;
	return ov;
}

