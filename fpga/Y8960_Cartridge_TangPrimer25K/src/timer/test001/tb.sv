// -----------------------------------------------------------------------------
//	Test of msx_timer.v
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
	localparam	clk_base	= 1_000_000_000/85.90908;	//	ps
	int				test_no;
	int				i, j;
	reg				clk;
	reg				reset_n;
	reg				bus_ioreq;
	reg		[7:0]	bus_address;
	reg				bus_write;
	reg				bus_valid;
	wire			bus_ready;
	reg		[7:0]	bus_wdata;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;
	wire			intr_n;
	reg		[32:0]	ff_counter = 0;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	msx_timer u_msx_timer (
		.clk			( clk			),
		.reset_n		( reset_n		),
		.bus_ioreq		( bus_ioreq		),
		.bus_address	( bus_address	),
		.bus_write		( bus_write		),
		.bus_valid		( bus_valid		),
		.bus_ready		( bus_ready		),
		.bus_wdata		( bus_wdata		),
		.bus_rdata		( bus_rdata		),
		.bus_rdata_en	( bus_rdata_en	),
		.intr_n			( intr_n		)
	);
	
	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	always @( posedge clk ) begin
		ff_counter <= ff_counter + 1;
	end

	// --------------------------------------------------------------------
	//	Task
	// --------------------------------------------------------------------
	task write_io(
		input	[7:0]	address,
		input	[7:0]	value,
		output			time_out
	);
		int		counter;

		bus_ioreq		<= 1'b1;
		bus_address		<= address;
		bus_wdata		<= value;
		bus_write		<= 1'b1;
		bus_valid		<= 1'b1;
		counter			= 0;
		time_out		= 1'b0;

		while( ~bus_ready ) begin
			counter		<= counter + 1;
			if( counter > 100 ) begin
				time_out	<= 1'b1;
				break;
			end
			@( posedge clk );
		end
		@( posedge clk );

		bus_ioreq		<= 1'b0;
		bus_address		<= 8'd0;
		bus_wdata		<= 8'd0;
		bus_write		<= 1'b0;
		bus_valid		<= 1'b0;
		@( posedge clk );
	endtask

	// --------------------------------------------------------------------
	task read_io(
		input	[7:0]	address,
		output	[7:0]	value,
		output			time_out
	);
		int		counter1;
		int		counter2;
	
		bus_ioreq		<= 1'b1;
		bus_address		<= address;
		bus_wdata		<= 8'd0;
		bus_write		<= 1'b0;
		bus_valid		<= 1'b1;
		counter1		= 0;
		counter2		= 0;
		time_out		= 1'b0;

		fork
			begin
				while( !bus_ready ) begin
					counter1		<= counter1 + 1;
					if( counter1 > 100 ) begin
						time_out	<= 1'b1;
						break;
					end
					@( posedge clk );
				end
				@( posedge clk );
				bus_valid		<= 1'b0;
			end
			begin
				while( !bus_rdata_en ) begin
					counter2		<= counter2 + 1;
					if( counter2 > 100 ) begin
						time_out	<= 1'b1;
						break;
					end
					@( posedge clk );
				end
				value			<= bus_rdata;
			end
		join

		bus_ioreq		<= 1'b0;
		bus_address		<= 8'd0;
		bus_wdata		<= 8'd0;
		bus_write		<= 1'b0;
		@( posedge clk );
	endtask

	// --------------------------------------------------------------------
	//	Test pattern
	// --------------------------------------------------------------------
	task test_pattern0(
		input	[1:0]	core_number
	);
		logic	[7:0]	data;
		logic			time_out;
		logic	[32:0]	start_time;
		logic	[32:0]	end_time;
		logic	[32:0]	count_time;
		logic	[32:0]	low_limit;
		logic	[32:0]	high_limit;

		$display( "******************************************************" );
		$display( "* Core%1d                                              *", core_number );
		$display( "******************************************************" );

		// ---------------------------------------------------------
		//	リセット直後の各レジスタの値をチェック
		// ---------------------------------------------------------
		test_no=1;
		$display( "Check MODE Register is 0 (test_no=1)" );
		write_io( 8'hB0, { 4'd0, core_number, 2'd0 }, time_out );
		assert( time_out == 1'b0 );
		read_io( 8'hB1, data, time_out );
		assert( time_out == 1'b0 );
		assert( data == 8'd0 );

		test_no=2;
		$display( "Check COUNT Register is 0 (test_no=2)" );
		write_io( 8'hB0, { 4'd0, core_number, 2'd1 }, time_out );
		assert( time_out == 1'b0 );
		read_io( 8'hB1, data, time_out );
		assert( time_out == 1'b0 );
		assert( data == 8'd0 );

		test_no=3;
		$display( "Check CONTROL Register is 0 (test_no=3)" );
		write_io( 8'hB0, { 4'd0, core_number, 2'd2 }, time_out );
		assert( time_out == 1'b0 );
		read_io( 8'hB1, data, time_out );
		assert( time_out == 1'b0 );
		assert( data == 8'd0 );

		// ---------------------------------------------------------
		//	ワンショットのカウンター動作
		// ---------------------------------------------------------
		test_no=4;
		$display( "Run one shot counter without interrupt (test_no=4)" );
		//	MODE
		write_io( 8'hB0, { 4'd0, core_number, 2'd0 }, time_out );
		assert( time_out == 1'b0 );
		//	[IE][RESO][RESO][RESO][RSV][RSV][RSV][MODE]
		write_io( 8'hB1, 8'h00, time_out );
		assert( time_out == 1'b0 );
		//	COUNT
		write_io( 8'hB0, { 4'd0, core_number, 2'd1 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd10, time_out );
		assert( time_out == 1'b0 );
		//	CONTROL
		write_io( 8'hB0, { 4'd0, core_number, 2'd2 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd3, time_out );
		assert( time_out == 1'b0 );
		forever begin
			read_io( 8'hB2, data, time_out );
			assert( time_out == 1'b0 );
			assert( data[7:4] == 4'd0 );
			if( data[core_number] ) begin
				break;
			end
		end
		//	IE=0 なので割り込みはあがらない
		assert( intr_n == 1'b1 );
		//	カウント値が停止していることを確認
		write_io( 8'hB3, { 6'd0, core_number }, time_out );
		assert( time_out == 1'b0 );
		read_io( 8'hB3, data, time_out );
		assert( time_out == 1'b0 );
		assert( data == 8'd10 );
		//	タイマー停止
		write_io( 8'hB0, { 4'd0, core_number, 2'd2 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd2, time_out );
		assert( time_out == 1'b0 );
		//	要因クリア
		write_io( 8'hB2, 1 << core_number, time_out );
		assert( time_out == 1'b0 );
		//	要因クリアされていることを確認
		read_io( 8'hB2, data, time_out );
		assert( time_out == 1'b0 );
		assert( data[core_number] == 1'b0 );
		//	要因クリア後にも割り込みはあがらない
		assert( intr_n == 1'b1 );

		// ---------------------------------------------------------
		//	ワンショットのタイマー割込み動作
		// ---------------------------------------------------------
		test_no=5;
		$display( "Run one shot counter with interrupt (test_no=5)" );
		//	MODE
		write_io( 8'hB0, { 4'd0, core_number, 2'd0 }, time_out );
		assert( time_out == 1'b0 );
		//	[IE][RESO][RESO][RESO][RSV][RSV][RSV][MODE]
		write_io( 8'hB1, 8'h80, time_out );
		assert( time_out == 1'b0 );
		//	COUNT
		write_io( 8'hB0, { 4'd0, core_number, 2'd1 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd10, time_out );
		assert( time_out == 1'b0 );
		//	CONTROL
		write_io( 8'hB0, { 4'd0, core_number, 2'd2 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd3, time_out );
		assert( time_out == 1'b0 );
		forever begin
			read_io( 8'hB2, data, time_out );
			assert( time_out == 1'b0 );
			assert( data[7:4] == 4'd0 );
			if( data[core_number] ) begin
				break;
			end
		end
		//	IE=1 なので割り込みがあがる
		assert( intr_n == 1'b0 );
		//	カウント値が停止していることを確認
		write_io( 8'hB3, { 6'd0, core_number }, time_out );
		assert( time_out == 1'b0 );
		read_io( 8'hB3, data, time_out );
		assert( time_out == 1'b0 );
		assert( data == 8'd10 );
		//	タイマー停止
		write_io( 8'hB0, { 4'd0, core_number, 2'd2 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd2, time_out );
		assert( time_out == 1'b0 );
		//	要因クリア
		write_io( 8'hB2, 1 << core_number, time_out );
		assert( time_out == 1'b0 );
		//	要因クリアされていることを確認
		read_io( 8'hB2, data, time_out );
		assert( time_out == 1'b0 );
		assert( data[core_number] == 1'b0 );
		//	要因クリア後に割り込に信号もクリアされていることを確認
		assert( intr_n == 1'b1 );

		// ---------------------------------------------------------
		//	リピートのカウンター動作
		// ---------------------------------------------------------
		test_no=6;
		$display( "Run repeat counter without interrupt (test_no=6)" );
		//	MODE
		write_io( 8'hB0, { 4'd0, core_number, 2'd0 }, time_out );
		assert( time_out == 1'b0 );
		//	[IE][RESO][RESO][RESO][RSV][RSV][RSV][MODE]
		write_io( 8'hB1, 8'h01, time_out );
		assert( time_out == 1'b0 );
		//	COUNT
		write_io( 8'hB0, { 4'd0, core_number, 2'd1 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd10, time_out );
		assert( time_out == 1'b0 );
		//	CONTROL
		write_io( 8'hB0, { 4'd0, core_number, 2'd2 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd3, time_out );
		assert( time_out == 1'b0 );
		for( i = 0; i < 5; i++ ) begin
			$display( "  count end #%1d", i + 1 );
			forever begin
				read_io( 8'hB2, data, time_out );
				assert( time_out == 1'b0 );
				assert( data[7:4] == 4'd0 );
				if( data[core_number] ) begin
					break;
				end
			end
			//	IE=0 なので割り込みはあがらない
			assert( intr_n == 1'b1 );
			//	要因クリア
			write_io( 8'hB2, 1 << core_number, time_out );
			assert( time_out == 1'b0 );
		end
		//	タイマー停止
		write_io( 8'hB0, { 4'd0, core_number, 2'd2 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd2, time_out );
		assert( time_out == 1'b0 );
		//	要因クリア
		write_io( 8'hB2, 1 << core_number, time_out );
		assert( time_out == 1'b0 );
		//	要因クリアされていることを確認
		read_io( 8'hB2, data, time_out );
		assert( time_out == 1'b0 );
		assert( data[core_number] == 1'b0 );
		//	要因クリア後にも割り込みはあがらない
		assert( intr_n == 1'b1 );

		// ---------------------------------------------------------
		//	リピートのタイマー割込み動作
		// ---------------------------------------------------------
		test_no=7;
		$display( "Run repeat counter with interrupt (test_no=7)" );
		//	MODE
		write_io( 8'hB0, { 4'd0, core_number, 2'd0 }, time_out );
		assert( time_out == 1'b0 );
		//	[IE][RESO][RESO][RESO][RSV][RSV][RSV][MODE]
		write_io( 8'hB1, 8'h81, time_out );
		assert( time_out == 1'b0 );
		//	COUNT
		write_io( 8'hB0, { 4'd0, core_number, 2'd1 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd10, time_out );
		assert( time_out == 1'b0 );
		//	CONTROL
		write_io( 8'hB0, { 4'd0, core_number, 2'd2 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd3, time_out );
		assert( time_out == 1'b0 );
		for( i = 0; i < 5; i++ ) begin
			$display( "  count end #%1d", i + 1 );
			forever begin
				read_io( 8'hB2, data, time_out );
				assert( time_out == 1'b0 );
				assert( data[7:4] == 4'd0 );
				if( data[core_number] ) begin
					break;
				end
			end
			//	IE=1 なので割り込みがあがる
			assert( intr_n == 1'b0 );
			//	要因クリア
			write_io( 8'hB2, 1 << core_number, time_out );
			assert( time_out == 1'b0 );
			@( posedge clk );
			@( posedge clk );
			//	割り込みがクリアされていることを確認
			assert( intr_n == 1'b1 );
		end
		//	タイマー停止
		write_io( 8'hB0, { 4'd0, core_number, 2'd2 }, time_out );
		assert( time_out == 1'b0 );
		write_io( 8'hB1, 8'd2, time_out );
		assert( time_out == 1'b0 );
		//	要因クリア
		write_io( 8'hB2, 1 << core_number, time_out );
		assert( time_out == 1'b0 );
		//	要因クリアされていることを確認
		read_io( 8'hB2, data, time_out );
		assert( time_out == 1'b0 );
		assert( data[core_number] == 1'b0 );
		//	要因クリア後に割り込に信号もクリアされていることを確認
		assert( intr_n == 1'b1 );

		// ---------------------------------------------------------
		//	ワンショットのカウンター動作による reso振り
		// ---------------------------------------------------------
		test_no=8;
		if( core_number == 0 ) begin
			j = 7;
		end
		else begin
			j = 4;
		end
		for( i = 0; i < j; i++ ) begin
			$display( "Reso = %1d (test_no=8)", i );
			//	MODE
			write_io( 8'hB0, { 4'd0, core_number, 2'd0 }, time_out );
			assert( time_out == 1'b0 );
			//	[IE][RESO][RESO][RESO][RSV][RSV][RSV][MODE]
			write_io( 8'hB1, i << 4, time_out );
			assert( time_out == 1'b0 );
			//	COUNT
			write_io( 8'hB0, { 4'd0, core_number, 2'd1 }, time_out );
			assert( time_out == 1'b0 );
			write_io( 8'hB1, 8'd5, time_out );
			assert( time_out == 1'b0 );
			//	CONTROL
			write_io( 8'hB0, { 4'd0, core_number, 2'd2 }, time_out );
			assert( time_out == 1'b0 );
			write_io( 8'hB1, 8'd3, time_out );
			assert( time_out == 1'b0 );
			start_time = ff_counter;
			forever begin
				read_io( 8'hB2, data, time_out );
				assert( time_out == 1'b0 );
				assert( data[7:4] == 4'd0 );
				if( data[core_number] ) begin
					break;
				end
			end
			//	IE=0 なので割り込みはあがらない
			assert( intr_n == 1'b1 );
			end_time = ff_counter;
			//	カウント値が停止していることを確認
			write_io( 8'hB3, { 6'd0, core_number }, time_out );
			assert( time_out == 1'b0 );
			read_io( 8'hB3, data, time_out );
			assert( time_out == 1'b0 );
			assert( data == 8'd5 );
			//	タイマー停止
			write_io( 8'hB0, { 4'd0, core_number, 2'd2 }, time_out );
			assert( time_out == 1'b0 );
			write_io( 8'hB1, 8'd2, time_out );
			assert( time_out == 1'b0 );
			//	要因クリア
			write_io( 8'hB2, 1 << core_number, time_out );
			assert( time_out == 1'b0 );
			//	要因クリアされていることを確認
			read_io( 8'hB2, data, time_out );
			assert( time_out == 1'b0 );
			assert( data[core_number] == 1'b0 );
			//	要因クリア後にも割り込みはあがらない
			assert( intr_n == 1'b1 );
			//	経過時間を確認
			count_time	= end_time - start_time;
			low_limit	= (5 << (i * 2 + 10));
			high_limit	= (6 << (i * 2 + 10)) + 10;
			$display( "  count time: %d (%d, %d)", count_time, low_limit, high_limit );
			assert( count_time >= low_limit );
			assert( count_time <= high_limit );
		end
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		logic			time_out;
		logic	[7:0]	data;

		test_no			= -1;
		reset_n			= 0;
		clk				= 1;
		bus_ioreq		= 0;
		bus_address		= 0;
		bus_write		= 0;
		bus_valid		= 0;
		bus_wdata		= 0;

		@( negedge clk );
		@( negedge clk );
		@( posedge clk );

		reset_n			= 1;
		@( posedge clk );

		// ---------------------------------------------------------
		//	余計なポートには反応しない
		// ---------------------------------------------------------
		$display( "******************************************************" );
		$display( "* Common test                                        *" );
		$display( "******************************************************" );
		$display( "Check ignore another port access (test_no=0)" );
		test_no = 0;
		for( i = 0; i < 8'hB0; i++ ) begin
			read_io( i, data, time_out );
			assert( data == 8'hFF );
			assert( time_out == 1'b1 );
			@( posedge clk );
		end

		for( i = 8'hB4; i <= 8'hFF; i++ ) begin
			read_io( i, data, time_out );
			assert( data == 8'hFF );
			assert( time_out == 1'b1 );
			@( posedge clk );
		end

		for( i = 0; i < 8'hB0; i++ ) begin
			write_io( i, $random & 255, time_out );
			@( posedge clk );
		end

		for( i = 8'hB4; i <= 8'hFF; i++ ) begin
			write_io( i, $random & 255, time_out );
			@( posedge clk );
		end

		test_pattern0( 0 );
		test_pattern0( 1 );
		test_pattern0( 2 );
		test_pattern0( 3 );

		repeat( 100 ) @( posedge clk );
		$finish;
	end
endmodule
