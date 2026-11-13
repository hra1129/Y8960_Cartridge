/* This file is part of JT12.


    JT12 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT12 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT12.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 21-03-2019
*/

// Y8960 patch (2026/11/13 t.hara):
//   The original interpolator divided the last sample difference by the
//   length of the previous sample interval (counted in cen55 ticks, up to 15)
//   and applied that step to the next interval. Since the interval length
//   varies when 65536 / DELTA-N is not an integer, the ramp stopped short or
//   jumped at the next sample (signal correlated error).
//   Now the phase of the DELTA-N accumulator (cnt in jt10_adpcmb_cnt) is used
//   as the exact interpolation ratio:
//       pcmout = x[n-1] + (x[n] - x[n-1]) * phase / 65536
//   The multiplication is done by a 16 step shift-and-add sequence on cen
//   (72 cen per cen55), so neither a hardware multiplier nor a divider is used.
//   While the channel is off (chon = 0), the state is cleared, so a new
//   playback starts from 0 like the decoder. Otherwise the last value of
//   the previous playback remains, and repeated START/RESET writes turn it
//   into a buzz.

module jt10_adpcmb_interpol(
    input           rst_n,
    input           clk,
    input           cen,      // 3.58MHz cen (72 cen per cen55)
    input           cen55,    // clk & cen55  =  49.7 kHz, coincides with cen
    input           chon,     // channel is playing
    input           adv,
    input    [15:0] phase,    // DELTA-N accumulator, valid with cen55
    input  signed [15:0] pcmdec,
    output signed [15:0] pcmout
);

reg signed [15:0] x_prev;   // x[n-1]
reg signed [16:0] diff;     // x[n] - x[n-1]
reg signed [17:0] acc;
reg        [15:0] ratio;
reg         [4:0] seq;
reg signed [15:0] pcminter;

wire signed [17:0] acc_add = acc + ( ratio[0] ? { diff[16], diff } : 18'sd0 );

assign pcmout = pcminter;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        x_prev   <= 16'sd0;
        diff     <= 17'sd0;
        acc      <= 18'sd0;
        ratio    <= 16'd0;
        seq      <= 5'd0;
        pcminter <= 16'sd0;
    end else if( !chon ) begin
        x_prev   <= 16'sd0;
        seq      <= 5'd0;
        pcminter <= 16'sd0;
    end else if( cen ) begin
        if( cen55 ) begin
            // the decoder starts to decode x[n] at this cen when adv = 1
            if( adv ) x_prev <= pcmdec;
            ratio <= phase;
            seq   <= 5'd1;
        end else if( seq != 5'd0 ) begin
            seq <= seq + 5'd1;
            if( seq == 5'd6 ) begin
                // the decoder updates its output 4 cen after adv
                diff <= { pcmdec[15], pcmdec } - { x_prev[15], x_prev };
                acc  <= 18'sd0;
            end else if( seq <= 5'd22 && seq >= 5'd7 ) begin
                acc   <= acc_add >>> 1;
                ratio <= { 1'b0, ratio[15:1] };
            end else if( seq == 5'd23 ) begin
                pcminter <= x_prev + acc[15:0];
                seq      <= 5'd0;
            end
        end
    end
end

endmodule // jt10_adpcmb_interpol
