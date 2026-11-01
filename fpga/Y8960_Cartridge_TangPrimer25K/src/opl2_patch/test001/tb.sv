// -----------------------------------------------------------------------------
//	Test of opl2.v
//	Copyright (C)2026 Takayuki Hara (HRA!)
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
	localparam		clk_base		= 1_000_000_000/28.63636;	//	ps
	int				test_no;
	int				i, j;

	// --------------------------------------------------------------------
	//	Signal declarations
	// --------------------------------------------------------------------
	reg				clk;
	reg				reset_n;
	reg				enable;
	reg				bus_cs;
	reg				bus_address;
	reg				bus_write;
	reg				bus_valid;
	wire			bus_ready;
	reg		[7:0]	bus_wdata;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;
	wire	[15:0]	opl2_sound_out_l;
	wire	[15:0]	opl2_sound_out_r;
	wire			intr_n;
	wire			adpcm_write;
	wire			adpcm_valid;
	wire			adpcm_ready;
	wire	[17:0]	adpcm_address;
	wire	[7:0]	adpcm_wdata;
	reg		[7:0]	adpcm_rdata;
	reg				adpcm_rdata_en;
	reg				acc_rst;
	reg				acc_zero;
	reg				acc_op;
	reg				acc_con;
	reg				acc_rhy_en;
	reg signed	[12:0]	acc_op_result;
	reg		[17:0]	acc_slot;
	reg		[7:0]	acc_pan;
	wire signed	[15:0]	acc_snd_l;
	wire signed	[15:0]	acc_snd_r;

	// --------------------------------------------------------------------
	//	enable generator: 28.63636MHz / 8 = 3.579545MHz
	// --------------------------------------------------------------------
	reg		[2:0]	enable_cnt;
	always @( posedge clk or negedge reset_n ) begin
		if( !reset_n ) begin
			enable_cnt	<= 3'd0;
			enable		<= 1'b0;
		end
		else begin
			if( enable_cnt == 3'd7 ) begin
				enable_cnt	<= 3'd0;
				enable		<= 1'b1;
			end
			else begin
				enable_cnt	<= enable_cnt + 3'd1;
				enable		<= 1'b0;
			end
		end
	end

	// --------------------------------------------------------------------
	//	ADPCM memory model (256KB)
	// --------------------------------------------------------------------
	reg		[7:0]	adpcm_mem [0:262143];

	initial begin
		for( int k = 0; k < 262144; k++ ) begin
			adpcm_mem[k] = 8'h00;
		end
	end

	assign adpcm_ready = 1'b1;

	always @( posedge clk ) begin
		adpcm_rdata_en	<= 1'b0;
		if( adpcm_valid && adpcm_ready ) begin
			if( adpcm_write ) begin
				adpcm_mem[ adpcm_address ] <= adpcm_wdata;
			end
			else begin
				adpcm_rdata		<= adpcm_mem[ adpcm_address ];
				adpcm_rdata_en	<= 1'b1;
			end
		end
	end

	// --------------------------------------------------------------------
	//	DUT: opl2
	// --------------------------------------------------------------------
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
		.adpcm_ready		( adpcm_ready		),
		.adpcm_address		( adpcm_address		),
		.adpcm_wdata		( adpcm_wdata		),
		.adpcm_rdata		( adpcm_rdata		),
		.adpcm_rdata_en		( adpcm_rdata_en	)
	);

	jtopl_acc u_acc_test (
		.rst		( acc_rst		),
		.clk		( clk			),
		.cenop		( 1'b1			),
		.slot		( acc_slot		),
		.rhy_en		( acc_rhy_en	),
		.op_result	( acc_op_result	),
		.zero		( acc_zero		),
		.op			( acc_op		),
		.con		( acc_con		),
		.pan		( acc_pan		),
		.snd_l		( acc_snd_l		),
		.snd_r		( acc_snd_r		)
	);

	// --------------------------------------------------------------------
	//	clock: 28.63636 MHz
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	Tasks: bus write
	// --------------------------------------------------------------------
	task bus_write_data(
		input			address,
		input	[7:0]	data
	);
		int timeout;
		$display( "[%t] bus_write_data( addr=0x%01X, data=0x%02X )", $time, address, data );
		@( posedge clk );
		bus_cs		<= 1'b1;
		bus_address	<= address;
		bus_write	<= 1'b1;
		bus_wdata	<= data;
		bus_valid	<= 1'b1;
		@( posedge clk );

		// wait for bus_ready
		timeout = 0;
		while( !bus_ready && timeout < 100000 ) begin
			@( posedge clk );
			timeout++;
		end
		if( timeout >= 100000 ) begin
			$display( "[%t] [TIMEOUT] bus_write_data: waiting for bus_ready", $time );
		end
		assert( timeout < 100000 );

		// deassert
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		bus_write	<= 1'b0;
		@( posedge clk );
	endtask

	task check_acc_pan(
		input	[7:0]	pan,
		input signed [15:0]	expected_l,
		input signed [15:0]	expected_r
	);
		acc_pan		= pan;
		acc_zero	= 1'b0;
		acc_op		= 1'b0;
		acc_op_result	= 13'sd0;
		repeat( 3 ) @( posedge clk );

		acc_zero	= 1'b1;
		@( posedge clk );
		acc_zero	= 1'b0;
		acc_op		= 1'b1;
		acc_op_result	= 13'sd1024;
		@( posedge clk );
		acc_zero	= 1'b1;
		acc_op		= 1'b0;
		acc_op_result	= 13'sd0;
		@( posedge clk );
		acc_zero	= 1'b0;
		@( posedge clk );
		#1;

		$display( "  PAN %0d: L=%0d R=%0d", pan, acc_snd_l, acc_snd_r );
		assert( acc_snd_l == expected_l );
		assert( acc_snd_r == expected_r );
	endtask

	task check_y8950_mix(
		input signed [15:0]	opl2_l,
		input signed [15:0]	opl2_r,
		input signed [15:0]	adpcm_l,
		input signed [15:0]	adpcm_r,
		input signed [15:0]	expected_l,
		input signed [15:0]	expected_r
	);
		force u_dut.ff_opl2_sound_out_l = opl2_l;
		force u_dut.ff_opl2_sound_out_r = opl2_r;
		force u_dut.ff_adpcm_sound_out_l = adpcm_l;
		force u_dut.ff_adpcm_sound_out_r = adpcm_r;
		#1;
		$display( "  Y8950 mix: L=%0d R=%0d", $signed(opl2_sound_out_l), $signed(opl2_sound_out_r) );
		assert( $signed(opl2_sound_out_l) == expected_l );
		assert( $signed(opl2_sound_out_r) == expected_r );
		release u_dut.ff_opl2_sound_out_l;
		release u_dut.ff_opl2_sound_out_r;
		release u_dut.ff_adpcm_sound_out_l;
		release u_dut.ff_adpcm_sound_out_r;
	endtask

	// --------------------------------------------------------------------
	//	Tasks: bus read
	// --------------------------------------------------------------------
	task bus_read_data(
		input			address,
		output	[7:0]	data
	);
		int timeout;
		$display( "[%t] bus_read_data( addr=0x%01X ) ...", $time, address );
		@( posedge clk );
		bus_cs		<= 1'b1;
		bus_address	<= address;
		bus_write	<= 1'b0;
		bus_valid	<= 1'b1;
		@( posedge clk );

		// wait for bus_ready
		timeout = 0;
		while( !bus_ready && timeout < 100000 ) begin
			@( posedge clk );
			timeout++;
		end
		if( timeout >= 100000 ) begin
			$display( "[%t] [TIMEOUT] bus_read_data: waiting for bus_ready", $time );
		end
		assert( timeout < 100000 );

		// deassert valid
		bus_valid	<= 1'b0;

		// wait for bus_rdata_en to go high
		timeout = 0;
		while( bus_rdata_en !== 1'b1 && timeout < 100000 ) begin
			@( posedge clk );
			timeout++;
		end
		if( timeout >= 100000 ) begin
			$display( "[%t] [TIMEOUT] bus_read_data: waiting for bus_rdata_en", $time );
		end
		assert( timeout < 100000 );

		// capture read data
		data = bus_rdata;

		// wait for bus_rdata_en to go low
		timeout = 0;
		while( bus_rdata_en === 1'b1 && timeout < 100000 ) begin
			@( posedge clk );
			timeout++;
		end
		if( timeout >= 100000 ) begin
			$display( "[%t] [TIMEOUT] bus_read_data: waiting for bus_rdata_en deassert", $time );
		end
		assert( timeout < 100000 );

		bus_cs		<= 1'b0;
		@( posedge clk );
		$display( "[%t] bus_read_data( addr=0x%01X ) => data=0x%02X", $time, address, data );
	endtask

	// --------------------------------------------------------------------
	//	Tasks: OPL2 register write (address set + data write)
	// --------------------------------------------------------------------
	task opl2_reg_write(
		input	[7:0]	reg_addr,
		input	[7:0]	data
	);
		$display( "[%t] opl2_reg_write( reg=0x%02X, data=0x%02X )", $time, reg_addr, data );
		// Step 1: write register address
		bus_write_data( 1'b0, reg_addr );
		// Step 2: write register data
		bus_write_data( 1'b1, data );
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	always @( negedge clk ) begin
		if( reset_n && !bus_rdata_en && bus_rdata !== 8'hFF ) begin
			$fatal( 1, "Inactive OPL2 response must be FF, got %02X", bus_rdata );
		end
	end

	initial begin
		reg [7:0] rd;

		test_no		= -1;
		clk			= 0;
		reset_n		= 0;
		bus_cs		= 0;
		bus_address	= 0;
		bus_write	= 0;
		bus_valid	= 0;
		bus_wdata	= 0;
		acc_rst		= 1;
		acc_zero	= 0;
		acc_op		= 0;
		acc_con		= 0;
		acc_rhy_en	= 0;
		acc_op_result	= 0;
		acc_slot	= 18'd0;
		acc_pan		= 8'd128;

		// reset
		repeat( 100 ) @( posedge clk );
		reset_n		= 1;
		acc_rst		= 0;
		repeat( 100 ) @( posedge clk );

		// ---- test_no 0: PAN reset values ----
		test_no = 0;
		$display( "==== Test %0d: PAN reset values ====", test_no );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_0 == 8'd128 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_1 == 8'd128 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_2 == 8'd128 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_3 == 8'd128 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_4 == 8'd128 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_5 == 8'd128 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_6 == 8'd128 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_7 == 8'd128 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_8 == 8'd128 );

		// ---- test_no 1: Read status register of OPL2 ----
		test_no = 1;
		$display( "==== Test %0d: Read OPL2 status ====", test_no );
		bus_read_data( 1'b0, rd );
		$display( "  Status = 0x%02X", rd );
		assert( rd == 8'h06 );

		// ---- test_no 2: Read registers of OPL2 ----
		test_no = 2;
		$display( "==== Test %0d: Read OPL2 registers (Beyond 0Fh) ====", test_no );
		for( i = 0; i < 256; i++ ) begin
			if( i == 8'h0F ) begin
				continue;
			end
			bus_write_data( 1'b0, i );
			bus_read_data( 1'b1, rd );
			$display( "  Register(0x%02X) = 0x%02X", i, rd );
			assert( rd == 8'hFF );
		end

		// ---- test_no 3: PAN writes and channel selection ----
		test_no = 3;
		$display( "==== Test %0d: PAN registers and channel selection ====", test_no );
		for( i = 0; i < 9; i++ ) begin
			opl2_reg_write( 8'hF6 + i, (i + 1) * 11 );
		end
		assert( u_dut.u_opl2.u_base.u_mmr.pan_0 == 8'd11 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_1 == 8'd22 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_2 == 8'd33 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_3 == 8'd44 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_4 == 8'd55 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_5 == 8'd66 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_6 == 8'd77 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_7 == 8'd88 );
		assert( u_dut.u_opl2.u_base.u_mmr.pan_8 == 8'd99 );
		for( i = 0; i < 18; i++ ) begin
			while( !u_dut.u_opl2.u_base.u_mmr.slot[i] ) @( negedge clk );
			$display( "  slot %0d: PAN=%0d expected=%0d", i,
				u_dut.u_opl2.u_base.u_mmr.pan_I,
				(((i / 6) * 3 + (i % 3) + 1) * 11) );
			assert( u_dut.u_opl2.u_base.u_mmr.pan_I ==
				(((i / 6) * 3 + (i % 3) + 1) * 11) );
			@( negedge clk );
		end

		// ---- test_no 4: Equal-power PAN gains ----
		test_no = 4;
		$display( "==== Test %0d: Equal-power PAN gains ====", test_no );
		check_acc_pan( 8'd0,   16'sd1024, 16'sd0    );
		check_acc_pan( 8'd1,   16'sd1024, 16'sd0    );
		check_acc_pan( 8'd128, 16'sd724,  16'sd724  );
		check_acc_pan( 8'd255, 16'sd0,    16'sd1024 );

		// ---- test_no 5: Y8950 EG control and internal sound mix ----
		test_no = 5;
		$display( "==== Test %0d: Y8950 EG control and internal sound mix ====", test_no );
		opl2_reg_write( 8'h12, 8'h40 );
		assert( u_dut.u_adpcm.reg_envelope_control == 8'h40 );
		check_y8950_mix( 16'sd1000,  -16'sd2000, 16'sd3000, 16'sd500,  16'sd4000,  -16'sd1500 );
		check_y8950_mix( 16'sd30000, 16'sd30000,  16'sd10000, 16'sd10000, 16'sd32767, 16'sd32767 );
		check_y8950_mix( -16'sd30000, -16'sd30000, -16'sd10000, -16'sd10000, -16'sd32768, -16'sd32768 );

		// ---- test_no 6: ADPCM playback memory fetch ----
		test_no = 6;
		$display( "==== Test %0d: ADPCM playback memory fetch ====", test_no );
		adpcm_mem[18'h01234] = 8'hA5;
		force u_dut.u_adpcm.w_core_address = 24'h001234;
		force u_dut.u_adpcm.w_adpcm_oe_n = 1'b0;
		force u_dut.u_adpcm.w_mode_play = 1'b1;
		@( posedge clk );
		release u_dut.u_adpcm.w_adpcm_oe_n;
		release u_dut.u_adpcm.w_mode_play;
		release u_dut.u_adpcm.w_core_address;
		repeat( 10 ) @( posedge clk );
		assert( u_dut.u_adpcm.ff_core_data == 8'hA5 );

		repeat( 100 ) @( posedge clk );
		$display( "==== All tests done ====");
		$finish;
	end
endmodule
