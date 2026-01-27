// -----------------------------------------------------------------------------
//	Test of ssram.v
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
	localparam	clk_136m_base	= 1_000_000_000/136.02271;	//	ps
	localparam	clk_base		= 1_000_000_000/28.63636;	//	ps
	int				test_no;
	int				i, j;
	reg				clk;
	reg				clk_136m;
	reg				reset_n;
	reg		[18:0]	address;
	reg				valid;
	wire			ready;
	reg				write;
	reg		[7:0]	wdata;
	wire	[7:0]	rdata;
	wire			rdata_en;
	wire			sram_sclk;
	wire			sram_cs_n;
	wire	[3:0]	sram_sio;
	reg		[7:0]	ff_rdata = 8'd0;
	reg				ff_read = 1'b0;
	reg		[3:0]	ff_sram_sio;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	ssram u_ssram (
		.clk				( clk				),
		.clk_136m			( clk_136m			),
		.reset_n			( reset_n			),
		.address			( address			),
		.valid				( valid				),
		.ready				( ready				),
		.write				( write				),
		.wdata				( wdata				),
		.rdata				( rdata				),
		.rdata_en			( rdata_en			),
		.sram_sclk			( sram_sclk			),
		.sram_cs_n			( sram_cs_n			),
		.sram_sio			( sram_sio			)
	);

	assign sram_sio	= ff_read ? ff_sram_sio: 4'dz;

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_136m_base/2) begin
		clk_136m <= ~clk_136m;
	end

	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	Task
	// --------------------------------------------------------------------
	task write_data(
		input	[18:0]	target_address,
		input	[7:0]	data
	);
		address		<= target_address;
		write		<= 1'b1;
		wdata		<= data;
		valid		<= 1'b1;
		while( !ready ) begin
			@( posedge clk );
		end
		valid		<= 1'b0;
		@( posedge clk );
	endtask

	// ---------------------------------------------------------
	task read_data(
		input	[18:0]	target_address,
		output	[7:0]	data
	);
		address		<= target_address;
		write		<= 1'b0;
		valid		<= 1'b1;
		while( !ready ) begin
			@( posedge clk );
		end
		valid		<= 1'b0;
		while( !rdata_en ) begin
			@( posedge clk );
		end
		data		<= rdata;
		@( posedge clk );
	endtask

	// --------------------------------------------------------------------
	task start_serial_sram_dummy();
		logic			quad_mode;
		logic	[7:0]	ff_command;
		logic	[7:0]	ff_data;
		logic	[18:0]	ff_address;
		int				ff_count;

		quad_mode	= 0;
		ff_command	= 0;
		ff_data		= 0;
		ff_count	= 0;
		ff_address	= 0;
		fork
			forever begin
				if( !sram_cs_n ) begin
					if( quad_mode ) begin
						case( ff_count )
						0: begin
							ff_command[7:4]	<= sram_sio;
							ff_count		<= ff_count + 1;
						end
						1: begin
							ff_command[3:0]	<= sram_sio;
							ff_count		<= ff_count + 1;
						end
						2: begin
							ff_count		<= ff_count + 1;
							if( ff_command == 8'd2 ) begin
								ff_read <= 1'b0;
							end
							else begin
								ff_read <= 1'b1;
							end
						end
						3: begin
							ff_address[18:16]	<= sram_sio[2:0];
							ff_count			<= ff_count + 1;
						end
						4: begin
							ff_address[15:12]	<= sram_sio;
							ff_count			<= ff_count + 1;
						end
						5: begin
							ff_address[11:8]	<= sram_sio;
							ff_count			<= ff_count + 1;
						end
						6: begin
							ff_address[7:4]		<= sram_sio;
							ff_count			<= ff_count + 1;
						end
						7: begin
							ff_address[3:0]		<= sram_sio;
							ff_count			<= ff_count + 1;
						end
						8: begin
							ff_data[7:4]		<= sram_sio;
							ff_count			<= ff_count + 1;
						end
						9: begin
							ff_data[3:0]		<= sram_sio;
							ff_count			<= 15;
						end
						10, 11, 12: begin
							ff_count			<= ff_count + 1;
						end
						13: begin
							ff_sram_sio			<= ff_rdata[7:4];
							ff_count			<= ff_count + 1;
						end
						14: begin
							ff_sram_sio			<= ff_rdata[3:0];
							ff_count			<= ff_count + 1;
						end
						15: begin
							ff_sram_sio			<= 4'bzzzz;
							ff_read				<= 1'b0;
							ff_count			<= 0;
						end
						endcase
					end
					else begin
						if( ff_count == 7 ) begin
							ff_command	<= { ff_command[6:0], sram_sio[0] };
							ff_count	<= 0;
						end
						else begin
							ff_command	<= { ff_command[6:0], sram_sio[0] };
							ff_count	<= ff_count + 1;
						end
					end
				end
				@( negedge sram_sclk );
				if( quad_mode ) begin
					if( ff_count == 15 ) begin
						if( ff_read ) begin
							$display( "[info] read data %02x", ff_rdata );
						end
						else begin
							$display( "[info] write data %02x", ff_data );
						end
					end
				end
				else begin
					if( ff_count == 0 && ff_command == 8'b00111000 ) begin
						$display( "[info] Done EQIO command." );
						quad_mode	<= 1'b1;
						ff_count	= 0;
					end
				end
			end
		join_none
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		logic	[7:0]	data;

		test_no = -1;
		clk = 1;
		clk_136m = 1;
		reset_n = 0;
		address = 0;
		valid = 0;
		write = 0;
		wdata = 0;

		start_serial_sram_dummy();

		@( negedge clk );
		@( negedge clk );
		@( posedge clk );

		reset_n = 1;
		@( posedge clk );

		write_data( 19'd100, 8'd123 );
		write_data( 19'd200, 8'd234 );
		write_data( 19'd300, 8'd34 );

		read_data( 19'd100, data );
		read_data( 19'd200, data );
		read_data( 19'd300, data );
		repeat( 100 ) @( posedge clk );
		$finish;
	end
endmodule
