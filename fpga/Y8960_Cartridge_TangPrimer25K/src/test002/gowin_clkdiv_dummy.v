// -----------------------------------------------------------------------------
//	Simulation model of Gowin_CLKDIV (divide by 4)
// -----------------------------------------------------------------------------

module Gowin_CLKDIV(
	output			clkout,
	input			hclkin,
	input			resetn
);
	reg		[1:0]	ff_count = 2'd0;

	always @( posedge hclkin or negedge resetn ) begin
		if( !resetn ) begin
			ff_count <= 2'd0;
		end
		else begin
			ff_count <= ff_count + 2'd1;
		end
	end

	assign clkout = ff_count[1];
endmodule
