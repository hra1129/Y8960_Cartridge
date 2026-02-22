module Gowin_PLL(
	input			clkin,
	output			clkout0,
	output			clkout1,
	input			mdclk
);
	localparam	clk_base	= 1_000_000_000/257.72724;	//	ps
	reg				clkout = 1'b0;

	always @( clk_base / 2 ) begin
		clkout <= ~clkout;
	end
	assign clkout0 = clkout;
	assign clkout1 = 0;
endmodule
