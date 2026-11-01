`timescale 1ps/1ps

module tb #(
	parameter integer SRC_HALF = 11640,
	parameter integer DST_HALF = 20694,
	parameter integer DST_PHASE = 5303
) ();
	reg				clk_src;
	reg				clk_dst;
	reg				reset_n;
	reg				src_valid;
	reg		[23:0]	src_l;
	reg		[23:0]	src_r;
	reg				dst_request;
	wire			dst_reset_n;
	wire	[23:0]	dst_l;
	wire	[23:0]	dst_r;
	reg				held_zero;
	reg				held_one;
	reg				held_request;
	reg		[31:0]	random_state;
	reg		[23:0]	expected_l;
	reg		[23:0]	expected_r;
	reg				test_passed;
	integer			i;

	audio_cdc u_dut (
		.clk_src		( clk_src		),
		.clk_dst		( clk_dst		),
		.reset_n		( reset_n		),
		.src_valid		( src_valid		),
		.src_l			( src_l			),
		.src_r			( src_r			),
		.dst_request	( dst_request	),
		.dst_reset_n	( dst_reset_n	),
		.dst_l			( dst_l			),
		.dst_r			( dst_r			)
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

	function [31:0] next_random( input [31:0] value );
		begin
			next_random = { value[30:0], value[31] ^ value[21] ^ value[1] ^ value[0] };
		end
	endfunction

	task request_sample;
		begin
			@( negedge clk_dst );
			dst_request = 1'b1;
			@( negedge clk_dst );
			dst_request = 1'b0;
		end
	endtask

	task wait_source_request;
		integer timeout;
		begin
			timeout = 0;
			while( u_dut.ff_request_sync === u_dut.ff_request_served && timeout < 200 ) begin
				@( posedge clk_src );
				#1;
				timeout = timeout + 1;
			end
			if( u_dut.ff_request_sync === u_dut.ff_request_served ) begin
				$fatal( 1, "source request timed out" );
			end
		end
	endtask

	task provide_sample( input [23:0] sample_l, input [23:0] sample_r );
		begin
			@( negedge clk_src );
			src_l = sample_l;
			src_r = sample_r;
			src_valid = 1'b1;
			@( negedge clk_src );
			src_valid = 1'b0;
			src_l = ~sample_l;
			src_r = ~sample_r;
		end
	endtask

	task wait_result( input [23:0] sample_l, input [23:0] sample_r );
		integer timeout;
		begin
			timeout = 0;
			while( u_dut.ff_request !== u_dut.ff_request_complete && timeout < 200 ) begin
				@( posedge clk_dst );
				#1;
				timeout = timeout + 1;
			end
			if( u_dut.ff_request !== u_dut.ff_request_complete ) begin
				$fatal( 1, "destination transfer timed out" );
			end
			if( dst_l !== sample_l || dst_r !== sample_r ) begin
				$fatal( 1, "expected L=%06h R=%06h, got L=%06h R=%06h",
					sample_l, sample_r, dst_l, dst_r );
			end
		end
	endtask

	task transfer( input [23:0] sample_l, input [23:0] sample_r );
		begin
			request_sample();
			wait_source_request();
			provide_sample( sample_l, sample_r );
			wait_result( sample_l, sample_r );
		end
	endtask

	initial begin
		reset_n = 1'b0;
		src_valid = 1'b0;
		src_l = 24'd0;
		src_r = 24'd0;
		dst_request = 1'b0;
		random_state = 32'h31579BDF;
		test_passed = 1'b0;
		repeat( 5 ) @( posedge clk_src );
		repeat( 4 ) @( posedge clk_dst );
		@( negedge clk_src );
		reset_n = 1'b1;
		wait( dst_reset_n === 1'b1 );
		repeat( 2 ) @( posedge clk_dst );

		request_sample();
		wait_source_request();
		src_l = 24'h012345;
		src_r = 24'hFEDCBA;
		repeat( 20 ) @( posedge clk_dst );
		if( dst_l !== 24'd0 || dst_r !== 24'd0 ||
			u_dut.ff_request === u_dut.ff_request_complete ) begin
			$fatal( 1, "transfer completed without a valid stereo sample" );
		end
		provide_sample( 24'hA55AC3, 24'h3CC33C );
		wait_result( 24'hA55AC3, 24'h3CC33C );

		//	Delay one bit independently of all other bits across the CDC.
		@( negedge clk_dst );
		held_zero = u_dut.ff_zero_sync[5];
		held_one = u_dut.ff_one_sync[5];
		if( held_zero ) force u_dut.ff_zero_sync[5] = 1'b1;
		else            force u_dut.ff_zero_sync[5] = 1'b0;
		if( held_one )  force u_dut.ff_one_sync[5] = 1'b1;
		else            force u_dut.ff_one_sync[5] = 1'b0;
		request_sample();
		wait_source_request();
		provide_sample( 24'h800001, 24'h7FFFFE );
		repeat( 280 ) @( posedge clk_dst );
		if( dst_l !== 24'hA55AC3 || dst_r !== 24'h3CC33C ||
			u_dut.ff_request === u_dut.ff_request_complete ) begin
			$fatal( 1, "a partial sample was accepted while one bit was delayed" );
		end
		held_request = u_dut.ff_request;
		request_sample();
		if( u_dut.ff_request !== held_request ) begin
			$fatal( 1, "a request was accepted while a transfer was pending" );
		end
		@( negedge clk_dst );
		release u_dut.ff_zero_sync[5];
		release u_dut.ff_one_sync[5];
		wait_result( 24'h800001, 24'h7FFFFE );
		transfer( 24'hFFFFFF, 24'h000000 );
		transfer( 24'h000000, 24'hFFFFFF );
		transfer( 24'h555555, 24'hAAAAAA );
		transfer( 24'hAAAAAA, 24'h555555 );

		request_sample();
		wait_source_request();
		@( negedge clk_dst );
		reset_n = 1'b0;
		#1;
		if( dst_reset_n !== 1'b0 ) begin
			$fatal( 1, "destination reset did not assert asynchronously" );
		end
		repeat( 5 ) @( posedge clk_dst );
		repeat( 2 ) @( posedge clk_src );
		#1;
		if( dst_l !== 24'd0 || dst_r !== 24'd0 ) begin
			$fatal( 1, "destination samples did not reset" );
		end
		@( negedge clk_dst );
		reset_n = 1'b1;
		@( posedge clk_dst );
		#1;
		if( dst_reset_n !== 1'b0 ) begin
			$fatal( 1, "destination reset released before synchronization" );
		end
		@( posedge clk_dst );
		#1;
		if( dst_reset_n !== 1'b1 ) begin
			$fatal( 1, "destination reset did not release after two clocks" );
		end
		repeat( 2 ) @( posedge clk_dst );
		transfer( 24'h123456, 24'hABCDEF );

		for( i = 0; i < 128; i = i + 1 ) begin
			random_state = next_random( random_state );
			expected_l = random_state[23:0];
			random_state = next_random( random_state );
			expected_r = random_state[23:0];
			transfer( expected_l, expected_r );
		end
		test_passed = 1'b1;
		$display( "OK: CDC wait, skew, backpressure, reset and sample patterns" );
		$finish;
	end

	initial begin
		#1000000000;
		$fatal( 1, "CDC test timed out" );
	end
endmodule
