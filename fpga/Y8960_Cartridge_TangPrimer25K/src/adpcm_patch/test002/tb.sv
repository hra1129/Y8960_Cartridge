// --------------------------------------------------------------------
//	ADPCM (Y8950 compatible) functional test
//	status flags, memory write/read, playback, 64K / ROM
// --------------------------------------------------------------------
module tb ();
	localparam	clk_base = 1_000_000_000_000.0 / 42_954_540;

	reg					clk;
	reg					reset_n;
	reg					cen55;
	reg		[7:0]		ff_cen_cnt;
	reg					bus_cs;
	reg					bus_address;
	reg					bus_write;
	reg					bus_valid;
	reg		[7:0]		bus_wdata;
	wire	[7:0]		bus_rdata;
	wire				bus_rdata_en;
	wire				adpcm_irq;
	wire signed	[15:0]	adpcm_sound_out_l;
	wire signed	[15:0]	adpcm_sound_out_r;
	wire				adpcm_write;
	wire				adpcm_valid;
	wire				adpcm_ready;
	wire	[23:0]		adpcm_address;
	wire	[7:0]		adpcm_wdata;
	reg		[7:0]		adpcm_rdata;
	reg					adpcm_rdata_en;
	integer				error_count;

	//	SRAM model
	reg		[7:0]		mem [0:262143];
	reg		[1:0]		ff_wait;
	reg		[2:0]		ff_rd_pipe;
	reg		[17:0]		ff_rd_addr [0:2];
	reg					monitor_play;
	integer				play_read_count;
	integer				play_addr_min;
	integer				play_addr_max;
	integer				max_abs_l;
	integer				max_abs_r;

	adpcm u_dut (
		.clk				( clk				),
		.reset_n			( reset_n			),
		.enable				( 1'b1				),
		.cen55				( cen55				),
		.bus_cs				( bus_cs			),
		.bus_address		( bus_address		),
		.bus_write			( bus_write			),
		.bus_valid			( bus_valid			),
		.bus_wdata			( bus_wdata			),
		.bus_rdata			( bus_rdata			),
		.bus_rdata_en		( bus_rdata_en		),
		.opl2_status		( 8'd0				),
		.adpcm_irq			( adpcm_irq			),
		.adpcm_sound_out_l	( adpcm_sound_out_l	),
		.adpcm_sound_out_r	( adpcm_sound_out_r	),
		.adpcm_write		( adpcm_write		),
		.adpcm_valid		( adpcm_valid		),
		.adpcm_ready		( adpcm_ready		),
		.adpcm_address		( adpcm_address		),
		.adpcm_wdata		( adpcm_wdata		),
		.adpcm_rdata		( adpcm_rdata		),
		.adpcm_rdata_en		( adpcm_rdata_en	)
	);

	always #(clk_base/2) clk = ~clk;

	//	cen55 is accelerated for simulation (1/256 clk)
	//	adpcm_lpf needs 197 clk per sample.
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_cen_cnt	<= 8'd0;
			cen55		<= 1'b0;
		end
		else begin
			ff_cen_cnt	<= ff_cen_cnt + 8'd1;
			cen55		<= (ff_cen_cnt == 8'd255);
		end
	end

	//	SRAM: request accepted 2 clocks after valid, read data 3 clocks after acceptance
	assign adpcm_ready = adpcm_valid & (ff_wait == 2'd2);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_wait			<= 2'd0;
			ff_rd_pipe		<= 3'd0;
			adpcm_rdata_en	<= 1'b0;
			adpcm_rdata		<= 8'hXX;
		end
		else begin
			if( adpcm_valid && !adpcm_ready ) begin
				ff_wait	<= ff_wait + 2'd1;
			end
			else begin
				ff_wait	<= 2'd0;
			end

			if( adpcm_valid && adpcm_ready && adpcm_write ) begin
				mem[ adpcm_address[17:0] ] <= adpcm_wdata;
			end

			ff_rd_pipe		<= { ff_rd_pipe[1:0], adpcm_valid & adpcm_ready & ~adpcm_write };
			ff_rd_addr[0]	<= adpcm_address[17:0];
			ff_rd_addr[1]	<= ff_rd_addr[0];
			ff_rd_addr[2]	<= ff_rd_addr[1];
			adpcm_rdata_en	<= ff_rd_pipe[2];
			adpcm_rdata		<= ff_rd_pipe[2] ? mem[ ff_rd_addr[2] ] : 8'hXX;

			if( monitor_play && adpcm_valid && adpcm_ready && !adpcm_write ) begin
				play_read_count = play_read_count + 1;
				if( adpcm_address < play_addr_min ) play_addr_min = adpcm_address;
				if( adpcm_address > play_addr_max ) play_addr_max = adpcm_address;
			end
			if( monitor_play ) begin
				if( adpcm_sound_out_l > max_abs_l ) max_abs_l = adpcm_sound_out_l;
				if( -adpcm_sound_out_l > max_abs_l ) max_abs_l = -adpcm_sound_out_l;
				if( adpcm_sound_out_r > max_abs_r ) max_abs_r = adpcm_sound_out_r;
				if( -adpcm_sound_out_r > max_abs_r ) max_abs_r = -adpcm_sound_out_r;
			end
		end
	end

	// ---------------------------------------------------------
	//	Bus tasks (bus_valid is a one clock pulse like msx_slot)
	// ---------------------------------------------------------
	task bus_write_cycle( input a, input [7:0] d );
		@( posedge clk );
		bus_cs		<= 1'b1;
		bus_valid	<= 1'b1;
		bus_write	<= 1'b1;
		bus_address	<= a;
		bus_wdata	<= d;
		@( posedge clk );
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		bus_write	<= 1'b0;
		repeat( 4 ) @( posedge clk );
	endtask

	task bus_read_cycle( input a, output [7:0] d );
		@( posedge clk );
		bus_cs		<= 1'b1;
		bus_valid	<= 1'b1;
		bus_write	<= 1'b0;
		bus_address	<= a;
		@( posedge clk );
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		#1;
		while( !bus_rdata_en ) begin
			@( posedge clk );
			#1;
		end
		d = bus_rdata;
		repeat( 4 ) @( posedge clk );
	endtask

	task write_reg( input [7:0] address, input [7:0] data );
		bus_write_cycle( 1'b0, address );
		bus_write_cycle( 1'b1, data );
	endtask

	task read_reg( input [7:0] address, output [7:0] data );
		bus_write_cycle( 1'b0, address );
		bus_read_cycle( 1'b1, data );
	endtask

	task read_status( output [7:0] data );
		bus_read_cycle( 1'b0, data );
	endtask

	task check( input string name, input [31:0] actual, input [31:0] expected );
		if( actual === expected ) begin
			$display( "OK   : %s = 0x%0h", name, actual );
		end
		else begin
			$display( "ERROR: %s expected 0x%0h, actual 0x%0h", name, expected, actual );
			error_count = error_count + 1;
		end
	endtask

	task wait_buf_rdy;
		reg		[7:0]	st;
		integer			timeout;
		begin
			timeout = 0;
			read_status( st );
			while( !st[3] && timeout < 100 ) begin
				read_status( st );
				timeout = timeout + 1;
			end
			if( !st[3] ) begin
				$display( "ERROR: BUF_RDY timeout" );
				error_count = error_count + 1;
			end
		end
	endtask

	task set_address( input [15:0] start_addr, input [15:0] stop_addr );
		write_reg( 8'h09, start_addr[7:0] );
		write_reg( 8'h0A, start_addr[15:8] );
		write_reg( 8'h0B, stop_addr[7:0] );
		write_reg( 8'h0C, stop_addr[15:8] );
	endtask

	// ---------------------------------------------------------
	//	Test sequence
	// ---------------------------------------------------------
	reg		[7:0]	st;
	reg		[7:0]	d;
	integer			i;
	integer			timeout;

	initial begin
		clk				= 1'b0;
		reset_n			= 1'b0;
		bus_cs			= 1'b0;
		bus_address		= 1'b0;
		bus_write		= 1'b0;
		bus_valid		= 1'b0;
		bus_wdata		= 8'd0;
		error_count		= 0;
		monitor_play	= 1'b0;
		play_read_count	= 0;
		play_addr_min	= 32'h7FFFFFFF;
		play_addr_max	= 0;
		max_abs_l		= 0;
		max_abs_r		= 0;
		for( i = 0; i < 262144; i = i + 1 ) begin
			mem[i] = 8'h00;
		end

		repeat( 4 ) @( posedge clk );
		reset_n = 1'b1;
		repeat( 4 ) @( posedge clk );

		$display( "==== Test 1: status and mask ====" );
		read_status( st );
		check( "reset status (all flags masked)", st, 8'h06 );
		check( "reset irq", adpcm_irq, 1'b0 );
		write_reg( 8'h04, 8'h00 );
		read_status( st );
		check( "unmasked idle status (IRQ + BUF_RDY)", st, 8'h8E );
		check( "unmasked idle irq", adpcm_irq, 1'b1 );
		write_reg( 8'h04, 8'h08 );
		read_status( st );
		check( "BUF_RDY masked", st, 8'h06 );
		write_reg( 8'h04, 8'h00 );

		$display( "==== Test 2: memory write (R#07=60h) ====" );
		write_reg( 8'h08, 8'h00 );
		set_address( 16'h0010, 16'h0011 );			//	byte 0040h - 0047h
		write_reg( 8'h07, 8'h01 );
		write_reg( 8'h07, 8'h60 );
		for( i = 0; i < 8; i = i + 1 ) begin
			wait_buf_rdy();
			write_reg( 8'h0F, 8'h11 * (i + 1) );
		end
		wait_buf_rdy();
		for( i = 0; i < 8; i = i + 1 ) begin
			check( $sformatf( "mem[%0h]", 18'h40 + i ), mem[ 18'h40 + i ], 8'h11 * (i + 1) );
		end
		check( "mem[3Fh] untouched", mem[ 18'h3F ], 8'h00 );
		check( "mem[48h] untouched", mem[ 18'h48 ], 8'h00 );
		read_status( st );
		check( "EOS after last write", st & 8'h10, 8'h10 );
		check( "irq after last write", adpcm_irq, 1'b1 );

		write_reg( 8'h04, 8'h80 );
		read_status( st );
		check( "R#04 bit7 clears EOS (BUF_RDY held in memory mode)", st, 8'h8E );

		$display( "==== Test 3: memory read (R#07=20h) ====" );
		write_reg( 8'h07, 8'h01 );
		write_reg( 8'h07, 8'h20 );
		write_reg( 8'h04, 8'h80 );
		read_reg( 8'h0F, d );
		read_reg( 8'h0F, d );
		for( i = 0; i < 8; i = i + 1 ) begin
			wait_buf_rdy();
			read_reg( 8'h0F, d );
			check( $sformatf( "read data %0d", i ), d, 8'h11 * (i + 1) );
		end
		read_status( st );
		check( "no EOS before reading beyond stop", st & 8'h10, 8'h00 );
		read_reg( 8'h0F, d );
		check( "read beyond stop", d, 8'h00 );
		read_status( st );
		check( "EOS after reading beyond stop", st & 8'h10, 8'h10 );

		$display( "==== Test 4: 64K mode and ROM bit ====" );
		write_reg( 8'h07, 8'h01 );
		write_reg( 8'h04, 8'h80 );
		write_reg( 8'h08, 8'h02 );					//	64K
		set_address( 16'h4001, 16'h4001 );			//	byte 10004h -> 0004h
		write_reg( 8'h07, 8'h60 );
		for( i = 0; i < 4; i = i + 1 ) begin
			wait_buf_rdy();
			write_reg( 8'h0F, 8'hA0 + i );
		end
		wait_buf_rdy();
		check( "64K mem[0004h]", mem[ 18'h00004 ], 8'hA0 );
		check( "64K mem[0007h]", mem[ 18'h00007 ], 8'hA3 );
		check( "64K mem[10004h] untouched", mem[ 18'h10004 ], 8'h00 );

		write_reg( 8'h07, 8'h01 );
		write_reg( 8'h08, 8'h01 );					//	ROM
		set_address( 16'h0001, 16'h0001 );
		write_reg( 8'h07, 8'h60 );
		wait_buf_rdy();
		write_reg( 8'h0F, 8'h5A );
		wait_buf_rdy();
		check( "ROM write ignored", mem[ 18'h00004 ], 8'hA0 );
		write_reg( 8'h07, 8'h01 );
		write_reg( 8'h07, 8'h20 );
		read_reg( 8'h0F, d );
		read_reg( 8'h0F, d );
		wait_buf_rdy();
		read_reg( 8'h0F, d );
		check( "ROM read returns 0", d, 8'h00 );

		$display( "==== Test 5: playback (R#07=A0h) ====" );
		write_reg( 8'h07, 8'h01 );
		write_reg( 8'h08, 8'h00 );
		//	sample data at byte 0100h - 017Fh
		for( i = 0; i < 128; i = i + 1 ) begin
			mem[ 18'h100 + i ] = (i < 32) ? 8'h77 : ((i < 64) ? 8'hFF : 8'h77);
		end
		set_address( 16'h0040, 16'h005F );			//	byte 0100h - 017Fh
		write_reg( 8'h10, 8'hFF );
		write_reg( 8'h11, 8'hFF );
		write_reg( 8'h12, 8'hFF );
		write_reg( 8'h04, 8'h80 );
		monitor_play = 1'b1;
		write_reg( 8'h07, 8'hA0 );
		read_status( st );
		check( "PCM_BSY during playback", st & 8'h01, 8'h01 );
		repeat( 3 * 256 ) @( posedge clk );
		check( "chon", u_dut.u_adpcm.u_cnt.chon, 1'b1 );

		timeout = 0;
		read_status( st );
		while( !st[4] && timeout < 2000 ) begin
			repeat( 200 ) @( posedge clk );
			read_status( st );
			timeout = timeout + 1;
		end
		monitor_play = 1'b0;
		check( "EOS at end of playback", st & 8'h10, 8'h10 );
		check( "PCM_BSY cleared at end", st & 8'h01, 8'h00 );
		check( "irq at end of playback", adpcm_irq, 1'b1 );
		check( "playback min address", play_addr_min, 32'h100 );
		check( "playback max address", play_addr_max, 32'h17F );
		if( play_read_count >= 128 ) begin
			$display( "OK   : playback read count = %0d", play_read_count );
		end
		else begin
			$display( "ERROR: playback read count = %0d (expected >= 128)", play_read_count );
			error_count = error_count + 1;
		end
		if( max_abs_l > 1000 && max_abs_r > 1000 ) begin
			$display( "OK   : playback output max |L|=%0d |R|=%0d", max_abs_l, max_abs_r );
		end
		else begin
			$display( "ERROR: playback output too small |L|=%0d |R|=%0d", max_abs_l, max_abs_r );
			error_count = error_count + 1;
		end

		write_reg( 8'h04, 8'h80 );
		read_status( st );
		check( "R#04 bit7 after playback (idle: BUF_RDY)", st, 8'h8E );
		//	adpcm_lpf output settles to 0 after 25 samples
		repeat( 26 * 256 ) @( posedge clk );
		check( "output is 0 after playback L", adpcm_sound_out_l, 16'd0 );
		check( "output is 0 after playback R", adpcm_sound_out_r, 16'd0 );

		$display( "==== Test 6: SP-OFF mutes output ====" );
		max_abs_l = 0;
		max_abs_r = 0;
		monitor_play = 1'b1;
		write_reg( 8'h07, 8'hA8 );
		repeat( 30 * 256 ) @( posedge clk );
		monitor_play = 1'b0;
		check( "SP-OFF |L|", max_abs_l, 0 );
		write_reg( 8'h07, 8'h01 );

		$display( "==== Test 7: repeat playback (R#07=B0h) ====" );
		write_reg( 8'h04, 8'h80 );
		set_address( 16'h0040, 16'h0043 );			//	byte 0100h - 010Fh
		write_reg( 8'h07, 8'hB0 );
		timeout = 0;
		read_status( st );
		while( !st[4] && timeout < 2000 ) begin
			repeat( 50 ) @( posedge clk );
			read_status( st );
			timeout = timeout + 1;
		end
		check( "EOS at loop end", st & 8'h10, 8'h10 );
		check( "PCM_BSY kept while repeating", st & 8'h01, 8'h01 );
		repeat( 2000 ) @( posedge clk );
		check( "still playing (chon)", u_dut.u_adpcm.u_cnt.chon, 1'b1 );
		write_reg( 8'h07, 8'h01 );
		read_status( st );
		check( "PCM_BSY cleared by RESET", st & 8'h01, 8'h00 );

		if( error_count == 0 ) begin
			$display( "OK   : all tests passed" );
		end
		else begin
			$display( "ERROR: %0d test(s) failed", error_count );
		end
		$finish;
	end
endmodule
