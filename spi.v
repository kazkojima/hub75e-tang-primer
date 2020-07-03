// This is a SPI satellite made by dachdecker2
// https://github.com/dachdecker2/icoboard_ws2812b_display/spi.v
// modifed for 32-bits word input only
module spi_satellite (
   input wire 	     clk,
   input wire 	     resetn,
   input wire 	     spi_clk,
   input wire 	     spi_mosi,
   input wire 	     spi_cs,
   output reg [31:0] read_value,
   output reg [0:0]  first_word,
   output reg [0:0]  done
);

   // CPOL == 0: clock state while idle is low  ("inactive")
   // CPOL == 1: clock state while idle is high ("inactive")
   parameter CPOL = 0;
   // CPHA == 0: write on clock deactivation, sample on clock activation
   // CPHA == 1: write on clock activation, sample on clock deactivation
   parameter CPHA = 0;
   parameter LSBFIRST = 0;
   // TIMEOUT__NOT_CS: 0 - use chip select
   //                  1 - don't use chip select, use timeout instead
   parameter TIMEOUT__NOT_CS = 0;
   parameter TIMEOUT_CYCLES  = 2;

   reg [6:0] 	     state = 0; // idle, start, d0, d1, ..., d31
   reg [31:0] 	     value_int = 0;
   wire [0:0] 	     sample;
   wire [0:0] 	     write;
   reg [0:0] 	     spi_clk_reg;    // registered value of spi_clk
   reg [0:0] 	     spi_clk_pre;    // previous value of spi_clk
   reg [0:0] 	     spi_cs_reg;     // registered value of spi_cs
   reg [0:0] 	     spi_cs_pre;     // previous value of spi_cs
   reg [0:0] 	     spi_mosi_reg;   // registered value of spi_mosi
   reg [0:0] 	     spi_mosi_pre;   // previous value of spi_mosi
   reg [0:0] 	     reset_timeout;  // timeout signal, used in timeout mode
   reg [0:0] 	     first_word_int; // high until the first word is done

   assign sample =    (CPOL ^  (CPHA ^ spi_clk_reg))
     && (CPOL ^ !(CPHA ^ spi_clk_pre));

   assign write  =    (CPOL ^ !(CPHA ^ spi_clk_reg))
     && (CPOL ^  (CPHA ^ spi_clk_pre));

   localparam TIMEOUT_CYCLE_BITS = TIMEOUT__NOT_CS * ($clog2(TIMEOUT_CYCLES)-1);
   reg [TIMEOUT_CYCLE_BITS:0] timeout_counter = 0;
   reg [0:0] 		      timeout_expired = 1;

   // actual implementation
   always @(posedge clk) begin
      if (!resetn) begin
         state           <= 0;
         reset_timeout   <= 1;
         done            <= 0;
         timeout_counter <= 0;
         timeout_expired <= 1;
         first_word      <= 0;
         spi_clk_reg     <= 0;
         spi_clk_pre     <= 0;
      end else begin
         timeout_counter <= reset_timeout ? TIMEOUT_CYCLES :
                            (timeout_counter ? timeout_counter - 1 : 0);
         if (!TIMEOUT__NOT_CS) begin
            timeout_expired <= spi_cs_reg;
         end else begin
            timeout_expired <= !timeout_counter;
         end

         // obtain actual and recent values of cs and clk
         spi_cs_reg <= spi_cs;
         spi_cs_pre <= spi_cs_reg;

         spi_clk_reg  <= spi_clk;
         spi_clk_pre  <= spi_clk_reg;

         spi_mosi_reg <= spi_mosi;
         spi_mosi_pre <= spi_mosi_reg;

         // default values
         reset_timeout <= 0;
         read_value <= 0;
         first_word <= 0;
         done <= 0;

         // detect falling edge of CS
         if (!spi_cs_reg && spi_cs_pre) first_word_int <= 1;

         if (timeout_expired) begin
            state <= 0;
            reset_timeout <= 1;
         end else if (sample) begin
            reset_timeout <= 1; // reset timeout in every bit
            value_int <= LSBFIRST ? {spi_mosi, value_int[31:1]}
                         : {value_int[30:0], spi_mosi};
            if (state < 32) begin
               // starting reception while idle
               state <= state + 1;
            end
         end else if (state == 32) begin
            first_word     <= first_word_int;
            first_word_int <= 0;
            read_value     <= value_int;
            done           <= 1;
            state          <= 0;
         end
      end
   end // always @ (posedge clk)

endmodule
