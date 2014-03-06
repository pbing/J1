/* FPGA Top level */

module CII_Starter_TOP (/* Clock Input */
                        input [1:0]   CLOCK_24,    // 24 MHz
                        input [1:0]   CLOCK_27,    // 27 MHz
                        input         CLOCK_50,    // 50 MHz
                        input         EXT_CLOCK,   // External Clock

                        /* Push Button */
                        input [3:0]   KEY,         // Pushbutton[3:0]

                        /* DPDT Switch */
                        input [9:0]   SW,          // Toggle Switch[9:0]

                        /* 7-SEG Display */
                        output logic [6:0]  HEX0,  // Seven Segment Digit 0
                        output logic [6:0]  HEX1,  // Seven Segment Digit 1
                        output logic [6:0]  HEX2,  // Seven Segment Digit 2
                        output logic [6:0]  HEX3,  // Seven Segment Digit 3

                        /* LED */
                        output logic [7:0]  LEDG,  // LED Green[7:0]
                        output logic [9:0]  LEDR,  // LED Red[9:0]

                        /* UART */
                        output        UART_TXD,    // UART Transmitter
                        input         UART_RXD,    // UART Receiver

                        /* SDRAM Interface */
                        inout  [15:0] DRAM_DQ,     // SDRAM Data bus 16 Bits
                        output [11:0] DRAM_ADDR,   // SDRAM Address bus 12 Bits
                        output        DRAM_LDQM,   // SDRAM Low-byte Data Mask
                        output        DRAM_UDQM,   // SDRAM High-byte Data Mask
                        output        DRAM_WE_N,   // SDRAM Write Enable
                        output        DRAM_CAS_N,  // SDRAM Column Address Strobe
                        output        DRAM_RAS_N,  // SDRAM Row Address Strobe
                        output        DRAM_CS_N,   // SDRAM Chip Select
                        output        DRAM_BA_0,   // SDRAM Bank Address 0
                        output        DRAM_BA_1,   // SDRAM Bank Address 0
                        output        DRAM_CLK,    // SDRAM Clock
                        output        DRAM_CKE,    // SDRAM Clock Enable

                        /* Flash Interface */
                        inout  [7:0]  FL_DQ,       // FLASH Data bus 8 Bits
                        output [21:0] FL_ADDR,     // FLASH Address bus 22 Bits
                        output        FL_WE_N,     // FLASH Write Enable
                        output        FL_RST_N,    // FLASH Reset
                        output        FL_OE_N,     // FLASH Output Enable
                        output        FL_CE_N,     // FLASH Chip Enable

                        /* SRAM Interface */
                        inout  [15:0] SRAM_DQ,     // SRAM Data bus 16 Bits
                        output [17:0] SRAM_ADDR,   // SRAM Address bus 18 Bits
                        output        SRAM_UB_N,   // SRAM High-byte Data Mask
                        output        SRAM_LB_N,   // SRAM Low-byte Data Mask
                        output        SRAM_WE_N,   // SRAM Write Enable
                        output        SRAM_CE_N,   // SRAM Chip Enable
                        output        SRAM_OE_N,   // SRAM Output Enable

                        /* SD Card Interface */
                        inout         SD_DAT,      // SD Card Data
                        inout         SD_DAT3,     // SD Card Data 3
                        inout         SD_CMD,      // SD Card Command Signal
                        output        SD_CLK,      // SD Card Clock

                        /* I2C */
                        inout         I2C_SDAT,    // I2C Data
                        output        I2C_SCLK,    // I2C Clock

                        /* PS2 */
                        input         PS2_DAT,     // PS2 Data
                        input         PS2_CLK,     // PS2 Clock

                        /* USB JTAG link */
                        input         TDI,         // CPLD -> FPGA (data in)
                        input         TCK,         // CPLD -> FPGA (clk)
                        input         TCS,         // CPLD -> FPGA (CS)
                        output        TDO,         // FPGA -> CPLD (data out)

                        /* VGA */
                        output        VGA_HS,      // VGA H_SYNC
                        output        VGA_VS,      // VGA V_SYNC
                        output [3:0]  VGA_R,       // VGA Red[3:0]
                        output [3:0]  VGA_G,       // VGA Green[3:0]
                        output [3:0]  VGA_B,       // VGA Blue[3:0]

                        /* Audio CODEC */
                        inout         AUD_ADCLRCK, // Audio CODEC ADC LR Clock
                        input         AUD_ADCDAT,  // Audio CODEC ADC Data
                        inout         AUD_DACLRCK, // Audio CODEC DAC LR Clock
                        output        AUD_DACDAT,  // Audio CODEC DAC Data
                        inout         AUD_BCLK,    // Audio CODEC Bit-Stream Clock
                        output        AUD_XCK,     // Audio CODEC Chip Clock

                        /* GPIO */
                        inout [35:0]  GPIO_0,      // GPIO Connection 0
                        inout [35:0]  GPIO_1);     // GPIO Connection 1

   /* I/O addresses */
   localparam bit [15:0] io_ledg = 16'h4000,
			 io_ledr = 16'h4002,

			 io_hex0 = 16'h4010,
			 io_hex1 = 16'h4012,
			 io_hex2 = 16'h4014,
			 io_hex3 = 16'h4016,

			 io_key  = 16'h4020,
			 io_sw   = 16'h4022;

   /* common signals */
   wire reset;
   wire clk;

   /* I/O signals */
   logic [15:0] io_din;
   wire  [15:0] io_dout,io_addr;
   wire         io_rd,io_wr;

   /* I/O assignments */
   assign clk = CLOCK_24[0];

   sync_reset sync_reset(.clk(clk),.key(KEY[0]),.reset(reset));

   j1 j1(.sys_clk_i(clk),.sys_rst_i(reset),.*);

   always_ff @(posedge clk)
     if (reset)
       begin
	  LEDG <= '0;
	  LEDR <= '0;
	  HEX0 <= '0;
	  HEX1 <= '0;
	  HEX2 <= '0;
	  HEX3 <= '0;
       end
     else
       if (io_wr)
	 case (io_addr)
	   io_ledg: LEDG <= io_dout[7:0];
	   io_ledr: LEDR <= io_dout[9:0];
	   io_hex0: HEX0 <= io_dout[6:0];
	   io_hex1: HEX1 <= io_dout[6:0];
	   io_hex2: HEX2 <= io_dout[6:0];
	   io_hex3: HEX3 <= io_dout[6:0];
	 endcase

   always_comb
     begin
	io_din = '0;

	if (io_rd)
	  case (io_addr)
	    io_key: io_din[3:0] = KEY;
	    io_sw : io_din[9:0] = SW;
	  endcase
     end
endmodule
