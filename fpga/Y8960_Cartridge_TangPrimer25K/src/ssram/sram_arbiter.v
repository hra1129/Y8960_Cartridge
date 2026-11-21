// --------------------------------------------------------------------
//	SRAM Arbiter
// ====================================================================
//	2026/03/01 t.hara
// --------------------------------------------------------------------

module sram_arbiter (
	input			clk,
	input			reset_n,
	//	SRAM interface for CPU side
	input	[17:0]	cpu_address,
	input			cpu_valid,
	output			cpu_ready,
	input			cpu_write,
	input	[7:0]	cpu_wdata,
	output	[7:0]	cpu_rdata,
	output			cpu_rdata_en,
	//	SRAM interface for ADPCM side
	input	[17:0]	adpcm_address,
	input			adpcm_valid,
	output			adpcm_ready,
	input			adpcm_write,
	input	[7:0]	adpcm_wdata,
	output	[7:0]	adpcm_rdata,
	output			adpcm_rdata_en,
	//	SRAM interface for SerialSRAM
	output	[18:0]	ssram_address,
	output			ssram_valid,
	input			ssram_ready,
	output			ssram_write,
	output	[7:0]	ssram_wdata,
	input	[7:0]	ssram_rdata,
	input			ssram_rdata_en
);
	reg				ff_adpcm_owner = 1'b0;
	wire			w_cpu_select;

	// ---------------------------------------------------------
	//	Arbitration (CPU has priority)
	//	ssram accepts a request when ssram_valid & ssram_ready, and
	//	ssram_ready does not return before the read data (ssram_rdata_en)
	//	of that request, so the owner of the last accepted request is the
	//	destination of ssram_rdata_en.
	// ---------------------------------------------------------
	assign w_cpu_select		= cpu_valid;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_adpcm_owner <= 1'b0;
		end
		else if( ssram_valid && ssram_ready ) begin
			ff_adpcm_owner <= ~w_cpu_select;
		end
	end

	assign ssram_address	= w_cpu_select ? { 1'b0, cpu_address } : { 1'b1, adpcm_address };
	assign ssram_write		= w_cpu_select ? cpu_write : adpcm_write;
	assign ssram_wdata		= w_cpu_select ? cpu_wdata : adpcm_wdata;
	assign ssram_valid		= cpu_valid | adpcm_valid;

	assign cpu_ready		= ssram_ready;
	assign adpcm_ready		= ssram_ready & ~w_cpu_select;

	assign cpu_rdata		= ssram_rdata;
	assign cpu_rdata_en		= ssram_rdata_en & ~ff_adpcm_owner;
	assign adpcm_rdata		= ssram_rdata;
	assign adpcm_rdata_en	= ssram_rdata_en & ff_adpcm_owner;
endmodule