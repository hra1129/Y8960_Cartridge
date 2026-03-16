module Gowin_PLL(
	input			clkin,
	output			clkout0,
	output			clkout1,
	input			mdclk
);
	localparam	clk_base0	= 1_000_000_000/257.72724;	//	ps
	localparam	clk_base1	= 1_000_000_000/24.576;		//	ps
	reg				ff_clkout0 = 1'b0;
	reg				ff_clkout1 = 1'b0;

	always @( clk_base0 / 2 ) begin
		ff_clkout0 <= ~ff_clkout0;
	end
	assign clkout0 = ff_clkout0;

	always @( clk_base1 / 2 ) begin
		ff_clkout1 <= ~ff_clkout1;
	end
	assign clkout1 = ff_clkout1;
endmodule
