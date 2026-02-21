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
	reg		[1:0]	bus_address;
	reg				bus_write;
	reg				bus_valid;
	wire			bus_ready;
	reg		[7:0]	bus_wdata;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;
	wire	[15:0]	opl2_sound_out_0;
	wire	[15:0]	opl2_sound_out_1;
	wire	[15:0]	adpcm_sound_out_l0;
	wire	[15:0]	adpcm_sound_out_r0;
	wire	[15:0]	adpcm_sound_out_l1;
	wire	[15:0]	adpcm_sound_out_r1;
	wire			intr_n;
	wire			adpcm_oe_n;
	wire			adpcm_we_n;
	wire	[17:0]	adpcm_address;
	wire	[7:0]	adpcm_wdata;
	reg		[7:0]	adpcm_rdata;
	reg				adpcm_rdata_en;

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
	reg				ff_adpcm_oe_n_d;

	initial begin
		for( int k = 0; k < 262144; k++ ) begin
			adpcm_mem[k] = 8'h00;
		end
	end

	always @( posedge clk ) begin
		ff_adpcm_oe_n_d <= adpcm_oe_n;
		if( !adpcm_we_n ) begin
			adpcm_mem[ adpcm_address ] <= adpcm_wdata;
		end
		if( !adpcm_oe_n ) begin
			adpcm_rdata		<= adpcm_mem[ adpcm_address ];
			adpcm_rdata_en	<= 1'b1;
		end
		else begin
			adpcm_rdata_en	<= 1'b0;
		end
	end

	// --------------------------------------------------------------------
	//	DUT: dual_opl2
	// --------------------------------------------------------------------
	dual_opl2 u_dut (
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
		.opl2_sound_out_0	( opl2_sound_out_0	),
		.opl2_sound_out_1	( opl2_sound_out_1	),
		.adpcm_sound_out_l0	( adpcm_sound_out_l0),
		.adpcm_sound_out_r0	( adpcm_sound_out_r0),
		.adpcm_sound_out_l1	( adpcm_sound_out_l1),
		.adpcm_sound_out_r1	( adpcm_sound_out_r1),
		.intr_n				( intr_n			),
		.adpcm_oe_n			( adpcm_oe_n		),
		.adpcm_we_n			( adpcm_we_n		),
		.adpcm_address		( adpcm_address		),
		.adpcm_wdata		( adpcm_wdata		),
		.adpcm_rdata		( adpcm_rdata		),
		.adpcm_rdata_en		( adpcm_rdata_en	)
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
		input	[1:0]	address,
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

	// --------------------------------------------------------------------
	//	Tasks: bus read
	// --------------------------------------------------------------------
	task bus_read_data(
		input	[1:0]	address,
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
		input	[1:0]	base,		//	2'b00: OPL2 #0, 2'b10: OPL2 #1
		input	[7:0]	reg_addr,
		input	[7:0]	data
	);
		$display( "[%t] opl2_reg_write( base=0x%01X, reg=0x%02X, data=0x%02X )", $time, base, reg_addr, data );
		// Step 1: write register address
		bus_write_data( base, reg_addr );
		// Step 2: write register data
		bus_write_data( base | 2'b01, data );
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
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

		// reset
		repeat( 100 ) @( posedge clk );
		reset_n		= 1;
		repeat( 100 ) @( posedge clk );

		// ---- test_no 0: Read status register of OPL2 #0 ----
		test_no = 0;
		$display( "==== Test %0d: Read OPL2 #0 status ====", test_no );
		bus_read_data( 2'd0, rd );
		$display( "  Status = 0x%02X", rd );
		assert( rd == 8'h06 );

		// ---- test_no 1: Read status register of OPL2 #1 ----
		test_no = 1;
		$display( "==== Test %0d: Read OPL2 #1 status ====", test_no );
		bus_read_data( 2'd2, rd );
		$display( "  Status = 0x%02X", rd );
		assert( rd == 8'h06 );

		// ---- test_no 2: Read status register of OPL2 #0 ----
		test_no = 2;
		$display( "==== Test %0d: Read OPL2 #0 registers (Beyond 0Fh) ====", test_no );
		for( i = 0; i < 256; i++ ) begin
			if( i == 8'h0F ) begin
				continue;
			end
			bus_write_data( 2'd0, i );
			bus_read_data( 2'd1, rd );
			$display( "  Register(0x%02X) = 0x%02X", i, rd );
			assert( rd == 8'hFF );
		end

		// ---- test_no 3: Read status register of OPL2 #1 ----
		test_no = 3;
		$display( "==== Test %0d: Read OPL2 #1 registers (Beyond 0Fh) ====", test_no );
		for( i = 0; i < 256; i++ ) begin
			if( i == 8'h0F ) begin
				continue;
			end
			bus_write_data( 2'd2, i );
			bus_read_data( 2'd3, rd );
			$display( "  Register(0x%02X) = 0x%02X", i, rd );
			assert( rd == 8'hFF );
		end

		repeat( 100 ) @( posedge clk );
		$display( "==== All tests done ====");
		$finish;
	end
endmodule
