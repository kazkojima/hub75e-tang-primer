`include "pll.v"
`include "spi.v"

module hub75e_if (
		  input 	clk,
		  input 	resetn,
		  output [4:0] 	lines,
		  output 	hub_ck,
		  output 	hub_st,
		  output reg	hub_oe,
		  output [10:0] ram_addr,
		  output reg 	frame_clk
);
   reg [10:0] 			   hub_addr;
   reg [4:0] 			   line;
   reg [1:0] 			   state = 0;
   assign ram_addr = hub_addr;
   assign hub_ck = clk & ~frame_clk;
   assign hub_st = clk & frame_clk;
   assign lines = hub_addr[10:6] - 1;

   always @(negedge clk) begin
      if (!resetn) begin
	 state <= 0;
	 hub_addr <= 0;
	 line <= 0;
	 frame_clk <= 0;
	 hub_oe <= 0;
      end
      if (state == 0) begin
	 if (hub_addr[5:0] == 63) begin
	    frame_clk <= 1;
	    hub_oe <= 1;
	    state <= 1;
	 end else begin
	    hub_addr <= hub_addr + 1;
	    frame_clk <= 0;
	    state <= 0;
	 end
      end
      else if (state == 1) begin
	 state <= 2;
      end
      else if (state == 2) begin
	 frame_clk <= 0;
	 hub_addr <= hub_addr + 1;
	 state <= 3;
      end
      else if (state == 3) begin
	 hub_oe <= 0;
	 state <= 0;
      end
   end // always @ (negedge pin_clk)

endmodule // hub75e_if

module pixram (
	       input wire 	 clk,
	       input wire 	 read,
	       input wire 	 write,
	       input wire [10:0] raddr,
	       input wire [10:0] waddr,
	       output reg [31:0] data_out,
	       input wire [31:0] data_in
);

   reg [31:0] 			 mem[0:2048-1];

   always @(posedge clk) begin
      if (write) begin
         mem[waddr] <= data_in;
      end
      if (read) begin
	 data_out <= mem[raddr];
      end
   end // always @ (posedge clk)

endmodule // pixram

module hub75e (
	       input wire 	 CLK_IN,
	       input wire 	 USER_KEY,
	       output wire [2:0] RGB_LED,
	       output wire 	 hub_R1,
	       output wire 	 hub_G1,
	       output wire 	 hub_B1,
	       output wire 	 hub_R2,
	       output wire 	 hub_G2,
	       output wire 	 hub_B2,
	       output wire 	 hub_E,
	       output wire 	 hub_A,
	       output wire 	 hub_B,
	       output wire 	 hub_C,
	       output wire 	 hub_D,
	       output wire 	 hub_CK,
	       output wire 	 hub_ST,
	       output wire 	 hub_OE,
	       output wire 	 dbg_0,
	       output wire 	 dbg_1,
	       input wire 	 spi_clk,
 	       input wire 	 spi_mosi,
	       input wire 	 spi_cs
);

   // Power-on and user reset
   reg [5:0] 			 reset_cnt = 0;
   wire 			 presetn = &reset_cnt;
   reg 				 uresetn = 0;
   wire 			 resetn = presetn & uresetn;

   always @(posedge CLK_IN) begin
      reset_cnt <= reset_cnt + !presetn;
      uresetn <= USER_KEY;
   end

   wire   clock;
   wire   extlock;
   pll pll0(CLK_IN, 1'b0, extlock, clock);
   //assign clock = CLK_IN;

   wire [31:0] ram_wdata;
   wire [10:0] ram_raddr;
   wire [15:0] ram_rdata1;
   wire [15:0] ram_rdata2;

   wire frame_clk;

   // Setup SPI and data transfers.
   wire spi_firstword;
   wire spi_done;
   wire spi_idle;
   reg [10:0] spi_word_count = 0;
   reg 	      first_cycle_done = 0;

   spi_satellite spi(clock, resetn, spi_clk, spi_mosi, spi_cs,
		 ram_wdata, spi_firstword, spi_done, spi_idle);

   always @(posedge clock) begin
       if (!resetn) begin
	 spi_word_count <= 0;
	 first_cycle_done <= 0;
      end

      if (spi_firstword || spi_idle) begin
         spi_word_count <= 0;
      end

      if (spi_done) begin
         spi_word_count <= spi_word_count + 1;
 	 if (&spi_word_count) begin
	    first_cycle_done <= 1;
	 end
      end

   end // always @ (posedge clock)

   // Pixel 2-port ram
   pixram pram(clock, 1'b1, spi_done, ram_raddr, spi_word_count,
	      {ram_rdata2, ram_rdata1}, ram_wdata);

   // Generate IF signals
   wire [4:0] lines;
   assign { hub_E, hub_D, hub_C, hub_B, hub_A } = lines;
 
   hub75e_if hubif(clock, resetn, lines, hub_CK, hub_ST, hub_OE, ram_raddr, frame_clk);

   // 5 bit PWM.
   reg [9:0] frame_count;
   always @(posedge frame_clk) begin
      if (!resetn) begin
	 frame_count <= 0;
      end
      else begin
	 frame_count <= frame_count + 1;
      end
   end

   // Enable display
   wire enable;
   assign       enable = first_cycle_done;

   assign hub_R1 = (ram_rdata1[14:10] > frame_count[9:5]) & enable;
   assign hub_G1 = (ram_rdata1[9:5] > frame_count[9:5]) & enable;
   assign hub_B1 = (ram_rdata1[4:0] > frame_count[9:5]) & enable;
   assign hub_R2 = (ram_rdata2[14:10] > frame_count[9:5]) & enable;
   assign hub_G2 = (ram_rdata2[9:5] > frame_count[9:5]) & enable;
   assign hub_B2 = (ram_rdata2[4:0] > frame_count[9:5]) & enable;


   assign RGB_LED[0] = 1'b1;
   assign RGB_LED[1] = 1'b1;
   assign RGB_LED[2] = spi_cs;
   assign dbg_0 = &spi_word_count;
   assign dbg_1 = first_cycle_done;

endmodule // hub75e
