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
//		Pulse wave modulation
// -----------------------------------------------------------------------------

module tb ();
	localparam	longint	clk_base	= 64'd1_000_000_000_000 / 64'd24_576_000;	//	ps (24.576MHz)
	int					test_no;
	int					i;
	reg					clk;				//	24.576MHz
	reg					reset_n;
	reg		[23:0]		sound_l_in;
	reg		[23:0]		sound_r_in;
	wire				i2s_audio_sclk;
	wire				i2s_audio_din;
	wire				i2s_audio_lrclk;
	wire				i2s_audio_bclk;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	i2s_audio u_i2s_audio (
		.clk				( clk				),
		.reset_n			( reset_n			),
		.sound_l_in			( sound_l_in		),
		.sound_r_in			( sound_r_in		),
		.i2s_audio_sclk		( i2s_audio_sclk	),
		.i2s_audio_din		( i2s_audio_din		),
		.i2s_audio_lrclk	( i2s_audio_lrclk	),
		.i2s_audio_bclk		( i2s_audio_bclk	)
	);
	
	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		test_no			= -1;
		reset_n			= 0;
		clk				= 1;
		sound_l_in		= 0;
		sound_r_in		= 0;

		@( negedge clk );
		@( negedge clk );
		@( posedge clk );

		reset_n		= 1;
		@( posedge clk );

		sound_l_in	<= 24'h800000;
		sound_r_in	<= 24'h7FFFFF;
		repeat( 1000 ) @( posedge clk );

		sound_l_in	<= 24'hFF0000;
		sound_r_in	<= 24'h00FF00;
		repeat( 1000 ) @( posedge clk );

		sound_l_in	<= 24'h555555;
		sound_r_in	<= 24'hAAAAAA;
		repeat( 1000 ) @( posedge clk );

		sound_l_in	<= 24'hEEEEEE;
		sound_r_in	<= 24'h111111;
		repeat( 1000 ) @( posedge clk );

		sound_l_in	<= 24'hCC3333;
		sound_r_in	<= 24'h33CC33;
		repeat( 1000 ) @( posedge clk );

		repeat( 10000 ) @( posedge clk );
		$finish;
	end
endmodule
