/*  This file is part of JTOPL.

	JTOPL is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	JTOPL is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with JTOPL.  If not, see <http://www.gnu.org/licenses/>.

	Author: Jose Tejada Gomez. Twitter: @topapate
	Version: 1.0
    Date: 17-6-2020

	Y8960 (2026/11/15): eg_cnt advances once every two samples, same as the
	real chip. The envelope was twice as fast for all rates.

	*/

module jtopl_eg_cnt(
	input             rst,
	input             clk,
	input             cen,
	input             zero,
	output reg [14:0] eg_cnt
);

reg eg_half;

always @(posedge clk, posedge rst) begin : envelope_counter
	if( rst ) begin
		eg_cnt		<=15'd0;
		eg_half		<=1'b0;
	end
	else begin
		if( zero && cen ) begin
			// The real chip advances the envelope once every two samples
			// (eg_state of Nuked-OPL3), so the counter increases at every
			// other zero input.
			eg_half <= ~eg_half;
			if( eg_half ) begin
				eg_cnt <= eg_cnt + 1'b1;
			end
		end
	end
end

endmodule