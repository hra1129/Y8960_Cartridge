// --------------------------------------------------------------------
//	Gowin_PLL simulation stub
// ====================================================================
//	Replaces the real Gowin_PLL (with Gowin PLLA primitive + PLL_INIT)
//	for behavioural simulation.
//
//	Output clock: 28.63636 MHz * 4 = 114.54544 MHz
// --------------------------------------------------------------------

`timescale 1ns/1ps

module Gowin_PLL (
	input			clkin,
	output	reg		clkout0,
	input			mdclk
);
	localparam	real	CLK_PERIOD	= 1000.0 / 200.452;	//	200.452MHz

	initial begin
		clkout0 = 1'b0;
	end

	always #(CLK_PERIOD / 2.0) begin
		clkout0 = ~clkout0;
	end
endmodule
