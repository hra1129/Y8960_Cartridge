module tb ();
	localparam	clk_base = 1_000_000_000_000.0 / 42_954_540;

	reg					clk;
	reg					reset_n;
	reg					cen55;
	reg signed	[15:0]	pcm_in;
	wire signed	[15:0]	pcm_out;
	integer				clk_count;
	integer				error_count;
	integer				check_count;
	integer				coef [0:24];
	integer				hist [0:24];
	integer				i;
	integer				n;
	reg			[15:0]	lfsr;

	adpcm_lpf u_dut (
		.clk		( clk		),
		.reset_n	( reset_n	),
		.cen55		( cen55		),
		.pcm_in		( pcm_in	),
		.pcm_out	( pcm_out	)
	);

	always #(clk_base/2) clk = ~clk;

	//	cen55 = 1 clk pulse every 864 clk (42.95MHz / 864 = 49.7kHz)
	always @( posedge clk ) begin
		if( !reset_n ) begin
			clk_count	<= 0;
			cen55		<= 1'b0;
		end
		else begin
			clk_count	<= (clk_count == 863) ? 0 : clk_count + 1;
			cen55		<= (clk_count == 863);
		end
	end

	function integer expected;
		input integer dummy;
		integer k;
		integer acc;
		begin
			acc = 0;
			for( k = 0; k < 25; k = k + 1 ) begin
				acc = acc + coef[k] * hist[k];
			end
			acc = (acc + 16384) >>> 15;
			if( acc > 32767 ) acc = 32767;
			if( acc < -32768 ) acc = -32768;
			expected = acc;
		end
	endfunction

	//	gives one sample, and checks the output just before the next cen55
	task put_sample( input string name, input integer value );
		integer exp_value;
		begin
			@( posedge clk );
			while( clk_count != 863 ) @( posedge clk );
			pcm_in <= value;
			for( i = 24; i > 0; i = i - 1 ) begin
				hist[i] = hist[i - 1];
			end
			hist[0] = value;
			exp_value = expected( 0 );
			@( posedge clk );
			while( clk_count != 862 ) @( posedge clk );
			#1;
			check_count = check_count + 1;
			if( pcm_out !== exp_value ) begin
				if( error_count < 20 ) begin
					$display( "ERROR: %s expected %0d, actual %0d", name, exp_value, pcm_out );
				end
				error_count = error_count + 1;
			end
		end
	endtask

	initial begin
		coef[ 0] =    28;	coef[ 1] =    78;	coef[ 2] =    96;	coef[ 3] =    -7;
		coef[ 4] =  -283;	coef[ 5] =  -645;	coef[ 6] =  -825;	coef[ 7] =  -458;
		coef[ 8] =   716;	coef[ 9] =  2632;	coef[10] =  4830;	coef[11] =  6591;
		coef[12] =  7262;
		for( i = 13; i < 25; i = i + 1 ) begin
			coef[i] = coef[24 - i];
		end
		for( i = 0; i < 25; i = i + 1 ) begin
			hist[i] = 0;
		end

		clk			= 1'b0;
		reset_n		= 1'b0;
		pcm_in		= 16'sd0;
		error_count	= 0;
		check_count	= 0;
		lfsr		= 16'hACE1;

		repeat( 4 ) @( posedge clk );
		reset_n = 1'b1;

		//	impulse response
		put_sample( "impulse", 32767 );
		for( n = 0; n < 30; n = n + 1 ) put_sample( "impulse", 0 );

		//	DC gain is exactly 1
		for( n = 0; n < 30; n = n + 1 ) put_sample( "step +", 12345 );
		if( pcm_out !== 16'sd12345 ) begin
			$display( "ERROR: DC gain, output %0d for input 12345", pcm_out );
			error_count = error_count + 1;
		end
		for( n = 0; n < 30; n = n + 1 ) put_sample( "step -", -32768 );
		if( pcm_out !== -16'sd32768 ) begin
			$display( "ERROR: DC gain, output %0d for input -32768", pcm_out );
			error_count = error_count + 1;
		end

		//	full scale square wave (overshoot is saturated)
		for( n = 0; n < 200; n = n + 1 ) put_sample( "square", ((n % 40) < 20) ? 32767 : -32768 );

		//	random
		for( n = 0; n < 500; n = n + 1 ) begin
			lfsr = { lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10] };
			put_sample( "random", $signed( lfsr ) );
		end

		if( error_count == 0 ) begin
			$display( "OK   : all tests passed (%0d samples)", check_count );
		end
		else begin
			$display( "ERROR: %0d / %0d sample(s) failed", error_count, check_count );
		end
		$finish;
	end
endmodule
