// -----------------------------------------------------------------------------
//	Test of i2s_audio.v
//	Copyright (C)2025 Takayuki Hara (HRA!)
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
//		I2S framing and stereo sample coherence
// -----------------------------------------------------------------------------

`timescale 1ps/1ps

module tb ();
	reg				clk;
	reg				reset_n;
	reg		[23:0]	sound_l;
	reg		[23:0]	sound_r;
	wire			sample_request;
	wire			i2s_audio_din;
	wire			i2s_audio_lrclk;
	wire			i2s_audio_bclk;
	integer			request_count;
	reg				test_passed;

	i2s_audio u_i2s_audio (
		.clk				( clk				),
		.reset_n			( reset_n			),
		.sound_l_in			( sound_l			),
		.sound_r_in			( sound_r			),
		.sample_request		( sample_request	),
		.i2s_audio_din		( i2s_audio_din		),
		.i2s_audio_lrclk	( i2s_audio_lrclk	),
		.i2s_audio_bclk		( i2s_audio_bclk	)
	);

	always #20694 clk = ~clk;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			request_count = 0;
		end
		else if( sample_request ) begin
			if( u_i2s_audio.ff_bclk_count !== 2'd1 ||
				u_i2s_audio.ff_bit_count !== 6'd31 ) begin
				$fatal( 1, "sample request was not at the right-channel boundary" );
			end
			request_count = request_count + 1;
		end
	end

	task check_channel( input bit channel, input [23:0] expected );
		integer bit_index;
		reg [23:0] actual;
		begin
			actual = 24'd0;
			for( bit_index = 0; bit_index < 32; bit_index = bit_index + 1 ) begin
				@( posedge i2s_audio_bclk );
				#1;
				if( i2s_audio_lrclk !== channel ) begin
					$fatal( 1, "LRCLK changed inside channel %0d at bit %0d", channel, bit_index );
				end
				if( bit_index == 0 || bit_index >= 25 ) begin
					if( i2s_audio_din !== 1'b0 ) begin
						$fatal( 1, "nonzero I2S lead or padding bit %0d", bit_index );
					end
				end
				else begin
					actual = { actual[22:0], i2s_audio_din };
				end
			end
			if( actual !== expected ) begin
				$fatal( 1, "channel %0d: expected %06h, got %06h", channel, expected, actual );
			end
		end
	endtask

	initial begin
		clk = 1'b0;
		reset_n = 1'b0;
		sound_l = 24'h812345;
		sound_r = 24'hFEDCBA;
		request_count = 0;
		test_passed = 1'b0;
		repeat( 4 ) @( posedge clk );
		@( negedge clk );
		reset_n = 1'b1;

		@( negedge i2s_audio_lrclk );
		fork
			begin
				check_channel( 1'b0, 24'h812345 );
				check_channel( 1'b1, 24'hFEDCBA );
				check_channel( 1'b0, 24'h7FFFFF );
				check_channel( 1'b1, 24'h800000 );
				check_channel( 1'b0, 24'h123456 );
				check_channel( 1'b1, 24'hABCDEF );
			end
			begin
				repeat( 10 ) @( posedge i2s_audio_bclk );
				@( negedge clk );
				sound_l = 24'h7FFFFF;
				sound_r = 24'h800000;
				@( negedge i2s_audio_lrclk );
				repeat( 18 ) @( posedge i2s_audio_bclk );
				@( negedge clk );
				sound_l = 24'h123456;
				sound_r = 24'hABCDEF;
			end
		join
		if( request_count != 4 ) begin
			$fatal( 1, "expected 4 sample requests, got %0d", request_count );
		end

		@( negedge clk );
		reset_n = 1'b0;
		sound_l = 24'hFFFFFF;
		sound_r = 24'h000001;
		repeat( 4 ) @( posedge clk );
		#1;
		if( i2s_audio_din !== 1'b0 || i2s_audio_lrclk !== 1'b0 ) begin
			$fatal( 1, "I2S outputs did not reset" );
		end
		@( negedge clk );
		reset_n = 1'b1;
		@( negedge i2s_audio_lrclk );
		check_channel( 1'b0, 24'hFFFFFF );
		check_channel( 1'b1, 24'h000001 );
		test_passed = 1'b1;
		$display( "OK: I2S framing, stereo snapshots, requests and reset" );
		$finish;
	end

	initial begin
		#1000000000;
		$fatal( 1, "I2S test timed out" );
	end
endmodule
