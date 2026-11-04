// -----------------------------------------------------------------------------
//	Top-level ADPCM memory write / read-back test
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
//		MSX slot -> OPL2/ADPCM (C0h/C1h) -> SRAM arbiter -> ssram -> SerialSRAM model
//		Loads N bytes in the ADPCM memory write mode (as CANCAN does), then
//		checks the SRAM contents, the CS hold time (TCSH) of every write, and
//		reads them back twice in the memory read mode.
// -----------------------------------------------------------------------------


module tb ();
	localparam	clk_base	= 1_000_000_000_000.0/28_636_360;	//	ps
	int				test_no;
	int				i, j;
	reg				clk;
	reg				clk_14m;
	reg				clk_50m;
	//	slot
	reg				slot_reset_n;
	reg		[15:0]	slot_a;
	wire	[7:0]	slot_d;
	reg				slot_sltsl_n;
	reg				slot_mereq_n;
	reg				slot_ioreq_n;
	reg				slot_wr_n;
	reg				slot_rd_n;
	wire			slot_wait;
	wire			slot_intr;
	wire			slot_busdir;
	//	audio
	wire			audio_mclk;
	wire			audio_bclk;
	wire			audio_lrclk;
	wire			audio_sdata;
	//	flash ROM
	wire			flash_spi_clk;
	wire			flash_spi_cs_n;
	wire	[3:0]	flash_spi_io;
	//	SRAM
	wire			sram_ce_n;
	wire			sram_sclk;
	wire	[3:0]	sram_sio;
	//	DIP S/W
	reg		[1:0]	dipsw;
	//	LED
	wire	[3:0]	led;

	//	task signals
	localparam	cpu_clk_base	= 1_000_000_000_000.0/3_579_545;	//	ps
	string			s_state;
	reg				p_slot_clk;
	reg		[7:0]	ff_slot_data;

	assign slot_d = !slot_wr_n ? ff_slot_data : 8'hZZ;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	y8960cartridge_tangprimer25k u_dut (
		.clk_28m				( clk					),
		.clk_50m				( clk					),
		.slot_reset_n			( slot_reset_n			),
		.slot_a					( slot_a				),
		.slot_d					( slot_d				),
		.slot_sltsl_n			( slot_sltsl_n			),
		.slot_mereq_n			( slot_mereq_n			),
		.slot_ioreq_n			( slot_ioreq_n			),
		.slot_wr_n				( slot_wr_n				),
		.slot_rd_n				( slot_rd_n				),
		.slot_wait				( slot_wait				),
		.slot_intr				( slot_intr				),
		.slot_busdir			( slot_busdir			),
		.audio_mclk				( audio_mclk			),
		.audio_bclk				( audio_bclk			),
		.audio_lrclk			( audio_lrclk			),
		.audio_sdata			( audio_sdata			),
		.flash_spi_clk			( flash_spi_clk			),
		.flash_spi_cs_n			( flash_spi_cs_n		),
		.flash_spi_io			( flash_spi_io			),
		.sram_ce_n				( sram_ce_n				),
		.sram_sclk				( sram_sclk				),
		.sram_sio				( sram_sio				),
		.dipsw					( dipsw					),
		.led					( led					)
	);

	// --------------------------------------------------------------------
	//	Serial Flash ROM test model
	// --------------------------------------------------------------------
	sfrom_test_model u_sfrom (
		.spi_clk				( flash_spi_clk			),
		.spi_cs_n				( flash_spi_cs_n		),
		.spi_io					( flash_spi_io			)
	);

	// --------------------------------------------------------------------
	//	Serial SRAM test model
	// --------------------------------------------------------------------
	ssram_test_model #( .VERBOSE( 0 ) ) u_ssram (
		.sclk					( sram_sclk				),
		.cs_n					( sram_ce_n				),
		.sio					( sram_sio				)
	);

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	Task
	// --------------------------------------------------------------------
	task write_io(
		input	[15:0]	address,
		input	[7:0]	wdata
	);
		fork
			//	CPU clock
			begin
				//	T1
				s_state		= "T1";
				p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T2
				s_state		= "T2";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	TW
				s_state		= "TW";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T3
				s_state		= "T3";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T4
				s_state		= "T4";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T5
				s_state		= "T5";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
			end
			//	Address
			begin
				#170ns slot_a = address;
			end
			//	/IORQ
			begin
				slot_ioreq_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#135ns slot_ioreq_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#145ns slot_ioreq_n = 1'b1;
			end
			//	/WR
			begin
				slot_wr_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#125ns slot_wr_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#120ns slot_wr_n = 1'b1;
			end
			//	others
			begin
				ff_slot_data	= wdata;
			end
		join
	endtask

	// --------------------------------------------------------------------
	task write_io_ex(
		input	[7:0]	address,
		input	[7:0]	wdata
	);
		fork
			//	CPU clock
			begin
				//	T1
				s_state		= "T1";
				p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T2
				s_state		= "T2";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	TW
				s_state		= "TW";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T3
				s_state		= "T3";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T4
				s_state		= "T4";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T5
				s_state		= "T5";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
			end
			//	Address
			begin
				#170ns slot_a = address;
			end
			//	/IORQ
			begin
				slot_ioreq_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#175ns slot_ioreq_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#185ns slot_ioreq_n = 1'b1;
			end
			//	/WR
			begin
				slot_wr_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#165ns slot_wr_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#150ns slot_wr_n = 1'b1;
			end
			//	others
			begin
				ff_slot_data	= wdata;
			end
		join
	endtask

	// --------------------------------------------------------------------
	task read_io(
		input	[15:0]	address,
		output	[7:0]	rdata
	);
		fork
			//	CPU clock
			begin
				//	T1
				s_state		= "T1";
				p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T2
				s_state		= "T2";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	TW
				s_state		= "TW";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T3
				s_state		= "T3";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T4
				s_state		= "T4";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T5
				s_state		= "T5";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
			end
			//	Address
			begin
				#170ns slot_a = address;
			end
			//	/IORQ
			begin
				slot_ioreq_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#135ns slot_ioreq_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#145ns slot_ioreq_n = 1'b1;
			end
			//	/RD
			begin
				slot_rd_n = 1'b1;
				//	T1
				@( negedge slot_ioreq_n );
				#10ns slot_rd_n = 1'b0;
				@( posedge slot_ioreq_n );
				rdata = slot_d;
				slot_rd_n = 1'b1;
			end
		join
	endtask

	localparam int N = 200;
	function automatic [7:0] pat( input int k );
		pat = (k * 37 + 5) ^ (k >> 3);
	endfunction

	task opl_w( input [7:0] r, input [7:0] v );
		write_io( 16'h00C0, r );
		write_io( 16'h00C1, v );
	endtask

	task wait_bufrdy;
		logic [7:0] st;
		int t;
		t = 0;
		do begin
			read_io( 16'h00C0, st );
			t++;
			if( t > 1000 ) $fatal( 1, "BUF_RDY timeout (status=%02X)", st );
		end while( !st[3] );
	endtask

	initial begin
		logic [7:0] data;
		int errs, merrs, total;

		clk = 1; slot_reset_n = 0; slot_a = 0; slot_sltsl_n = 1; slot_mereq_n = 1;
		slot_ioreq_n = 1; slot_wr_n = 1; slot_rd_n = 1; p_slot_clk = 0; ff_slot_data = 0;
		dipsw = 2'b00;
		repeat( 4 ) @( negedge clk );
		slot_reset_n = 1;
		repeat( 100 ) @( posedge clk );
		wait( u_dut.ff_slot_connected === 1'b1 );
		wait( u_dut.w_wait_n === 1'b1 );
		repeat( 50 ) @( negedge u_dut.clk_42m );
		$display( "[INFO] boot done at %t", $time );
		force u_dut.u_y8960_address_decode.ff_opl2_io_en = 1'b1;

		opl_w( 8'h07, 8'h01 );
		opl_w( 8'h08, 8'h00 );
		opl_w( 8'h09, 8'h00 );
		opl_w( 8'h0A, 8'h00 );
		opl_w( 8'h0B, N / 4 );
		opl_w( 8'h0C, 8'h00 );
		opl_w( 8'h10, 8'h55 );
		opl_w( 8'h11, 8'h55 );
		opl_w( 8'h12, 8'hFF );
		opl_w( 8'h07, 8'h60 );
		opl_w( 8'h04, 8'h80 );
		opl_w( 8'h04, 8'h00 );
		write_io( 16'h00C0, 8'h0F );
		for( int k = 0; k < N; k++ ) begin
			wait_bufrdy();
			write_io( 16'h00C1, pat( k ) );
		end
		opl_w( 8'h07, 8'h01 );
		opl_w( 8'h04, 8'h80 );
		opl_w( 8'h04, 8'h18 );
		repeat( 200 ) @( negedge u_dut.clk_42m );

		total = 0;
		merrs = 0;
		for( int k = 0; k < N; k++ ) begin
			if( u_ssram.mem[ 19'h40000 + k ] !== pat( k ) ) begin
				if( merrs < 10 ) $display( "[MEM] %0d: %02X expected %02X", k, u_ssram.mem[ 19'h40000 + k ], pat( k ) );
				merrs++;
			end
		end
		$display( "[INFO] SRAM model mismatches: %0d / %0d", merrs, N );

		for( int pass = 0; pass < 2; pass++ ) begin
			opl_w( 8'h07, 8'h01 );
			opl_w( 8'h07, 8'h20 );
			opl_w( 8'h04, 8'h80 );
			opl_w( 8'h04, 8'h00 );
			write_io( 16'h00C0, 8'h0F );
			wait_bufrdy(); read_io( 16'h00C1, data );
			wait_bufrdy(); read_io( 16'h00C1, data );
			errs = 0;
			for( int k = 0; k < N; k++ ) begin
				wait_bufrdy();
				read_io( 16'h00C1, data );
				if( data !== pat( k ) ) begin
					if( errs < 10 ) $display( "[RD%0d] %0d: %02X expected %02X", pass, k, data, pat( k ) );
					errs++;
				end
			end
			total += errs;
			$display( "[INFO] pass %0d read-back mismatches: %0d / %0d", pass, errs, N );
			opl_w( 8'h07, 8'h01 );
			opl_w( 8'h04, 8'h80 );
			opl_w( 8'h04, 8'h18 );
		end
		$display( "[INFO] TCSH violations: %0d", u_ssram.tcsh_errors );
		if( merrs != 0 || total != 0 || u_ssram.tcsh_errors != 0 ) begin
			$fatal( 1, "[RESULT] ADPCM memory test: FAIL" );
		end
		$display( "[RESULT] ADPCM memory test: PASS" );
		$finish;
	end

	initial begin
		#200ms;
		$fatal( 1, "timeout" );
	end
endmodule
