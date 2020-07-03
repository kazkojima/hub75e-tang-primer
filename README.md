## HUB75E driver with Tang PRiMer FPGA

This is a driver by Tang PRiMer for 64x64 LED panels with the HUB75E
interface, based on https://github.com/shinyblink/sled-fpga-hub75.
The bit-stream is generated with [yosys](https://github.com/YosysHQ/yosys) and [nextpnr](https://github.com/YosysHQ/nextpnr).

![picture of a sled example](https://github.com/kazkojima/hub75e-tang-primer/blob/junkyard/images/hub75e-tang-primer.jpg)

The main SPI should assert CS, write 64x64(4096) RGB555 words and negate CS
with mode0. The HUB75E panel is divided to 2 64x32 planes and the SPI data
should be organized as

```
   word 0, word 2048, word 1, word 2049, ... , word 2047, word 4095
```

so as to get 2 words for both panels at the same time with one 32-bit data
from BRAM.

This driver does nothing to sync frame read/write from/to BRAM, the images
displayed on the top and bottom panels may be out of sync.

I use 16Mhz clock for the base clock to minimize the artifacts on my panel,
though there may be panels which can be ok with the higher clocks. You can
change the base clock with modifying pll.v. SPI requires the base clock
which is at least x4 the SCLK, i.e. the maximal SCLK is limited by 4Mhz
for the 16Mhz base clock.

The prerequisites is yosys, nextpnr and Anlogic TD(Tang Dynasty) which is
needed to write bit-stream to the chip.  See also [yosys's examples/anlogic/README](https://github.com/YosysHQ/yosys/blob/master/examples/anlogic/README).
