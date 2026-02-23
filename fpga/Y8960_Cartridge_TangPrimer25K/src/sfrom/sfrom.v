// --------------------------------------------------------------------
//	SerialFlashROM Controller
// ====================================================================
//	2026/01/26 t.hara
// --------------------------------------------------------------------

module sfrom (
	input			clk,
	input			clk_258m,		//	257.72724MHz
	input			reset_n,
	input	[22:0]	address,		//	8MB
	input			valid,
	output			ready,
	input	[1:0]	command,
	input	[7:0]	wdata,
	output	[7:0]	rdata,
	output			rdata_en,
	//	Burst read interface
	input			burst_start,		//	Start burst read (clk domain pulse)
	input	[22:0]	burst_address,		//	Start address
	input	[16:0]	burst_length,		//	Number of bytes - 1
	output	[7:0]	burst_rdata,		//	Read data (clk_258m domain)
	output			burst_rdata_en,		//	Read data valid (clk_258m domain)
	output			burst_active,		//	Burst in progress (clk domain)
	//	Serial FlashROM I/F
	output			flash_spi_clk,
	output			flash_spi_cs_n,
	inout	[3:0]	flash_spi_io
);

	// ----------------------------------------------------------------
	//	Command definitions (from host interface)
	// ----------------------------------------------------------------
	localparam		c_command_read			= 2'd0;
	localparam		c_command_write			= 2'd1;
	localparam		c_command_sector_erase	= 2'd2;
	localparam		c_command_all_erase		= 2'd3;

	// ----------------------------------------------------------------
	//	SPI Flash command codes
	// ----------------------------------------------------------------
	localparam [7:0] SPI_CMD_READ           = 8'h03;	// Read Data
	localparam [7:0] SPI_CMD_FAST_READ      = 8'h0B;	// Fast Read
	localparam [7:0] SPI_CMD_QUAD_IO_READ   = 8'hEB;	// Quad I/O Read
	localparam [7:0] SPI_CMD_PAGE_PROGRAM   = 8'h02;	// Page Program (Write)
	localparam [7:0] SPI_CMD_SECTOR_ERASE   = 8'h20;	// Sector Erase (4KB)
	localparam [7:0] SPI_CMD_CHIP_ERASE     = 8'hC7;	// Chip Erase
	localparam [7:0] SPI_CMD_WRITE_ENABLE   = 8'h06;	// Write Enable
	localparam [7:0] SPI_CMD_WRITE_DISABLE  = 8'h04;	// Write Disable
	localparam [7:0] SPI_CMD_READ_STATUS    = 8'h05;	// Read Status Register
	localparam [7:0] SPI_CMD_READ_STATUS2   = 8'h35;	// Read Status Register 2

	// ----------------------------------------------------------------
	//	State machine states
	// ----------------------------------------------------------------
	localparam [4:0] ST_IDLE                = 5'd0;
	localparam [4:0] ST_SEND_WREN           = 5'd1;		// Write Enable
	localparam [4:0] ST_WREN_WAIT           = 5'd2;
	localparam [4:0] ST_SEND_CMD            = 5'd3;		// Send SPI command
	localparam [4:0] ST_SEND_ADDR2          = 5'd4;		// Send address[23:16]
	localparam [4:0] ST_SEND_ADDR1          = 5'd5;		// Send address[15:8]
	localparam [4:0] ST_SEND_ADDR0          = 5'd6;		// Send address[7:0]
	localparam [4:0] ST_SEND_ADDR_LAST      = 5'd7;		// Finish address byte 0 (Quad)
	localparam [4:0] ST_DUMMY_CYCLES        = 5'd15;	// Quad I/O dummy cycles
	localparam [4:0] ST_READ_DATA           = 5'd8;		// Read data byte (Quad)
	localparam [4:0] ST_WRITE_DATA          = 5'd9;		// Write data byte
	localparam [4:0] ST_WAIT_BUSY           = 5'd10;	// Poll status for busy
	localparam [4:0] ST_READ_STATUS         = 5'd11;	// Read status register
	localparam [4:0] ST_CHECK_STATUS        = 5'd12;	// Check WIP bit
	localparam [4:0] ST_FINISH              = 5'd13;	// Complete operation
	localparam [4:0] ST_CS_HIGH             = 5'd14;	// CS high interval

	// ----------------------------------------------------------------
	//	Registers
	// ----------------------------------------------------------------
	reg [4:0]	ff_state;
	reg [4:0]	ff_next_state;			// State to return after CS_HIGH
	reg [4:0]	ff_return_state;		// State to return after busy wait
	reg [7:0]	ff_shift_out;			// SPI output shift register
	reg [7:0]	ff_shift_in;			// SPI input shift register
	reg [2:0]	ff_bit_cnt;				// Bit counter (0-7)
	reg			ff_spi_clk_en;			// SPI clock enable
	reg			ff_spi_cs_n;			// SPI chip select (active low)
	reg			ff_spi_mosi;			// SPI MOSI output
	reg [7:0]	ff_spi_cmd_reg;			// Stored SPI command
	reg [22:0]	ff_addr_reg;			// Stored address
	reg [7:0]	ff_wdata_reg;			// Stored write data
	reg [7:0]	ff_rdata_reg;			// Read data output (clk_258m domain)
	reg			ff_rdata_en_reg;		// Read data valid (clk_258m domain)
	reg			ff_ready_reg;			// Ready for new command (clk_258m domain)
	reg [3:0]	ff_cs_wait_cnt;			// CS high wait counter
	reg			ff_io_quad_out;			// Quad mode output enable
	reg [3:0]	ff_io_out;				// IO output data for Quad mode
	reg [2:0]	ff_dummy_cnt;			// Dummy cycle counter
	reg			ff_quad_read_mode;		// Quad I/O Read in progress (IO[2:3] should be Hi-Z)

	// ----------------------------------------------------------------
	//	Burst read registers
	// ----------------------------------------------------------------
	reg				ff_burst_mode;			// Burst read active (clk_258m domain)
	reg	[16:0]		ff_burst_count;			// Remaining bytes to read
	reg	[7:0]		ff_burst_rdata;			// Burst read data (clk_258m domain)
	reg				ff_burst_rdata_en;		// Burst read data valid (clk_258m domain)

	// ----------------------------------------------------------------
	//	SPI clock generation (clk_258m speed)
	// ----------------------------------------------------------------
	// SPI clock toggles every clk_258m cycle when enabled
	// Effective SPI clock frequency: clk_258m / 2 ≈ 128.86MHz
	reg			ff_spi_clk;				// SPI clock register
	reg			ff_spi_clk_d;			// Delayed SPI clock for edge detection
	reg			ff_spi_clk_en_sync;		// Synchronized clock enable (1 cycle delayed)
	wire		w_spi_rising_edge;		// SPI clock rising edge
	wire		w_spi_falling_edge;		// SPI clock falling edge

	always @(posedge clk_258m or negedge reset_n) begin
		if(!reset_n) begin
			ff_spi_clk <= 1'b0;
			ff_spi_clk_d <= 1'b0;
			ff_spi_clk_en_sync <= 1'b0;
		end
		else begin
			ff_spi_clk_d <= ff_spi_clk;
			ff_spi_clk_en_sync <= ff_spi_clk_en;
			// Clock generation with proper start/stop timing
			// Use ff_spi_clk_en_sync for toggling, but force 0 when ff_spi_clk_en is 0
			if(ff_spi_clk_en && ff_spi_clk_en_sync) begin
				ff_spi_clk <= ~ff_spi_clk;
			end
			else if(!ff_spi_clk_en) begin
				ff_spi_clk <= 1'b0;		// Force clock low when disabled
			end
			else begin
				// ff_spi_clk_en=1 but ff_spi_clk_en_sync=0 (clock just enabled)
				// Keep clock at 0, will start toggling next cycle
				ff_spi_clk <= 1'b0;
			end
		end
	end

	// SPI clock: clk_258m / 2 ≈ 128.86MHz
	// Detect edges using synchronized enable to match clock generation timing
	assign w_spi_rising_edge = ff_spi_clk_en_sync && !ff_spi_clk_d && ff_spi_clk;
	assign w_spi_falling_edge = ff_spi_clk_en_sync && ff_spi_clk_d && !ff_spi_clk;
	assign flash_spi_clk = ff_spi_clk;

	// ----------------------------------------------------------------
	//	SPI I/O control (Quad mode support)
	// ----------------------------------------------------------------
	// Single mode: IO[0]=MOSI(output), IO[1]=MISO(input)
	// Quad mode output: IO[0:3]=output
	// Quad mode input:  IO[0:3]=Hi-Z (for reading)
	assign flash_spi_cs_n = ff_spi_cs_n;
	assign flash_spi_io[0] = ff_io_quad_out ? ff_io_out[0] : (ff_quad_read_mode ? 1'bz : ff_spi_mosi);
	assign flash_spi_io[1] = ff_io_quad_out ? ff_io_out[1] : 1'bz;
	assign flash_spi_io[2] = ff_io_quad_out ? ff_io_out[2] : (ff_quad_read_mode ? 1'bz : 1'b1);
	assign flash_spi_io[3] = ff_io_quad_out ? ff_io_out[3] : (ff_quad_read_mode ? 1'bz : 1'b1);

	wire [3:0] w_spi_io_in = flash_spi_io;
	wire w_spi_miso = flash_spi_io[1];

	// ----------------------------------------------------------------
	//	Output assignments
	// ----------------------------------------------------------------
	// ready, rdata, rdata_en are synchronized to clk domain below

	// ----------------------------------------------------------------
	//	CDC: clk_258m domain to clk domain (for outputs)
	//	Using toggle synchronization for pulse transfer
	// ----------------------------------------------------------------
	reg [7:0]	ff_rdata_clk;			// Read data in clk domain
	reg			ff_rdata_en_clk;		// Read data valid in clk domain
	reg			ff_ready_clk;			// Ready in clk domain

	// Toggle signal in clk_129m domain
	reg			ff_rdata_toggle;		// Toggles when rdata_en pulses
	reg [2:0]	ff_rdata_toggle_sync;	// Synchronizer for toggle
	reg [1:0]	ff_ready_sync;			// Synchronizer for ready

	// Generate toggle in clk_258m domain
	always @(posedge clk_258m or negedge reset_n) begin
		if(!reset_n) begin
			ff_rdata_toggle <= 1'b0;
		end
		else if(ff_rdata_en_reg) begin
			ff_rdata_toggle <= ~ff_rdata_toggle;
		end
	end

	// Synchronize toggle and detect edge in clk domain
	always @(posedge clk or negedge reset_n) begin
		if(!reset_n) begin
			ff_rdata_clk <= 8'd0;
			ff_rdata_en_clk <= 1'b0;
			ff_rdata_toggle_sync <= 3'b000;
			ff_ready_clk <= 1'b0;
			ff_ready_sync <= 2'b00;
		end
		else begin
			// Synchronize toggle signal
			ff_rdata_toggle_sync <= {ff_rdata_toggle_sync[1:0], ff_rdata_toggle};

			// Detect toggle edge (pulse reconstruction)
			ff_rdata_en_clk <= ff_rdata_toggle_sync[1] ^ ff_rdata_toggle_sync[2];

			// Latch rdata when toggle edge detected
			if(ff_rdata_toggle_sync[1] ^ ff_rdata_toggle_sync[2]) begin
				ff_rdata_clk <= ff_rdata_reg;
			end

			// Synchronize ready signal (level, not pulse)
			ff_ready_sync <= {ff_ready_sync[0], ff_ready_reg};
			ff_ready_clk <= ff_ready_sync[1];
		end
	end

	// ----------------------------------------------------------------
	//	CDC: burst_start (clk -> clk_258m)
	// ----------------------------------------------------------------
	reg [2:0]	ff_burst_start_sync;
	wire		w_burst_start_pulse;

	always @(posedge clk_258m or negedge reset_n) begin
		if(!reset_n) begin
			ff_burst_start_sync <= 3'b000;
		end
		else begin
			ff_burst_start_sync <= {ff_burst_start_sync[1:0], burst_start};
		end
	end

	assign w_burst_start_pulse = ff_burst_start_sync[1] && !ff_burst_start_sync[2];

	// ----------------------------------------------------------------
	//	CDC: burst_active (clk_258m -> clk)
	// ----------------------------------------------------------------
	reg [1:0]	ff_burst_active_sync;

	always @(posedge clk or negedge reset_n) begin
		if(!reset_n) begin
			ff_burst_active_sync <= 2'b00;
		end
		else begin
			ff_burst_active_sync <= {ff_burst_active_sync[0], ff_burst_mode};
		end
	end

	assign burst_active = ff_burst_active_sync[1];
	assign burst_rdata = ff_burst_rdata;
	assign burst_rdata_en = ff_burst_rdata_en;

	assign ready = ff_ready_clk & ~ff_burst_active_sync[1];
	assign rdata = ff_rdata_clk;
	assign rdata_en = ff_rdata_en_clk;

	// ----------------------------------------------------------------
	//	CDC: clk domain to clk_258m domain (for inputs)
	// ----------------------------------------------------------------
	reg [2:0]	ff_valid_sync;
	reg [22:0]	ff_addr_latch;
	reg [1:0]	ff_cmd_latch;
	reg [7:0]	ff_wdata_latch;
	wire		w_valid_pulse;

	always @(posedge clk_258m or negedge reset_n) begin
		if(!reset_n) begin
			ff_valid_sync <= 3'b000;
		end
		else begin
			ff_valid_sync <= {ff_valid_sync[1:0], valid & ff_ready_reg};
		end
	end

	assign w_valid_pulse = ff_valid_sync[1] && !ff_valid_sync[2];

	// Latch inputs when valid
	always @(posedge clk_258m or negedge reset_n) begin
		if(!reset_n) begin
			ff_addr_latch <= 23'd0;
			ff_cmd_latch <= 2'd0;
			ff_wdata_latch <= 8'd0;
		end
		else if(w_valid_pulse) begin
			ff_addr_latch <= address;
			ff_cmd_latch <= command;
			ff_wdata_latch <= wdata;
		end
	end

	// ----------------------------------------------------------------
	//	Main State Machine (clk_258m domain)
	// ----------------------------------------------------------------
	always @(posedge clk_258m or negedge reset_n) begin
		if(!reset_n) begin
			ff_state <= ST_IDLE;
			ff_next_state <= ST_IDLE;
			ff_return_state <= ST_IDLE;
			ff_shift_out <= 8'd0;
			ff_shift_in <= 8'd0;
			ff_bit_cnt <= 3'd0;
			ff_spi_clk_en <= 1'b0;
			ff_spi_cs_n <= 1'b1;
			ff_spi_mosi <= 1'b0;
			ff_spi_cmd_reg <= 8'd0;
			ff_addr_reg <= 23'd0;
			ff_wdata_reg <= 8'd0;
			ff_rdata_reg <= 8'd0;
			ff_rdata_en_reg <= 1'b0;
			ff_ready_reg <= 1'b0;
			ff_cs_wait_cnt <= 4'd0;
			ff_io_quad_out <= 1'b0;
			ff_io_out <= 4'd0;
			ff_dummy_cnt <= 3'd0;
			ff_quad_read_mode <= 1'b0;
			ff_burst_mode <= 1'b0;
			ff_burst_count <= 17'd0;
			ff_burst_rdata <= 8'd0;
			ff_burst_rdata_en <= 1'b0;
		end
		else begin
			// Default: clear data-valid pulses after one cycle
			ff_rdata_en_reg <= 1'b0;
			ff_burst_rdata_en <= 1'b0;

			case(ff_state)
				// ----------------------------------------------------
				ST_IDLE: begin
					ff_spi_cs_n <= 1'b1;
					ff_spi_clk_en <= 1'b0;
					ff_ready_reg <= 1'b1;
					// Reset Quad mode flags in idle state
					ff_io_quad_out <= 1'b0;
					ff_quad_read_mode <= 1'b0;

					if(w_valid_pulse) begin
						ff_ready_reg <= 1'b0;
						ff_addr_reg <= address;
						ff_wdata_reg <= wdata;
						// Reset I/O output register
						ff_io_out <= 4'd0;

						case(command)
							c_command_read: begin
								// Read: Send Quad I/O Read command
								ff_spi_cmd_reg <= SPI_CMD_QUAD_IO_READ;
								ff_state <= ST_SEND_CMD;
								ff_next_state <= ST_SEND_ADDR2;
								ff_return_state <= ST_READ_DATA;
								// ff_quad_read_mode is set later in ST_DUMMY_CYCLES
							end

							default: ;

							c_command_write: begin
								// Write: Need WREN first
								ff_spi_cmd_reg <= SPI_CMD_PAGE_PROGRAM;
								ff_state <= ST_SEND_WREN;
								ff_return_state <= ST_WRITE_DATA;
							end

							c_command_sector_erase: begin
								// Sector Erase: Need WREN first
								ff_spi_cmd_reg <= SPI_CMD_SECTOR_ERASE;
								ff_state <= ST_SEND_WREN;
								ff_return_state <= ST_WAIT_BUSY;
							end

							c_command_all_erase: begin
								// Chip Erase: Need WREN first
								ff_spi_cmd_reg <= SPI_CMD_CHIP_ERASE;
								ff_state <= ST_SEND_WREN;
								ff_return_state <= ST_WAIT_BUSY;
							end
						endcase
					end
					else if(w_burst_start_pulse) begin
						// Burst read mode
						ff_ready_reg <= 1'b0;
						ff_burst_mode <= 1'b1;
						ff_burst_count <= burst_length;
						ff_addr_reg <= burst_address;
						ff_io_out <= 4'd0;
						ff_spi_cmd_reg <= SPI_CMD_QUAD_IO_READ;
						ff_state <= ST_SEND_CMD;
						ff_next_state <= ST_SEND_ADDR2;
						ff_return_state <= ST_READ_DATA;
					end
				end

				// ----------------------------------------------------
				ST_SEND_WREN: begin
					// Send Write Enable command
					ff_spi_cs_n <= 1'b0;
					ff_spi_clk_en <= 1'b1;
					ff_shift_out <= SPI_CMD_WRITE_ENABLE;
					ff_bit_cnt <= 3'd7;
					ff_spi_mosi <= SPI_CMD_WRITE_ENABLE[7];
					ff_state <= ST_WREN_WAIT;
				end

				// ----------------------------------------------------
				ST_WREN_WAIT: begin
					// Sample on rising, shift on falling
					if(w_spi_rising_edge) begin
						// Rising edge - Flash samples MOSI here
						// Check if this was the last bit (bit 0)
						if(ff_bit_cnt == 3'd0) begin
							// Last bit sampled by Flash, stop clock now
							// This prevents extra clock edges
							ff_spi_clk_en <= 1'b0;
						end
					end
					if(w_spi_falling_edge) begin
						// Falling edge - update MOSI for next bit
						if(ff_bit_cnt == 3'd0) begin
							// WREN complete, go to CS high then main command
							ff_state <= ST_CS_HIGH;
							ff_next_state <= ST_SEND_CMD;
						end
						else begin
							ff_bit_cnt <= ff_bit_cnt - 3'd1;
							ff_shift_out <= {ff_shift_out[6:0], 1'b0};
							ff_spi_mosi <= ff_shift_out[6];
						end
					end
				end

				// ----------------------------------------------------
				ST_CS_HIGH: begin
					// CS high interval (required between commands)
					ff_spi_cs_n <= 1'b1;
					ff_spi_clk_en <= 1'b0;
					ff_cs_wait_cnt <= ff_cs_wait_cnt + 4'd1;
					if(ff_cs_wait_cnt >= 4'd8) begin
						ff_cs_wait_cnt <= 4'd0;
						ff_state <= ff_next_state;
					end
				end

				// ----------------------------------------------------
				// ST_SEND_CMD: Initialize command byte transmission
				ST_SEND_CMD: begin
					// Send SPI command byte
					ff_spi_cs_n <= 1'b0;
					ff_spi_clk_en <= 1'b1;
					ff_shift_out <= ff_spi_cmd_reg;
					ff_bit_cnt <= 3'd7;
					ff_spi_mosi <= ff_spi_cmd_reg[7];
					ff_state <= ST_SEND_ADDR2;		// Use ADDR2 state as byte shift loop
				end

				// ----------------------------------------------------
				// ST_SEND_ADDR2: Shift out command byte, then send address byte 2 (Quad)
				ST_SEND_ADDR2: begin
					if(w_spi_falling_edge) begin
						// Falling edge - update MOSI for next bit
						if(ff_bit_cnt == 3'd0) begin
							// Command byte complete
							if(ff_spi_cmd_reg == SPI_CMD_CHIP_ERASE) begin
								// No address for chip erase, wait for busy
								ff_spi_clk_en <= 1'b0;
								ff_state <= ST_CS_HIGH;
								ff_next_state <= ST_WAIT_BUSY;
							end
							else if(ff_spi_cmd_reg == SPI_CMD_READ_STATUS) begin
								ff_bit_cnt <= 3'd7;
								ff_state <= ST_CHECK_STATUS;
							end
							else if(ff_spi_cmd_reg == SPI_CMD_QUAD_IO_READ) begin
								// Quad I/O Read: Send address in Quad mode (4 bits per clock)
								// Address byte 2 high nibble (bits 23:16)
								// 24-bit address: [23:20] then [19:16] then [15:12] ...
								ff_io_quad_out <= 1'b1;
								ff_io_out <= {1'b0, ff_addr_reg[22:20]};	// High nibble of addr[23:16]
								ff_bit_cnt <= 3'd5;		// 6 clocks total for 24-bit address (6 nibbles)
								ff_state <= ST_SEND_ADDR1;
							end
							else begin
								// Single SPI mode: Start address byte 2 (bits 23:16)
								ff_shift_out <= {1'b0, ff_addr_reg[22:16]};
								ff_bit_cnt <= 3'd7;
								ff_spi_mosi <= 1'b0;	// MSB of addr byte 2
								ff_state <= ST_SEND_ADDR1;
							end
						end
						else begin
							ff_bit_cnt <= ff_bit_cnt - 3'd1;
							ff_shift_out <= {ff_shift_out[6:0], 1'b0};
							ff_spi_mosi <= ff_shift_out[6];
						end
					end
				end

				// ----------------------------------------------------
				// ST_SEND_ADDR1: Shift out address in Quad mode (all 6 nibbles)
				ST_SEND_ADDR1: begin
					if(w_spi_falling_edge) begin
						if(ff_io_quad_out) begin
							// Quad mode address transmission (6 nibbles = 24 bits)
							case(ff_bit_cnt)
								3'd5: ff_io_out <= ff_addr_reg[19:16];	// Nibble 1
								3'd4: ff_io_out <= ff_addr_reg[15:12];	// Nibble 2
								3'd3: ff_io_out <= ff_addr_reg[11:8];	// Nibble 3
								3'd2: ff_io_out <= ff_addr_reg[7:4];	// Nibble 4
								3'd1: ff_io_out <= ff_addr_reg[3:0];	// Nibble 5
								3'd0: begin
									// Address complete, send mode byte
									ff_io_out <= 4'hF;		// Mode byte high nibble
									ff_bit_cnt <= 3'd1;		// 2 clocks for mode byte
									ff_state <= ST_DUMMY_CYCLES;
								end
								default: ;
							endcase
							if(ff_bit_cnt != 3'd0) begin
								ff_bit_cnt <= ff_bit_cnt - 3'd1;
							end
						end
						else begin
							// Single SPI mode
							if(ff_bit_cnt == 3'd0) begin
								// Address byte 2 complete, start address byte 1 (bits 15:8)
								ff_shift_out <= ff_addr_reg[15:8];
								ff_bit_cnt <= 3'd7;
								ff_spi_mosi <= ff_addr_reg[15];
								ff_state <= ST_SEND_ADDR0;
							end
							else begin
								ff_bit_cnt <= ff_bit_cnt - 3'd1;
								ff_shift_out <= {ff_shift_out[6:0], 1'b0};
								ff_spi_mosi <= ff_shift_out[6];
							end
						end
					end
				end

				// ----------------------------------------------------
				// ST_SEND_ADDR0: Shift out address byte 1 (Single SPI mode only)
				ST_SEND_ADDR0: begin
					if(w_spi_falling_edge) begin
						// Single SPI mode only (Quad mode is handled in ST_SEND_ADDR1)
						if(ff_bit_cnt == 3'd0) begin
							// Address byte 1 complete, start address byte 0 (bits 7:0)
							ff_shift_out <= ff_addr_reg[7:0];
							ff_bit_cnt <= 3'd7;
							ff_spi_mosi <= ff_addr_reg[7];
							ff_state <= ST_SEND_ADDR_LAST;
						end
						else begin
							ff_bit_cnt <= ff_bit_cnt - 3'd1;
							ff_shift_out <= {ff_shift_out[6:0], 1'b0};
							ff_spi_mosi <= ff_shift_out[6];
						end
					end
				end

				// ----------------------------------------------------
				// ST_SEND_ADDR_LAST: Shift out address byte 0 (Single SPI mode only)
				ST_SEND_ADDR_LAST: begin
					if(w_spi_falling_edge) begin
						// Single SPI mode only (Quad mode is handled in ST_SEND_ADDR1)
						if(ff_bit_cnt == 3'd0) begin
							// Address complete, go to data phase
							if(ff_return_state == ST_WRITE_DATA) begin
								// Initialize for write
								ff_shift_out <= ff_wdata_reg;
								ff_bit_cnt <= 3'd7;
								ff_spi_mosi <= ff_wdata_reg[7];
								ff_state <= ST_WRITE_DATA;
							end
							else begin
								// Sector erase - wait for busy
								ff_spi_clk_en <= 1'b0;
								ff_state <= ST_CS_HIGH;
								ff_next_state <= ST_WAIT_BUSY;
							end
						end
						else begin
							ff_bit_cnt <= ff_bit_cnt - 3'd1;
							ff_shift_out <= {ff_shift_out[6:0], 1'b0};
							ff_spi_mosi <= ff_shift_out[6];
						end
					end
				end

				// ----------------------------------------------------
				ST_READ_DATA: begin
					// Sample IO on rising edge (Quad mode: 4 bits per clock)
					if(w_spi_rising_edge) begin
						// Quad mode: sample 4 bits at a time
						// IO[3:0] -> shift_in (IO3=MSB, IO0=LSB per nibble)
						ff_shift_in <= {ff_shift_in[3:0], w_spi_io_in};

						if(ff_bit_cnt == 3'd0) begin
							if(ff_burst_mode) begin
								// Burst read: output byte and continue
								ff_burst_rdata <= {ff_shift_in[3:0], w_spi_io_in};
								ff_burst_rdata_en <= 1'b1;
								if(ff_burst_count == 17'd0) begin
									// Last byte of burst
									ff_burst_mode <= 1'b0;
									ff_io_quad_out <= 1'b0;
									ff_state <= ST_FINISH;
								end
								else begin
									ff_burst_count <= ff_burst_count - 17'd1;
									ff_bit_cnt <= 3'd1;		// Read next byte (2 clocks)
									// Stay in ST_READ_DATA
								end
							end
							else begin
								// Single read: output and finish
								ff_rdata_reg <= {ff_shift_in[3:0], w_spi_io_in};
								ff_rdata_en_reg <= 1'b1;
								ff_io_quad_out <= 1'b0;
								ff_state <= ST_FINISH;
							end
						end
						else begin
							ff_bit_cnt <= ff_bit_cnt - 3'd1;
						end
					end
				end

				// ----------------------------------------------------
				// ST_DUMMY_CYCLES: Quad I/O Read dummy cycles (mode byte + dummy)
				ST_DUMMY_CYCLES: begin
					if(w_spi_falling_edge) begin
						if(ff_io_quad_out) begin
							// Still in mode byte phase
							if(ff_bit_cnt == 3'd0) begin
								// Mode byte complete, start dummy cycles
								// Typical: 4 dummy clocks for Quad I/O Read
								ff_io_quad_out <= 1'b0;		// Hi-Z during dummy cycles
								ff_dummy_cnt <= 3'd3;		// 4 dummy clocks (0,1,2,3)
							end
							else begin
								// Mode byte low nibble
								ff_io_out <= 4'hF;
								ff_bit_cnt <= ff_bit_cnt - 3'd1;
							end
						end
					end
					if(w_spi_rising_edge && !ff_io_quad_out) begin
						// Count dummy cycles on rising edge
						if(ff_dummy_cnt == 3'd0) begin
							// Dummy cycles complete, go to read data
							// Now IO[3:0] should be Hi-Z for flash to drive data
							ff_quad_read_mode <= 1'b1;
							ff_bit_cnt <= 3'd1;		// 2 clocks for 8 bits in Quad
							ff_state <= ST_READ_DATA;
						end
						else begin
							ff_dummy_cnt <= ff_dummy_cnt - 3'd1;
						end
					end
				end

				// ----------------------------------------------------
				ST_WRITE_DATA: begin
					if(w_spi_falling_edge) begin
						if(ff_bit_cnt == 3'd0) begin
							// Write byte complete, check busy status
							ff_spi_clk_en <= 1'b0;
							ff_state <= ST_CS_HIGH;
							ff_next_state <= ST_WAIT_BUSY;
						end
						else begin
							ff_bit_cnt <= ff_bit_cnt - 3'd1;
							ff_shift_out <= {ff_shift_out[6:0], 1'b0};
							ff_spi_mosi <= ff_shift_out[6];
						end
					end
				end

				// ----------------------------------------------------
				ST_WAIT_BUSY: begin
					// Start status read sequence
					ff_spi_cs_n <= 1'b0;
					ff_spi_clk_en <= 1'b1;
					ff_shift_out <= SPI_CMD_READ_STATUS;
					ff_bit_cnt <= 3'd7;
					ff_spi_mosi <= SPI_CMD_READ_STATUS[7];
					ff_state <= ST_READ_STATUS;
				end

				// ----------------------------------------------------
				ST_READ_STATUS: begin
					// Shift out Read Status command (8 bits)
					if(w_spi_falling_edge) begin
						if(ff_bit_cnt == 3'd0) begin
							// Command sent, now read status byte
							ff_bit_cnt <= 3'd7;
							ff_state <= ST_CHECK_STATUS;
						end
						else begin
							ff_bit_cnt <= ff_bit_cnt - 3'd1;
							ff_shift_out <= {ff_shift_out[6:0], 1'b0};
							ff_spi_mosi <= ff_shift_out[6];
						end
					end
				end

				// ----------------------------------------------------
				ST_CHECK_STATUS: begin
					// Read status byte from Flash
					if(w_spi_rising_edge) begin
						// Sample MISO on rising edge
						ff_shift_in <= {ff_shift_in[6:0], w_spi_miso};
					end
					if(w_spi_falling_edge) begin
						if(ff_bit_cnt == 3'd0) begin
							// Status byte received, check WIP bit
							// WIP is bit 0 of the status register
							if(ff_shift_in[0] == 1'b0) begin
								// Not busy, operation complete
								ff_spi_clk_en <= 1'b0;
								ff_state <= ST_FINISH;
							end
							else begin
								// Still busy, read another status byte
								ff_bit_cnt <= 3'd7;
							end
						end
						else begin
							ff_bit_cnt <= ff_bit_cnt - 3'd1;
						end
					end
				end

				// ----------------------------------------------------
				ST_FINISH: begin
					ff_spi_cs_n <= 1'b1;
					ff_spi_clk_en <= 1'b0;
					ff_io_quad_out <= 1'b0;
					ff_quad_read_mode <= 1'b0;
					ff_state <= ST_IDLE;
				end

				default: begin
					ff_state <= ST_IDLE;
				end
			endcase
		end
	end

endmodule
