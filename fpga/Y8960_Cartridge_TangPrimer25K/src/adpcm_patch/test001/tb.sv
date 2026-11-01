module tb ();
	localparam	clk_base = 1_000_000_000_000.0 / 42_954_540;

	reg					clk;
	reg					reset_n;
	reg					bus_cs;
	reg					bus_address;
	reg					bus_write;
	reg					bus_valid;
	reg		[7:0]		bus_wdata;
	wire	[7:0]		bus_rdata;
	wire				bus_rdata_en;
	wire signed	[15:0]	adpcm_sound_out_l;
	wire signed	[15:0]	adpcm_sound_out_r;
	wire				adpcm_write;
	wire				adpcm_valid;
	wire	[23:0]		adpcm_address;
	wire	[7:0]		adpcm_wdata;
	integer				error_count;

	adpcm u_dut (
		.clk				( clk				),
		.reset_n			( reset_n			),
		.enable				( 1'b1				),
		.cen55				( 1'b0				),
		.bus_cs				( bus_cs			),
		.bus_address		( bus_address		),
		.bus_write			( bus_write			),
		.bus_valid			( bus_valid			),
		.bus_wdata			( bus_wdata			),
		.bus_rdata			( bus_rdata			),
		.bus_rdata_en		( bus_rdata_en		),
		.opl2_status		( 8'd0				),
		.adpcm_irq			(					),
		.adpcm_sound_out_l	( adpcm_sound_out_l	),
		.adpcm_sound_out_r	( adpcm_sound_out_r	),
		.adpcm_write		( adpcm_write		),
		.adpcm_valid		( adpcm_valid		),
		.adpcm_ready		( 1'b1				),
		.adpcm_address		( adpcm_address		),
		.adpcm_wdata		( adpcm_wdata		),
		.adpcm_rdata		( 8'd0				),
		.adpcm_rdata_en		( 1'b0				)
	);

	always #(clk_base/2) clk = ~clk;

	task write_reg( input [7:0] address, input [7:0] data );
		@( posedge clk );
		bus_cs		<= 1'b1;
		bus_valid	<= 1'b1;
		bus_write	<= 1'b1;
		bus_address	<= 1'b0;
		bus_wdata	<= address;
		@( posedge clk );
		bus_address	<= 1'b1;
		bus_wdata	<= data;
		@( posedge clk );
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		bus_write	<= 1'b0;
	endtask

	task check_output(
		input string name,
		input signed [15:0] pcm,
		input signed [15:0] expected_l,
		input signed [15:0] expected_r
	);
		force u_dut.w_pcm = pcm;
		repeat( 6 ) @( posedge clk );
		#1;
		if( adpcm_sound_out_l == expected_l && adpcm_sound_out_r == expected_r ) begin
			$display( "OK   : %s L=%0d R=%0d", name, adpcm_sound_out_l, adpcm_sound_out_r );
		end
		else begin
			$display( "ERROR: %s expected L=%0d R=%0d, actual L=%0d R=%0d",
				name, expected_l, expected_r, adpcm_sound_out_l, adpcm_sound_out_r );
			error_count = error_count + 1;
		end
	endtask

	initial begin
		clk			= 1'b0;
		reset_n		= 1'b0;
		bus_cs		= 1'b0;
		bus_address	= 1'b0;
		bus_write	= 1'b0;
		bus_valid	= 1'b0;
		bus_wdata	= 8'd0;
		error_count	= 0;

		repeat( 4 ) @( posedge clk );
		reset_n = 1'b1;
		repeat( 2 ) @( posedge clk );

		if( u_dut.reg_pan != 8'd128 ) begin
			$display( "ERROR: reset PAN is not 128 (%0d)", u_dut.reg_pan );
			error_count = error_count + 1;
		end
		else begin
			$display( "OK   : reset PAN == 128" );
		end

		//	center gain = 181/256
		check_output( "PAN=128 (default) positive", 16'sd10000, 16'sd7070, 16'sd7070 );
		check_output( "PAN=128 (default) negative", -16'sd10000, -16'sd7071, -16'sd7071 );

		write_reg( 8'hFF, 8'd1 );
		check_output( "PAN=1 left", 16'sd10000, 16'sd10000, 16'sd0 );

		write_reg( 8'hFF, 8'd255 );
		check_output( "PAN=255 right", 16'sd10000, 16'sd0, 16'sd10000 );

		write_reg( 8'hFF, 8'd0 );
		check_output( "PAN=0 behaves as 1", 16'sd10000, 16'sd10000, 16'sd0 );

		write_reg( 8'hFF, 8'd1 );
		check_output( "PAN=1 full scale negative", -16'sd32768, -16'sd32768, 16'sd0 );
		check_output( "PAN=1 full scale positive", 16'sd32767, 16'sd32767, 16'sd0 );

		write_reg( 8'hFF, 8'd128 );
		check_output( "PAN=128 restore", 16'sd10000, 16'sd7070, 16'sd7070 );

		if( error_count == 0 ) begin
			$display( "OK   : all tests passed" );
		end
		else begin
			$display( "ERROR: %0d test(s) failed", error_count );
		end
		$finish;
	end
endmodule