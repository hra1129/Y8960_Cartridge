// -----------------------------------------------------------------------------
//	Test of sfrom.v
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
//		Serial FlashROM Controller Test
// -----------------------------------------------------------------------------

module tb ();
	localparam	clk_258m_base	= 1_000_000_000/257.72724;	//	ps
	localparam	clk_base		= 1_000_000_000/28.63636;	//	ps

	// Command definitions
	localparam	CMD_READ			= 2'd0;
	localparam	CMD_WRITE			= 2'd1;
	localparam	CMD_SECTOR_ERASE	= 2'd2;
	localparam	CMD_ALL_ERASE		= 2'd3;

	int				test_no;
	int				error_count;
	int				i, j;
	reg				clk;
	reg				clk_258m;		//	257.72724MHz
	reg				reset_n;
	reg		[22:0]	address;		//	8MB
	reg				valid;
	wire			ready;
	reg		[1:0]	command;
	reg		[7:0]	wdata;
	wire	[7:0]	rdata;
	wire			rdata_en;
	wire			flash_spi_clk;
	wire			flash_spi_cs_n;
	wire	[3:0]	flash_spi_io;

	// SPI Flash mock signals
	reg		[7:0]	spi_shift_in;
	reg		[7:0]	spi_shift_out;
	reg		[2:0]	spi_bit_cnt;
	reg		[7:0]	spi_cmd;
	reg		[23:0]	spi_addr;
	reg		[2:0]	spi_state;
	reg		[7:0]	flash_memory[0:255];	// Simple 256 byte memory for test
	reg				spi_miso_reg;

	// SPI Flash mock state
	localparam	SPI_ST_CMD			= 3'd0;
	localparam	SPI_ST_ADDR2		= 3'd1;
	localparam	SPI_ST_ADDR1		= 3'd2;
	localparam	SPI_ST_ADDR0		= 3'd3;
	localparam	SPI_ST_DATA			= 3'd4;
	localparam	SPI_ST_STATUS		= 3'd5;
	localparam	SPI_ST_QUAD_ADDR	= 3'd6;		// Quad I/O address phase
	localparam	SPI_ST_QUAD_DUMMY	= 3'd7;		// Quad I/O dummy cycles

	// SPI I/O connections
	wire	spi_mosi = flash_spi_io[0];
	reg		spi_quad_output;			// Quad mode output enable
	reg	[3:0]	spi_io_out;				// Quad output data
	reg	[2:0]	spi_quad_cnt;			// Quad nibble counter
	reg	[3:0]	spi_dummy_cnt;			// Dummy cycle counter
	reg		spi_quad_input_mode;		// Hi-Z during Quad address/mode/dummy receive
	
	assign	flash_spi_io[0] = spi_quad_output ? spi_io_out[0] : 1'bz;
	assign	flash_spi_io[1] = spi_quad_output ? spi_io_out[1] : (spi_quad_input_mode ? 1'bz : spi_miso_reg);
	assign	flash_spi_io[2] = spi_quad_output ? spi_io_out[2] : 1'bz;
	assign	flash_spi_io[3] = spi_quad_output ? spi_io_out[3] : 1'bz;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	sfrom u_sfrom (
		.clk					( clk					),
		.clk_258m				( clk_258m				),
		.reset_n				( reset_n				),
		.address				( address				),
		.valid					( valid					),
		.ready					( ready					),
		.command				( command				),
		.wdata					( wdata					),
		.rdata					( rdata					),
		.rdata_en				( rdata_en				),
		.burst_start			( 1'b0					),
		.burst_address			( 23'd0					),
		.burst_length			( 17'd0					),
		.burst_rdata			(						),
		.burst_rdata_en			(						),
		.burst_active			(						),
		.flash_spi_clk			( flash_spi_clk			),
		.flash_spi_cs_n			( flash_spi_cs_n		),
		.flash_spi_io			( flash_spi_io			)
	);

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_258m_base/2) begin
		clk_258m <= ~clk_258m;
	end

	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	SPI Flash Mock Model
	// --------------------------------------------------------------------
	// Simple SPI Flash behavioral model
	reg		spi_wip;			// Write In Progress flag
	reg		spi_wel;			// Write Enable Latch
	int		wip_counter;

	// CS# edge detection
	reg		prev_cs_n;
	always @(posedge clk_258m) begin
		prev_cs_n <= flash_spi_cs_n;
	end

	wire	cs_falling = prev_cs_n && !flash_spi_cs_n;
	wire	cs_rising = !prev_cs_n && flash_spi_cs_n;

	// SPI clock edge detection (directly from SPI clock, not clk_258m)
	reg		prev_spi_clk;
	always @(posedge clk_258m) begin
		prev_spi_clk <= flash_spi_clk;
	end

	wire	spi_clk_rising = !prev_spi_clk && flash_spi_clk;
	wire	spi_clk_falling = prev_spi_clk && !flash_spi_clk;

	// WIP counter (simulate write/erase delay)
	always @(posedge clk_258m or negedge reset_n) begin
		if(!reset_n) begin
			wip_counter <= 0;
			spi_wip <= 1'b0;
		end
		else if(wip_counter > 0) begin
			wip_counter <= wip_counter - 1;
			if(wip_counter == 1) begin
				spi_wip <= 1'b0;
			end
		end
	end

	// Flag to track when read data is ready to output
	reg		read_data_ready;

	// SPI Flash state machine - directly driven by SPI clock edges
	always @(posedge clk_258m or negedge reset_n) begin
		if(!reset_n) begin
			spi_state <= SPI_ST_CMD;
			spi_bit_cnt <= 3'd7;
			spi_shift_in <= 8'd0;
			spi_shift_out <= 8'd0;
			spi_cmd <= 8'd0;
			spi_addr <= 24'd0;
			spi_miso_reg <= 1'b1;
			spi_wel <= 1'b0;
			read_data_ready <= 1'b0;
			spi_quad_output <= 1'b0;
			spi_io_out <= 4'hF;
			spi_quad_cnt <= 3'd0;
			spi_dummy_cnt <= 4'd0;
			spi_quad_input_mode <= 1'b0;
		end
		else if(flash_spi_cs_n) begin
			// CS# high - reset state
			spi_state <= SPI_ST_CMD;
			spi_bit_cnt <= 3'd7;
			spi_miso_reg <= 1'b1;
			read_data_ready <= 1'b0;
			spi_quad_output <= 1'b0;
			spi_io_out <= 4'hF;
			spi_quad_input_mode <= 1'b0;
		end
		else begin
			// CS# low - active
			
			// On rising edge: sample MOSI (or all IO in Quad mode)
			if(spi_clk_rising) begin
				// Quad mode states - process every clock
				if(spi_state == SPI_ST_QUAD_ADDR) begin
					// Receive 4 bits of address per clock
					spi_addr <= {spi_addr[19:0], flash_spi_io};
					if(spi_quad_cnt == 3'd0) begin
						// Address complete, now receive mode byte (2 nibbles)
						spi_quad_cnt <= 3'd1;	// 2 nibbles for mode byte
						spi_state <= SPI_ST_QUAD_DUMMY;
						spi_dummy_cnt <= 4'd0;
					end
					else begin
						spi_quad_cnt <= spi_quad_cnt - 3'd1;
					end
				end
				else if(spi_state == SPI_ST_QUAD_DUMMY) begin
					// Mode byte and dummy cycles
					if(spi_quad_cnt > 3'd0) begin
						// Still receiving mode byte
						spi_quad_cnt <= spi_quad_cnt - 3'd1;
						if(spi_quad_cnt == 3'd1) begin
							// Mode byte complete, start dummy cycles
							spi_dummy_cnt <= 4'd4;	// 4 dummy clocks
						end
					end
					else if(spi_dummy_cnt > 4'd0) begin
						spi_dummy_cnt <= spi_dummy_cnt - 4'd1;
					end
				end
				else begin
					// Single SPI mode - bit-by-bit processing
					spi_shift_in <= {spi_shift_in[6:0], spi_mosi};

					if(spi_bit_cnt == 3'd0) begin
						// Byte complete
						case(spi_state)
							SPI_ST_CMD: begin
								spi_cmd <= {spi_shift_in[6:0], spi_mosi};
								$display("[MOCK] Received command: %02Xh", {spi_shift_in[6:0], spi_mosi});
								case({spi_shift_in[6:0], spi_mosi})
									8'h06: begin	// Write Enable
										spi_wel <= 1'b1;
									end
									8'h04: begin	// Write Disable
										spi_wel <= 1'b0;
									end
									8'h03: begin	// Read
										spi_state <= SPI_ST_ADDR2;
									end
									8'hEB: begin	// Quad I/O Read
										spi_state <= SPI_ST_QUAD_ADDR;
										spi_quad_cnt <= 3'd5;	// 6 nibbles for 24-bit addr
										spi_quad_input_mode <= 1'b1;	// Hi-Z MISO during Quad input
									end
									8'h02: begin	// Page Program
										spi_state <= SPI_ST_ADDR2;
									end
									8'h20: begin	// Sector Erase
										spi_state <= SPI_ST_ADDR2;
									end
									8'hC7: begin	// Chip Erase
										if(spi_wel) begin
											// Erase all memory
											for(int k = 0; k < 256; k++) begin
												flash_memory[k] <= 8'hFF;
											end
											spi_wip <= 1'b1;
											wip_counter <= 100;	// Short delay for simulation
											spi_wel <= 1'b0;
										end
									end
									8'h05: begin	// Read Status
										spi_state <= SPI_ST_STATUS;
										spi_shift_out <= {6'b0, spi_wel, spi_wip};
									end
								endcase
								spi_bit_cnt <= 3'd7;
							end

							SPI_ST_ADDR2: begin
								spi_addr[23:16] <= {spi_shift_in[6:0], spi_mosi};
								spi_state <= SPI_ST_ADDR1;
								spi_bit_cnt <= 3'd7;
							end

							SPI_ST_ADDR1: begin
								spi_addr[15:8] <= {spi_shift_in[6:0], spi_mosi};
								spi_state <= SPI_ST_ADDR0;
								spi_bit_cnt <= 3'd7;
							end

							SPI_ST_ADDR0: begin
								spi_addr[7:0] <= {spi_shift_in[6:0], spi_mosi};
								spi_state <= SPI_ST_DATA;
								spi_bit_cnt <= 3'd7;

								// Prepare data for read - load from memory
								if(spi_cmd == 8'h03) begin
									spi_shift_out <= flash_memory[{spi_shift_in[6:0], spi_mosi}];
									read_data_ready <= 1'b1;	// Mark data ready for next falling edge
								end

								// Sector erase
								if(spi_cmd == 8'h20 && spi_wel) begin
									for(int k = 0; k < 256; k++) begin
										flash_memory[k] <= 8'hFF;
									end
									spi_wip <= 1'b1;
									wip_counter <= 50;
									spi_wel <= 1'b0;
								end
							end

							SPI_ST_DATA: begin
								if(spi_cmd == 8'h02 && spi_wel) begin
									// Page Program - write data
									flash_memory[spi_addr[7:0]] <= {spi_shift_in[6:0], spi_mosi};
									spi_wip <= 1'b1;
									wip_counter <= 20;
									spi_wel <= 1'b0;
								end
								spi_bit_cnt <= 3'd7;
							end

							SPI_ST_STATUS: begin
								// Continue reading status
								spi_shift_out <= {6'b0, spi_wel, spi_wip};
								spi_bit_cnt <= 3'd7;
							end
						endcase
					end
					else begin
						spi_bit_cnt <= spi_bit_cnt - 3'd1;
					end
				end
			end

			// On falling edge: output MISO / Quad data
			if(spi_clk_falling) begin
				// Start Quad data output when dummy cycles complete
				if(spi_state == SPI_ST_QUAD_DUMMY && spi_quad_cnt == 3'd0 && spi_dummy_cnt == 4'd0) begin
					// Dummy cycles complete, prepare data for read
					$display("[MOCK] Quad read addr=%06Xh, data=%02Xh", spi_addr, flash_memory[spi_addr[7:0]]);
					spi_shift_out <= flash_memory[spi_addr[7:0]];
					spi_state <= SPI_ST_DATA;
					spi_quad_output <= 1'b1;
					spi_quad_input_mode <= 1'b0;	// End of input phase
					spi_quad_cnt <= 3'd2;	// High nibble hold for 1 clock, then low nibble
					// Output first nibble (high nibble)
					spi_io_out <= flash_memory[spi_addr[7:0]][7:4];
				end
				else if(spi_quad_output && spi_state == SPI_ST_DATA) begin
					// Quad mode data output
					if(spi_quad_cnt == 3'd2) begin
						// Keep high nibble one more falling edge for DUT to sample on rising edge
						spi_quad_cnt <= 3'd1;
					end
					else if(spi_quad_cnt == 3'd1) begin
						// Output low nibble
						spi_io_out <= spi_shift_out[3:0];
						spi_quad_cnt <= 3'd0;
					end
					else if(spi_quad_cnt == 3'd0) begin
						// Low nibble already output, keep it one more clock for DUT to sample
						spi_quad_cnt <= 3'd7;	// Use 7 as "done" marker
					end
					else if(spi_quad_cnt == 3'd7) begin
						// Now we can turn off output
						spi_quad_output <= 1'b0;
					end
				end
				else if(read_data_ready || (spi_state == SPI_ST_DATA && spi_cmd == 8'h03)) begin
					// Read data: output MSB and shift
					spi_miso_reg <= spi_shift_out[7];
					spi_shift_out <= {spi_shift_out[6:0], 1'b0};
					read_data_ready <= 1'b0;
				end
				else if(spi_state == SPI_ST_STATUS) begin
					spi_miso_reg <= spi_shift_out[7];
					spi_shift_out <= {spi_shift_out[6:0], 1'b0};
				end
				else begin
					spi_miso_reg <= 1'b1;
				end
			end
		end
	end

	// --------------------------------------------------------------------
	//	Task: Wait for ready
	// --------------------------------------------------------------------
	task wait_ready();
		int cnt;
		cnt = 0;
		while(!ready) begin
			@(posedge clk);
			cnt++;
			if(cnt % 100 == 0) begin
				$display("[DEBUG wait_ready] cnt=%0d, ready=%b, DUT state=%0d", cnt, ready, u_sfrom.ff_state);
			end
		end
	endtask

	// --------------------------------------------------------------------
	//	Task: Issue read command
	// --------------------------------------------------------------------
	task issue_read(input [22:0] addr);
		$display("[DEBUG] issue_read called, addr=%06Xh", addr);
		wait_ready();
		$display("[DEBUG] issue_read: wait_ready done");
		@(posedge clk);
		address <= addr;
		command <= CMD_READ;
		valid <= 1'b1;
		@(posedge clk);
		valid <= 1'b0;
		$display("[DEBUG] issue_read: valid pulse sent");
	endtask

	// --------------------------------------------------------------------
	//	Task: Issue write command
	// --------------------------------------------------------------------
	task issue_write(input [22:0] addr, input [7:0] data);
		wait_ready();
		@(posedge clk);
		address <= addr;
		command <= CMD_WRITE;
		wdata <= data;
		valid <= 1'b1;
		@(posedge clk);
		valid <= 1'b0;
	endtask

	// --------------------------------------------------------------------
	//	Task: Issue sector erase command
	// --------------------------------------------------------------------
	task issue_sector_erase(input [22:0] addr);
		wait_ready();
		@(posedge clk);
		address <= addr;
		command <= CMD_SECTOR_ERASE;
		valid <= 1'b1;
		@(posedge clk);
		valid <= 1'b0;
	endtask

	// --------------------------------------------------------------------
	//	Task: Issue chip erase command
	// --------------------------------------------------------------------
	task issue_chip_erase();
		wait_ready();
		@(posedge clk);
		command <= CMD_ALL_ERASE;
		valid <= 1'b1;
		@(posedge clk);
		valid <= 1'b0;
	endtask

	// --------------------------------------------------------------------
	//	Debug monitor for DUT state machine
	// --------------------------------------------------------------------
	int dbg_cnt;
	int test_cnt;
	initial begin
		dbg_cnt = 0;
		test_cnt = 0;
	end
	always @(posedge clk_258m) begin
		dbg_cnt <= dbg_cnt + 1;
		// Debug trace disabled for normal testing
		/*
		// Trace state transitions during Test 5 (around cnt 450-520)
		if(dbg_cnt >= 450 && dbg_cnt <= 520) begin
			$display("[TRC5] cnt=%0d, CS=%b, DUT: state=%0d bit=%0d | MOCK: state=%0d qout=%b | io=%b rdata=%02Xh shift=%02Xh",
				dbg_cnt, flash_spi_cs_n, u_sfrom.ff_state, u_sfrom.ff_bit_cnt,
				spi_state, spi_quad_output, flash_spi_io, u_sfrom.ff_rdata_reg, u_sfrom.ff_shift_in);
		end
		*/
	end

	// --------------------------------------------------------------------
	//	Task: Wait for rdata_en and check data
	// --------------------------------------------------------------------
	task wait_and_check_rdata(input [7:0] expected);
		int timeout;
		timeout = 0;
		while(!rdata_en && timeout < 100000) begin
			@(posedge clk);
			timeout++;
			if(timeout % 100 == 0) begin
				$display("[DEBUG] t=%0d, state=%0d, clk_en=%b, spi_clk=%b, spi_clk_d=%b, io=%b, quad_out=%b, bit=%0d, dum=%0d",
					timeout, u_sfrom.ff_state, u_sfrom.ff_spi_clk_en, u_sfrom.ff_spi_clk, u_sfrom.ff_spi_clk_d, flash_spi_io, 
					u_sfrom.ff_io_quad_out, u_sfrom.ff_bit_cnt, u_sfrom.ff_dummy_cnt);
			end
		end

		if(timeout >= 100000) begin
			$display("[ERROR] Test %0d: Timeout waiting for rdata_en", test_no);
			error_count++;
		end
		else if(rdata !== expected) begin
			$display("[ERROR] Test %0d: rdata mismatch. Expected: %02Xh, Got: %02Xh", test_no, expected, rdata);
			error_count++;
		end
		else begin
			$display("[OK] Test %0d: rdata = %02Xh", test_no, rdata);
		end
	endtask

	// --------------------------------------------------------------------
	//	Task: Wait for operation complete (ready goes high)
	// --------------------------------------------------------------------
	task wait_operation_complete();
		int timeout;
		timeout = 0;
		// First wait for ready to go low
		while(ready && timeout < 100) begin
			@(posedge clk);
			timeout++;
		end
		// Then wait for ready to go high
		timeout = 0;
		while(!ready && timeout < 50000) begin
			@(posedge clk);
			timeout++;
		end
		if(timeout >= 50000) begin
			$display("[ERROR] Test %0d: Timeout waiting for operation complete", test_no);
			error_count++;
		end
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		test_no = 0;
		error_count = 0;
		clk = 1;
		clk_258m = 1;
		reset_n = 0;
		address = 0;
		valid = 0;
		command = 0;
		wdata = 0;

		// Initialize flash memory with test pattern
		for(i = 0; i < 256; i++) begin
			flash_memory[i] = i;
		end

		// ================================================================
		//	Reset sequence
		// ================================================================
		$display("========================================");
		$display("Starting Serial FlashROM Controller Test");
		$display("========================================");

		repeat(10) @(posedge clk_258m);
		reset_n = 1;
		repeat(10) @(posedge clk_258m);

		// Wait for ready
		wait_ready();
		$display("[INFO] DUT is ready");

		// ================================================================
		//	Test 1: Read from address 0x00
		// ================================================================
		test_no = 1;
		$display("\n[Test %0d] Read from address 0x000000", test_no);
		issue_read(23'h000000);
		wait_and_check_rdata(8'h00);
		wait_ready();

		// ================================================================
		//	Test 2: Read from address 0x55
		// ================================================================
		test_no = 2;
		$display("\n[Test %0d] Read from address 0x000055", test_no);
		issue_read(23'h000055);
		wait_and_check_rdata(8'h55);
		wait_ready();

		// ================================================================
		//	Test 3: Read from address 0xAA
		// ================================================================
		test_no = 3;
		$display("\n[Test %0d] Read from address 0x0000AA", test_no);
		issue_read(23'h0000AA);
		wait_and_check_rdata(8'hAA);
		wait_ready();

		// ================================================================
		//	Test 4: Write to address 0x10
		// ================================================================
		test_no = 4;
		$display("\n[Test %0d] Write 0x5A to address 0x000010", test_no);
		issue_write(23'h000010, 8'h5A);
		wait_operation_complete();
		$display("[INFO] Write operation complete");

		// ================================================================
		//	Test 5: Read back written data
		// ================================================================
		test_no = 5;
		$display("\n[Test %0d] Read back from address 0x000010", test_no);
		issue_read(23'h000010);
		wait_and_check_rdata(8'h5A);
		wait_ready();

		// ================================================================
		//	Test 6: Write another value
		// ================================================================
		test_no = 6;
		$display("\n[Test %0d] Write 0xA5 to address 0x000020", test_no);
		issue_write(23'h000020, 8'hA5);
		wait_operation_complete();
		$display("[INFO] Write operation complete");

		// ================================================================
		//	Test 7: Read back
		// ================================================================
		test_no = 7;
		$display("\n[Test %0d] Read back from address 0x000020", test_no);
		issue_read(23'h000020);
		wait_and_check_rdata(8'hA5);
		wait_ready();

		// ================================================================
		//	Test 8: Sector Erase
		// ================================================================
		test_no = 8;
		$display("\n[Test %0d] Sector Erase at address 0x000000", test_no);
		issue_sector_erase(23'h000000);
		wait_operation_complete();
		$display("[INFO] Sector erase operation complete");

		// ================================================================
		//	Test 9: Read after erase (should be 0xFF)
		// ================================================================
		test_no = 9;
		$display("\n[Test %0d] Read from address 0x000010 after erase", test_no);
		issue_read(23'h000010);
		wait_and_check_rdata(8'hFF);
		wait_ready();

		// ================================================================
		//	Test 10: Read after erase (should be 0xFF)
		// ================================================================
		test_no = 10;
		$display("\n[Test %0d] Read from address 0x000020 after erase", test_no);
		issue_read(23'h000020);
		wait_and_check_rdata(8'hFF);
		wait_ready();

		// ================================================================
		//	Test Summary
		// ================================================================
		$display("\n========================================");
		$display("Test Complete");
		$display("Total Errors: %0d", error_count);
		if(error_count == 0) begin
			$display("*** ALL TESTS PASSED ***");
		end
		else begin
			$display("*** SOME TESTS FAILED ***");
		end
		$display("========================================\n");

		repeat(100) @(posedge clk);
		$finish;
	end
endmodule
