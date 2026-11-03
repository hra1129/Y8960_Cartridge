// -----------------------------------------------------------------------------
//	Test of dual_ssg.v (BUILTIN = 0 : Cartridge)
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
//		SSG1 (R#0-15 and its gain/pan) read must never drive the bus, because
//		the MSX main PSG answers the same I/O ports. SSG2 reads are answered.
//		Both DUTs (BUILTIN = 0 / 1) receive the same bus cycles.
// -----------------------------------------------------------------------------

module tb ();
	localparam	clk_base	= 1_000_000_000/85.90908;	//	ps
	reg		[4:0]	ff_divider;
	reg				ff_enable;
	reg				clk;
	reg				reset_n;
	reg				bus_cs;
	reg				bus_valid;
	reg				bus_write;
	reg		[1:0]	bus_address;
	wire			bus_ready_c;
	wire			bus_ready_b;
	reg		[7:0]	bus_wdata;
	wire	[7:0]	bus_rdata_c;
	wire			bus_rdata_en_c;
	wire	[7:0]	bus_rdata_b;
	wire			bus_rdata_en_b;
	wire	[12:0]	sound_out_l_c, sound_out_r_c;
	wire	[12:0]	sound_out_l_b, sound_out_r_b;
	integer			error_count;
	reg				ff_drive_c;			//	cartridge DUT drove the bus during the read
	reg				ff_drive_b;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_divider	<= 5'd0;
			ff_enable	<= 1'b0;
		end
		else if( ff_divider == 5'd23 ) begin
			ff_divider	<= 5'd0;
			ff_enable	<= 1'b1;
		end
		else begin
			ff_divider	<= ff_divider + 5'd1;
			ff_enable	<= 1'b0;
		end
	end

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	dual_ssg #(
		.BUILTIN			( 0					)
	) u_cartridge (
		.clk				( clk				),
		.reset_n			( reset_n			),
		.enable				( ff_enable			),
		.bus_cs				( bus_cs			),
		.bus_valid			( bus_valid			),
		.bus_write			( bus_write			),
		.bus_address		( bus_address		),
		.bus_ready			( bus_ready_c		),
		.bus_wdata			( bus_wdata			),
		.bus_rdata			( bus_rdata_c		),
		.bus_rdata_en		( bus_rdata_en_c	),
		.ssg_ioa0			( 8'h5A				),
		.ssg_iob0			( 					),
		.ssg_ioa1			( 8'hC3				),
		.ssg_iob1			( 					),
		.sound_l_out		( sound_out_l_c		),
		.sound_r_out		( sound_out_r_c		),
		.mode				( 2'b11				)
	);

	dual_ssg #(
		.BUILTIN			( 1					)
	) u_builtin (
		.clk				( clk				),
		.reset_n			( reset_n			),
		.enable				( ff_enable			),
		.bus_cs				( bus_cs			),
		.bus_valid			( bus_valid			),
		.bus_write			( bus_write			),
		.bus_address		( bus_address		),
		.bus_ready			( bus_ready_b		),
		.bus_wdata			( bus_wdata			),
		.bus_rdata			( bus_rdata_b		),
		.bus_rdata_en		( bus_rdata_en_b	),
		.ssg_ioa0			( 8'h5A				),
		.ssg_iob0			( 					),
		.ssg_ioa1			( 8'hC3				),
		.ssg_iob1			( 					),
		.sound_l_out		( sound_out_l_b		),
		.sound_r_out		( sound_out_r_b		),
		.mode				( 2'b11				)
	);

	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	Task
	// --------------------------------------------------------------------
	task write_io(
		input	[1:0]	address,
		input	[7:0]	value
	);
		bus_cs			<= 1'b1;
		bus_address		<= address;
		bus_wdata		<= value;
		bus_write		<= 1'b1;
		bus_valid		<= 1'b1;
		@( posedge clk );
		bus_cs			<= 1'b0;
		bus_write		<= 1'b0;
		bus_valid		<= 1'b0;
		@( posedge clk );
	endtask

	//	Holds the read cycle for 100 clocks (longer than the enable period)
	//	and records whether each DUT asserted bus_rdata_en at any time.
	task read_io(
		input	[1:0]	address,
		output	[7:0]	value_c,
		output	[7:0]	value_b
	);
		bus_cs			= 1'b1;
		bus_address		= address;
		bus_write		= 1'b0;
		bus_valid		= 1'b1;
		ff_drive_c		= 1'b0;
		ff_drive_b		= 1'b0;
		value_c			= 8'hXX;
		value_b			= 8'hXX;
		repeat( 100 ) begin
			@( posedge clk );
			#1;
			if( bus_rdata_en_c ) begin
				ff_drive_c	= 1'b1;
				value_c		= bus_rdata_c;
			end
			if( bus_rdata_en_b ) begin
				ff_drive_b	= 1'b1;
				value_b		= bus_rdata_b;
			end
		end
		bus_valid		= 1'b0;
		bus_cs			= 1'b0;
		@( posedge clk );
		@( posedge clk );
	endtask

	task check(
		input string	name,
		input			condition
	);
		if( condition ) begin
			$display( "OK   : %s", name );
		end
		else begin
			$display( "ERROR: %s", name );
			error_count = error_count + 1;
		end
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		logic	[7:0]	data_c, data_b;
		int				i;
		logic	[7:0]	c_ssg1_ext[6] = '{ 8'h20, 8'h21, 8'h22, 8'h28, 8'h29, 8'h2A };

		error_count		= 0;
		reset_n			= 0;
		clk				= 1;
		bus_cs			= 0;
		bus_address		= 0;
		bus_write		= 0;
		bus_valid		= 0;
		bus_wdata		= 0;

		repeat( 4 ) @( posedge clk );
		reset_n			= 1;
		repeat( 4 ) @( posedge clk );

		//	SSG1 R#0 = 12h, SSG2 R#16 = 34h
		write_io( 2'd0, 8'h00 );
		write_io( 2'd1, 8'h12 );
		write_io( 2'd0, 8'h10 );
		write_io( 2'd1, 8'h34 );

		//	SSG1 registers: cartridge must not drive, builtin must answer
		for( i = 0; i < 16; i++ ) begin
			write_io( 2'd0, i );
			read_io( 2'd2, data_c, data_b );
			check( $sformatf( "SSG1 R#%0d read: cartridge does not drive", i ), !ff_drive_c );
			check( $sformatf( "SSG1 R#%0d read: builtin answers", i ), ff_drive_b );
		end
		write_io( 2'd0, 8'h00 );
		read_io( 2'd2, data_c, data_b );
		check( "SSG1 R#0 builtin value = 12h", data_b == 8'h12 );
		write_io( 2'd0, 8'h0E );
		read_io( 2'd2, data_c, data_b );
		check( "SSG1 R#14 builtin value = port A (5Ah)", data_b == 8'h5A );

		//	SSG1 gain / pan registers (20h-22h, 28h-2Ah)
		for( i = 0; i < 6; i++ ) begin
			write_io( 2'd0, c_ssg1_ext[i] );
			read_io( 2'd2, data_c, data_b );
			check( $sformatf( "SSG1 gain/pan #%0d read: cartridge does not drive", i ), !ff_drive_c );
		end

		//	A0h/A1h reads (address/data write ports) must not drive on the cartridge
		write_io( 2'd0, 8'h10 );
		read_io( 2'd0, data_c, data_b );
		check( "A0h read: cartridge does not drive", !ff_drive_c );
		read_io( 2'd1, data_c, data_b );
		check( "A1h read: cartridge does not drive", !ff_drive_c );

		//	SSG2 registers: both answer
		for( i = 16; i < 32; i++ ) begin
			write_io( 2'd0, i );
			read_io( 2'd2, data_c, data_b );
			check( $sformatf( "SSG2 R#%0d read: cartridge answers", i ), ff_drive_c && ( data_c == data_b ) );
		end
		write_io( 2'd0, 8'h10 );
		read_io( 2'd2, data_c, data_b );
		check( "SSG2 R#16 cartridge value = 34h", data_c == 8'h34 );
		write_io( 2'd0, 8'h1E );
		read_io( 2'd2, data_c, data_b );
		check( "SSG2 R#30 cartridge value = port A (C3h)", data_c == 8'hC3 );

		//	SSG2 gain / pan registers (24h-26h, 2Ch-2Eh)
		write_io( 2'd0, 8'h2C );
		write_io( 2'd1, 8'h55 );
		read_io( 2'd2, data_c, data_b );
		check( "SSG2 Ch.A PAN read: cartridge answers 55h", ff_drive_c && data_c == 8'h55 );
		write_io( 2'd0, 8'h24 );
		read_io( 2'd2, data_c, data_b );
		check( "SSG2 Ch.A gain read: cartridge answers 80h", ff_drive_c && data_c == 8'h80 );

		//	Writes to SSG1 still work on the cartridge
		check( "SSG1 R#0 written on cartridge", u_cartridge.ssg_core0.ff_ssg_ch_a_frequency[7:0] == 8'h12 );

		if( error_count == 0 ) begin
			$display( "PASS" );
		end
		else begin
			$display( "FAIL: %0d errors", error_count );
		end
		$finish;
	end
endmodule
