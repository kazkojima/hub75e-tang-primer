PROG=hub75e

all: $(PROG).bit

$(PROG).bit: $(PROG).v pll.v spi.v
	./build.sh

clean:
	rm -rf *.log *~ full.v $(PROG).bit
	rm -rf $(PROG)_*.h $(PROG)_phy.area $(PROG)_sram.svf $(PROG)_sram.tde
