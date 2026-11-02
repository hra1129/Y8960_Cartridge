// --------------------------------------------------------------------
//	SerialSRAM (Microchip 23AA04M, SQI mode)
// ====================================================================
//	2026/01/26 t.hara
// --------------------------------------------------------------------
//	bus_ready
//		1 when the controller can accept a new request.
//		It falls in the clock following an accepted request and rises again
//		when the serial side has completed the request.
//	bus_burst (write only)
//		1: more sequential writes follow. CE# stays low and SCLK stops after
//		   the data byte, and the next write streams only the data byte.
//		   bus_address of following writes is ignored (sequential mode).
//		0: the burst ends with this write.
//	bus_rdata_en
//		One clock pulse when bus_rdata holds the requested read data.
// --------------------------------------------------------------------

module ssram (
	input			n_reset,
	input			clk,
	input			clk_serial,
	input			bus_cs,
	input	[18:0]	bus_address,
	input			bus_write,
	input			bus_burst,
	input			bus_valid,
	input	[7:0]	bus_wdata,
	output			bus_ready,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	//	SPI SRAM I/F
	output			sram_sclk,
	output			sram_ce_n,
	inout	[3:0]	sram_sio
);
	localparam	[5:0]	c_state_init_w0		= 6'd0;
	localparam	[5:0]	c_state_init_eqio0	= 6'd1;
	localparam	[5:0]	c_state_init_eqio1	= 6'd2;
	localparam	[5:0]	c_state_init_eqio2	= 6'd3;
	localparam	[5:0]	c_state_init_eqio3	= 6'd4;
	localparam	[5:0]	c_state_init_eqio4	= 6'd5;
	localparam	[5:0]	c_state_init_eqio5	= 6'd6;
	localparam	[5:0]	c_state_init_eqio6	= 6'd7;
	localparam	[5:0]	c_state_init_eqio7	= 6'd8;
	localparam	[5:0]	c_state_idle		= 6'd9;
	localparam	[5:0]	c_state_start		= 6'd10;
	localparam	[5:0]	c_state_cmd			= 6'd11;
	localparam	[5:0]	c_state_address0	= 6'd12;
	localparam	[5:0]	c_state_address1	= 6'd13;
	localparam	[5:0]	c_state_address2	= 6'd14;
	localparam	[5:0]	c_state_address3	= 6'd15;
	localparam	[5:0]	c_state_address4	= 6'd16;
	localparam	[5:0]	c_state_address5	= 6'd17;
	localparam	[5:0]	c_state_write0		= 6'd18;
	localparam	[5:0]	c_state_write1		= 6'd19;
	localparam	[5:0]	c_state_dummy0		= 6'd20;
	localparam	[5:0]	c_state_dummy1		= 6'd21;
	localparam	[5:0]	c_state_dummy2		= 6'd22;
	localparam	[5:0]	c_state_dummy3		= 6'd23;
	localparam	[5:0]	c_state_dummy4		= 6'd24;
	localparam	[5:0]	c_state_dummy5		= 6'd25;
	localparam	[5:0]	c_state_read0		= 6'd26;
	localparam	[5:0]	c_state_read1		= 6'd27;
	localparam	[5:0]	c_state_read2		= 6'd28;
	localparam	[5:0]	c_state_read3		= 6'd29;
	localparam	[5:0]	c_state_read_wait	= 6'd30;
	localparam	[5:0]	c_state_init_rstio0	= 6'd31;
	localparam	[5:0]	c_state_init_rstio1	= 6'd32;
	localparam	[5:0]	c_state_init_rstio2	= 6'd33;
	localparam	[5:0]	c_state_burst_wait	= 6'd34;
	localparam	[5:0]	c_state_restart		= 6'd35;
	localparam [13:0]	c_powerup_wait_count = 14'd10000;	// 116us at 85.9MHz SCLK timing tick

	//	clk domain
	reg				ff_req_toggle_clk;
	reg		[18:0]	ff_req_address_clk;
	reg				ff_req_write_clk;
	reg				ff_req_burst_clk;
	reg		[7:0]	ff_req_wdata_clk;
	reg				ff_ack_s1;
	reg				ff_ack_s2;
	reg				ff_ack_s3;
	reg				ff_init_s1;
	reg				ff_init_s2;
	wire			w_req;
	wire			w_ready;

	//	clk_serial domain
	reg				ff_req_toggle_200_d0;
	reg				ff_req_toggle_200_d1;
	reg				ff_valid_d0;
	reg				ff_valid_d1;
	wire			w_valid;
	reg		[18:0]	ff_address;
	reg		[7:0]	ff_wdata;
	reg		[7:0]	ff_rdata;
	reg				ff_write;
	reg				ff_burst;
	reg				ff_read;
	reg		[5:0]	ff_state;
	reg				ff_init_done;
	reg				ff_ack_toggle;
	reg				ff_ce_n;
	reg				ff_sclk_en;
	reg		[3:0]	ff_so;
	reg				ff_sclk_div;
	reg				ff_sclk;
	reg		[13:0]	ff_powerup_wait;

	assign w_req	= bus_cs && bus_valid;

	// ---------------------------------------------------------
	//	clk domain: request / completion handshake
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !n_reset ) begin
			ff_ack_s1	<= 1'b0;
			ff_ack_s2	<= 1'b0;
			ff_ack_s3	<= 1'b0;
			ff_init_s1	<= 1'b0;
			ff_init_s2	<= 1'b0;
		end
		else begin
			ff_ack_s1	<= ff_ack_toggle;
			ff_ack_s2	<= ff_ack_s1;
			ff_ack_s3	<= ff_ack_s2;
			ff_init_s1	<= ff_init_done;
			ff_init_s2	<= ff_init_s1;
		end
	end

	assign w_ready	= ff_init_s2 && (ff_ack_s2 == ff_req_toggle_clk);

	always @( posedge clk ) begin
		if( !n_reset ) begin
			ff_req_toggle_clk	<= 1'b0;
			ff_req_address_clk	<= 19'd0;
			ff_req_write_clk	<= 1'b0;
			ff_req_burst_clk	<= 1'b0;
			ff_req_wdata_clk	<= 8'd0;
		end
		else if( w_req && w_ready ) begin
			ff_req_address_clk	<= bus_address;
			ff_req_write_clk	<= bus_write;
			ff_req_burst_clk	<= bus_write & bus_burst;
			ff_req_wdata_clk	<= bus_wdata;
			ff_req_toggle_clk	<= ~ff_req_toggle_clk;
		end
	end

	// Internal SCLK divider: input clock is 171.8MHz, output SCLK becomes half-rate.
	always @( posedge clk_serial ) begin
		if( !n_reset ) begin
			ff_sclk_div <= 1'b0;
		end
		else begin
			ff_sclk_div <= ~ff_sclk_div;
		end
	end

	// ---------------------------------------------------------
	//	Request synchronizer (clk -> clk_serial)
	// ---------------------------------------------------------
	always @( posedge clk_serial ) begin
		if( !n_reset ) begin
			ff_req_toggle_200_d0 <= 1'b0;
			ff_req_toggle_200_d1 <= 1'b0;
		end
		else begin
			ff_req_toggle_200_d0 <= ff_req_toggle_clk;
			ff_req_toggle_200_d1 <= ff_req_toggle_200_d0;
		end
	end

	always @( posedge clk_serial ) begin
		if( !n_reset ) begin
			ff_valid_d0 <= 1'b0;
			ff_valid_d1 <= 1'b0;
		end
		else if( ff_sclk_div ) begin
			ff_valid_d0 <= ff_req_toggle_200_d1;
			ff_valid_d1 <= ff_valid_d0;
		end
	end

	assign w_valid		= ff_valid_d0 ^ ff_valid_d1;

	// ---------------------------------------------------------
	//	Data latch
	// ---------------------------------------------------------
	always @( posedge clk_serial ) begin
		if( !n_reset ) begin
			ff_wdata	<= 8'd0;
		end
		else if( ff_sclk_div && w_valid ) begin
			ff_wdata	<= ff_req_wdata_clk;
		end
	end

	// ---------------------------------------------------------
	//	State machine
	// ---------------------------------------------------------
	always @( posedge clk_serial ) begin
		if( !n_reset ) begin
			ff_state		<= c_state_init_w0;
			ff_ce_n			<= 1'b1;
			ff_sclk_en		<= 1'b1;
			ff_init_done	<= 1'b0;
			ff_ack_toggle	<= 1'b0;
			ff_so			<= 4'b1zz0;
			ff_address		<= 19'd0;
			ff_read			<= 1'b0;
			ff_write		<= 1'b0;
			ff_burst		<= 1'b0;
			ff_powerup_wait	<= 14'd0;
		end
		else if( ff_sclk_div ) begin
			case( ff_state )
			//	RSTIO (Reset Quad I/O) ----------------------------------------
			//	FFh in SQI mode (2 SCLK). When the SRAM is already in SQI mode
			//	(e.g. after an MSX reset), this returns it to SPI mode. In SPI
			//	mode, these 2 SCLK form an incomplete command and are ignored.
			c_state_init_w0: begin
				// Datasheet TPU timing: do not assert CS for at least 100us after power-up.
				if( ff_powerup_wait == c_powerup_wait_count - 14'd1 ) begin
					ff_state		<= c_state_init_rstio0;
					ff_ce_n			<= 1'b0;
					ff_so			<= 4'b1111;
				end
				else begin
					ff_powerup_wait	<= ff_powerup_wait + 14'd1;
					ff_ce_n			<= 1'b1;
					ff_so			<= 4'bzzzz;
				end
			end
			c_state_init_rstio0: begin
				ff_state		<= c_state_init_rstio1;
				ff_so			<= 4'b1111;
			end
			c_state_init_rstio1: begin
				ff_state		<= c_state_init_rstio2;
				ff_ce_n			<= 1'b1;
				ff_so			<= 4'bzzzz;
				ff_powerup_wait	<= 14'd0;
			end
			c_state_init_rstio2: begin
				//	CE# high time before EQIO
				if( ff_powerup_wait == 14'd7 ) begin
					ff_state		<= c_state_init_eqio0;
					ff_ce_n			<= 1'b0;
					ff_so			<= 4'b1zz0;
				end
				else begin
					ff_powerup_wait	<= ff_powerup_wait + 14'd1;
				end
			end
			//	EQIO (Enable Quad I/O Instruction) -----------------------------
			//	            __                                __
			//	sram_ce_n     ________________________________
			//	            __  __  __  __  __  __  __  __  __  
			//	sram_sclk     __  __  __  __  __  __  __  __  __
			//	            __        ____________            
			//	sram_sio[0]   _0___0__ 1   1   1  _0___0___0____ SI
			//	
			//	sram_sio[1] ---Z-------------------------------- SO
			//	
			//	sram_sio[2] ---Z-------------------------------- N/A
			//	            ____________________________________
			//	sram_sio[3]    1                                 /HOLD
			//
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
				ff_state		<= c_state_idle;
				ff_so			<= 4'bzzzz;
				ff_init_done	<= 1'b1;
				ff_ce_n			<= 1'b1;
			end
			//	IDLE -----------------------------------------------------------
			c_state_idle: begin
				if( w_valid ) begin
					//	1st nibble: 0000
					ff_state	<= c_state_start;
					ff_ce_n		<= 1'b0;
					ff_sclk_en	<= 1'b1;
					ff_so		<= 4'd0;
					ff_address	<= ff_req_address_clk;
					ff_write	<= ff_req_write_clk;
					ff_burst	<= ff_req_burst_clk;
				end
			end
			c_state_restart: begin
				//	Read request after a burst write: keep CE# high, then start a new command.
				if( ff_powerup_wait == 14'd3 ) begin
					ff_state	<= c_state_start;
					ff_ce_n		<= 1'b0;
					ff_sclk_en	<= 1'b1;
					ff_so		<= 4'd0;
				end
				else begin
					ff_powerup_wait	<= ff_powerup_wait + 14'd1;
				end
			end
			c_state_start: begin
					if( ff_write ) begin
						//	2nd nibble: BYTE WRITE (SQI MODE)
						ff_so		<= 4'd2;
					end
					else begin
						//	2nd nibble: HIGH SPEED READ (Read memory cmmand)
						ff_so		<= 4'd11;
					end
					ff_state	<= c_state_cmd;
			end
			c_state_cmd: begin
				//	3rd nibble: address0
				ff_so		<= 4'd0;
				ff_state	<= c_state_address0;
			end
			c_state_address0: begin
				//	4th nibble: address1
				ff_so		<= { 1'b0, ff_address[18:16] };
				ff_state	<= c_state_address1;
			end
			c_state_address1: begin
				//	5th nibble: address2
				ff_so		<= ff_address[15:12];
				ff_state	<= c_state_address2;
			end
			c_state_address2: begin
				//	6th nibble: address3
				ff_so		<= ff_address[11:8];
				ff_state	<= c_state_address3;
			end
			c_state_address3: begin
				//	7th nibble: address4
				ff_so		<= ff_address[7:4];
				ff_state	<= c_state_address4;
			end
			c_state_address4: begin
				//	8th nibble: address5
				ff_so		<= ff_address[3:0];
				ff_state	<= c_state_address5;
			end
			c_state_address5: begin
				if( ff_write ) begin
					//	9th nibble: BYTE WRITE upper nibble
					ff_state	<= c_state_write0;
					ff_so		<= ff_wdata[7:4];
				end
				else begin
					//	upper nibble 1st byte
					ff_state	<= c_state_dummy0;
					ff_so		<= 4'bzzzz;
				end
			end
			// BYTE WRITE ------------------------------------------------------
			c_state_write0: begin
				//	10th nibble: BYTE WRITE lower nibble
				ff_so		<= ff_wdata[3:0];
				ff_state	<= c_state_write1;
			end
			c_state_write1: begin
				ff_so			<= 4'bzzzz;
				ff_ack_toggle	<= ~ff_ack_toggle;
				if( ff_burst ) begin
					//	keep CE# low and stop SCLK until the next sequential byte
					ff_state	<= c_state_burst_wait;
					ff_sclk_en	<= 1'b0;
				end
				else begin
					//	finish: BYTE WRITE
					ff_state	<= c_state_idle;
					ff_ce_n		<= 1'b1;
				end
			end
			c_state_burst_wait: begin
				if( w_valid ) begin
					if( ff_req_write_clk ) begin
						//	next sequential byte: upper nibble
						ff_state	<= c_state_write0;
						ff_sclk_en	<= 1'b1;
						ff_so		<= ff_req_wdata_clk[7:4];
						ff_burst	<= ff_req_burst_clk;
					end
					else begin
						//	a read request terminates the burst
						ff_state	<= c_state_restart;
						ff_ce_n		<= 1'b1;
						ff_powerup_wait	<= 14'd0;
						ff_address	<= ff_req_address_clk;
						ff_write	<= 1'b0;
						ff_burst	<= 1'b0;
					end
				end
			end
			// HIGH SPEED BYTE READ --------------------------------------------
			c_state_dummy0: begin
				//	lower nibble 1st byte
				ff_read		<= 1'b1;
				ff_so		<= 4'bzzzz;
				ff_state	<= c_state_dummy1;
			end
			c_state_dummy1: begin
				//	upper nibble 2nd byte
				ff_state	<= c_state_dummy2;
			end
			c_state_dummy2: begin
				//	lower nibble 2nd byte
				ff_state	<= c_state_dummy3;
			end
			c_state_dummy3: begin
				//	upper nibble 3rd byte
				ff_state	<= c_state_dummy4;
			end
			c_state_dummy4: begin
				//	lower nibble 3rd byte
				ff_state	<= c_state_dummy5;
			end
			c_state_dummy5: begin
				// One nibble turnaround before the data phase. (This was
				// hardware-only under an `ifdef SIM fork; the fork is
				// removed so simulation and hardware always take the
				// same path - the read_wait state also carries the
				// upper-nibble capture, see the sample block below.)
				ff_state		<= c_state_read_wait;
			end
			c_state_read_wait: begin
				ff_state		<= c_state_read0;
			end
			c_state_read0: begin
				//	upper nibble read byte
				ff_state		<= c_state_read1;
			end
			c_state_read1: begin
				//	lower nibble read byte
				ff_state		<= c_state_read2;
			end
			c_state_read2: begin
				ff_state		<= c_state_read3;
				ff_ce_n			<= 1'b1;
				ff_read			<= 1'b0;
			end
			c_state_read3: begin
				//	ff_rdata is stable here; notify completion.
				ff_state		<= c_state_idle;
				ff_ack_toggle	<= ~ff_ack_toggle;
			end
			default: begin
				ff_state		<= c_state_idle;
				ff_ce_n			<= 1'b1;
			end
			endcase
		end
	end

	// Sample read data at the end of the SCLK high phase (Route A fix).
	// The capture edge (ff_sclk_div == 1) is the edge that makes the
	// registered SCLK fall, so the value captured here is the nibble that
	// was valid during the high phase. The next nibble is launched by the
	// SRAM in response to that falling edge, which leaves the FPGA only
	// after this capture, so it cannot be picked up by mistake. This is
	// the same sampling phase as FPGA_MSXtR's ssram (w_sclk_sample).
	// (Previously the capture used !ff_sclk_div, half a serial period
	// earlier, which left the hold-side margin dependent on the board
	// round-trip delay.)
	// Note the capture states sit one state earlier than before
	// (read_wait for the upper nibble, read0 for the lower): this FSM
	// advances on ff_sclk_div == 1 edges, so the end-of-high-phase
	// capture for a nibble falls in the state preceding the one the old
	// mid-phase capture used.
	always @( posedge clk_serial ) begin
		if( !n_reset ) begin
			ff_rdata <= 8'd0;
		end
		else begin
			if( ff_sclk_div && !ff_ce_n && ff_state == c_state_read_wait ) begin
				ff_rdata[7:4] <= sram_sio;
			end
			else if( ff_sclk_div && !ff_ce_n && ff_state == c_state_read0 ) begin
				ff_rdata[3:0] <= sram_sio;
			end
		end
	end

	// Registered SCLK (glitch free). ff_ce_n and ff_sclk_en change only when
	// ff_sclk_div falls, so this equals ff_sclk_div & ~ff_ce_n & ff_sclk_en.
	always @( posedge clk_serial ) begin
		if( !n_reset ) begin
			ff_sclk <= 1'b0;
		end
		else begin
			ff_sclk <= ~ff_sclk_div & ~ff_ce_n & ff_sclk_en;
		end
	end

	assign sram_sclk	= ff_sclk;
	assign sram_ce_n	= ff_ce_n;
	assign sram_sio		= ff_read ? 4'bzzzz: ff_so;
	assign bus_ready	= w_ready;
	assign bus_rdata	= ff_rdata;
	//	ff_req_write_clk is not updated until the next request, which needs bus_ready.
	assign bus_rdata_en	= (ff_ack_s2 != ff_ack_s3) & ~ff_req_write_clk;
endmodule
