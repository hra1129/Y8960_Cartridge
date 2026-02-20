// --------------------------------------------------------------------
//	SerialSRAM
// ====================================================================
//	2026/01/26 t.hara
// --------------------------------------------------------------------

module ssram (
	input			clk,
	input			clk_258m,
	input			reset_n,
	input	[18:0]	address,		//	512KB
	input			valid,
	output			ready,
	input			write,
	input	[7:0]	wdata,
	output	[7:0]	rdata,
	output			rdata_en,
	output			sram_sclk,
	output			sram_ce_n,
	inout	[3:0]	sram_sio
);
	localparam		c_state_init_w0		= 5'd0;
	localparam		c_state_init_eqio0	= 5'd1;
	localparam		c_state_init_eqio1	= 5'd2;
	localparam		c_state_init_eqio2	= 5'd3;
	localparam		c_state_init_eqio3	= 5'd4;
	localparam		c_state_init_eqio4	= 5'd5;
	localparam		c_state_init_eqio5	= 5'd6;
	localparam		c_state_init_eqio6	= 5'd7;
	localparam		c_state_init_eqio7	= 5'd8;
	localparam		c_state_idle		= 5'd9;
	localparam		c_state_start		= 5'd10;
	localparam		c_state_cmd			= 5'd11;
	localparam		c_state_address0	= 5'd12;
	localparam		c_state_address1	= 5'd13;
	localparam		c_state_address2	= 5'd14;
	localparam		c_state_address3	= 5'd15;
	localparam		c_state_address4	= 5'd16;
	localparam		c_state_address5	= 5'd17;
	localparam		c_state_write0		= 5'd18;
	localparam		c_state_write1		= 5'd19;
	localparam		c_state_dummy0		= 5'd20;
	localparam		c_state_dummy1		= 5'd21;
	localparam		c_state_dummy2		= 5'd22;
	localparam		c_state_read0		= 5'd23;
	localparam		c_state_read1		= 5'd24;
	localparam		c_state_read2		= 5'd25;

	reg				ff_ready;
	reg				ff_valid_d0;
	reg				ff_valid_d1;
	wire			w_valid;
	reg		[18:0]	ff_address;
	reg		[7:0]	ff_wdata;
	reg		[7:0]	ff_rdata;
	reg				ff_rdata_en;
	reg				ff_read_complete;		// Toggle signal for read complete
	reg				ff_read_complete_sync1;
	reg				ff_read_complete_sync2;
	reg				ff_write;
	reg				ff_read;
	reg		[4:0]	ff_state;
	reg				ff_active;
	reg				ff_active_write;		// Toggle signal for write complete
	reg				ff_ce_n;
	reg		[3:0]	ff_so;
	reg				ff_sclk_div;		//	258MHz -> 129MHz divider

	// ---------------------------------------------------------
	//	SCLK divider (258MHz -> 129MHz)
	// ---------------------------------------------------------
	always @( posedge clk_258m ) begin
		if( !reset_n ) begin
			ff_sclk_div <= 1'b0;
		end
		else begin
			ff_sclk_div <= ~ff_sclk_div;
		end
	end

	wire w_sclk_timing = ~ff_sclk_div;	//	State machine timing enable (update on SCLK falling edge)
	wire w_sclk_sample = ff_sclk_div;	//	Read data sample timing (sample on SCLK rising edge)

	// ---------------------------------------------------------
	//	Access timing pulse
	// ---------------------------------------------------------
	always @( posedge clk_258m ) begin
		if( !reset_n ) begin
			ff_valid_d0 <= 1'b0;
			ff_valid_d1 <= 1'b0;
		end
		else begin
			ff_valid_d0 <= valid & ff_ready;
			if( w_sclk_timing ) begin
				ff_valid_d1 <= ff_valid_d0;
			end
		end
	end

	assign w_valid		= ff_valid_d0 & ~ff_valid_d1;

	// ---------------------------------------------------------
	//	Ready (synchronize to clk domain)
	//	- Write: ready=1 when write complete (ff_active_write toggle)
	//	- Read:  ready=1 one cycle after rdata_en=1
	// ---------------------------------------------------------
	reg ff_active_sync1;
	reg ff_active_sync2;
	reg ff_active_sync2_d;
	reg ff_active_write_sync1;
	reg ff_active_write_sync2;
	wire w_write_complete;
	wire w_read_complete;
	reg ff_busy;		// Busy flag in clk domain
	
	assign w_write_complete = ff_active_write_sync1 ^ ff_active_write_sync2;	// Detect toggle
	assign w_read_complete = ff_read_complete_sync1 ^ ff_read_complete_sync2;	// Detect toggle
	
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ready <= 1'b0;
			ff_busy <= 1'b0;
			ff_rdata_en <= 1'b0;
			ff_active_sync1 <= 1'b0;
			ff_active_sync2 <= 1'b0;
			ff_active_sync2_d <= 1'b0;
			ff_active_write_sync1 <= 1'b0;
			ff_active_write_sync2 <= 1'b0;
			ff_read_complete_sync1 <= 1'b0;
			ff_read_complete_sync2 <= 1'b0;
		end
		else begin
			// Synchronize ff_active (for init complete)
			ff_active_sync1 <= ff_active;
			ff_active_sync2 <= ff_active_sync1;
			ff_active_sync2_d <= ff_active_sync2;
			// Synchronize ff_active_write (for write complete - toggle signal)
			ff_active_write_sync1 <= ff_active_write;
			ff_active_write_sync2 <= ff_active_write_sync1;
			// Synchronize ff_read_complete (for read complete - toggle signal)
			ff_read_complete_sync1 <= ff_read_complete;
			ff_read_complete_sync2 <= ff_read_complete_sync1;
			
			// rdata_en: pulse when read complete detected
			ff_rdata_en <= w_read_complete;
			
			// Busy flag control
			if( valid & ff_ready ) begin
				// Accept request - set busy
				ff_busy <= 1'b1;
			end
			else if( w_write_complete ) begin
				// Write complete - clear busy
				ff_busy <= 1'b0;
			end
			else if( w_read_complete ) begin
				// Read complete - clear busy
				ff_busy <= 1'b0;
			end
			
			// Ready control
			if( ff_active_sync2 & ~ff_active_sync2_d ) begin
				// Init complete - ready=1
				ff_ready <= 1'b1;
			end
			else if( valid & ff_ready ) begin
				// Accept request - ready=0
				ff_ready <= 1'b0;
			end
			else if( ff_busy && w_write_complete ) begin
				// Write complete - ready=1
				ff_ready <= 1'b1;
			end
			else if( ff_rdata_en ) begin
				// Read complete - ready=1 (one cycle after rdata_en)
				ff_ready <= 1'b1;
			end
		end
	end

	assign ready		= ff_ready;

	// ---------------------------------------------------------
	//	Data latch
	// ---------------------------------------------------------
	always @( posedge clk_258m ) begin
		if( !reset_n ) begin
			ff_address	<= 19'd0;
			ff_wdata	<= 8'd0;
			ff_write	<= 1'b0;
		end
		else if( w_valid ) begin
			ff_address	<= address;
			ff_wdata	<= wdata;
			ff_write	<= write;
		end
	end

	// ---------------------------------------------------------
	//	State machine
	// ---------------------------------------------------------
	always @( posedge clk_258m ) begin
		if( !reset_n ) begin
			ff_state	<= c_state_init_w0;
			ff_active	<= 1'b0;
			ff_active_write <= 1'b0;
			ff_read_complete <= 1'b0;
			ff_ce_n		<= 1'b1;
			ff_so		<= 4'b1zz0;
			ff_read		<= 1'b0;
		end
		else if( w_sclk_timing ) begin
			case( ff_state )
			c_state_init_w0: begin
				ff_state	<= c_state_init_eqio0;
				ff_ce_n		<= 1'b0;
				ff_so		<= 4'b1zz0;
			end
			c_state_init_eqio0: begin
				ff_state	<= c_state_init_eqio1;
				ff_so		<= 4'b1zz0;
			end
			c_state_init_eqio1: begin
				ff_state	<= c_state_init_eqio2;
				ff_so		<= 4'b1zz1;
			end
			c_state_init_eqio2: begin
				ff_state	<= c_state_init_eqio3;
				ff_so		<= 4'b1zz1;
			end
			c_state_init_eqio3: begin
				ff_state	<= c_state_init_eqio4;
				ff_so		<= 4'b1zz1;
			end
			c_state_init_eqio4: begin
				ff_state	<= c_state_init_eqio5;
				ff_so		<= 4'b1zz0;
			end
			c_state_init_eqio5: begin
				ff_state	<= c_state_init_eqio6;
				ff_so		<= 4'b1zz0;
			end
			c_state_init_eqio6: begin
				ff_state	<= c_state_init_eqio7;
				ff_so		<= 4'b1zz0;
			end
			c_state_init_eqio7: begin
				ff_state	<= c_state_idle;
				ff_so		<= 4'bzzzz;
				ff_active	<= 1'b1;		// Init complete (stays high)
				ff_ce_n		<= 1'b1;
			end
			c_state_idle: begin
				if( w_valid ) begin
					ff_state	<= c_state_start;
					ff_ce_n		<= 1'b0;
					ff_so		<= 4'd0;
				end
			end
			c_state_start: begin
					if( ff_write ) begin
						ff_so		<= 4'd2;
					end
					else begin
						ff_so		<= 4'd11;
					end
					ff_state	<= c_state_cmd;
			end
			c_state_cmd: begin
				ff_so		<= 4'd0;
				ff_state	<= c_state_address0;
			end
			c_state_address0: begin
				ff_so		<= { 1'b0, ff_address[18:16] };
				ff_state	<= c_state_address1;
			end
			c_state_address1: begin
				ff_so		<= ff_address[15:12];
				ff_state	<= c_state_address2;
			end
			c_state_address2: begin
				ff_so		<= ff_address[11:8];
				ff_state	<= c_state_address3;
			end
			c_state_address3: begin
				ff_so		<= ff_address[7:4];
				ff_state	<= c_state_address4;
			end
			c_state_address4: begin
				ff_so		<= ff_address[3:0];
				ff_state	<= c_state_address5;
			end
			c_state_address5: begin
				if( ff_write ) begin
					ff_state	<= c_state_write0;
					ff_so		<= ff_wdata[7:4];
				end
				else begin
					ff_state	<= c_state_dummy0;
					ff_so		<= 4'bzzzz;
				end
			end
			c_state_write0: begin
				ff_so		<= ff_wdata[3:0];
				ff_state	<= c_state_write1;
			end
			c_state_write1: begin
				ff_so		<= 4'bzzzz;
				ff_state	<= c_state_idle;
				ff_active_write	<= ~ff_active_write;	// Toggle on write complete
				ff_ce_n		<= 1'b1;
			end
			c_state_dummy0: begin
				ff_read		<= 1'b1;
				ff_so		<= 4'bzzzz;
				ff_state	<= c_state_dummy1;
			end
			c_state_dummy1: begin
				ff_state	<= c_state_dummy2;
			end
			c_state_dummy2: begin
				ff_state		<= c_state_read0;
			end
			c_state_read0: begin
				ff_state		<= c_state_read1;
			end
			c_state_read1: begin
				ff_state		<= c_state_read2;
			end
			c_state_read2: begin
				ff_state		<= c_state_idle;
				ff_ce_n			<= 1'b1;
				ff_read			<= 1'b0;
				ff_read_complete <= ~ff_read_complete;	// Toggle on read complete
			end
			endcase
		end
	end

	// Sample read data on SCLK rising edge
	always @( posedge clk_258m ) begin
		if( !reset_n ) begin
			ff_rdata <= 8'd0;
		end
		else if( w_sclk_sample ) begin
			if( ff_state == c_state_read0 ) begin
				ff_rdata[7:4] <= sram_sio;
			end
			else if( ff_state == c_state_read1 ) begin
				ff_rdata[3:0] <= sram_sio;
			end
		end
	end

	assign sram_sclk	= ff_sclk_div & ~ff_ce_n;
	assign sram_ce_n	= ff_ce_n;
	assign sram_sio		= ff_read ? 4'bzzzz: ff_so;
	assign rdata		= ff_rdata;
	assign rdata_en		= ff_rdata_en;
endmodule
