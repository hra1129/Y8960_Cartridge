// -----------------------------------------------------------------------------
//	Test of dual_ssg.v
//	Copyright (C)2026 Takayuki Hara (HRA!)
//	
//	 Permission is hereby granted, free of charge, to any person obtaining a 
//	copy of this software and associated documentation files (the "Software"), 
//	to deal in the Software without restriction, including without limitation 
//	the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//	and/or sell copies of the Software, and to permit persons to whom the 
//	Software is furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in 
//	all copies or substantial portions of the Software.
//	
//	The Software is provided "as is", without warranty of any kind, express or 
//	implied, including but not limited to the warranties of merchantability, 
//	fitness for a particular purpose and noninfringement. In no event shall the 
//	authors or copyright holders be liable for any claim, damages or other 
//	liability, whether in an action of contract, tort or otherwise, arising 
//	from, out of or in connection with the Software or the use or other dealings 
//	in the Software.
// -----------------------------------------------------------------------------
//	Description:
//		Pulse wave modulation
// -----------------------------------------------------------------------------

module tb ();
	localparam	clk_base	= 1_000_000_000/85.90908;	//	ps
	int				test_no;
	int				i, j;
	reg				clk;
	reg				clk_14m;
	reg				clk_50m;
	//	slot
	reg				slot_reset;
	reg		[15:0]	slot_a;
	wire	[7:0]	slot_d;
	reg				slot_sltsl;
	reg				slot_mereq_n;
	reg				slot_ioreq_n;
	reg				slot_wr_n;
	reg				slot_rd_n;
	wire			slot_wait;
	wire			slot_intr;
	wire			slot_busdir;
	//	audio
	wire			audio_mclk;
	wire			audio_bclk;
	wire			audio_lrclk;
	wire			audio_sdata;
	//	flash ROM
	wire			flash_spi_clk;
	wire			flash_spi_cs_n;
	wire			flash_spi_wp_n;
	wire			flash_spi_hold_n;
	reg				flash_spi_miso;
	wire			flash_spi_mosi;
	//	PSRAM
	wire			psram_ce_n;
	wire			psram_sclk;
	wire	[3:0]	psram_sio;
	//	DIP S/W
	reg		[1:0]	dipsw;
	//	LED
	wire	[3:0]	led;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	y8960cartridge_tangprimer25k u_dut (
		.clk_14m				( clk					),
		.clk_50m				( clk					),
		.slot_reset				( slot_reset			),
		.slot_a					( slot_a				),
		.slot_d					( slot_d				),
		.slot_sltsl				( slot_sltsl			),
		.slot_mereq_n			( slot_mereq_n			),
		.slot_ioreq_n			( slot_ioreq_n			),
		.slot_wr_n				( slot_wr_n				),
		.slot_rd_n				( slot_rd_n				),
		.slot_wait				( slot_wait				),
		.slot_intr				( slot_intr				),
		.slot_busdir			( slot_busdir			),
		.audio_mclk				( audio_mclk			),
		.audio_bclk				( audio_bclk			),
		.audio_lrclk			( audio_lrclk			),
		.audio_sdata			( audio_sdata			),
		.flash_spi_clk			( flash_spi_clk			),
		.flash_spi_cs_n			( flash_spi_cs_n		),
		.flash_spi_wp_n			( flash_spi_wp_n		),
		.flash_spi_hold_n		( flash_spi_hold_n		),
		.flash_spi_miso			( flash_spi_miso		),
		.flash_spi_mosi			( flash_spi_mosi		),
		.psram_ce_n				( psram_ce_n			),
		.psram_sclk				( psram_sclk			),
		.psram_sio				( psram_sio				),
		.dipsw					( dipsw					),
		.led					( led					)
	);

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	Task
	// --------------------------------------------------------------------

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		logic			time_out;
		logic	[7:0]	data;

		test_no = -1;
		clk = 1;
		slot_reset = 0;
		slot_a = 0;
		slot_sltsl = 0;
		slot_mereq_n = 0;
		slot_ioreq_n = 0;
		slot_wr_n = 0;
		slot_rd_n = 0;
		flash_spi_miso = 0;
		dipsw = 0;

		@( negedge clk );
		@( negedge clk );
		@( posedge clk );

		@( posedge clk );

		repeat( 100 ) @( posedge clk );
		$finish;
	end
endmodule
