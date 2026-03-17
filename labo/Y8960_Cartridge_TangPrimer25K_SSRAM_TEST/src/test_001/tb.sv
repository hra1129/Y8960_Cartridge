// -----------------------------------------------------------------------------
//	Test bench for y8960cartridge_tangprimer25k (top-level)
// =============================================================================
//	Instantiates the DUT with ssram_test_model as the Serial SRAM.
//	Gowin_PLL is replaced by a simulation stub (gowin_pll_sim.v).
//
//	The DUT runs a 4-phase SSRAM test:
//	  Phase 1: Burst write   (increment pattern, 512KB)
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
		.led			( led			)
	);

	// ----------------------------------------------------------------
	//	Serial SRAM model
	// ----------------------------------------------------------------
	ssram_test_model u_sram_model (
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
	//	Timeout watchdog
	// ----------------------------------------------------------------
	localparam	TIMEOUT_MS	= 5000;		//	5 seconds simulation time
	initial begin
		#(TIMEOUT_MS * 1_000_000);
		$display( "============================================" );
		$display( "[TB] TIMEOUT after %0d ms -- aborting.", TIMEOUT_MS );
		$display( "  Phase 1 done = %b", u_dut.ff_phase1_done );
		$display( "  Phase 2 done = %b", u_dut.ff_phase2_done );
		$display( "  Phase 3 done = %b", u_dut.ff_phase3_done );
		$display( "  Phase 4 done = %b", u_dut.ff_phase4_done );
		$display( "  Error 1      = %b", u_dut.ff_error1 );
		$display( "  Error 2      = %b", u_dut.ff_error2 );
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
		$display( "[TB] Simulation start" );
		$display( "============================================" );

		// --------------------------------------------------------
		//	Wait for each phase to complete, report progress
		// --------------------------------------------------------
		fork
			begin
				wait( u_dut.ff_phase1_done === 1'b1 );
				$display( "[TB] Phase 1 complete -- burst write (increment pattern)" );
			end
			begin
				wait( u_dut.ff_phase2_done === 1'b1 );
				$display( "[TB] Phase 2 complete -- read & verify (increment pattern)" );
			end
			begin
				wait( u_dut.ff_phase3_done === 1'b1 );
				$display( "[TB] Phase 3 complete -- single write (decrement pattern)" );
			end
			begin
				wait( u_dut.ff_phase4_done === 1'b1 );
				$display( "[TB] Phase 4 complete -- read & verify (decrement pattern)" );
			end
		join

		// --------------------------------------------------------
		//	Let a few more clocks pass, then report results
		// --------------------------------------------------------
		repeat( 100 ) @( posedge clk_28m );

		$display( "============================================" );
		if( !u_dut.ff_error1 && !u_dut.ff_error2 ) begin
			$display( "[TB] RESULT: ALL TESTS PASSED" );
		end
		else begin
			if( u_dut.ff_error1 )
				$display( "[TB] RESULT: Phase 2 read-verify FAILED (error1)" );
			if( u_dut.ff_error2 )
				$display( "[TB] RESULT: Phase 4 read-verify FAILED (error2)" );
		end
		$display( "[TB] LED = %b (active-low: 0=ON)", led );
		$display( "============================================" );

		$finish;
	end
endmodule
