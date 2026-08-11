// --------------------------------------------------------------------
//	SRAM 4KB
// ====================================================================
//	2026/03/21 t.hara
// --------------------------------------------------------------------

module ram (
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
	reg		[7:0]	ff_ram [0:4095];
	reg		[7:0]	ff_rdata;
	reg				ff_rdata_en;
	wire			w_rd_valid;
	wire			w_wr_valid;

	assign w_rd_valid = bus_cs && bus_valid && !bus_write;
	assign w_wr_valid = bus_cs && bus_valid && bus_write;

	always @( posedge clk ) begin
		if( !n_reset ) begin
			ff_rdata <= 8'd0;
			ff_rdata_en <= 1'b0;
		end
		else begin
			if( w_wr_valid ) begin
				ff_ram[ bus_address[11:0] ] <= bus_wdata;
				ff_rdata_en <= 1'b0;
			end
			else if( w_rd_valid ) begin
				ff_rdata <= ff_ram[ bus_address[11:0] ];
				ff_rdata_en <= 1'b1;
			end
			else begin
				ff_rdata_en <= 1'b0;
			end
		end
	end

	assign bus_ready	= 1'b1;
	assign bus_rdata	= ff_rdata;
	assign bus_rdata_en	= ff_rdata_en;
endmodule
