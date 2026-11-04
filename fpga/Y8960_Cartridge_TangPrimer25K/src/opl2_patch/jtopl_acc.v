/* This file is part of JTOPL.

 
    JTOPL program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTOPL program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTOPL.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-6-2020 

*/

module jtopl_acc(
    input                rst,
    input                clk,
    input                cenop,
    input         [17:0] slot,
    input                rhy_en,
    input  signed [12:0] op_result,
    input                zero,
    input                op,  // 0 for modulator operators
    input                con, // 0 for modulated connection
    input         [ 7:0] pan,
    output signed [15:0] snd_l,
    output signed [15:0] snd_r
);

wire               sum_en;
wire signed [13:0] op2x;
wire               rhy2x;
wire        [ 8:0] gain_l;
wire        [ 8:0] gain_r;
reg  signed [13:0] op2x_d;
reg         [ 7:0] pan_d;
reg                sum_en_d;
reg                zero_d;
wire signed [23:0] product_l;
wire signed [23:0] product_r;
wire signed [14:0] sample_l;
wire signed [14:0] sample_r;

// all rhythm channels are amplified by two
// given the data path latency, slot 16(-1) data enters at slot 6(-1) and so on
// slots 13~18 (counting from 1 to 18) will enter when bits slot[7:2] are set
assign rhy2x  = rhy_en && |slot[7:2];
assign sum_en = op | con;
assign op2x   = rhy2x ? {op_result, 1'b0} : {op_result[12],op_result};
assign product_l = op2x_d * $signed({1'b0, gain_l});
assign product_r = op2x_d * $signed({1'b0, gain_r});
assign sample_l  = product_l[22:8];
assign sample_r  = product_r[22:8];

// pan must be delayed by one slot together with op2x_d. Otherwise the gain
// of the next slot (= next channel) is applied.
pan_lut u_pan_lut(
    .i_clk      ( clk       ),
    .i_pan      ( pan_d     ),
    .o_gain_l   ( gain_l    ),
    .o_gain_r   ( gain_r    )
);

always @(posedge clk) if(cenop) begin
    if(rst) begin
        op2x_d  <= 14'sd0;
        pan_d   <= 8'd128;
        sum_en_d <= 1'b0;
        zero_d  <= 1'b0;
    end else begin
        op2x_d  <= op2x;
        pan_d   <= pan;
        sum_en_d <= sum_en;
        zero_d  <= zero;
    end
end

// Continuous output
jtopl_single_acc #(.INW(15),.OUTW(16)) u_acc_l(
    .clk        ( clk       ),
    .cenop      ( cenop     ),
    .op_result  ( sample_l  ),
    .sum_en     ( sum_en_d  ),
    .zero       ( zero_d    ),
    .snd        ( snd_l     )
);

jtopl_single_acc #(.INW(15),.OUTW(16)) u_acc_r(
    .clk        ( clk       ),
    .cenop      ( cenop     ),
    .op_result  ( sample_r  ),
    .sum_en     ( sum_en_d  ),
    .zero       ( zero_d    ),
    .snd        ( snd_r     )
);

endmodule
