////////////////////////////////////////////////////////////////////////////////
//
// Filename:	bench/cpp/micnco.h
// {{{
// Project:	FFT-DEMO, a verilator-based spectrogram display project
//
// Purpose:	To define the class that will provide a simulated A/D input for
//		testing
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
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
#ifndef	MICNCO_H
#define	MICNCO_H

class MICNCO {
	unsigned	m_phase, m_step, m_dstep, m_ticks, m_state;
	int		m_last_sck, m_oreg;
public:
	bool		m_bomb;
	MICNCO();
	void	step(unsigned s);
	int operator()(int sck, int csn);
};

#endif

