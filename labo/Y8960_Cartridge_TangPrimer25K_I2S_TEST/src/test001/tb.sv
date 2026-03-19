// -----------------------------------------------------------------------------
//	Test of y8960_cartridge_tangprimer25k.v
//	Copyright (C)2026 Takayuki Hara (HRA!)
// -----------------------------------------------------------------------------

// --------------------------------------------------------------------
//	Gowin_PLL stub for simulation
// --------------------------------------------------------------------
module Gowin_PLL (
	input			clkin,
	output			clkout0,
	output			clkout1,
	input			mdclk
);
	//	clkout0 : 128.86362MHz (period ≒ 7.760ns)
	//	clkout1 :  24.576MHz   (period ≒ 40.690ns)
	localparam	longint	period_129m	= 64'd1_000_000_000_000 / 64'd128_863_620;	//	ps
	localparam	longint	period_25m	= 64'd1_000_000_000_000 / 64'd24_576_000;	//	ps

	reg		r_clk129m = 1'b0;
	reg		r_clk25m  = 1'b0;

	always #(period_129m/2) r_clk129m <= ~r_clk129m;
	always #(period_25m/2)  r_clk25m  <= ~r_clk25m;

	assign clkout0 = r_clk129m;
	assign clkout1 = r_clk25m;
endmodule

// --------------------------------------------------------------------
//	Testbench
// --------------------------------------------------------------------
module tb ();
	longint			clk28_base	= 64'd1_000_000_000_000 / 64'd28_636_360;	//	ps (28.63636MHz)
	longint			clk50_base	= 64'd1_000_000_000_000 / 64'd50_000_000;	//	ps (50MHz)

	reg				clk_28m;
	reg				clk_50m;
	reg		[1:0]	dipsw;

	wire			audio_mclk;
	wire			audio_bclk;
	wire			audio_lrclk;
	wire			audio_sdata;
	wire	[3:0]	led;

	int				error_count;
	int				bclk_edge_count;
	int				lrclk_toggle_count;
	reg				prev_audio_bclk;
	reg				prev_audio_lrclk;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	y8960cartridge_tangprimer25k u_dut (
		.clk_28m			( clk_28m			),
		.clk_50m			( clk_50m			),
		.audio_mclk			( audio_mclk		),
		.audio_bclk			( audio_bclk		),
		.audio_lrclk		( audio_lrclk		),
		.audio_sdata		( audio_sdata		),
		.dipsw				( dipsw				),
		.led				( led				)
	);

	// --------------------------------------------------------------------
	//	clock : 28.63636MHz
	// --------------------------------------------------------------------
	always #(clk28_base/2) begin
		clk_28m <= ~clk_28m;
	end

	// --------------------------------------------------------------------
	//	clock : 50MHz
	// --------------------------------------------------------------------
	always #(clk50_base/2) begin
		clk_50m <= ~clk_50m;
	end

	// --------------------------------------------------------------------
	//	I2S output monitor
	// --------------------------------------------------------------------
	always @( posedge clk_28m ) begin
		prev_audio_bclk  <= audio_bclk;
		prev_audio_lrclk <= audio_lrclk;

		//	BCLK edge count (rising)
		if( !prev_audio_bclk && audio_bclk ) begin
			bclk_edge_count <= bclk_edge_count + 1;
		end

		//	LRCLK toggle count
		if( prev_audio_lrclk != audio_lrclk ) begin
			lrclk_toggle_count <= lrclk_toggle_count + 1;
		end
	end

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		clk_28m          = 0;
		clk_50m          = 0;
		dipsw            = 2'b00;
		error_count      = 0;
		bclk_edge_count  = 0;
		lrclk_toggle_count = 0;
		prev_audio_bclk  = 0;
		prev_audio_lrclk = 0;

		$display( "[%t] Simulation start.", $realtime );

		// ---- Wait for reset to complete (power-on reset is ~15 clk_25m cycles)
		#1us;
		$display( "[%t] Reset should be released by now.", $realtime );

		// ---- Run for ~100ms to observe tone changes and I2S output
		//       48kHz * 4800 samples = 100ms per tone, 8 tones = 800ms total
		//       Run 1000ms to cover all tones + margin
		#1000ms;

		$display( "" );
		$display( "======================================" );
		$display( "  BCLK rising edges : %0d", bclk_edge_count );
		$display( "  LRCLK toggles     : %0d", lrclk_toggle_count );
		$display( "  LED state         : %04b", led );
		$display( "======================================" );

		// ---- Basic sanity checks
		//  BCLK should be ~6.144MHz => ~6,144,000 edges/sec => ~6,144,000 in 1s
		if( bclk_edge_count < 5_000_000 ) begin
			$display( "[ERROR] BCLK edge count too low: %0d (expected ~6,144,000)", bclk_edge_count );
			error_count = error_count + 1;
		end

		//  LRCLK should toggle at ~96kHz => ~96,000 toggles/sec
		if( lrclk_toggle_count < 80_000 ) begin
			$display( "[ERROR] LRCLK toggle count too low: %0d (expected ~96,000)", lrclk_toggle_count );
			error_count = error_count + 1;
		end

		if( error_count == 0 ) begin
			$display( "TEST PASSED" );
		end
		else begin
			$display( "TEST FAILED (%0d errors)", error_count );
		end

		$finish;
	end
endmodule
