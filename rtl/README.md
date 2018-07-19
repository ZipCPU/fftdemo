Here are the RTL components.  Most of these have been integrated from other
repositories.  For example:

- [memdev.v](memdev.v) came from the [ZBasic](https://github.com/ZipCPU/zbasic) repository
- [pmic](pmic/) came from the [wbpmic](https://github.com/ZipCPU/wbpmic) repository
- [fft](fft/) was generated using the [dblclockfft](https://github.com/ZipCPU/dblclockfft) repository
- [video](video/) was built from the [vgasim](https://github.com/ZipCPU/vgasim) repository, with a few modificatinos to allow scrolling, to remove the test pattern, and to apply a false-color map to 8-bit data
- [subfildown](subfildown.v) comes from a (previously unpublished) member of the [dspfilters](https://github.com/ZipCPU/dspfilters) repository
- [wbpriarbiter.v](wbpriarbiter.v), a priority wishbone arbiter, comes from a [ZipCPU](https://github.com/ZipCPU/zipcpu) repository

If you want to look at an overview of the entire design, you can either take a
peak at the [overview image](../doc/fftdemo.png), or look inside the
[main.v](main.v) module.
