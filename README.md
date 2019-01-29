This project contains a Verilator FFT to screen spectrogram demonstration.
To build, type "make" in the main directory.  This will build a file
"main\_tb" in the [bench/cpp](bench/cpp) directory, and similarly a
"ddr\_tb" in the [bench/cpp](bench/cpp) directory.  Running either program
will simulate the entire design, all the way from A/D to display output,
all using Verilator.  The "main\_tb" demo uses an unreasonable amount of
block RAM with a VGA output, and the "ddr\_tb" demo uses an external
DDR3 SDRAM together with a (simulated) HDMI output.
You will need to install Verilator and gtkmm to do this.

There's a pictoral overview of the project in the doc directory
[here](doc/fftdemo.png), showing all of the components of this design.
Most of those components can also be seen in the [top-level](rtl/main.v)
simulatable file, as a processing flow that works its way through that file.
Listed separately, these components are:

1. A/D, 1Msps, taken from the [wbpmic](https://github.com/ZipCPU/wbpmic) repository
2. A [filter](rtl/subfiledown.v), taking the A/D input at 1MHz down by a factor of 23x to 40kHz.  A different configuration of this core will reduce the A/D from 1MHz down to 8kHz, for better resolution of speech.
3. [A hanning window function](rtl/fft/windowfn.v), drawn from the [dblclockfft](https://github.com/ZipCPU/dblclockfft) repository, that not only applies the hanning window but also creates an FFT overlap of 50%
4. An [FFT](rtl/fft), of 1k points which should therefore yield about 43Hz resolution from a 40kHz stream.
6. [A very-rudimentary conversion to dB](rtl/fft/logfn.v)
7. A [controller to write the incoming data to screen memory](rtl/wrdata.v)
8. [Read from screen memory](rtl/vgasim/imgfifo.v)
9. [False colormap](rtl/colormap.v)
10. ... and the final component, the display.  Since this is a verilator simulation, the actual display code, either for [VGA](bench/cpp/vgasim.cpp) or [HDMI](bench/cpp/hdmisim.cpp), is written in C++.  The [VGA simulation code](bench/cpp/vgasim.cpp) was also borrowed, this time from the [vgasim](https://github.com/ZipCPU/vgasim) repository

This project is in response to all of those students who keep asking how to do
this on [Digilent's forum(s)](https://forum.digilentinc.com), while believing
that it is impossible to simulate their designs.  In particular, this design
can be completely simulated from A/D to video output.  VCD files can be
generated, which will tell you *every trace* within this design--useful for
debugging.  Many of the design components have also been formally verified,
so include several of the FFT components.

## Hardware

The code now contains an actual hardware implementation.  This implementation
runs on a Nexys Video board with a PMod MIC3.  It uses the DDR3 SDRAM of the
Nexys Video board for storing the video frames and the HDMI for output.

This portion of the design is currently working on my desktop.

## Copyright

This project is shared under the GPLv3 license.  Please feel free to contact
me if that license is insufficient for your needs.
