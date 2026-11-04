// --------------------------------------------------------------------
//	OPL2 per-channel PAN register test (F6h-FEh)
//	Keys on one channel at a time with a sine tone. The PAN of that
//	channel is 0 (left) and the PAN of all the other channels is 255
//	(right), so the tone must appear only on Lch of jtopl2.
// --------------------------------------------------------------------
`timescale 1ps/1ps
module tb ();
	localparam	clk_base	= 1_000_000_000_000.0 / 42_954_540;

	reg					clk;
	reg					reset_n;
	reg					enable;
	reg		[3:0]		ff_divider;
	reg					bus_cs;
	reg					bus_address;
	reg					bus_write;
	reg					bus_valid;
	reg		[7:0]		bus_wdata;
	wire				bus_ready;
	wire	[7:0]		bus_rdata;
	wire				bus_rdata_en;
	wire	[15:0]		opl2_sound_out_l;
	wire	[15:0]		opl2_sound_out_r;
	wire				intr_n;
	wire				adpcm_write;
	wire				adpcm_valid;
	wire	[17:0]		adpcm_address;
	wire	[7:0]		adpcm_wdata;
	reg					test_passed;
	reg					measure;
	integer				max_l;
	integer				max_r;

	opl2 u_dut (
		.clk				( clk				),
		.reset_n			( reset_n			),
		.enable				( enable			),
		.bus_cs				( bus_cs			),
		.bus_address		( bus_address		),
		.bus_write			( bus_write			),
		.bus_valid			( bus_valid			),
		.bus_ready			( bus_ready			),
		.bus_wdata			( bus_wdata			),
		.bus_rdata			( bus_rdata			),
		.bus_rdata_en		( bus_rdata_en		),
		.opl2_sound_out_l	( opl2_sound_out_l	),
		.opl2_sound_out_r	( opl2_sound_out_r	),
		.intr_n				( intr_n			),
		.adpcm_write		( adpcm_write		),
		.adpcm_valid		( adpcm_valid		),
		.adpcm_ready		( 1'b0				),
		.adpcm_address		( adpcm_address		),
		.adpcm_wdata		( adpcm_wdata		),
		.adpcm_rdata		( 8'h00				),
		.adpcm_rdata_en		( 1'b0				)
	);

	always #(clk_base/2) clk = ~clk;

	//	Same enable as y8960_cartridge_tangprimer25k.v (one clock in 12)
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_divider	<= 4'd0;
			enable		<= 1'b0;
		end
		else if( ff_divider == 4'd11 ) begin
			ff_divider	<= 4'd0;
			enable		<= 1'b1;
		end
		else begin
			ff_divider	<= ff_divider + 4'd1;
			enable		<= 1'b0;
		end
	end

	always @( posedge clk ) begin
		if( measure && !$isunknown( u_dut.w_opl2_sound_out_l ) && !$isunknown( u_dut.w_opl2_sound_out_r ) ) begin
			if(  $signed( u_dut.w_opl2_sound_out_l ) > max_l ) max_l =  $signed( u_dut.w_opl2_sound_out_l );
			if( -$signed( u_dut.w_opl2_sound_out_l ) > max_l ) max_l = -$signed( u_dut.w_opl2_sound_out_l );
			if(  $signed( u_dut.w_opl2_sound_out_r ) > max_r ) max_r =  $signed( u_dut.w_opl2_sound_out_r );
			if( -$signed( u_dut.w_opl2_sound_out_r ) > max_r ) max_r = -$signed( u_dut.w_opl2_sound_out_r );
		end
	end

	// ---------------------------------------------------------
	//	Bus tasks
	// ---------------------------------------------------------
	task bus_write_cycle( input a, input [7:0] d );
		@( posedge clk );
		bus_cs		<= 1'b1;
		bus_valid	<= 1'b1;
		bus_write	<= 1'b1;
		bus_address	<= a;
		bus_wdata	<= d;
		@( posedge clk );
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		bus_write	<= 1'b0;
		repeat( 40 ) @( posedge clk );
	endtask

	task write_reg( input [7:0] address, input [7:0] data );
		bus_write_cycle( 1'b0, address );
		bus_write_cycle( 1'b1, data );
		//	jtopl applies a register when its slot comes around (864 clocks per sample)
		repeat( 1000 ) @( posedge clk );
	endtask

	// ---------------------------------------------------------
	//	Test sequence
	// ---------------------------------------------------------
	reg		[7:0]	slot_offset [0:8];
	integer			ch, k, errors;

	initial begin
		clk				= 1'b0;
		reset_n			= 1'b0;
		bus_cs			= 1'b0;
		bus_address		= 1'b0;
		bus_write		= 1'b0;
		bus_valid		= 1'b0;
		bus_wdata		= 8'd0;
		test_passed		= 1'b0;
		measure			= 1'b0;
		errors			= 0;
		slot_offset[0] = 8'h00; slot_offset[1] = 8'h01; slot_offset[2] = 8'h02;
		slot_offset[3] = 8'h08; slot_offset[4] = 8'h09; slot_offset[5] = 8'h0A;
		slot_offset[6] = 8'h10; slot_offset[7] = 8'h11; slot_offset[8] = 8'h12;

		repeat( 20 ) @( posedge clk );
		reset_n = 1'b1;
		repeat( 20 ) @( posedge clk );

		//	All channels: silent sine voice, PAN = 255 (right)
		for( k = 0; k < 9; k = k + 1 ) begin
			write_reg( 8'h20 + slot_offset[k], 8'h21 );
			write_reg( 8'h23 + slot_offset[k], 8'h21 );
			write_reg( 8'h40 + slot_offset[k], 8'h3F );
			write_reg( 8'h43 + slot_offset[k], 8'h3F );
			write_reg( 8'h60 + slot_offset[k], 8'hF0 );
			write_reg( 8'h63 + slot_offset[k], 8'hF0 );
			write_reg( 8'h80 + slot_offset[k], 8'h0F );
			write_reg( 8'h83 + slot_offset[k], 8'h0F );
			write_reg( 8'hC0 + k, 8'h00 );
			write_reg( 8'hA0 + k, 8'h00 );
			//	Key on once so that the operator pipeline of this channel is not X in simulation
			write_reg( 8'hB0 + k, 8'h32 );
			write_reg( 8'hB0 + k, 8'h12 );
			write_reg( 8'hF6 + k, 8'd255 );
		end

		for( ch = 0; ch < 9; ch = ch + 1 ) begin
			//	Only this channel sounds, panned to the left.
			write_reg( 8'hF6 + ch, 8'd0 );
			write_reg( 8'h43 + slot_offset[ch], 8'h00 );
			write_reg( 8'hB0 + ch, 8'h32 );
			#1ms;
			max_l	= 0;
			max_r	= 0;
			measure	= 1'b1;
			#2ms;
			measure	= 1'b0;
			$display( "  ch%0d (PAN reg %02Xh): max L=%0d R=%0d", ch + 1, 8'hF6 + ch, max_l, max_r );
			if( max_l < 256 || max_r * 16 > max_l ) begin
				$display( "[ERROR] ch%0d is not panned by %02Xh", ch + 1, 8'hF6 + ch );
				errors = errors + 1;
			end
			write_reg( 8'hB0 + ch, 8'h12 );
			write_reg( 8'h43 + slot_offset[ch], 8'h3F );
			write_reg( 8'hF6 + ch, 8'd255 );
		end

		if( errors != 0 ) $fatal( 1, "[RESULT] OPL2 PAN test: FAIL (%0d errors)", errors );
		$display( "[RESULT] OPL2 PAN test: PASS" );
		test_passed = 1'b1;
		$stop;
	end
endmodule