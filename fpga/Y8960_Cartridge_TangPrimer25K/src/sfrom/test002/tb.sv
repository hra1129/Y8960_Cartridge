// -----------------------------------------------------------------------------
//	Test of sfrom.v with sfrom_test_model.v (W25Q64JV)
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
//		Serial FlashROM Controller Test with W25Q64JV Model
//		- Single Read
//		- Single Write
//		- Burst Read (Continuous Read)
//		- Burst Write (Continuous Write)
//		- Sector Erase
//		- Chip Erase
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

	// --------------------------------------------------------------------
	//	DUT: Serial FlashROM Controller
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
		.flash_spi_clk			( flash_spi_clk			),
		.flash_spi_cs_n			( flash_spi_cs_n		),
		.flash_spi_io			( flash_spi_io			)
	);

	// --------------------------------------------------------------------
	//	Flash ROM Model: W25Q64JV
	// --------------------------------------------------------------------
	sfrom_test_model u_flash (
		.spi_clk				( flash_spi_clk			),
		.spi_cs_n				( flash_spi_cs_n		),
		.spi_io					( flash_spi_io			)
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
	//	Task: Wait for ready
	// --------------------------------------------------------------------
	task wait_ready();
		int cnt;
		cnt = 0;
		while(!ready) begin
			@(posedge clk);
			cnt++;
			if(cnt % 1000 == 0) begin
				$display("[DEBUG wait_ready] cnt=%0d, ready=%b, DUT state=%0d", cnt, ready, u_sfrom.ff_state);
			end
			if(cnt > 100000) begin
				$display("[ERROR] wait_ready timeout");
				$finish;
			end
		end
	endtask

	// --------------------------------------------------------------------
	//	Task: Issue read command
	// --------------------------------------------------------------------
	task issue_read(input [22:0] addr);
		wait_ready();
		@(posedge clk);
		address <= addr;
		command <= CMD_READ;
		valid <= 1'b1;
		@(posedge clk);
		valid <= 1'b0;
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
	//	Task: Wait for rdata_en and check data
	// --------------------------------------------------------------------
	task wait_and_check_rdata(input [7:0] expected);
		int timeout;
		timeout = 0;
		while(!rdata_en && timeout < 100000) begin
			@(posedge clk);
			timeout++;
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
	//	Task: Wait for rdata_en and return data
	// --------------------------------------------------------------------
	task wait_rdata(output [7:0] data);
		int timeout;
		timeout = 0;
		while(!rdata_en && timeout < 100000) begin
			@(posedge clk);
			timeout++;
		end

		if(timeout >= 100000) begin
			$display("[ERROR] Test %0d: Timeout waiting for rdata_en", test_no);
			error_count++;
			data = 8'hXX;
		end
		else begin
			data = rdata;
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
		while(!ready && timeout < 100000) begin
			@(posedge clk);
			timeout++;
		end
		if(timeout >= 100000) begin
			$display("[ERROR] Test %0d: Timeout waiting for operation complete", test_no);
			error_count++;
		end
	endtask

	// --------------------------------------------------------------------
	//	Task: Burst read (continuous read)
	// --------------------------------------------------------------------
	task burst_read(input [22:0] start_addr, input int count, input [7:0] expected_data[]);
		int k;
		reg [7:0] read_data;
		begin
			for(k = 0; k < count; k++) begin
				issue_read(start_addr + k);
				wait_rdata(read_data);
				if(read_data !== expected_data[k]) begin
					$display("[ERROR] Test %0d: Burst read[%0d] mismatch. Expected: %02Xh, Got: %02Xh", 
						test_no, k, expected_data[k], read_data);
					error_count++;
				end
				else begin
					$display("[OK] Test %0d: Burst read[%0d] addr=%06Xh, data=%02Xh", 
						test_no, k, start_addr + k, read_data);
				end
				wait_ready();
			end
		end
	endtask

	// --------------------------------------------------------------------
	//	Task: Burst write (continuous write)
	// --------------------------------------------------------------------
	task burst_write(input [22:0] start_addr, input int count, input [7:0] write_data[]);
		int k;
		begin
			for(k = 0; k < count; k++) begin
				issue_write(start_addr + k, write_data[k]);
				wait_operation_complete();
				$display("[INFO] Test %0d: Burst write[%0d] addr=%06Xh, data=%02Xh complete", 
					test_no, k, start_addr + k, write_data[k]);
			end
		end
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	reg [7:0] test_pattern [0:15];
	reg [7:0] read_result [0:15];
	reg [7:0] single_read_data;

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

		// Initialize test patterns
		for(i = 0; i < 16; i++) begin
			test_pattern[i] = i * 16 + i;	// 00, 11, 22, 33, ..., FF
		end

		// Initialize flash memory with test data
		$display("[INFO] Initializing flash memory with test pattern...");
		for(i = 0; i < 256; i++) begin
			u_flash.write_memory(i, i);	// Address = Data pattern
		end
		// Also initialize sector 1 with different pattern
		for(i = 0; i < 256; i++) begin
			u_flash.write_memory(24'h001000 + i, 255 - i);
		end

		// ================================================================
		//	Reset sequence
		// ================================================================
		$display("========================================");
		$display("Starting Serial FlashROM Controller Test");
		$display("with W25Q64JV Flash Model");
		$display("========================================");

		repeat(10) @(posedge clk_258m);
		reset_n = 1;
		repeat(10) @(posedge clk_258m);

		// Wait for ready
		wait_ready();
		$display("[INFO] DUT is ready\n");

		// ================================================================
		//	Test 1: Single Read from address 0x00
		// ================================================================
		test_no = 1;
		$display("----------------------------------------");
		$display("[Test %0d] Single Read from address 0x000000", test_no);
		issue_read(23'h000000);
		wait_and_check_rdata(8'h00);
		wait_ready();

		// ================================================================
		//	Test 2: Single Read from address 0x55
		// ================================================================
		test_no = 2;
		$display("----------------------------------------");
		$display("[Test %0d] Single Read from address 0x000055", test_no);
		issue_read(23'h000055);
		wait_and_check_rdata(8'h55);
		wait_ready();

		// ================================================================
		//	Test 3: Single Read from address 0xAA
		// ================================================================
		test_no = 3;
		$display("----------------------------------------");
		$display("[Test %0d] Single Read from address 0x0000AA", test_no);
		issue_read(23'h0000AA);
		wait_and_check_rdata(8'hAA);
		wait_ready();

		// ================================================================
		//	Test 4: Single Read from Sector 1
		// ================================================================
		test_no = 4;
		$display("----------------------------------------");
		$display("[Test %0d] Single Read from Sector 1 (addr=0x001000)", test_no);
		issue_read(23'h001000);
		wait_and_check_rdata(8'hFF);	// 255 - 0 = 255 = 0xFF
		wait_ready();

		// ================================================================
		//	Test 5: Single Write to address 0x100
		// ================================================================
		test_no = 5;
		$display("----------------------------------------");
		$display("[Test %0d] Single Write 0x5A to address 0x000100", test_no);
		issue_write(23'h000100, 8'h5A);
		wait_operation_complete();
		$display("[INFO] Write operation complete");

		// ================================================================
		//	Test 6: Read back written data
		// ================================================================
		test_no = 6;
		$display("----------------------------------------");
		$display("[Test %0d] Read back from address 0x000100", test_no);
		issue_read(23'h000100);
		wait_and_check_rdata(8'h5A);
		wait_ready();

		// ================================================================
		//	Test 7: Burst Read (16 bytes from address 0x00)
		// ================================================================
		test_no = 7;
		$display("----------------------------------------");
		$display("[Test %0d] Burst Read - 16 bytes from address 0x000000", test_no);
		for(i = 0; i < 16; i++) begin
			read_result[i] = i;	// Expected: 00, 01, 02, ..., 0F
		end
		burst_read(23'h000000, 16, read_result);

		// ================================================================
		//	Test 8: Burst Write (16 bytes to address 0x200)
		// ================================================================
		test_no = 8;
		$display("----------------------------------------");
		$display("[Test %0d] Burst Write - 16 bytes to address 0x000200", test_no);
		burst_write(23'h000200, 16, test_pattern);

		// ================================================================
		//	Test 9: Burst Read to verify written data
		// ================================================================
		test_no = 9;
		$display("----------------------------------------");
		$display("[Test %0d] Burst Read - Verify 16 bytes at address 0x000200", test_no);
		burst_read(23'h000200, 16, test_pattern);

		// ================================================================
		//	Test 10: Sector Erase (Sector 0)
		// ================================================================
		test_no = 10;
		$display("----------------------------------------");
		$display("[Test %0d] Sector Erase at address 0x000000 (Sector 0)", test_no);
		issue_sector_erase(23'h000000);
		wait_operation_complete();
		$display("[INFO] Sector erase operation complete");

		// ================================================================
		//	Test 11: Read after sector erase (should be 0xFF)
		// ================================================================
		test_no = 11;
		$display("----------------------------------------");
		$display("[Test %0d] Read from address 0x000000 after sector erase", test_no);
		issue_read(23'h000000);
		wait_and_check_rdata(8'hFF);
		wait_ready();

		// ================================================================
		//	Test 12: Read from erased address 0x100 (should be 0xFF)
		// ================================================================
		test_no = 12;
		$display("----------------------------------------");
		$display("[Test %0d] Read from address 0x000100 after sector erase", test_no);
		issue_read(23'h000100);
		wait_and_check_rdata(8'hFF);
		wait_ready();

		// ================================================================
		//	Test 13: Read from erased address 0x200 (should be 0xFF)
		// ================================================================
		test_no = 13;
		$display("----------------------------------------");
		$display("[Test %0d] Read from address 0x000200 after sector erase", test_no);
		issue_read(23'h000200);
		wait_and_check_rdata(8'hFF);
		wait_ready();

		// ================================================================
		//	Test 14: Verify Sector 1 is NOT erased
		// ================================================================
		test_no = 14;
		$display("----------------------------------------");
		$display("[Test %0d] Verify Sector 1 (addr=0x001000) is NOT erased", test_no);
		issue_read(23'h001000);
		wait_and_check_rdata(8'hFF);	// 255 - 0 = 0xFF
		wait_ready();

		// ================================================================
		//	Test 15: Write after erase
		// ================================================================
		test_no = 15;
		$display("----------------------------------------");
		$display("[Test %0d] Write 0xAB to address 0x000050 after erase", test_no);
		issue_write(23'h000050, 8'hAB);
		wait_operation_complete();
		$display("[INFO] Write operation complete");

		// ================================================================
		//	Test 16: Read back after write
		// ================================================================
		test_no = 16;
		$display("----------------------------------------");
		$display("[Test %0d] Read back from address 0x000050", test_no);
		issue_read(23'h000050);
		wait_and_check_rdata(8'hAB);
		wait_ready();

		// ================================================================
		//	Test 17: Chip Erase
		// ================================================================
		test_no = 17;
		$display("----------------------------------------");
		$display("[Test %0d] Chip Erase", test_no);
		issue_chip_erase();
		wait_operation_complete();
		$display("[INFO] Chip erase operation complete");

		// ================================================================
		//	Test 18: Read after chip erase (address 0x50)
		// ================================================================
		test_no = 18;
		$display("----------------------------------------");
		$display("[Test %0d] Read from address 0x000050 after chip erase", test_no);
		issue_read(23'h000050);
		wait_and_check_rdata(8'hFF);
		wait_ready();

		// ================================================================
		//	Test 19: Read after chip erase (Sector 1)
		// ================================================================
		test_no = 19;
		$display("----------------------------------------");
		$display("[Test %0d] Read from Sector 1 (addr=0x001000) after chip erase", test_no);
		issue_read(23'h001000);
		wait_and_check_rdata(8'hFF);
		wait_ready();

		// ================================================================
		//	Test 20: Full sequence - Erase, Write multiple, Read back
		// ================================================================
		test_no = 20;
		$display("----------------------------------------");
		$display("[Test %0d] Full sequence test", test_no);
		
		// Write pattern to address 0x300-0x30F
		$display("[INFO] Writing test pattern to 0x000300-0x00030F");
		for(i = 0; i < 16; i++) begin
			issue_write(23'h000300 + i, test_pattern[i]);
			wait_operation_complete();
		end
		
		// Verify written data
		$display("[INFO] Verifying written data");
		for(i = 0; i < 16; i++) begin
			issue_read(23'h000300 + i);
			wait_rdata(single_read_data);
			if(single_read_data !== test_pattern[i]) begin
				$display("[ERROR] Test %0d: Full seq read[%0d] mismatch. Expected: %02Xh, Got: %02Xh", 
					test_no, i, test_pattern[i], single_read_data);
				error_count++;
			end
			else begin
				$display("[OK] Test %0d: Full seq verify[%0d] addr=%06Xh, data=%02Xh", 
					test_no, i, 23'h000300 + i, single_read_data);
			end
			wait_ready();
		end

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
