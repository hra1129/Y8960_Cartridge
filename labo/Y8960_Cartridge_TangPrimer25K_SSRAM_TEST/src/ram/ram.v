// --------------------------------------------------------------------
//	SRAM 4KB
// ====================================================================
//	2026/03/21 t.hara
// --------------------------------------------------------------------

module ram (
	input			clk,
	input	[11:0]	address,
	input			mreq_n,
	input			rd_n,
	input			wr_n,
	input	[7:0]	di,
	output	[7:0]	do
);
	reg		[7:0]	ff_ram [0:4095];
	reg		[7:0]	ff_do;
	reg				ff_wr_n;

	always @( posedge clk ) begin
		ff_wr_n <= wr_n;
	end

	always @( posedge clk ) begin
		if( !rd_n ) begin
			ff_do <= ff_ram[ address ];
		end
		else if( !wr_n && ff_wr_n ) begin
			ff_ram[ address ] <= di;
		end
	end

	assign do = ff_do;
endmodule
