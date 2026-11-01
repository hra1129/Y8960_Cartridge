`timescale 1ps/1ps

module tb #(
	parameter integer SRC_HALF = 11640,
	parameter integer DST_HALF = 20694,
	parameter integer DST_PHASE = 5303
) ();
	reg					clk_src;
	reg					clk_dst;
	reg					reset_n;
	reg signed	[15:0]	opll_l;
	reg signed	[15:0]	opll_r;
	reg			[15:0]	wave;
	wire signed	[23:0]	mix_l;
	wire signed	[23:0]	mix_r;
	wire				mix_valid;
	wire				dst_reset_n;
	wire		[23:0]	dst_l;
	wire		[23:0]	dst_r;
	wire				sample_request;
	wire				i2s_din;
	wire				i2s_lrclk;
	wire				i2s_bclk;

	reg			[47:0]	expected_source;
	reg			[23:0]	model_l;
	reg			[23:0]	model_r;
	reg			[23:0]	frame_l;
	reg			[23:0]	frame_r;
	integer				source_count;
	integer				delivered_count;
	integer				frame_sequence;
	integer				src_cycles;
	integer				last_valid_cycle;
	integer				positive_samples;
	integer				negative_samples;
	reg					test_passed;

	mixier u_mixer (
		.clk			( clk_src	),
		.reset_n		( reset_n	),
		.ssg_l			( 13'd0		),
		.ssg_r			( 13'd0		),
		.opll_l			( opll_l	),
		.opll_r			( opll_r	),
		.opl2_l			( 16'sd0	),
		.opl2_r			( 16'sd0	),
		.scc_l			( 11'sd0	),
		.scc_r			( 11'sd0	),
		.opm_l			( 16'sd0	),
		.opm_r			( 16'sd0	),
		.ssg_volume		( 8'd0		),
		.opll_volume	( 8'd128	),
		.opl2_volume	( 8'd0		),
		.scc_volume		( 8'd0		),
		.opm_volume		( 8'd0		),
		.master_volume	( 8'd127	),
		.audio_l_out	( mix_l		),
		.audio_r_out	( mix_r		),
		.audio_valid	( mix_valid	)
	);

	audio_cdc u_cdc (
		.clk_src		( clk_src			),
		.clk_dst		( clk_dst			),
		.reset_n		( reset_n			),
		.src_valid		( mix_valid			),
		.src_l			( mix_l				),
		.src_r			( mix_r				),
		.dst_request	( sample_request	),
		.dst_reset_n	( dst_reset_n		),
		.dst_l			( dst_l				),
		.dst_r			( dst_r				)
	);

	i2s_audio u_i2s (
		.clk				( clk_dst			),
		.reset_n			( dst_reset_n		),
		.sound_l_in			( dst_l				),
		.sound_r_in			( dst_r				),
		.sample_request		( sample_request	),
		.i2s_audio_din		( i2s_din			),
		.i2s_audio_lrclk	( i2s_lrclk			),
		.i2s_audio_bclk		( i2s_bclk			)
	);

	initial begin
		clk_src = 1'b0;
		forever #SRC_HALF clk_src = ~clk_src;
	end

	initial begin
		clk_dst = 1'b0;
		#DST_PHASE;
		forever #DST_HALF clk_dst = ~clk_dst;
	end

	//	Change both mixer inputs only between complete mixing passes.
	always @( negedge clk_src ) begin
		if( !reset_n ) begin
			wave	<= 16'hACE1;
			opll_l	<= 16'sd1000;
			opll_r	<= -16'sd1000;
		end
		else if( mix_valid ) begin
			wave <= { wave[14:0], wave[15] ^ wave[13] ^ wave[12] ^ wave[10] };
			if( wave[15] ) begin
				opll_l <= -$signed( { 1'b0, wave[14:0] } );
				opll_r <=  $signed( { 1'b0, wave[14:0] } );
			end
			else begin
				opll_l <=  $signed( { 1'b0, wave[14:0] } );
				opll_r <= -$signed( { 1'b0, wave[14:0] } );
			end
		end
	end

	always @( posedge clk_src ) begin
		if( !reset_n ) begin
			expected_source		= 48'd0;
			source_count		= 0;
			src_cycles			= 0;
			last_valid_cycle	= 0;
			positive_samples	= 0;
			negative_samples	= 0;
		end
		else begin
			src_cycles = src_cycles + 1;
			if( mix_valid ) begin
				if( u_mixer.ff_state !== 4'd0 ) begin
					$fatal( 1, "mixer valid was not after the right-channel update" );
				end
				if( last_valid_cycle != 0 && (src_cycles - last_valid_cycle) != 12 ) begin
					$fatal( 1, "mixer valid period was not 12 source clocks" );
				end
				if( mix_r !== (~mix_l + 24'd1) ) begin
					$fatal( 1, "mixer valid exposed mismatched channels L=%06h R=%06h", mix_l, mix_r );
				end
				last_valid_cycle = src_cycles;
			end
			if( (u_cdc.ff_request_sync != u_cdc.ff_request_served) && mix_valid ) begin
				expected_source = { mix_l, mix_r };
				source_count = source_count + 1;
				if( mix_l > 0 ) positive_samples = positive_samples + 1;
				if( mix_l < 0 ) negative_samples = negative_samples + 1;
			end
		end
	end

	always @( posedge clk_dst ) begin
		if( !dst_reset_n ) begin
			model_l			= 24'd0;
			model_r			= 24'd0;
			frame_l			= 24'd0;
			frame_r			= 24'd0;
			delivered_count	= 0;
			frame_sequence	= 0;
		end
		else begin
			if( u_i2s.w_frame_start ) begin
				frame_l = model_l;
				frame_r = model_r;
				frame_sequence = delivered_count;
			end
			if( (u_cdc.ff_request != u_cdc.ff_request_complete) && (&u_cdc.w_arrived) ) begin
				model_l = expected_source[47:24];
				model_r = expected_source[23:0];
				delivered_count = delivered_count + 1;
				#1;
				if( dst_l !== model_l || dst_r !== model_r ) begin
					$fatal( 1, "CDC sample differs from the accepted mixer sample" );
				end
			end
		end
	end

	task check_channel( input bit channel, input [23:0] expected );
		integer bit_index;
		reg [23:0] actual;
		begin
			actual = 24'd0;
			for( bit_index = 0; bit_index < 32; bit_index = bit_index + 1 ) begin
				@( posedge i2s_bclk );
				#1;
				if( i2s_lrclk !== channel ) begin
					$fatal( 1, "unexpected LRCLK at bit %0d", bit_index );
				end
				if( bit_index == 0 || bit_index >= 25 ) begin
					if( i2s_din !== 1'b0 ) begin
						$fatal( 1, "nonzero I2S lead or padding bit %0d", bit_index );
					end
				end
				else begin
					actual = { actual[22:0], i2s_din };
				end
			end
			if( actual !== expected ) begin
				$fatal( 1, "I2S channel %0d: expected %06h, got %06h", channel, expected, actual );
			end
		end
	endtask

	task check_frames( input integer count );
		integer frame;
		integer previous_sequence;
		integer sample_sequence;
		reg [23:0] expected_l;
		reg [23:0] expected_r;
		begin
			previous_sequence = 0;
			for( frame = 0; frame < count; frame = frame + 1 ) begin
				@( negedge i2s_lrclk );
				#1;
				expected_l = frame_l;
				expected_r = frame_r;
				sample_sequence = frame_sequence;
				if( sample_sequence == 0 ||
					(previous_sequence != 0 && sample_sequence != previous_sequence + 1) ) begin
					$fatal( 1, "missing or repeated transfer at frame %0d: %0d after %0d",
						frame, sample_sequence, previous_sequence );
				end
				previous_sequence = sample_sequence;
				check_channel( 1'b0, expected_l );
				check_channel( 1'b1, expected_r );
			end
		end
	endtask

	task check_delayed_transfer;
		integer frame;
		integer saved_sequence;
		integer saved_source_count;
		integer timeout;
		reg [23:0] saved_l;
		reg [23:0] saved_r;
		reg held_zero;
		reg held_one;
		begin
			@( negedge clk_dst );
			if( u_cdc.ff_request !== u_cdc.ff_request_complete ) begin
				$fatal( 1, "unexpected pending transfer before delay test" );
			end
			saved_sequence = delivered_count;
			saved_source_count = source_count;
			saved_l = model_l;
			saved_r = model_r;
			held_zero = u_cdc.ff_zero_sync[5];
			held_one = u_cdc.ff_one_sync[5];
			if( held_zero ) force u_cdc.ff_zero_sync[5] = 1'b1;
			else            force u_cdc.ff_zero_sync[5] = 1'b0;
			if( held_one )  force u_cdc.ff_one_sync[5] = 1'b1;
			else            force u_cdc.ff_one_sync[5] = 1'b0;

			for( frame = 0; frame < 3; frame = frame + 1 ) begin
				@( negedge i2s_lrclk );
				#1;
				if( frame_sequence != saved_sequence ||
					frame_l !== saved_l || frame_r !== saved_r ) begin
					$fatal( 1, "delayed transfer changed the held I2S frame" );
				end
				check_channel( 1'b0, saved_l );
				check_channel( 1'b1, saved_r );
			end
			if( u_cdc.ff_request === u_cdc.ff_request_complete ||
				source_count != saved_source_count + 1 ) begin
				$fatal( 1, "delayed transfer did not remain pending" );
			end

			@( negedge clk_dst );
			release u_cdc.ff_zero_sync[5];
			release u_cdc.ff_one_sync[5];
			timeout = 0;
			while( u_cdc.ff_request !== u_cdc.ff_request_complete && timeout < 20 ) begin
				@( posedge clk_dst );
				#2;
				timeout = timeout + 1;
			end
			if( u_cdc.ff_request !== u_cdc.ff_request_complete ||
				delivered_count != saved_sequence + 1 ) begin
				$fatal( 1, "delayed transfer did not complete after the bit arrived" );
			end
		end
	endtask

	initial begin
		reset_n = 1'b0;
		test_passed = 1'b0;
		repeat( 5 ) @( posedge clk_src );
		repeat( 4 ) @( posedge clk_dst );
		@( negedge clk_src );
		reset_n = 1'b1;
		wait( dst_reset_n === 1'b1 );
		check_frames( 100 );
		if( positive_samples == 0 || negative_samples == 0 ) begin
			$fatal( 1, "the first test did not cover both sample signs" );
		end
		check_delayed_transfer();
		check_frames( 25 );

		//	Reset in the middle of a serialized frame.
		@( negedge i2s_lrclk );
		repeat( 8 ) @( posedge i2s_bclk );
		@( negedge clk_src );
		reset_n = 1'b0;
		repeat( 5 ) @( posedge clk_src );
		repeat( 4 ) @( posedge clk_dst );
		#1;
		if( dst_l !== 24'd0 || dst_r !== 24'd0 || i2s_din !== 1'b0 ) begin
			$fatal( 1, "audio path did not reset to silence" );
		end
		@( negedge clk_src );
		reset_n = 1'b1;
		wait( dst_reset_n === 1'b1 );
		check_frames( 100 );
		if( source_count < 100 || delivered_count < 100 ||
			positive_samples == 0 || negative_samples == 0 ) begin
			$fatal( 1, "insufficient post-reset transfer coverage" );
		end
		test_passed = 1'b1;
		$display( "OK: 225 mixer-to-I2S frames, delayed transfer and mid-frame reset" );
		$finish;
	end

	initial begin
		#(64'd5000000000);
		$fatal( 1, "end-to-end audio test timed out" );
	end
endmodule
