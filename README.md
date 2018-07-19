This project will contains a Verilator FFT to screen spectrogram demonstration.
To build, type "make" in the main directory.  This will build a file "main\_tb"
in the [bench/cpp](bench/cpp) directory.  Running that program will simulate
the entire design, all the way from A/D to display output, all using Verilator.
You will need to install Verilator and gtkmm to do this.

There's a pictoral overview of the project in the doc directory
[here](doc/fftdemo.png), showing all of the components of this design.
Most of those components can also be seen in the [top-level](rtl/main.v)
simulatable file, as a processing flow that works its way through that file.
Listed separately, these components are:

1. A/D, 1Msps, taken from the [wbpmic](https://github.com/ZipCPU/wbpmic) repository
2. A [filter](rtl/subfiledown.v), taking the A/D input at 1MHz down by a factor of 23x to 40kHz
3. [A hanning window function](rtl/fft/windowfn.v), drawn from the [dblclockfft](https://github.com/ZipCPU/dblclockfft) repository, that not only applies the hanning window but also creates an FFT overlap of 50%
4. An [FFT](rtl/fft), if 1k points which should therefore yield about 43Hz resolution
6. [A very-rudimentary conversion to dB](rtl/fft/logfn.v)
7. A controller to write the incoming data to screen memory
8. [Read from screen memory](rtl/vgasim/imgfifo.v)
9. [False colormap](rtl/colormap.v)
10. ... and the final component, the display.  Since this is a verilator simulation, the actual [display code](bench/cpp/vgasim.cpp) is written in C++.  It was also borrowed, this time from the [vgasim](https://github.com/ZipCPU/vgasim) repository

This project is in response to all of those students who keep asking how to do
this on [Digilent's forum(s)](https://forum.digilentinc.com), while believing
that it is impossible to simulate their designs.  In particular, this design
can be completely simulated from A/D to video output.  VCD files can be
generated, which will tell you *every trace* within this design--useful for
debugging.  Many of the design components have also been formally verified,
so include several of the FFT components.

## Copyright

This project is shared under the GPLv3 license.  Please feel free to contact
me if that license is insufficient for your needs.
