################################################################################
##
## Filename:	bench/cpp/Makefile
## {{{
## Project:	FFT-DEMO, a verilator-based spectrogram display project
##
## Purpose:	To direct the Verilator build of the VGA simulation sources.
##
## Targets:
##
##	main_tb
##		This demo program shows the utility of the VGA simulator, by
##		using the VGA outputs of a Verilator based test bench to drive
##		a window on your screen.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
## }}}
## Copyright (C) 2015-2024, Gisselquist Technology, LLC
## {{{
## This program is free software (firmware): you can redistribute it and/or
## modify it under the terms of the GNU General Public License as published
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
.PHONY: all
# Make certain the "all" target is the first and therefore the default target
all:
CXX	:= g++
OBJDIR	:= obj-pc
RTLD	:= ../../rtl
YYMMDD  := `date +%Y%m%d`
VOBJDR	:= $(RTLD)/obj_dir
ifneq ($(VERILATOR_ROOT),)
VERILATOR:=$(VERILATOR_ROOT)/bin/verilator
else
VERILATOR_ROOT ?= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
endif
export	$(VERILATOR)
VROOT	:= $(VERILATOR_ROOT)
VINCD   := $(VROOT)/include
VINC	:= -I$(VINCD) -I$(VINCD)/vltstd -I$(VOBJDR)
INCS	:= -I$(RTLD)/obj_dir/ -I$(RTLD) -I$(VINCD)
VDEFS   := $(shell ./vversion.sh)
FLAGS	:= -Wall -Og -g $(VDEFS)
GFXFLAGS:= $(GFXFLAGS) `pkg-config gtkmm-3.0 --cflags`
GFXLIBS := `pkg-config gtkmm-3.0 --libs`
CFLAGS  :=  $(GFXFLAGS)
SIMSOURCES:= vgasim.cpp micnco.cpp hdmisim.cpp
SIMOBJECTS:= $(addprefix $(OBJDIR)/,$(subst .cpp,.o,$(SIMSOURCES)))
SIMHEADERS:= $(foreach header,$(subst .cpp,.h,$(SIMSOURCES)),$(wildcard $(header)))
VOBJS   := $(OBJDIR)/verilated_vcd_c.o $(OBJDIR)/verilated.o $(OBJDIR)/verilated_threads.o
all:	main_tb ddr_tb hexf

SOURCES := main_tb.cpp vgasim.cpp
HEADERS := image.h testb.h vgasim.h micnco.h videomode.h image.cpp
#
PROGRAMS := main_tb ddr_tb
# Now the return to the "all" target, and fill in some details
all:	$(PROGRAMS)

.PHONY: main_tb.o hdmimain_tb.o vgasim.o hdmisim.o micnco.o
main_tb.o:	$(OBJDIR)/main_tb.o
ddr_tb.o:	$(OBJDIR)/ddr_tb.o
hdmisim.o:	$(OBJDIR)/hdmisim_tb.o
micnco.o:	$(OBJDIR)/micnco.o
memsim.o:	$(OBJDIR)/memsim.o

%.o: $(OBJDIR)/%.o
$(OBJDIR)/%.o: %.cpp
	$(mk-objdir)
	$(CXX) $(CFLAGS) $(INCS) -c $< -o $@

$(OBJDIR)/%.o: $(VINCD)/%.cpp
	$(mk-objdir)
	$(CXX) $(FLAGS) $(INCS) -c $< -o $@

#
#
#
#
MAINOBJS := $(OBJDIR)/main_tb.o
main_tb: $(MAINOBJS) $(SIMOBJECTS) $(VOBJS) $(VOBJDR)/Vmain__ALL.a
	$(CXX) $(GFXFLAGS) $^ $(VOBJDR)/Vmain__ALL.a $(GFXLIBS) -lpthread -o $@

DDROBJS := $(OBJDIR)/ddr_tb.o $(OBJDIR)/memsim.o
ddr_tb: $(DDROBJS) $(SIMOBJECTS) $(VOBJS) $(VOBJDR)/Vhdmiddr__ALL.a
	$(CXX) $(GFXFLAGS) $^ $(VOBJDR)/Vhdmiddr__ALL.a $(GFXLIBS) -lz -lpthread -o $@

HEXF := cmem_8.hex cmem_16.hex cmem_32.hex cmem_64.hex cmem_128.hex cmem_256.hex
HEXF += cmem_512.hex cmem_1024.hex hanning.hex subfildown.hex

hexf:
	ln -sf ../../rtl/*.hex .
	ln -sf ../../rtl/fft/*.hex .

.PHONY: clean
clean:
	rm -f *.vcd
	rm -f *.hex
	rm -f $(PROGRAMS)
	rm -rf $(OBJDIR)/

#
# The "depends" target, to know what files things depend upon.  The depends
# file itself is kept in $(OBJDIR)/depends.txt
#
define build-depends
	$(mk-objdir)
	@echo "Building dependency file"
	@$(CXX) $(CFLAGS) $(INCS) -MM $(SOURCES) > $(OBJDIR)/xdepends.txt
	@sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt > $(OBJDIR)/depends.txt
	@rm $(OBJDIR)/xdepends.txt
endef

.PHONY: archive
archive:
	tar --transform s,^,$(YYMMDD)-bench-cpp/, -chjf $(YYMMDD)-bench-cpp.tjz Makefile *.cpp *.h

.PHONY: depends
depends: tags
	$(build-depends)

$(OBJDIR)/depends.txt: depends

#
define	mk-objdir
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR); fi"
endef


#
# The "tags" target
#
tags:	$(SOURCES) $(HEADERS)
	@echo "Generating tags"
	@ctags $(SOURCES) $(HEADERS)

ifneq ($(MAKECMDGOALS),clean)
-include $(OBJDIR)/depends.txt
endif
