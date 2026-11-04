module Gowin_PLL(
	input			clkin,
	output			clkout0,
	output			clkout1,
	input			mdclk
);
	localparam	real	clk_base0	= 1_000_000_000_000.0/171_818_160.0;	//	ps
	localparam	real	clk_base1	= 1_000_000_000_000.0/24_161_930.0;		//	ps
	reg				ff_clkout0 = 1'b0;
	reg				ff_clkout1 = 1'b0;

	always #(clk_base0 / 2) begin
		ff_clkout0 <= ~ff_clkout0;
	end
	assign clkout0 = ff_clkout0;

	always #(clk_base1 / 2) begin
		ff_clkout1 <= ~ff_clkout1;
	end
	assign clkout1 = ff_clkout1;
endmodule
