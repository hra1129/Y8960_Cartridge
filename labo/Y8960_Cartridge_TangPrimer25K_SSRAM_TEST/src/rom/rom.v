// --------------------------------------------------------------------
//	ROM 16KB
// ====================================================================
//	2026/03/21 t.hara
// --------------------------------------------------------------------

module rom (
	input			clk,
	input	[13:0]	address,
	input			mreq_n,
	input			rd_n,
	input	[7:0]	di,
	output	[7:0]	do
);
	reg		[7:0]	ff_rom [0:16383];
	reg		[7:0]	ff_do;

	initial begin
		`include "rom_image.v"
	end

	always @( posedge clk ) begin
		if( !rd_n ) begin
			ff_do <= ff_rom[ address ];
		end
	end

	assign do = ff_do;
endmodule
