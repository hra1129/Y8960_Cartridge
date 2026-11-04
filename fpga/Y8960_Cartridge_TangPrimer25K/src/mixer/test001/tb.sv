module tb ();
	localparam	clk_base = 1_000_000_000_000.0 / 42_954_540;

	reg					clk;
	reg					reset_n;
	reg		[12:0]		ssg_l;
	reg		[12:0]		ssg_r;
	reg signed	[15:0]	opll_l;
	reg signed	[15:0]	opll_r;
	reg signed	[15:0]	opl2_l;
	reg signed	[15:0]	opl2_r;
	reg signed	[10:0]	scc_l;
	reg signed	[10:0]	scc_r;
	reg signed	[15:0]	opm_l;
	reg signed	[15:0]	opm_r;
	reg		[7:0]		ssg_volume;
	reg		[7:0]		opll_volume;
	reg		[7:0]		opl2_volume;
	reg		[7:0]		scc_volume;
	reg		[7:0]		opm_volume;
	reg		[7:0]		master_volume;
	wire signed	[23:0]	audio_l_out;
	wire signed	[23:0]	audio_r_out;
	wire				audio_valid;
	integer				error_count;

	mixier u_dut (
		.clk			( clk			),
		.reset_n		( reset_n		),
		.ssg_l			( ssg_l		),
		.ssg_r			( ssg_r		),
		.opll_l			( opll_l		),
		.opll_r			( opll_r		),
		.opl2_l			( opl2_l		),
		.opl2_r			( opl2_r		),
		.scc_l			( scc_l			),
		.scc_r			( scc_r			),
		.opm_l			( opm_l			),
		.opm_r			( opm_r			),
		.ssg_volume		( ssg_volume	),
		.opll_volume	( opll_volume	),
		.opl2_volume	( opl2_volume	),
		.scc_volume		( scc_volume	),
		.opm_volume		( opm_volume	),
		.master_volume	( master_volume	),
		.audio_l_out	( audio_l_out	),
		.audio_r_out	( audio_r_out	),
		.audio_valid	( audio_valid	)
	);

	always #(clk_base/2) clk = ~clk;

	task check_output(
		input string name,
		input signed [23:0] expected_l,
		input signed [23:0] expected_r
	);
		repeat( 30 ) @( posedge clk );
		#1;
		if( audio_l_out == expected_l && audio_r_out == expected_r ) begin
			$display( "OK   : %s L=%0d R=%0d", name, audio_l_out, audio_r_out );
		end
		else begin
			$display( "ERROR: %s expected L=%0d R=%0d, actual L=%0d R=%0d",
				name, expected_l, expected_r, audio_l_out, audio_r_out );
			error_count = error_count + 1;
		end
	endtask

	initial begin
		clk				= 1'b0;
		reset_n			= 1'b0;
		ssg_l			= 13'd0;
		ssg_r			= 13'd0;
		opll_l			= 16'sd0;
		opll_r			= 16'sd0;
		opl2_l			= 16'sd0;
		opl2_r			= 16'sd0;
		scc_l			= 11'sd0;
		scc_r			= 11'sd0;
		opm_l			= 16'sd0;
		opm_r			= 16'sd0;
		ssg_volume		= 8'd128;
		opll_volume		= 8'd128;
		opl2_volume		= 8'd128;
		scc_volume		= 8'd128;
		opm_volume		= 8'd128;
		master_volume	= 8'd128;
		error_count		= 0;

		repeat( 3 ) @( posedge clk );
		if( audio_l_out != 24'sd0 || audio_r_out != 24'sd0 ) begin
			$display( "ERROR: reset output is not zero" );
			error_count = error_count + 1;
		end
		reset_n = 1'b1;
		//	The SSG DC cut is tested separately at the end.
		force u_dut.ff_ssg_dc_l = 29'd0;
		force u_dut.ff_ssg_dc_r = 29'd0;

		ssg_l	= 13'd1000;
		ssg_r	= 13'd2000;
		opll_l	= -16'sd200;
		opll_r	= 16'sd300;
		opl2_l	= 16'sd400;
		opl2_r	= -16'sd500;
		scc_l	= -11'sd50;
		scc_r	= -11'sd50;
		check_output( "all sources at 100%", 24'sd1689600, 24'sd3635200 );

		ssg_l	= 13'd1024;
		ssg_r	= 13'd1024;
		opll_l	= 16'sd1024;
		opll_r	= 16'sd1024;
		opl2_l	= 16'sd1024;
		opl2_r	= 16'sd1024;
		scc_l	= 11'sd256;
		scc_r	= -11'sd256;
		ssg_volume		= 8'd64;
		opll_volume		= 8'd32;
		opl2_volume		= 8'd0;
		scc_volume		= 8'd127;
		check_output( "independent gains and SCC L/R", 24'sd3194880, -24'sd966656 );

		ssg_volume		= 8'd0;
		opll_volume		= 8'd0;
		opl2_volume		= 8'd0;
		scc_volume		= 8'd0;
		check_output( "all sources muted", 24'sd0, 24'sd0 );

		ssg_volume		= 8'd128;
		opll_volume		= 8'd128;
		opl2_volume		= 8'd128;
		scc_volume		= 8'd128;
		ssg_l	= 13'd1000;
		ssg_r	= 13'd2000;
		opll_l	= -16'sd200;
		opll_r	= 16'sd300;
		opl2_l	= 16'sd400;
		opl2_r	= -16'sd500;
		scc_l	= -11'sd50;
		scc_r	= -11'sd50;
		master_volume	= 8'd64;
		check_output( "master volume 50%", 24'sd844800, 24'sd1817600 );

		master_volume	= 8'd1;
		check_output( "master volume 1/128", 24'sd13200, 24'sd28400 );

		master_volume	= 8'd255;
		check_output( "master volume bit7 clamps to 100%", 24'sd1689600, 24'sd3635200 );

		master_volume	= 8'd0;
		check_output( "master volume muted", 24'sd0, 24'sd0 );

		ssg_l	= 13'd8191;
		ssg_r	= 13'd8191;
		opll_l	= 16'sd32767;
		opll_r	= -16'sd32768;
		opl2_l	= 16'sd32767;
		opl2_r	= -16'sd32768;
		scc_l	= 11'sd1023;
		scc_r	= -11'sd1024;
		master_volume	= 8'd128;
		check_output( "full scale at master 100% (L/R saturated)", 24'sd8388607, -24'sd8388608 );

		master_volume	= 8'd96;
		check_output( "full scale at master 75%", 24'sd6291455, -24'sd6291456 );

		ssg_l	= 13'd0;
		ssg_r	= 13'd0;
		opll_l	= 16'sd0;
		opll_r	= 16'sd0;
		opl2_l	= 16'sd0;
		opl2_r	= 16'sd0;
		scc_l	= 11'sd0;
		scc_r	= 11'sd0;
		opm_l	= 16'sd1024;
		opm_r	= -16'sd2048;
		master_volume	= 8'd128;
		check_output( "OPM only at 100%", 24'sd131072, -24'sd262144 );

		opm_volume		= 8'd32;
		check_output( "OPM volume 25%", 24'sd32768, -24'sd65536 );

		opm_volume		= 8'd0;
		check_output( "OPM muted", 24'sd0, 24'sd0 );

		ssg_l	= 13'd8191;
		ssg_r	= 13'd8191;
		opll_l	= 16'sd32767;
		opll_r	= -16'sd32768;
		opl2_l	= 16'sd32767;
		opl2_r	= -16'sd32768;
		scc_l	= 11'sd1023;
		scc_r	= -11'sd1024;
		opm_l	= 16'sd32767;
		opm_r	= -16'sd32768;
		opm_volume		= 8'd128;
		check_output( "full scale with OPM at master 100% (L/R saturated)", 24'sd8388607, -24'sd8388608 );

		master_volume	= 8'd96;
		check_output( "full scale with OPM at master 75%", 24'sd6291455, -24'sd6291456 );

		//	SSG DC cut (high-pass filter, time constant 2^16 x 12 clocks)
		opll_l	= 16'sd0;
		opll_r	= 16'sd0;
		opl2_l	= 16'sd0;
		opl2_r	= 16'sd0;
		scc_l	= 11'sd0;
		scc_r	= 11'sd0;
		opm_l	= 16'sd0;
		opm_r	= 16'sd0;
		ssg_l	= 13'd0;
		ssg_r	= 13'd0;
		master_volume	= 8'd128;
		check_output( "SSG DC cut: zero input", 24'sd0, 24'sd0 );
		release u_dut.ff_ssg_dc_l;
		release u_dut.ff_ssg_dc_r;
		ssg_l	= 13'd1000;
		ssg_r	= 13'd500;
		//	SSG x16 x volume 128 x master 128: 1 LSB = 2048 (DC is still almost 0)
		repeat( 30 ) @( posedge clk );
		#1;
		if( audio_l_out <= 24'sd2048000 && audio_l_out >= 24'sd2043904 && audio_r_out <= 24'sd1024000 && audio_r_out >= 24'sd1019904 ) begin
			$display( "OK   : SSG DC cut: step response L=%0d R=%0d", audio_l_out, audio_r_out );
		end
		else begin
			$display( "ERROR: SSG DC cut: step response L=%0d R=%0d", audio_l_out, audio_r_out );
			error_count = error_count + 1;
		end
		repeat( 6_300_000 ) @( posedge clk );
		#1;
		if( audio_l_out >= 0 && audio_l_out <= 24'sd2048 && audio_r_out >= 0 && audio_r_out <= 24'sd2048 ) begin
			$display( "OK   : SSG DC cut: settled L=%0d R=%0d", audio_l_out, audio_r_out );
		end
		else begin
			$display( "ERROR: SSG DC cut: not settled L=%0d R=%0d", audio_l_out, audio_r_out );
			error_count = error_count + 1;
		end
		ssg_l	= 13'd0;
		ssg_r	= 13'd0;
		repeat( 30 ) @( posedge clk );
		#1;
		if( audio_l_out <= -24'sd2043904 && audio_l_out >= -24'sd2048000 && audio_r_out <= -24'sd1019904 && audio_r_out >= -24'sd1024000 ) begin
			$display( "OK   : SSG DC cut: negative step L=%0d R=%0d", audio_l_out, audio_r_out );
		end
		else begin
			$display( "ERROR: SSG DC cut: negative step L=%0d R=%0d", audio_l_out, audio_r_out );
			error_count = error_count + 1;
		end		if( error_count == 0 ) begin
			$display( "OK   : all tests passed" );
		end
		else begin
			$display( "ERROR: %0d test(s) failed", error_count );
		end
		$finish;
	end
endmodule
