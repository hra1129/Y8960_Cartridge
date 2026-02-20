// --------------------------------------------------------------------
//	Winbond W25Q64JV Serial Flash ROM Test Model
// ====================================================================
//	64Mbit (8MB) SPI Flash Memory Behavioral Model for Simulation
//	2026/02/20 t.hara
// --------------------------------------------------------------------
//	Supported Commands:
//		0x06 - Write Enable (WREN)
//		0x04 - Write Disable (WRDI)
//		0x05 - Read Status Register-1 (RDSR1)
//		0x35 - Read Status Register-2 (RDSR2)
//		0x03 - Read Data
//		0x0B - Fast Read
//		0xEB - Quad I/O Read
//		0x02 - Page Program
//		0x20 - Sector Erase (4KB)
//		0x52 - Block Erase (32KB)
//		0xD8 - Block Erase (64KB)
//		0xC7 - Chip Erase
//		0x9F - Read JEDEC ID
//		0x90 - Read Manufacturer/Device ID
// --------------------------------------------------------------------

module sfrom_test_model #(
	parameter	MEMORY_SIZE		= 8*1024*1024,		// 8MB (64Mbit)
	parameter	PAGE_SIZE		= 256,				// 256 bytes
	parameter	SECTOR_SIZE		= 4*1024,			// 4KB
	parameter	BLOCK32_SIZE	= 32*1024,			// 32KB
	parameter	BLOCK64_SIZE	= 64*1024,			// 64KB
	parameter	INIT_FILE		= ""				// Optional initialization file
)(
	input			spi_clk,
	input			spi_cs_n,
	inout	[3:0]	spi_io
);

	// ----------------------------------------------------------------
	//	SPI Flash command codes
	// ----------------------------------------------------------------
	localparam [7:0] CMD_WRITE_ENABLE		= 8'h06;
	localparam [7:0] CMD_WRITE_DISABLE		= 8'h04;
	localparam [7:0] CMD_READ_STATUS_1		= 8'h05;
	localparam [7:0] CMD_READ_STATUS_2		= 8'h35;
	localparam [7:0] CMD_WRITE_STATUS		= 8'h01;
	localparam [7:0] CMD_READ_DATA			= 8'h03;
	localparam [7:0] CMD_FAST_READ			= 8'h0B;
	localparam [7:0] CMD_QUAD_IO_READ		= 8'hEB;
	localparam [7:0] CMD_PAGE_PROGRAM		= 8'h02;
	localparam [7:0] CMD_SECTOR_ERASE		= 8'h20;
	localparam [7:0] CMD_BLOCK32_ERASE		= 8'h52;
	localparam [7:0] CMD_BLOCK64_ERASE		= 8'hD8;
	localparam [7:0] CMD_CHIP_ERASE			= 8'hC7;
	localparam [7:0] CMD_CHIP_ERASE_ALT		= 8'h60;
	localparam [7:0] CMD_READ_JEDEC_ID		= 8'h9F;
	localparam [7:0] CMD_READ_MANU_DEV_ID	= 8'h90;
	localparam [7:0] CMD_POWER_DOWN			= 8'hB9;
	localparam [7:0] CMD_RELEASE_POWER_DOWN	= 8'hAB;

	// ----------------------------------------------------------------
	//	Device identification (W25Q64JV)
	// ----------------------------------------------------------------
	localparam [7:0] MANUFACTURER_ID		= 8'hEF;	// Winbond
	localparam [7:0] MEMORY_TYPE			= 8'h40;	// SPI
	localparam [7:0] CAPACITY_ID			= 8'h17;	// 64Mbit
	localparam [7:0] DEVICE_ID				= 8'h16;	// W25Q64

	// ----------------------------------------------------------------
	//	State machine states
	// ----------------------------------------------------------------
	localparam [3:0] ST_CMD					= 4'd0;
	localparam [3:0] ST_ADDR2				= 4'd1;
	localparam [3:0] ST_ADDR1				= 4'd2;
	localparam [3:0] ST_ADDR0				= 4'd3;
	localparam [3:0] ST_DUMMY				= 4'd4;
	localparam [3:0] ST_DATA_READ			= 4'd5;
	localparam [3:0] ST_DATA_WRITE			= 4'd6;
	localparam [3:0] ST_STATUS_READ			= 4'd7;
	localparam [3:0] ST_QUAD_ADDR			= 4'd8;
	localparam [3:0] ST_QUAD_MODE			= 4'd9;
	localparam [3:0] ST_QUAD_DUMMY			= 4'd10;
	localparam [3:0] ST_QUAD_DATA			= 4'd11;
	localparam [3:0] ST_JEDEC_ID			= 4'd12;
	localparam [3:0] ST_MANU_DEV_ID			= 4'd13;

	// ----------------------------------------------------------------
	//	Flash memory array
	// ----------------------------------------------------------------
	reg [7:0]	memory [0:MEMORY_SIZE-1];

	// ----------------------------------------------------------------
	//	Registers
	// ----------------------------------------------------------------
	reg [3:0]	state;
	reg [7:0]	cmd_reg;
	reg [23:0]	addr_reg;
	reg [7:0]	shift_in;
	reg [7:0]	shift_out;
	reg [2:0]	bit_cnt;
	reg [2:0]	quad_cnt;			// Quad mode nibble counter
	reg [3:0]	dummy_cnt;			// Dummy cycle counter
	reg			quad_output_en;		// Quad mode output enable
	reg [3:0]	io_out_reg;			// IO output data
	reg			miso_reg;			// MISO output (single mode)
	reg			quad_input_mode;	// Hi-Z for quad input

	// ----------------------------------------------------------------
	//	Status Registers
	// ----------------------------------------------------------------
	reg			status_wip;			// Write In Progress (Status1[0])
	reg			status_wel;			// Write Enable Latch (Status1[1])
	reg [5:0]	status_bp;			// Block Protect bits (Status1[7:2])
	reg [7:0]	status_reg2;		// Status Register 2

	// ----------------------------------------------------------------
	//	WIP Timer (for simulation timing)
	// ----------------------------------------------------------------
	reg [31:0]	wip_counter;

	// ----------------------------------------------------------------
	//	Page Program buffer
	// ----------------------------------------------------------------
	reg [7:0]	page_buffer [0:PAGE_SIZE-1];
	reg [8:0]	page_index;
	reg [23:0]	page_start_addr;

	// ----------------------------------------------------------------
	//	IO connections
	// ----------------------------------------------------------------
	wire		spi_mosi = spi_io[0];
	wire [3:0]	spi_io_in = spi_io;

	// Tri-state control
	assign spi_io[0] = quad_output_en ? io_out_reg[0] : 1'bz;
	assign spi_io[1] = quad_output_en ? io_out_reg[1] : (quad_input_mode ? 1'bz : miso_reg);
	assign spi_io[2] = quad_output_en ? io_out_reg[2] : 1'bz;
	assign spi_io[3] = quad_output_en ? io_out_reg[3] : 1'bz;

	// ----------------------------------------------------------------
	//	Initialize memory
	// ----------------------------------------------------------------
	integer init_i;
	initial begin
		// Initialize to erased state (all FF)
		for (init_i = 0; init_i < MEMORY_SIZE; init_i = init_i + 1) begin
			memory[init_i] = 8'hFF;
		end
		// Load from file if specified
		if (INIT_FILE != "") begin
			$readmemh(INIT_FILE, memory);
		end
		// Initialize registers
		state = ST_CMD;
		cmd_reg = 8'h00;
		addr_reg = 24'h000000;
		shift_in = 8'h00;
		shift_out = 8'hFF;
		bit_cnt = 3'd7;
		quad_cnt = 3'd0;
		dummy_cnt = 4'd0;
		quad_output_en = 1'b0;
		io_out_reg = 4'hF;
		miso_reg = 1'b1;
		quad_input_mode = 1'b0;
		status_wip = 1'b0;
		status_wel = 1'b0;
		status_bp = 6'b000000;
		status_reg2 = 8'h00;
		wip_counter = 32'd0;
		page_index = 9'd0;
		page_start_addr = 24'h000000;
	end

	// ----------------------------------------------------------------
	//	WIP counter process
	//	Count down on SPI clock regardless of CS state
	// ----------------------------------------------------------------
	always @(posedge spi_clk) begin
		if (wip_counter > 0) begin
			wip_counter <= wip_counter - 1;
			if (wip_counter == 1) begin
				status_wip <= 1'b0;
				$display("[W25Q64JV] WIP cleared - operation complete");
			end
		end
	end

	// ----------------------------------------------------------------
	//	CS# rising edge - end of transaction
	// ----------------------------------------------------------------
	always @(posedge spi_cs_n) begin
		// Reset state
		state <= ST_CMD;
		bit_cnt <= 3'd7;
		quad_output_en <= 1'b0;
		io_out_reg <= 4'hF;
		miso_reg <= 1'b1;
		quad_input_mode <= 1'b0;
		shift_in <= 8'h00;		// Reset shift register for next command

		// Handle Page Program completion
		if (cmd_reg == CMD_PAGE_PROGRAM && status_wel && page_index > 0) begin
			execute_page_program();
		end
		// Reset page_index for next transaction
		page_index <= 9'd0;
	end

	// ----------------------------------------------------------------
	//	SPI Clock Rising Edge - Sample input
	// ----------------------------------------------------------------
	always @(posedge spi_clk) begin
		if (!spi_cs_n) begin
			// Command phase is always processed (even during WIP)
			// Other phases are blocked during WIP except status read
			case (state)
				// ------------------------------------------------
				// Command Phase (Single SPI - 8 bits)
				// ------------------------------------------------
				ST_CMD: begin
					shift_in <= {shift_in[6:0], spi_mosi};
					if (bit_cnt == 3'd0) begin
						cmd_reg <= {shift_in[6:0], spi_mosi};
						process_command({shift_in[6:0], spi_mosi});
					end
					else begin
						bit_cnt <= bit_cnt - 3'd1;
					end
				end

				// ------------------------------------------------
				// Status Register Read (allowed during WIP)
				// ------------------------------------------------
				ST_STATUS_READ: begin
					if (bit_cnt == 3'd0) begin
						// Reload status for continuous read
						shift_out <= {status_bp, status_wel, status_wip};
						bit_cnt <= 3'd7;
					end
					else begin
						bit_cnt <= bit_cnt - 3'd1;
					end
				end

				default: begin
					// Other states only process when not WIP
					if (!status_wip) begin
						case (state)
							// ------------------------------------------------
							// Address Phase (Single SPI - 24 bits)
							// ------------------------------------------------
							ST_ADDR2: begin
								shift_in <= {shift_in[6:0], spi_mosi};
								if (bit_cnt == 3'd0) begin
									addr_reg[23:16] = {shift_in[6:0], spi_mosi};	// Blocking for consistency
									bit_cnt <= 3'd7;
									state <= ST_ADDR1;
								end
								else begin
									bit_cnt <= bit_cnt - 3'd1;
								end
							end

							ST_ADDR1: begin
								shift_in <= {shift_in[6:0], spi_mosi};
								if (bit_cnt == 3'd0) begin
									addr_reg[15:8] = {shift_in[6:0], spi_mosi};	// Blocking for consistency
									bit_cnt <= 3'd7;
									state <= ST_ADDR0;
								end
								else begin
									bit_cnt <= bit_cnt - 3'd1;
								end
							end

							ST_ADDR0: begin
								shift_in <= {shift_in[6:0], spi_mosi};
								if (bit_cnt == 3'd0) begin
									addr_reg[7:0] = {shift_in[6:0], spi_mosi};	// Blocking for task
									bit_cnt <= 3'd7;
									process_address_complete();
								end
								else begin
									bit_cnt <= bit_cnt - 3'd1;
								end
							end

							// ------------------------------------------------
							// Dummy Cycles (Fast Read - 8 clocks)
							// ------------------------------------------------
							ST_DUMMY: begin
								if (bit_cnt == 3'd0) begin
									shift_out <= memory[addr_reg];
									state <= ST_DATA_READ;
									bit_cnt <= 3'd7;
									$display("[W25Q64JV] Fast Read addr=%06Xh, data=%02Xh", addr_reg, memory[addr_reg]);
								end
								else begin
									bit_cnt <= bit_cnt - 3'd1;
								end
							end

							// ------------------------------------------------
							// Data Read Phase (Single SPI)
							// ------------------------------------------------
							ST_DATA_READ: begin
								// Data output on falling edge
								if (bit_cnt == 3'd0) begin
									addr_reg <= addr_reg + 24'd1;
									shift_out <= memory[addr_reg + 24'd1];
									bit_cnt <= 3'd7;
								end
								else begin
									bit_cnt <= bit_cnt - 3'd1;
								end
							end

							// ------------------------------------------------
							// Data Write Phase (Page Program)
							// ------------------------------------------------
							ST_DATA_WRITE: begin
								shift_in <= {shift_in[6:0], spi_mosi};
								if (bit_cnt == 3'd0) begin
									if (page_index < PAGE_SIZE) begin
										page_buffer[page_index] <= {shift_in[6:0], spi_mosi};
										page_index <= page_index + 9'd1;
									end
									bit_cnt <= 3'd7;
								end
								else begin
									bit_cnt <= bit_cnt - 3'd1;
								end
							end

							// ------------------------------------------------
							// Quad I/O Address Phase (6 nibbles = 24 bits)
							// ------------------------------------------------
							ST_QUAD_ADDR: begin
								addr_reg <= {addr_reg[19:0], spi_io_in};
								if (quad_cnt == 3'd0) begin
									state <= ST_QUAD_MODE;
									quad_cnt <= 3'd1;	// 2 nibbles for mode byte
								end
								else begin
									quad_cnt <= quad_cnt - 3'd1;
								end
							end

							// ------------------------------------------------
							// Quad I/O Mode Byte (2 nibbles = 8 bits)
							// ------------------------------------------------
							ST_QUAD_MODE: begin
								// Receive mode byte (usually 0xFF or 0xF0 for continuous read)
								if (quad_cnt == 3'd0) begin
									state <= ST_QUAD_DUMMY;
									dummy_cnt <= 4'd4;	// 4 dummy clocks for W25Q64JV
								end
								else begin
									quad_cnt <= quad_cnt - 3'd1;
								end
							end

							// ------------------------------------------------
							// Quad I/O Dummy Cycles
							// ------------------------------------------------
							ST_QUAD_DUMMY: begin
								if (dummy_cnt == 4'd0) begin
									// Prepare first data nibble
									shift_out <= memory[addr_reg];
									state <= ST_QUAD_DATA;
									quad_cnt <= 3'd1;	// Toggle high/low nibble
									$display("[W25Q64JV] Quad Read addr=%06Xh, data=%02Xh", addr_reg, memory[addr_reg]);
								end
								else begin
									dummy_cnt <= dummy_cnt - 4'd1;
								end
							end

							// ------------------------------------------------
							// Quad I/O Data Read (2 nibbles per byte)
							// ------------------------------------------------
							ST_QUAD_DATA: begin
								if (quad_cnt == 3'd0) begin
									// Low nibble was output, move to next byte
									addr_reg <= addr_reg + 24'd1;
									shift_out <= memory[addr_reg + 24'd1];
									quad_cnt <= 3'd1;
								end
								else begin
									quad_cnt <= 3'd0;
								end
							end

							// ------------------------------------------------
							// JEDEC ID Read
							// ------------------------------------------------
							ST_JEDEC_ID: begin
								if (bit_cnt == 3'd0) begin
									bit_cnt <= 3'd7;
									case (dummy_cnt)
										4'd0: shift_out <= MEMORY_TYPE;
										4'd1: shift_out <= CAPACITY_ID;
										default: shift_out <= 8'hFF;
									endcase
									dummy_cnt <= dummy_cnt + 4'd1;
								end
								else begin
									bit_cnt <= bit_cnt - 3'd1;
								end
							end

							// ------------------------------------------------
							// Manufacturer/Device ID Read
							// ------------------------------------------------
							ST_MANU_DEV_ID: begin
								if (bit_cnt == 3'd0) begin
									bit_cnt <= 3'd7;
									shift_out <= (dummy_cnt[0]) ? DEVICE_ID : MANUFACTURER_ID;
									dummy_cnt <= dummy_cnt + 4'd1;
								end
								else begin
									bit_cnt <= bit_cnt - 3'd1;
								end
							end
						endcase
					end
				end
			endcase
		end
	end

	// ----------------------------------------------------------------
	//	SPI Clock Falling Edge - Output data
	// ----------------------------------------------------------------
	always @(negedge spi_clk) begin
		if (!spi_cs_n) begin
			case (state)
				ST_DATA_READ: begin
					miso_reg <= shift_out[7];
					shift_out <= {shift_out[6:0], 1'b0};
				end

				ST_DUMMY: begin
					// Keep MISO high during dummy cycles
					miso_reg <= 1'b1;
				end

				ST_STATUS_READ: begin
					miso_reg <= shift_out[7];
					shift_out <= {shift_out[6:0], 1'b0};
				end

				ST_JEDEC_ID: begin
					miso_reg <= shift_out[7];
					shift_out <= {shift_out[6:0], 1'b0};
				end

				ST_MANU_DEV_ID: begin
					miso_reg <= shift_out[7];
					shift_out <= {shift_out[6:0], 1'b0};
				end

				ST_QUAD_DUMMY: begin
					if (dummy_cnt == 4'd1) begin
						// Prepare quad output ONE CYCLE EARLY so DUT can sample on rising edge
						quad_output_en <= 1'b1;
						quad_input_mode <= 1'b0;
						io_out_reg <= memory[addr_reg][7:4];	// High nibble first
					end
				end

				ST_QUAD_DATA: begin
					quad_output_en <= 1'b1;
					if (quad_cnt == 3'd1) begin
						// Output low nibble (DUT will sample high nibble on next rising edge, 
						// then this low nibble on the following rising edge)
						io_out_reg <= shift_out[3:0];
					end
					else begin
						// Output next byte's high nibble
						io_out_reg <= shift_out[7:4];
					end
				end

				default: begin
					miso_reg <= 1'b1;
				end
			endcase
		end
	end

	// ----------------------------------------------------------------
	//	Task: Process Command
	// ----------------------------------------------------------------
	task process_command;
		input [7:0] cmd;
		begin
			$display("[W25Q64JV] Command received: %02Xh", cmd);
			
			// Read Status commands are always allowed (even during WIP)
			if (cmd == CMD_READ_STATUS_1) begin
				shift_out <= {status_bp, status_wel, status_wip};
				state <= ST_STATUS_READ;
				bit_cnt <= 3'd7;
				$display("[W25Q64JV] Read Status-1: %02Xh (WIP=%b)", {status_bp, status_wel, status_wip}, status_wip);
			end
			else if (cmd == CMD_READ_STATUS_2) begin
				shift_out <= status_reg2;
				state <= ST_STATUS_READ;
				bit_cnt <= 3'd7;
				$display("[W25Q64JV] Read Status-2: %02Xh", status_reg2);
			end
			// Other commands are ignored during WIP
			else if (status_wip) begin
				$display("[W25Q64JV] Command %02Xh ignored - WIP in progress", cmd);
			end
			else begin
				case (cmd)
					CMD_WRITE_ENABLE: begin
						status_wel <= 1'b1;
						$display("[W25Q64JV] Write Enable");
					end

					CMD_WRITE_DISABLE: begin
						status_wel <= 1'b0;
						$display("[W25Q64JV] Write Disable");
					end

					CMD_READ_DATA: begin
						state <= ST_ADDR2;
						bit_cnt <= 3'd7;
					end

					CMD_FAST_READ: begin
						state <= ST_ADDR2;
						bit_cnt <= 3'd7;
					end

					CMD_QUAD_IO_READ: begin
						state <= ST_QUAD_ADDR;
						quad_cnt <= 3'd5;	// 6 nibbles for 24-bit address
						quad_input_mode <= 1'b1;
					end

					CMD_PAGE_PROGRAM: begin
						if (status_wel) begin
							state <= ST_ADDR2;
							bit_cnt <= 3'd7;
							page_index <= 9'd0;
						end
						else begin
							$display("[W25Q64JV] Warning: Page Program without WEL");
						end
					end

					CMD_SECTOR_ERASE: begin
						if (status_wel) begin
							state <= ST_ADDR2;
							bit_cnt <= 3'd7;
						end
						else begin
							$display("[W25Q64JV] Warning: Sector Erase without WEL");
						end
					end

					CMD_BLOCK32_ERASE: begin
						if (status_wel) begin
							state <= ST_ADDR2;
							bit_cnt <= 3'd7;
						end
						else begin
							$display("[W25Q64JV] Warning: Block32 Erase without WEL");
						end
					end

					CMD_BLOCK64_ERASE: begin
						if (status_wel) begin
							state <= ST_ADDR2;
							bit_cnt <= 3'd7;
						end
						else begin
							$display("[W25Q64JV] Warning: Block64 Erase without WEL");
						end
					end

					CMD_CHIP_ERASE, CMD_CHIP_ERASE_ALT: begin
						if (status_wel) begin
							execute_chip_erase();
						end
						else begin
							$display("[W25Q64JV] Warning: Chip Erase without WEL");
						end
					end

					CMD_READ_JEDEC_ID: begin
						shift_out <= MANUFACTURER_ID;
						state <= ST_JEDEC_ID;
						bit_cnt <= 3'd7;
						dummy_cnt <= 4'd0;
						$display("[W25Q64JV] Read JEDEC ID: EF4017h");
					end

					CMD_READ_MANU_DEV_ID: begin
						state <= ST_ADDR2;	// Need 3 dummy address bytes
						bit_cnt <= 3'd7;
					end

					default: begin
						$display("[W25Q64JV] Unknown command: %02Xh", cmd);
					end
				endcase
			end
		end
	endtask

	// ----------------------------------------------------------------
	//	Task: Process Address Complete
	// ----------------------------------------------------------------
	task process_address_complete;
		begin
			case (cmd_reg)
				CMD_READ_DATA: begin
					shift_out <= memory[addr_reg];
					state <= ST_DATA_READ;
					$display("[W25Q64JV] Read Data addr=%06Xh, data=%02Xh", addr_reg, memory[addr_reg]);
				end

				CMD_FAST_READ: begin
					state <= ST_DUMMY;
					bit_cnt <= 3'd7;
				end

				CMD_PAGE_PROGRAM: begin
					page_start_addr <= addr_reg;
					state <= ST_DATA_WRITE;
					$display("[W25Q64JV] Page Program start addr=%06Xh", addr_reg);
				end

				CMD_SECTOR_ERASE: begin
					execute_sector_erase(addr_reg);
				end

				CMD_BLOCK32_ERASE: begin
					execute_block32_erase(addr_reg);
				end

				CMD_BLOCK64_ERASE: begin
					execute_block64_erase(addr_reg);
				end

				CMD_READ_MANU_DEV_ID: begin
					shift_out <= MANUFACTURER_ID;
					state <= ST_MANU_DEV_ID;
					bit_cnt <= 3'd7;
					dummy_cnt <= 4'd0;
				end
			endcase
		end
	endtask

	// ----------------------------------------------------------------
	//	Task: Execute Page Program
	// ----------------------------------------------------------------
	task execute_page_program;
		integer i;
		reg [23:0] program_addr;
		begin
			$display("[W25Q64JV] Executing Page Program at addr=%06Xh, %0d bytes", page_start_addr, page_index);
			for (i = 0; i < page_index && i < PAGE_SIZE; i = i + 1) begin
				// Page Program can only clear bits (0->0, 1->0 or 1->1)
				// Address wraps within page
				program_addr = {page_start_addr[23:8], page_start_addr[7:0] + i[7:0]};
				memory[program_addr] <= memory[program_addr] & page_buffer[i];
			end
			status_wip <= 1'b1;
			status_wel <= 1'b0;
			wip_counter <= 32'd50;	// Simulation timing (short)
		end
	endtask

	// ----------------------------------------------------------------
	//	Task: Execute Sector Erase (4KB)
	// ----------------------------------------------------------------
	task execute_sector_erase;
		input [23:0] addr;
		integer i;
		reg [23:0] sector_base;
		begin
			sector_base = {addr[23:12], 12'h000};
			$display("[W25Q64JV] Sector Erase at addr=%06Xh (sector base=%06Xh)", addr, sector_base);
			for (i = 0; i < SECTOR_SIZE; i = i + 1) begin
				memory[sector_base + i] <= 8'hFF;
			end
			status_wip <= 1'b1;
			status_wel <= 1'b0;
			wip_counter <= 32'd100;	// Simulation timing (short)
		end
	endtask

	// ----------------------------------------------------------------
	//	Task: Execute Block Erase (32KB)
	// ----------------------------------------------------------------
	task execute_block32_erase;
		input [23:0] addr;
		integer i;
		reg [23:0] block_base;
		begin
			block_base = {addr[23:15], 15'h0000};
			$display("[W25Q64JV] Block32 Erase at addr=%06Xh (block base=%06Xh)", addr, block_base);
			for (i = 0; i < BLOCK32_SIZE; i = i + 1) begin
				memory[block_base + i] <= 8'hFF;
			end
			status_wip <= 1'b1;
			status_wel <= 1'b0;
			wip_counter <= 32'd200;	// Simulation timing (short)
		end
	endtask

	// ----------------------------------------------------------------
	//	Task: Execute Block Erase (64KB)
	// ----------------------------------------------------------------
	task execute_block64_erase;
		input [23:0] addr;
		integer i;
		reg [23:0] block_base;
		begin
			block_base = {addr[23:16], 16'h0000};
			$display("[W25Q64JV] Block64 Erase at addr=%06Xh (block base=%06Xh)", addr, block_base);
			for (i = 0; i < BLOCK64_SIZE; i = i + 1) begin
				memory[block_base + i] <= 8'hFF;
			end
			status_wip <= 1'b1;
			status_wel <= 1'b0;
			wip_counter <= 32'd400;	// Simulation timing (short)
		end
	endtask

	// ----------------------------------------------------------------
	//	Task: Execute Chip Erase
	// ----------------------------------------------------------------
	task execute_chip_erase;
		integer i;
		begin
			$display("[W25Q64JV] Chip Erase");
			for (i = 0; i < MEMORY_SIZE; i = i + 1) begin
				memory[i] <= 8'hFF;
			end
			status_wip <= 1'b1;
			status_wel <= 1'b0;
			wip_counter <= 32'd1000;	// Simulation timing (short)
		end
	endtask

	// ----------------------------------------------------------------
	//	Function: Read memory content (for testbench access)
	// ----------------------------------------------------------------
	function [7:0] read_memory;
		input [23:0] addr;
		begin
			read_memory = memory[addr];
		end
	endfunction

	// ----------------------------------------------------------------
	//	Task: Write memory content (for testbench initialization)
	// ----------------------------------------------------------------
	task write_memory;
		input [23:0] addr;
		input [7:0] data;
		begin
			memory[addr] = data;
		end
	endtask

	// ----------------------------------------------------------------
	//	Task: Initialize memory from array
	// ----------------------------------------------------------------
	task init_memory_block;
		input [23:0] start_addr;
		input [31:0] size;
		input [7:0] pattern;
		integer i;
		begin
			for (i = 0; i < size && (start_addr + i) < MEMORY_SIZE; i = i + 1) begin
				memory[start_addr + i] = pattern;
			end
		end
	endtask

endmodule
