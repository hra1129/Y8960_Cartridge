// --------------------------------------------------------------------
//	SCC Bank
// ====================================================================
//	2026/03/02 t.hara
// --------------------------------------------------------------------
//	Bridges MSX memory accesses to the SCC mapper area (4000h-BFFFh) to
//	the SerialSRAM through sram_arbiter.
//
//	SerialSRAM map (CPU side, 18bit = BANK#0-#31 x 8KB)
//		00000h-1FFFFh : BANK#0 -#15 ... ROM (boot copy of SPI ROM 7E0000h-)
//		20000h-3FFFFh : BANK#16-#31 ... RAM (writable in RAM mode only,
//		                                except through BANK0 at 4000h-5FFFh)
//
//	Read
//		/WAIT is asserted as soon as a read is detected and is released
//		when the read data is delivered to msx_slot.
//	Write
//		Posted write (2 entries). The Z80 cannot be stopped in time for a
//		write cycle, so the write is queued immediately. While the queue is
//		full, /WAIT is asserted so the next bus cycle is held until one
//		entry has been written. Queued writes are always executed before a
//		read, so a read after a write returns the new data.
// --------------------------------------------------------------------

module scc_bank (
	input			clk,
	input			reset_n,
	//	SCC bank interface
	input			bus_cs,
	input	[15:0]	bus_address,
	input			bus_io,				//	1: current MSX transaction is I/O
	input			bus_valid,
	input			bus_write,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	output			wait_n,
	input			scc_memory_cs_n,	//	0: SCC mapper memory area (not SCC register window)
	input	[18:13]	scc_ma,
	//	SRAM interface for SerialSRAM
	output	[17:0]	cpu_address,
	output			cpu_valid,
	input			cpu_ready,
	output			cpu_write,
	output	[7:0]	cpu_wdata,
	input	[7:0]	cpu_rdata,
	input			cpu_rdata_en
);
	wire			w_ram_mode;		//	0: Compatible mode, 1: RAM mode
	wire			w_writable;
	wire			w_access;
	wire			w_start;
	wire			w_start_read;
	wire			w_push;
	wire			w_pop;
	wire			w_read_issue;
	wire	[17:0]	w_address;

	reg				ff_access_d = 1'b0;
	reg		[1:0]	ff_q_count = 2'd0;
	reg		[17:0]	ff_q_address0 = 18'd0;
	reg		[7:0]	ff_q_wdata0 = 8'd0;
	reg		[17:0]	ff_q_address1 = 18'd0;
	reg		[7:0]	ff_q_wdata1 = 8'd0;
	reg				ff_rd_pending = 1'b0;
	reg				ff_rd_issued = 1'b0;
	reg		[17:0]	ff_rd_address = 18'd0;

	// ---------------------------------------------------------
	//	Compatible mode
	//		BANK#0 ...#31 : Read only
	//	RAM mode
	//		BANK#0 ...#15 : Read only
	//		BANK#16...#31 : Read and write
	//		(BANK0 page, 4000h-5FFFh, is always read only. It holds the
	//		 mode/bank registers 4?FBh-4?FFh.)
	// ---------------------------------------------------------
	assign w_ram_mode	= scc_ma[18];
	assign w_writable	= w_ram_mode & scc_ma[17] & (bus_address[15:13] != 3'b010);
	assign w_address	= { scc_ma[17:13], bus_address[12:0] };

	// ---------------------------------------------------------
	//	Access detection
	//	bus_valid is held by msx_slot until the SCC accepts it, so the
	//	first clock of (bus_cs & bus_valid) is the start of an access.
	// ---------------------------------------------------------
	assign w_access		= bus_cs & bus_valid;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_access_d	<= 1'b0;
		end
		else begin
			ff_access_d	<= w_access;
		end
	end

	assign w_start		= w_access & ~ff_access_d & ~scc_memory_cs_n;
	assign w_start_read	= w_start & ~bus_write;
	assign w_push		= w_start &  bus_write & w_writable;

	// ---------------------------------------------------------
	//	Posted write queue (2 entries, entry0 is the head)
	// ---------------------------------------------------------
	assign w_pop		= (ff_q_count != 2'd0) & cpu_ready;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_q_count		<= 2'd0;
			ff_q_address0	<= 18'd0;
			ff_q_wdata0		<= 8'd0;
			ff_q_address1	<= 18'd0;
			ff_q_wdata1		<= 8'd0;
		end
		else begin
			case( { w_push, w_pop } )
			2'b10: begin
				if( ff_q_count == 2'd0 ) begin
					ff_q_address0	<= w_address;
					ff_q_wdata0		<= bus_wdata;
				end
				else if( ff_q_count == 2'd1 ) begin
					ff_q_address1	<= w_address;
					ff_q_wdata1		<= bus_wdata;
				end
				//	The queue cannot overflow: /WAIT is asserted while it is full.
				if( ff_q_count != 2'd2 ) begin
					ff_q_count		<= ff_q_count + 2'd1;
				end
			end
			2'b01: begin
				ff_q_address0	<= ff_q_address1;
				ff_q_wdata0		<= ff_q_wdata1;
				ff_q_count		<= ff_q_count - 2'd1;
			end
			2'b11: begin
				if( ff_q_count == 2'd1 ) begin
					ff_q_address0	<= w_address;
					ff_q_wdata0		<= bus_wdata;
				end
				else begin
					ff_q_address0	<= ff_q_address1;
					ff_q_wdata0		<= ff_q_wdata1;
					ff_q_address1	<= w_address;
					ff_q_wdata1		<= bus_wdata;
				end
			end
			default: begin
				//	hold
			end
			endcase
		end
	end

	// ---------------------------------------------------------
	//	Read
	// ---------------------------------------------------------
	assign w_read_issue	= ff_rd_pending & ~ff_rd_issued & (ff_q_count == 2'd0);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_rd_pending	<= 1'b0;
			ff_rd_issued	<= 1'b0;
			ff_rd_address	<= 18'd0;
		end
		else if( w_start_read ) begin
			ff_rd_pending	<= 1'b1;
			ff_rd_issued	<= 1'b0;
			ff_rd_address	<= w_address;
		end
		else if( ff_rd_issued && cpu_rdata_en ) begin
			ff_rd_pending	<= 1'b0;
			ff_rd_issued	<= 1'b0;
		end
		else if( w_read_issue && cpu_ready ) begin
			ff_rd_issued	<= 1'b1;
		end
	end

	// ---------------------------------------------------------
	//	SRAM request (queued writes first)
	// ---------------------------------------------------------
	assign cpu_valid	= (ff_q_count != 2'd0) | w_read_issue;
	assign cpu_write	= (ff_q_count != 2'd0);
	assign cpu_address	= (ff_q_count != 2'd0) ? ff_q_address0 : ff_rd_address;
	assign cpu_wdata	= ff_q_wdata0;

	//	Without /WAIT the response may arrive after the memory read cycle has
	//	ended. It must not be returned in a following I/O cycle.
	assign bus_rdata_en	= ff_rd_issued & cpu_rdata_en & ~bus_io;
	assign bus_rdata	= bus_rdata_en ? cpu_rdata : 8'hFF;

	assign wait_n		= ~( w_start_read | ff_rd_pending | (ff_q_count == 2'd2) );
endmodule