// -----------------------------------------------------------------------------
//	Test of scc.v stereo panning (9900h-9904h / 7900h-7904h: SCC Ch.A-E PAN)
//	Copyright (C)2026 Takayuki Hara (HRA!)
// -----------------------------------------------------------------------------

module tb ();
	localparam	clk_base	= 1_000_000_000_000.0 / 42_954_540;	//	ps

	reg				clk;
	reg				reset_n;
	reg		[3:0]	ff_enable_cnt;
	reg				enable;
	reg				bus_cs;
	reg		[15:0]	bus_address;
	reg				bus_write;
	reg				bus_valid;
	reg		[7:0]	bus_wdata;
	wire			bus_ready;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;
	wire			scc_memory_cs;
	wire	[5:0]	scc_ma;
	wire	[10:0]	sound_l_out;
	wire	[10:0]	sound_r_out;
	int				error_count;

	scc u_dut (
		.reset_n				( reset_n				),
		.clk					( clk					),
		.enable					( enable				),
		.bus_cs					( bus_cs				),
		.bus_address			( bus_address			),
		.bus_write				( bus_write				),
		.bus_ready				( bus_ready				),
		.bus_valid				( bus_valid				),
		.bus_wdata				( bus_wdata				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_en			( bus_rdata_en			),
		.scc_memory_cs			( scc_memory_cs			),
		.scc_ma					( scc_ma				),
		.sound_l_out			( sound_l_out			),
		.sound_r_out			( sound_r_out			)
	);

	always #(clk_base/2) clk = ~clk;

	always @( posedge clk ) begin
		if( ff_enable_cnt == 4'd11 ) begin
			ff_enable_cnt	<= 4'd0;
			enable			<= 1'b1;
		end
		else begin
			ff_enable_cnt	<= ff_enable_cnt + 4'd1;
			enable			<= 1'b0;
		end
	end

	// --------------------------------------------------------------------
	task write_mem( input [15:0] address, input [7:0] data );
		@( posedge clk );
		bus_address	<= address;
		bus_wdata	<= data;
		bus_write	<= 1'b1;
		bus_cs		<= 1'b1;
		bus_valid	<= 1'b1;
		repeat( 36 ) @( posedge clk );
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		bus_write	<= 1'b0;
		repeat( 36 ) @( posedge clk );
	endtask

	//	Same timing as msx_slot.v: bus_valid drops 1 clock after bus_ready and
	//	the address follows the next bus cycle (opcode fetch at 01E5h) at once.
	task write_slot( input [15:0] address, input [7:0] data );
		@( posedge clk );
		bus_address	<= address;
		bus_wdata	<= data;
		bus_write	<= 1'b1;
		bus_cs		<= 1'b1;
		bus_valid	<= 1'b1;
		@( posedge clk );
		while( !bus_ready ) @( posedge clk );
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		bus_write	<= 1'b0;
		bus_address	<= 16'h01E5;
		repeat( 60 ) @( posedge clk );
	endtask

	//	Z80 memory write on the real slot: /WR is about 12 clocks and msx_slot
	//	starts the access about 5 clocks after /WR, so bus_valid is dropped after
	//	7 clocks even without bus_ready. One call takes 'cycle' clocks
	//	(36 = 3 Z80 states, back-to-back writes such as PUSH).
	task write_z80( input [15:0] address, input [7:0] data, input int cycle );
		int		n;
		reg		r;
		#1;
		bus_address	= address;
		bus_wdata	= data;
		bus_write	= 1'b1;
		bus_cs		= 1'b1;
		bus_valid	= 1'b1;
		n = 0;
		forever begin
			r = bus_ready;
			@( posedge clk );
			#1;
			n++;
			if( r || n >= 7 ) break;
		end
		bus_cs		= 1'b0;
		bus_valid	= 1'b0;
		bus_write	= 1'b0;
		bus_address	= 16'h01E5;
		repeat( cycle - n - 1 ) @( posedge clk );
		@( posedge clk );
	endtask

	//	Same as msx_slot.v: the read data is taken at the first clock of bus_rdata_en.
	task read_slot( input [15:0] address, output [7:0] data );
		@( posedge clk );
		bus_address	<= address;
		bus_write	<= 1'b0;
		bus_cs		<= 1'b1;
		bus_valid	<= 1'b1;
		data		= 8'hXX;
		@( posedge clk );
		while( !bus_ready ) begin
			if( bus_rdata_en && data === 8'hXX ) data = bus_rdata;
			@( posedge clk );
		end
		if( bus_rdata_en && data === 8'hXX ) data = bus_rdata;
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		bus_address	<= 16'h01E5;
		repeat( 60 ) @( posedge clk );
	endtask

	task read_mem( input [15:0] address, output [7:0] data );
		@( posedge clk );
		bus_address	<= address;
		bus_write	<= 1'b0;
		bus_cs		<= 1'b1;
		bus_valid	<= 1'b1;
		repeat( 36 ) @( posedge clk );
		#1;
		data		= bus_rdata;
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		repeat( 36 ) @( posedge clk );
	endtask

	task check_mem( input string name, input [15:0] address, input [7:0] expected );
		reg		[7:0]	data;
		read_mem( address, data );
		if( data == expected ) begin
			$display( "OK   : %s [%04X]=%02X", name, address, data );
		end
		else begin
			$display( "ERROR: %s [%04X] expected %02X, actual %02X", name, address, expected, data );
			error_count++;
		end
	endtask

	task check_romcs( input string name, input [15:0] address, input expected_cs_n );
		@( posedge clk );
		bus_address	<= address;
		bus_write	<= 1'b0;
		bus_cs		<= 1'b1;
		bus_valid	<= 1'b1;
		@( posedge clk );
		#1;
		if( scc_memory_cs == expected_cs_n ) begin
			$display( "OK   : %s ROMCS_n=%0d", name, scc_memory_cs );
		end
		else begin
			$display( "ERROR: %s ROMCS_n expected %0d, actual %0d", name, expected_cs_n, scc_memory_cs );
			error_count++;
		end
		bus_cs		<= 1'b0;
		bus_valid	<= 1'b0;
		repeat( 36 ) @( posedge clk );
	endtask
	task check_pan( input string name, input [7:0] a, input [7:0] b, input [7:0] c, input [7:0] d, input [7:0] e );
		if( u_dut.ff_pan_a == a && u_dut.ff_pan_b == b && u_dut.ff_pan_c == c && u_dut.ff_pan_d == d && u_dut.ff_pan_e == e ) begin
			$display( "OK   : %s PAN=%0d,%0d,%0d,%0d,%0d", name, a, b, c, d, e );
		end
		else begin
			$display( "ERROR: %s PAN expected %0d,%0d,%0d,%0d,%0d actual %0d,%0d,%0d,%0d,%0d", name,
				a, b, c, d, e, u_dut.ff_pan_a, u_dut.ff_pan_b, u_dut.ff_pan_c, u_dut.ff_pan_d, u_dut.ff_pan_e );
			error_count++;
		end
	endtask

	task check_sound( input string name, input signed [7:0] sa, input signed [7:0] sb, input signed [7:0] sc,
			input signed [7:0] sd, input signed [7:0] se, input signed [10:0] expected_l, input signed [10:0] expected_r );
		force u_dut.w_sound_ch = { se, sd, sc, sb, sa };
		repeat( 40 ) @( posedge clk );
		#1;
		if( $signed( sound_l_out ) == expected_l && $signed( sound_r_out ) == expected_r ) begin
			$display( "OK   : %s L=%0d R=%0d", name, $signed( sound_l_out ), $signed( sound_r_out ) );
		end
		else begin
			$display( "ERROR: %s expected L=%0d R=%0d, actual L=%0d R=%0d", name,
				expected_l, expected_r, $signed( sound_l_out ), $signed( sound_r_out ) );
			error_count++;
		end
		release u_dut.w_sound_ch;
	endtask

	// --------------------------------------------------------------------
	initial begin
		clk				= 1'b0;
		reset_n			= 1'b0;
		ff_enable_cnt	= 4'd0;
		enable			= 1'b0;
		bus_cs			= 1'b0;
		bus_address		= 16'h0000;
		bus_write		= 1'b0;
		bus_valid		= 1'b0;
		bus_wdata		= 8'h00;
		error_count		= 0;

		repeat( 30 ) @( posedge clk );
		reset_n			= 1'b1;
		repeat( 30 ) @( posedge clk );

		check_pan( "reset default", 128, 128, 128, 128, 128 );

		//	SCC register window is closed: PAN must not change.
		write_mem( 16'h9900, 8'd1 );
		check_pan( "write while bank2 != 3Fh", 128, 128, 128, 128, 128 );

		//	Open SCC register window, initialize wave RAM Ch.A [00h-05h]
		write_mem( 16'h9000, 8'h3F );
		write_mem( 16'h9800, 8'h11 );
		write_mem( 16'h9801, 8'h22 );
		write_mem( 16'h9802, 8'h33 );
		write_mem( 16'h9803, 8'h44 );
		write_mem( 16'h9804, 8'h55 );
		write_mem( 16'h9805, 8'h66 );

		//	PAN registers
		write_mem( 16'h9900, 8'd1 );
		write_mem( 16'h9901, 8'd255 );
		write_mem( 16'h9902, 8'd64 );
		write_mem( 16'h9903, 8'd200 );
		write_mem( 16'h9904, 8'd128 );
		check_pan( "PAN write", 1, 255, 64, 200, 128 );

		//	PAN writes must not reach wave RAM 9800h-9804h
		check_mem( "wave RAM A[0] kept", 16'h9800, 8'h11 );
		check_mem( "wave RAM A[1] kept", 16'h9801, 8'h22 );
		check_mem( "wave RAM A[2] kept", 16'h9802, 8'h33 );
		check_mem( "wave RAM A[3] kept", 16'h9803, 8'h44 );
		check_mem( "wave RAM A[4] kept", 16'h9804, 8'h55 );

		//	9905h is not a PAN register: original mirror behavior is kept.
		write_mem( 16'h9905, 8'h77 );
		check_mem( "9905h mirrors 9805h", 16'h9805, 8'h77 );
		check_pan( "9905h does not change PAN", 1, 255, 64, 200, 128 );

		//	Panning
		write_mem( 16'h9902, 8'd1 );
		write_mem( 16'h9903, 8'd255 );
		check_sound( "A left, B right", 8'sd100, -8'sd50, 8'sd0, 8'sd0, 8'sd0, 11'sd100, -11'sd50 );
		check_sound( "C left, D right", 8'sd0, 8'sd0, 8'sd127, -8'sd128, 8'sd0, 11'sd127, -11'sd128 );
		//	center: 100 * 181 / 256 = 70.7 -> 70
		check_sound( "E center", 8'sd0, 8'sd0, 8'sd0, 8'sd0, 8'sd100, 11'sd70, 11'sd70 );

		write_mem( 16'h9900, 8'd128 );
		write_mem( 16'h9901, 8'd128 );
		write_mem( 16'h9902, 8'd128 );
		write_mem( 16'h9903, 8'd128 );
		write_mem( 16'h9904, 8'd128 );
		//	5 * 127 * 181 / 256 = 448.9 -> 448
		check_sound( "all center max", 8'sd127, 8'sd127, 8'sd127, 8'sd127, 8'sd127, 11'sd448, 11'sd448 );
		//	5 * -128 * 181 / 256 = -452.5 -> -453
		check_sound( "all center min", -8'sd128, -8'sd128, -8'sd128, -8'sd128, -8'sd128, -11'sd453, -11'sd453 );

		write_mem( 16'h9900, 8'd1 );
		write_mem( 16'h9901, 8'd1 );
		write_mem( 16'h9902, 8'd1 );
		write_mem( 16'h9903, 8'd1 );
		write_mem( 16'h9904, 8'd1 );
		check_sound( "all left min", -8'sd128, -8'sd128, -8'sd128, -8'sd128, -8'sd128, -11'sd640, 11'sd0 );

		//	Real IKASCC output: Ch.A only, PAN = left
		for( int i = 0; i < 32; i++ ) begin
			write_mem( 16'h9800 + i, 8'h40 );
		end
		write_mem( 16'h9880, 8'h10 );
		write_mem( 16'h9881, 8'h00 );
		write_mem( 16'h988A, 8'h0F );
		write_mem( 16'h988F, 8'h01 );
		repeat( 2000 ) @( posedge clk );
		#1;
		if( $signed( sound_l_out ) > 0 && $signed( sound_r_out ) == 0 ) begin
			$display( "OK   : real Ch.A left L=%0d R=%0d", $signed( sound_l_out ), $signed( sound_r_out ) );
		end
		else begin
			$display( "ERROR: real Ch.A left L=%0d R=%0d", $signed( sound_l_out ), $signed( sound_r_out ) );
			error_count++;
		end
		write_mem( 16'h9900, 8'd255 );
		repeat( 100 ) @( posedge clk );
		#1;
		if( $signed( sound_l_out ) == 0 && $signed( sound_r_out ) > 0 ) begin
			$display( "OK   : real Ch.A right L=%0d R=%0d", $signed( sound_l_out ), $signed( sound_r_out ) );
		end
		else begin
			$display( "ERROR: real Ch.A right L=%0d R=%0d", $signed( sound_l_out ), $signed( sound_r_out ) );
			error_count++;
		end

		//	Oscillation frequency: f = 3.579545MHz / (32 * (FREQ + 1)).
		//	FREQ = 100h -> 435.2Hz -> about 21.8 cycles in 50ms.
		//	This detects a wrong polarity of i_MCLK_PCEN_n (the core runs 11x faster).
		for( int i = 0; i < 16; i++ ) begin
			write_mem( 16'h9800 + i, 8'h7F );
		end
		for( int i = 16; i < 32; i++ ) begin
			write_mem( 16'h9800 + i, 8'h80 );
		end
		write_mem( 16'h9880, 8'h00 );
		write_mem( 16'h9881, 8'h01 );
		begin
			int		crossings;
			reg		prev_neg;
			crossings	= 0;
			prev_neg	= 1'b0;
			repeat( 2147727 ) begin
				@( posedge clk );
				#1;
				if( prev_neg && $signed( sound_r_out ) > 0 ) crossings++;
				prev_neg = ( $signed( sound_r_out ) < 0 );
			end
			if( crossings >= 20 && crossings <= 23 ) begin
				$display( "OK   : real Ch.A frequency %0d cycles/50ms", crossings );
			end
			else begin
				$display( "ERROR: real Ch.A frequency %0d cycles/50ms (expected 20-23)", crossings );
				error_count++;
			end
		end
		write_mem( 16'h9900, 8'd1 );

		//	RAM Mode = 1, BANK2 = #63: SCC and PAN remain accessible.
		write_mem( 16'h9800, 8'h40 );
		write_mem( 16'h4FFB, 8'h01 );
		write_mem( 16'h4FFE, 8'h3F );
		write_mem( 16'h9900, 8'd200 );
		write_mem( 16'h9904, 8'd200 );
		write_mem( 16'h9800, 8'h5A );
		check_pan( "RAM Mode=1 BANK2=#63 PAN write", 200, 1, 1, 1, 200 );
		check_romcs( "RAM Mode=1 BANK2=#63 9800h is SCC", 16'h9800, 1'b1 );
		check_romcs( "RAM Mode=1 BANK2=#63 9900h no SRAM", 16'h9900, 1'b1 );
		check_romcs( "RAM Mode=1 BANK2=#63 8000h unconnected", 16'h8000, 1'b1 );
		check_mem( "RAM Mode=1 BANK2=#63 wave RAM", 16'h9800, 8'h5A );
		write_mem( 16'h9900, 8'd10 );
		check_mem( "RAM Mode=1 BANK2 PAN keeps wave RAM", 16'h9800, 8'h5A );
		write_mem( 16'h9880, 8'h23 );
		write_mem( 16'h9881, 8'h01 );
		if( u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.u_ctrl_ch1.freq !== 12'h123 ) begin
			$display( "ERROR: RAM Mode=1 BANK2 frequency write" );
			error_count++;
		end

		//	RAM Mode = 1, BANK2 = #31: SRAM bank
		write_mem( 16'h4FFE, 8'h1F );
		check_romcs( "RAM Mode=1 BANK2=#31 9800h is SRAM", 16'h9800, 1'b0 );
		if( scc_ma == 6'b1_11111 ) begin
			$display( "OK   : RAM Mode=1 BANK2=#31 MA=%02X", scc_ma );
		end
		else begin
			$display( "ERROR: RAM Mode=1 BANK2=#31 MA=%02X", scc_ma );
			error_count++;
		end

		//	RAM Mode = 1, BANK1 = #63: SCC register window at 7800h-7FFFh, PAN at 7900h-7904h
		write_mem( 16'h4FFD, 8'h3F );
		check_romcs( "RAM Mode=1 BANK1=#63 7800h is SCC", 16'h7800, 1'b1 );
		check_romcs( "RAM Mode=1 BANK1=#63 6000h unconnected", 16'h6000, 1'b1 );
		check_mem( "RAM Mode=1 BANK1 wave RAM A[0]", 16'h7800, 8'h5A );
		write_mem( 16'h7800, 8'h21 );
		write_mem( 16'h7804, 8'h25 );
		write_mem( 16'h7900, 8'd10 );
		write_mem( 16'h7901, 8'd20 );
		write_mem( 16'h7902, 8'd30 );
		write_mem( 16'h7903, 8'd40 );
		write_mem( 16'h7904, 8'd50 );
		check_pan( "RAM Mode=1 BANK1 PAN write", 10, 20, 30, 40, 50 );
		check_mem( "RAM Mode=1 BANK1 wave RAM A[0] kept", 16'h7800, 8'h21 );
		check_mem( "RAM Mode=1 BANK1 wave RAM A[4] kept", 16'h7804, 8'h25 );
		write_mem( 16'h7905, 8'h26 );
		check_mem( "RAM Mode=1 7905h mirrors 7805h", 16'h7805, 8'h26 );
		check_pan( "RAM Mode=1 7905h does not change PAN", 10, 20, 30, 40, 50 );

		//	Both windows access the same SCC and PAN registers.
		write_mem( 16'h4FFE, 8'h3F );
		check_mem( "both windows share wave RAM", 16'h9800, 8'h21 );
		write_mem( 16'h7880, 8'h34 );
		write_mem( 16'h7881, 8'h02 );
		if( u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.u_ctrl_ch1.freq !== 12'h234 ) begin
			$display( "ERROR: RAM Mode=1 BANK1 frequency write" );
			error_count++;
		end
		write_mem( 16'h9900, 8'd255 );
		check_pan( "BANK2 changes shared PAN", 255, 20, 30, 40, 50 );
		check_sound( "shared PAN A right", 8'sd100, 8'sd0, 8'sd0, 8'sd0, 8'sd0, 11'sd0, 11'sd100 );
		write_mem( 16'h7900, 8'd1 );
		check_sound( "shared PAN A left", 8'sd100, 8'sd0, 8'sd0, 8'sd0, 8'sd0, 11'sd100, 11'sd0 );
		write_mem( 16'h7900, 8'd10 );

		//	Back to RAM Mode = 0 (BANK2 = #63 by 9000h): BANK1 = #63 is not a window.
		write_mem( 16'h4FFB, 8'h00 );
		write_mem( 16'h9000, 8'h3F );
		check_mem( "RAM Mode=0 9800h shows wave RAM written via 7800h", 16'h9800, 8'h21 );
		write_mem( 16'h7900, 8'd99 );
		check_pan( "RAM Mode=0 7900h ignored", 10, 20, 30, 40, 50 );
		check_romcs( "RAM Mode=0 BANK1=#63 7900h unconnected", 16'h7900, 1'b1 );
		check_romcs( "RAM Mode=0 BANK2=#63 8000h unconnected", 16'h8000, 1'b1 );
		write_mem( 16'h9900, 8'd1 );
		write_mem( 16'h9901, 8'd1 );
		write_mem( 16'h9902, 8'd1 );
		write_mem( 16'h9903, 8'd1 );
		write_mem( 16'h9904, 8'd200 );
		check_pan( "write after back to RAM Mode=0", 1, 1, 1, 1, 200 );
		write_mem( 16'h9904, 8'd1 );
		//	Close SCC register window: PAN must not change.
		write_mem( 16'h9000, 8'h00 );
		write_mem( 16'h9900, 8'd255 );
		check_pan( "write after window closed", 1, 1, 1, 1, 1 );

		//	CANCAN-like sequence with the msx_slot.v bus timing.
		write_slot( 16'h9000, 8'h3F );
		write_slot( 16'h988A, 8'h00 );
		write_slot( 16'h988F, 8'h1F );
		for( int i = 0; i < 16; i++ ) begin
			write_slot( 16'h9800 + i, 8'h7F );
		end
		for( int i = 16; i < 32; i++ ) begin
			write_slot( 16'h9800 + i, 8'h80 );
		end
		write_slot( 16'h9900, 8'd128 );
		write_slot( 16'h9880, 8'h00 );
		write_slot( 16'h9881, 8'h01 );
		write_slot( 16'h988A, 8'h0F );
		if( u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.u_ctrl_ch1.freq === 12'h100 &&
			u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.u_ctrl_ch1.vol === 4'hF &&
			u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.test === 8'h00 ) begin
			$display( "OK   : slot timing FREQ/VOL/TEST" );
		end
		else begin
			$display( "ERROR: slot timing FREQ=%03X VOL=%0d TEST=%02X",
				u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.u_ctrl_ch1.freq,
				u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.u_ctrl_ch1.vol,
				u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.test );
			error_count++;
		end
		begin
			int		crossings;
			reg		prev_neg;
			crossings	= 0;
			prev_neg	= 1'b0;
			repeat( 2147727 ) begin
				@( posedge clk );
				#1;
				if( prev_neg && $signed( sound_l_out ) > 0 ) crossings++;
				prev_neg = ( $signed( sound_l_out ) < 0 );
			end
			if( crossings >= 20 && crossings <= 23 ) begin
				$display( "OK   : slot timing Ch.A frequency %0d cycles/50ms", crossings );
			end
			else begin
				$display( "ERROR: slot timing Ch.A frequency %0d cycles/50ms (expected 20-23)", crossings );
				error_count++;
			end
		end

		//	Wave RAM write/read with the msx_slot.v bus timing (Ch.B).
		for( int i = 0; i < 32; i++ ) begin
			write_slot( 16'h9820 + i, 8'h11 * ( i & 15 ) + i );
		end
		begin
			reg		[7:0]	rd;
			int		ng;
			ng = 0;
			for( int i = 0; i < 32; i++ ) begin
				read_mem( 16'h9820 + i, rd );
				if( rd !== 8'(8'h11 * ( i & 15 ) + i) ) ng++;
			end
			for( int i = 0; i < 32; i += 7 ) begin
				read_slot( 16'h9820 + i, rd );
				if( rd !== 8'(8'h11 * ( i & 15 ) + i) ) begin
					$display( "  read_slot [%04X]=%02X expected %02X", 16'h9820 + i, rd, 8'(8'h11 * ( i & 15 ) + i) );
					ng++;
				end
			end
			if( ng == 0 ) begin
				$display( "OK   : slot timing wave RAM write/read" );
			end
			else begin
				$display( "ERROR: slot timing wave RAM write/read %0d mismatch(es)", ng );
				error_count++;
			end
		end

		//	Short /WR (Z80 memory write) at every phase of enable.
		begin
			reg		[7:0]	rd;
			int		ng;
			ng = 0;
			for( int ph = 0; ph < 12; ph++ ) begin
				@( posedge clk );
				while( !enable ) @( posedge clk );
				repeat( ph ) @( posedge clk );
				write_z80( 16'h9000, 8'h00, 36 );
				write_z80( 16'h9000, 8'h3F, 36 );
				write_z80( 16'h9840 + ph, 8'hA0 + ph, 36 );
				write_z80( 16'h9884, 8'h10 + ph, 36 );
				write_z80( 16'h9885, 8'h02, 36 );
				write_z80( 16'h988C, 8'(ph), 36 );
				write_z80( 16'h9902, 8'd10 + ph, 36 );
				//	Writes closer than a Z80 can do: the 2nd one hits the gap enable.
				write_z80( 16'h9860 + ph, 8'hC0 + ph, 13 );
				write_z80( 16'h9870 + ph, 8'hD0 + ph, 36 );
				repeat( 36 ) @( posedge clk );
				if( u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.u_ctrl_ch3.freq !== 12'h210 + ph ||
					u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.u_ctrl_ch3.vol !== 4'(ph) ||
					u_dut.ff_pan_c !== 8'd10 + ph ) begin
					$display( "  phase %0d: FREQ=%03X VOL=%0d PAN=%0d", ph,
						u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.u_ctrl_ch3.freq,
						u_dut.u_ikascc.IKASCC_SYNC_MODE.u_player_main.u_ctrl_ch3.vol,
						u_dut.ff_pan_c );
					ng++;
				end
				read_mem( 16'h9840 + ph, rd );
				if( rd !== 8'hA0 + ph ) begin
					$display( "  phase %0d: wave [%04X]=%02X", ph, 16'h9840 + ph, rd );
					ng++;
				end
				read_mem( 16'h9860 + ph, rd );
				if( rd !== 8'hC0 + ph ) begin
					$display( "  phase %0d: wave [%04X]=%02X", ph, 16'h9860 + ph, rd );
					ng++;
				end
				read_mem( 16'h9870 + ph, rd );
				if( rd !== 8'hD0 + ph ) begin
					$display( "  phase %0d: wave [%04X]=%02X", ph, 16'h9870 + ph, rd );
					ng++;
				end
			end
			if( ng == 0 ) begin
				$display( "OK   : short /WR at every enable phase" );
			end
			else begin
				$display( "ERROR: short /WR %0d mismatch(es)", ng );
				error_count++;
			end
		end

		if( error_count == 0 ) begin
			$display( "OK   : all tests passed" );
		end
		else begin
			$display( "ERROR: %0d test(s) failed", error_count );
		end
		$finish;
	end
endmodule
