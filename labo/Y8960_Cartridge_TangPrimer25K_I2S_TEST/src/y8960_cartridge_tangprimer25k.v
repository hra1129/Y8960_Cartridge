//
//	y8960_cartridge_tangprimer25k.v
//	Y8960 Cartridge for TangPrimer25K
//
//	Copyright (C) 2026 Takayuki Hara
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

module y8960cartridge_tangprimer25k (
	input			clk_28m,				//	H5	28.63636MHz MSX clock
	input			clk_50m,				//	E2	50.00000MHz audio base clock (on board)
	//	audio
	output			audio_sclk,				//	B11
	output			audio_bclk,				//	E10
	output			audio_lrclk,			//	A11
	output			audio_sdata,			//	A10
	//	DIP S/W
	input	[1:0]	dipsw,					//	E3,E8
	//	LED
	output	[3:0]	led						//	B10,B11,C10,C11
);
    wire            clk_129m;               // 128.86362MHz
    wire            clk_25m;                // 24.576MHz 
	reg				ff_reset_n = 1'b0;
	reg		[3:0]	ff_reset_cnt = 4'd0;
	wire				w_pcm_fs;
	wire	[23:0]	w_pcm_l;
	wire	[23:0]	w_pcm_r;

	reg		[3:0]	ff_led = 4'b0000;
	reg		[24:0]	ff_cnt25	= 25'd0;
	reg		[24:0]	ff_cnt28	= 25'd0;
	reg		[25:0]	ff_cnt50	= 26'd0;
	reg		[26:0]	ff_cnt129	= 27'd0;
	wire				w_trig25;
	wire				w_trig28;
	wire				w_trig50;
	wire				w_trig129;

	Gowin_PLL u_pll (
		.clkin		( clk_28m	),	//	input		 28.63636MHz
		.clkout0	( clk_129m	),	//	output		128.86362MHz
		.clkout1	( clk_25m	),	//	output		 24.57600MHz 
		.mdclk		( clk_50m	)	//	input		 50.00000MHz
	);

	assign w_trig25  = (ff_cnt25 == 25'd24576000 );
	assign w_trig28  = (ff_cnt28 == 25'd28636362 );
	assign w_trig50  = (ff_cnt50 == 26'd50000000 );
	assign w_trig129 = (ff_cnt129 == 27'd128863620 );

	always @( posedge clk_25m ) begin
		if( w_trig25 ) begin
			ff_cnt25 <= 25'd0;
			ff_led[0] <= ~ff_led[0];
		end
		else begin
			ff_cnt25 <= ff_cnt25 + 25'd1;
		end
	end

	always @( posedge clk_28m ) begin
		if( w_trig28 ) begin
			ff_cnt28 <= 25'd0;
			ff_led[1] <= ~ff_led[1];
		end
		else begin
			ff_cnt28 <= ff_cnt28 + 25'd1;
		end
	end

	always @( posedge clk_50m ) begin
		if( w_trig50 ) begin
			ff_cnt50 <= 26'd0;
			ff_led[2] <= ~ff_led[2];
		end
		else begin
			ff_cnt50 <= ff_cnt50 + 26'd1;
		end
	end

	always @( posedge clk_129m ) begin
		if( w_trig129 ) begin
			ff_cnt129 <= 27'd0;
			ff_led[3] <= ~ff_led[3];
		end
		else begin
			ff_cnt129 <= ff_cnt129 + 27'd1;
		end
	end

	assign led		= ff_led;

	// ---------------------------------------------------------
	//	Power-on Reset
	// ---------------------------------------------------------
	always @( posedge clk_25m ) begin
		if( ff_reset_cnt != 4'd15 ) begin
			ff_reset_cnt <= ff_reset_cnt + 4'd1;
			ff_reset_n   <= 1'b0;
		end
		else begin
			ff_reset_n   <= 1'b1;
		end
	end

	// ---------------------------------------------------------
	//	Sound Generator (test tone)
	// ---------------------------------------------------------
	sound u_sound (
		.reset_n	( ff_reset_n	),
		.clk		( clk_28m		),
		.pcm_fs		( w_pcm_fs		),
		.pcm_l		( w_pcm_l		),
		.pcm_r		( w_pcm_r		)
	);

	// ---------------------------------------------------------
	//	I2S Audio Output
	// ---------------------------------------------------------
	i2s_audio u_i2s_audio (
		.clk				( clk_25m		),
		.reset_n			( ff_reset_n	),
		.sound_l_in			( w_pcm_l		),
		.sound_r_in			( w_pcm_r		),
		.i2s_audio_sclk		( audio_sclk	),
		.i2s_audio_din		( audio_sdata	),
		.i2s_audio_lrclk	( audio_lrclk	),
		.i2s_audio_bclk		( audio_bclk	)
	);
endmodule
