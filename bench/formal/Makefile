###############################################################################
##
## Filename:	Makefile
## {{{
## Project:	FFT-DEMO, a verilator-based spectrogram display project
##
## Purpose:	Script the building of the various formal proofs used in this
##		design.  Modules imported from other projects may have proofs
##	not tested here.  See their respective projects for their proofs.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
## }}}
## Copyright (C) 2018-2024, Gisselquist Technology, LLC
## {{{
## This program is free software (firmware): you can redistribute it and/or
## modify it under the terms of  the GNU General Public License as published
## by the Free Software Foundation, either version 3 of the License, or (at
## your option) any later version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.
##
## You should have received a copy of the GNU General Public License along
## with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
## }}}
## License:	GPL, v3, as defined and found on www.gnu.org,
## {{{
##		http://www.gnu.org/licenses/gpl.html
##
################################################################################
##
## }}}
all: wrdata tmdstest logfn # genhdmi

.PHONY: genhdmi
## {{{
genhdmi: genhdmi_prf/PASS
genhdmi_prf/PASS: genhdmi.sby ../../rtl/video/tmdsencode.v ../../rtl/video/genhdmi.v
	sby -f genhdmi.sby prf
## }}}

.PHONY: logfn
## {{{
logfn: logfn_prf/PASS
logfn_prf/PASS: logfn.sby ../../rtl/fft/logfn.v
	sby -f logfn.sby prf
## }}}

.PHONY: tmdstest
## {{{
tmdstest: tmdstest_prf/PASS
tmdstest_prf/PASS: tmdstest.sby tmdstest.v ../../rtl/video/tmdsencode.v ../../rtl/video/tmdsdecode.v
	sby -f tmdstest.sby prf
## }}}

.PHONY: wrdata
## {{{
wrdata: wrdata_prf/PASS
wrdata_prf/PASS: wrdata.sby ../../rtl/wrdata.v ../../rtl/sfifo.v fwb_master.v
	sby -f wrdata.sby prf
## }}}

clean:
	rm -rf wrdata_*/
	rm -rf genhdmi_*/
	rm -rf tmdstest_*/
	rm -rf logfn_*/
