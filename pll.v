// Tang PRiMer's PLL is described in Eagle datasheet:
// https://github.com/kprasadvnsi/tang-doc/releases/download/1.0.0/Eagle_DataSheet_V2.8_english.pdf
// VCO frequency range should be 300-1200 Mhz.
// A static configuration to output 16Mhz on channel 0.
//   FIN*FBCLK_DIV/REFCLK_DIV = 24*16/24 = 16Mhz
// See yosys/techlibs/anlogic/eagle_bb.v for more EG_PHY_PLL parameters.
module pll (
	    input refclk,
	    input reset,
	    output extlock,
	    output clk0_out)
;

   wire 	   clk0_buf;

   EG_LOGIC_BUFG bufg_feedback(.i(clk0_buf), .o(clk0_out));

   EG_PHY_PLL #(
		.DPHASE_SOURCE("DISABLE"),
		.DYNCFG("DISABLE"),
		.FIN("24.000"),
		.FEEDBK_MODE("NORMAL"),
		.FEEDBK_PATH("CLKC0_EXT"),
		.STDBY_ENABLE("DISABLE"),
		.PLLRST_ENA("ENABLE"),
		.SYNC_ENABLE("ENABLE"),
		.DERIVE_PLL_CLOCKS("DISABLE"),
		.GEN_BASIC_CLOCK("DISABLE"),
		.GMC_GAIN(6),
		.ICP_CURRENT(3),
		.KVCO(6),
		.LPF_CAPACITOR(3),
		.LPF_RESISTOR(2),
		.REFCLK_DIV(24),
		.FBCLK_DIV(16),
		.CLKC0_ENABLE("ENABLE"),
		.CLKC0_DIV(30),
		.CLKC0_CPHASE(30),
		.CLKC0_FPHASE(0)
		)
   pll_inst (
	     .refclk(refclk),
	     .reset(reset),
	     .stdby(1'b0),
	     .extlock(extlock),
	     .psclk(1'b0),
	     .psdown(1'b0),
	     .psstep(1'b0),
	     .psclksel(3'b000),
	     .psdone(open),
	     .dclk(1'b0),
	     .dcs(1'b0),
	     .dwe(1'b0),
	     .di(8'b00000000),
	     .daddr(6'b000000),
	     .do({open, open, open, open, open, open, open, open}),
	     .fbclk(clk0_out),
	     .clkc({open, open, open, open, clk0_buf})
);

endmodule // pll
