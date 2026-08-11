// --------------------------------------------------------------------
//	ROM 16KB
// ====================================================================
//	2026/03/21 t.hara
// --------------------------------------------------------------------

module rom (
	input			n_reset,
	input			clk,
	input			bus_cs,
	input	[15:0]	bus_address,
	input			bus_write,
	input			bus_valid,
	input	[7:0]	bus_wdata,
	output			bus_ready,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en
);
	reg		[7:0]	ff_rom_q;
	reg				ff_rdata_en;
	wire			w_read_valid;

	assign w_read_valid = bus_cs && bus_valid && !bus_write;

	always @( posedge clk ) begin
		if( !n_reset ) begin
			ff_rom_q <= 8'd0;
			ff_rdata_en <= 1'b0;
		end
		else begin
			if( w_read_valid ) begin
				case( bus_address[11:0] )
				`include "bootrom.vh"
				endcase
				ff_rdata_en <= 1'b1;
			end
			else begin
				ff_rdata_en <= 1'b0;
			end
		end
	end

	assign bus_ready	= 1'b1;
	assign bus_rdata	= ff_rom_q;
	assign bus_rdata_en = ff_rdata_en;
endmodule
