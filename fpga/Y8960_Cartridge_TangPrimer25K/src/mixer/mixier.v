//
//	mixier.v
//	 Mixer module for audio signals
//
//	Copyright (C) 2025 Takayuki Hara
//
//	本ソフトウェアおよび本ソフトウェアに基づいて作成された派生物は、以下の条件を
//	満たす場合に限り、再頒布および使用が許可されます。
//
//	1.ソースコード形式で再頒布する場合、上記の著作権表示、本条件一覧、および下記
//	  免責条項をそのままの形で保持すること。
//	2.バイナリ形式で再頒布する場合、頒布物に付属のドキュメント等の資料に、上記の
//	  著作権表示、本条件一覧、および下記免責条項を含めること。
//	3.書面による事前の許可なしに、本ソフトウェアを販売、および商業的な製品や活動
//	  に使用しないこと。
//
//	本ソフトウェアは、著作権者によって「現状のまま」提供されています。著作権者は、
//	特定目的への適合性の保証、商品性の保証、またそれに限定されない、いかなる明示
//	的もしくは暗黙な保証責任も負いません。著作権者は、事由のいかんを問わず、損害
//	発生の原因いかんを問わず、かつ責任の根拠が契約であるか厳格責任であるか（過失
//	その他の）不法行為であるかを問わず、仮にそのような損害が発生する可能性を知ら
//	されていたとしても、本ソフトウェアの使用によって発生した（代替品または代用サ
//	ービスの調達、使用の喪失、データの喪失、利益の喪失、業務の中断も含め、またそ
//	れに限定されない）直接損害、間接損害、偶発的な損害、特別損害、懲罰的損害、ま
//	たは結果損害について、一切責任を負わないものとします。
//
//	Note that above Japanese version license is the formal document.
//	The following translation is only for reference.
//
//	Redistribution and use of this software or any derivative works,
//	are permitted provided that the following conditions are met:
//
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above
//	   copyright notice, this list of conditions and the following
//	   disclaimer in the documentation and/or other materials
//	   provided with the distribution.
//	3. Redistributions may not be sold, nor may they be used in a
//	   commercial product or activity without specific prior written
//	   permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//	COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//	LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//	POSSIBILITY OF SUCH DAMAGE.
//
//-----------------------------------------------------------------------------

module mixier (
	input						clk,
	input						reset_n,
	input			[12:0]		ssg_l,
	input			[12:0]		ssg_r,
	input signed	[15:0]		opll_l,
	input signed	[15:0]		opll_r,
	input signed	[15:0]		opl2_l,
	input signed	[15:0]		opl2_r,
	input signed	[10:0]		scc_l,
	input signed	[10:0]		scc_r,
	input signed	[15:0]		opm_l,
	input signed	[15:0]		opm_r,
	input			[7:0]		ssg_volume,
	input			[7:0]		opll_volume,
	input			[7:0]		opl2_volume,
	input			[7:0]		scc_volume,
	input			[7:0]		opm_volume,
	input			[7:0]		master_volume,
	output reg signed [23:0]	audio_l_out,
	output reg signed [23:0]	audio_r_out,
	output reg					audio_valid
);
	//	One multiplier is shared by 12 steps:
	//	  0-4 : SSG/OPLL/OPL2/SCC/OPM Lch x volume, 5 : Lch mix x master volume
	//	  6-10: SSG/OPLL/OPL2/SCC/OPM Rch x volume, 11: Rch mix x master volume
	reg			[3:0]	ff_state;
	reg signed	[27:0]	ff_acc;
	reg signed	[23:0]	ff_mix;
	reg signed	[23:0]	w_sample;
	reg			[7:0]	w_volume;
	wire		[7:0]	w_gain;
	wire signed	[32:0]	w_product_raw;
	wire signed	[27:0]	w_product;
	wire signed	[27:0]	w_sum;
	wire signed	[27:0]	w_scaled;
	wire signed	[23:0]	w_master_out;
	wire				w_master_state;

	assign w_gain			= w_volume[7] ? 8'd128 : { 1'b0, w_volume[6:0] };
	assign w_product_raw	= w_sample * $signed({ 1'b0, w_gain });
	assign w_product		= w_product_raw[27:0];
	assign w_sum			= ff_acc + w_product;
	//	No attenuation after mixing: a full-scale 16bit source at volume 128 is
	//	-6dBFS. Louder mixes are clipped by saturate_24().
	assign w_scaled			= w_sum;
	//	|ff_mix| <= 2^23 and gain <= 128, so the result always fits in 24 bits.
	assign w_master_out		= w_product_raw[30:7];
	assign w_master_state	= (ff_state == 4'd5) || (ff_state == 4'd11);

	always @(*) begin
		w_sample	= 24'sd0;
		w_volume	= 8'd128;
		case( ff_state )
			4'd0:  begin w_sample = $signed({ 11'd0, ssg_l });					w_volume = ssg_volume;		end
			4'd1:  begin w_sample = { {8{opll_l[15]}}, opll_l };				w_volume = opll_volume;		end
			4'd2:  begin w_sample = { {8{opl2_l[15]}}, opl2_l };				w_volume = opl2_volume;		end
			4'd3:  begin w_sample = { {11{scc_l[10]}}, scc_l, 2'd0 };			w_volume = scc_volume;		end
			4'd4:  begin w_sample = { {8{opm_l[15]}}, opm_l };					w_volume = opm_volume;		end
			4'd5:  begin w_sample = ff_mix;										w_volume = master_volume;	end
			4'd6:  begin w_sample = $signed({ 11'd0, ssg_r });					w_volume = ssg_volume;		end
			4'd7:  begin w_sample = { {8{opll_r[15]}}, opll_r };				w_volume = opll_volume;		end
			4'd8:  begin w_sample = { {8{opl2_r[15]}}, opl2_r };				w_volume = opl2_volume;		end
			4'd9:  begin w_sample = { {11{scc_r[10]}}, scc_r, 2'd0 };			w_volume = scc_volume;		end
			4'd10: begin w_sample = { {8{opm_r[15]}}, opm_r };					w_volume = opm_volume;		end
			4'd11: begin w_sample = ff_mix;										w_volume = master_volume;	end
			default: ;
		endcase
	end

	function signed [23:0] saturate_24;
		input signed [27:0] value;
		begin
			if( value[27:23] == {5{value[23]}} ) begin
				saturate_24 = value[23:0];
			end
			else if( value[27] ) begin
				saturate_24 = 24'sh800000;
			end
			else begin
				saturate_24 = 24'sh7FFFFF;
			end
		end
	endfunction

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_state		<= 4'd0;
			ff_acc			<= 28'sd0;
			ff_mix			<= 24'sd0;
			audio_l_out		<= 24'sd0;
			audio_r_out		<= 24'sd0;
			audio_valid		<= 1'b0;
		end
		else begin
			//	High after the R output is updated, with both channels stable.
			audio_valid <= (ff_state == 4'd11);

			if( ff_state == 4'd0 || ff_state == 4'd6 ) begin
				ff_acc <= w_product;
			end
			else if( !w_master_state ) begin
				ff_acc <= w_sum;
			end

			if( ff_state == 4'd4 || ff_state == 4'd10 ) begin
				ff_mix <= saturate_24( w_scaled );
			end

			if( ff_state == 4'd5 ) begin
				audio_l_out <= w_master_out;
			end
			else if( ff_state == 4'd11 ) begin
				audio_r_out <= w_master_out;
			end

			if( ff_state == 4'd11 ) begin
				ff_state <= 4'd0;
			end
			else begin
				ff_state <= ff_state + 4'd1;
			end
		end
	end
endmodule