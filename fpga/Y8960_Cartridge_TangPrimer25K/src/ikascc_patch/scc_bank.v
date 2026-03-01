// --------------------------------------------------------------------
//	SCC Bank
// ====================================================================
//	2026/03/02 t.hara
// --------------------------------------------------------------------

module scc_bank (
	input			clk,
	input			reset_n,
	//	SCC bank interface
	input			bus_cs,
	input	[15:0]	bus_address,
	input			bus_valid,
	output			bus_ready,
	input			bus_write,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	input			scc_memory_cs,
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

	// ---------------------------------------------------------
	//	Compatible mode
	//		BANK#0 ...#31 : Read only
	//	RAM mode
	//		BANK#0 ...#15 : Read only
	//		BANK#16...#31 : Read and write
	// ---------------------------------------------------------
	assign w_ram_mode	= scc_ma[18];

	assign bus_ready	= cpu_ready;
	assign bus_rdata	= cpu_rdata;
	assign bus_rdata_en	= cpu_rdata_en;

	assign cpu_address	= { scc_ma[17:13], bus_address[12:0] };
	assign cpu_write	= w_ram_mode & bus_write;
	assign cpu_valid	= bus_cs & bus_valid & (~bus_write | w_ram_mode);
	assign cpu_wdata	= bus_wdata;
endmodule
