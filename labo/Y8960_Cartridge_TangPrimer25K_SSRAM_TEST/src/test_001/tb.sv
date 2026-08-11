// -----------------------------------------------------------------------------
//	Test bench for y8960cartridge_tangprimer25k (top-level)
// =============================================================================
//	Instantiates the DUT with ssram_test_model as the Serial SRAM.
//	Gowin_PLL is replaced by a simulation stub (gowin_pll_sim.v).
//
//	The DUT runs a 4-phase SSRAM test:
//	  Phase 1: Single write  (increment pattern, 512KB)
//	  Phase 2: Single read   & verify (increment pattern)
//	  Phase 3: Single write  (decrement pattern, 512KB)
//	  Phase 4: Single read   & verify (decrement pattern)
//
//	LED[0]: Phase 1 complete
//	LED[1]: Phase 2 result (ON=OK, blink=NG)
//	LED[2]: Phase 3 complete
//	LED[3]: Phase 4 result (ON=OK, blink=NG)
//	(active low: 0=ON, 1=OFF)
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module tb ();
	// ----------------------------------------------------------------
	//	Clock periods (ps)
	// ----------------------------------------------------------------
	localparam	clk_28m_base	= 1_000.0 / 28.63636;		//	~34926 ps
	localparam	clk_50m_base	= 1_000.0 / 50.00000;		//	 20000 ps

	// ----------------------------------------------------------------
	//	Signals
	// ----------------------------------------------------------------
	reg				clk_28m;
	reg				clk_50m;
	wire			sram_ce_n;
	wire			sram_sclk;
	wire	[3:0]	sram_sio;
	reg		[1:0]	dipsw;
	wire	[3:0]	led;
	reg		[3:0]	ff_led = 4'b1111;
	wire			uart_tx;

	// ----------------------------------------------------------------
	//	DUT: y8960cartridge_tangprimer25k
	// ----------------------------------------------------------------
	y8960cartridge_tangprimer25k u_dut (
		.clk_28m		( clk_28m		),
		.clk_50m		( clk_50m		),
		.sram_ce_n		( sram_ce_n		),
		.sram_sclk		( sram_sclk		),
		.sram_sio		( sram_sio		),
		.dipsw			( dipsw			),
		.led			( led			),
		.uart_tx		( uart_tx		)
	);

	// ----------------------------------------------------------------
	//	Serial SRAM model
	// ----------------------------------------------------------------
	ssram_test_model #(
		.DEBUG_OUT		( 0				)
	) u_sram_model (
		.sclk			( sram_sclk		),
		.cs_n			( sram_ce_n		),
		.sio			( sram_sio		)
	);

	// ----------------------------------------------------------------
	//	Clock generators
	// ----------------------------------------------------------------
	always #(clk_28m_base / 2) begin
		clk_28m <= ~clk_28m;
	end

	always #(clk_50m_base / 2) begin
		clk_50m <= ~clk_50m;
	end

	// ----------------------------------------------------------------
	//	Debug log
	// ----------------------------------------------------------------
	always @( posedge clk_28m ) begin
		ff_led <= led;
	end

	initial begin
		forever begin
			if( ff_led != led ) begin
				$display( "[%0t] LED Changed: %1d%1d%1d%1d", $realtime, led[3], led[2], led[1], led[0] );
			end
			@( posedge clk_28m );
		end
	end

	// ----------------------------------------------------------------
	//	Timeout watchdog
	// ----------------------------------------------------------------
	localparam	TIMEOUT_MS	= 5000;		//	5 seconds simulation time
	initial begin
		#(TIMEOUT_MS * 1_000_000);
		$display( "============================================" );
		$display( "[TB] TIMEOUT after %0d ms -- aborting.", TIMEOUT_MS );
		$display( "============================================" );
		$finish;
	end

	// ----------------------------------------------------------------
	//	Main test sequence
	// ----------------------------------------------------------------
	initial begin
		clk_28m	= 1'b1;
		clk_50m	= 1'b1;
		dipsw	= 2'b00;

		$display( "============================================" );
		$display( "[%0t][TB] Simulation start", $realtime );
		$display( "============================================" );

		// --------------------------------------------------------
		//	DIPSW trigger at proper timing
		//	led=1110 means ST_WAIT_DIP in current top-level polarity.
		// --------------------------------------------------------
		wait( led == 4'b1110 );
		repeat( 70000 ) @( posedge clk_28m );
		dipsw <= 2'b01;
		@( posedge clk_28m );

		$display( "[TB] DIPSW trigger injected after stable wait." );

		// --------------------------------------------------------
		//	Wait until PASS LED pattern appears
		//	w_led=1011 -> led=0100 because top-level output is inverted.
		// --------------------------------------------------------
		wait( led == 4'b0100 );

		repeat( 100 ) @( posedge clk_28m );

		$display( "============================================" );
		$display( "[TB] RESULT: ALL TESTS PASSED" );
		$display( "============================================" );

		$finish;
	end
endmodule
