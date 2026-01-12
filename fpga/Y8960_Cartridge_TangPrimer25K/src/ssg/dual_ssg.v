//
//	dual_ssg.v
//	DualSSG (YM2149. AY-3-8910 Compatible Processor)
//
//	Copyright (C) 2024 Takayuki Hara
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

module dual_ssg #( 
	parameter		core_number = 1'b0
) (
	input			clk,
	input			reset_n,
	input			enable,
	input			iorq_n,
	input			wr_n,
	input			rd_n,
	input	[1:0]	address,
	input	[7:0]	wdata,
	output	[7:0]	rdata,
	output			rdata_en,

	inout	[5:0]	ssg_ioa,
	output	[2:0]	ssg_iob,

	input			keyboard_type,		//	PortA bit6: Keyboard type  0: 50音配列, 1: JIS配列 
	input			cmt_read,			//	PortA bit7: CMT Read Signal
	output			kana_led,			//	PortB bit7: KANA LED  0: ON, 1: OFF

	output	[12:0]	sound_out_l,		//	10bit/ch * 6ch = 13bit
	output	[12:0]	sound_out_r,		//	10bit/ch * 6ch = 13bit
	input	[1:0]	mode,				//	0: disable, 1: single(core0), 2: single(core1), 3: dual
	input			stereo				//	0: mono, 1: stereo
);
	wire	[11:0]	w_sound_out0;
	wire	[11:0]	w_sound_out1;
	reg		[12:0]	ff_sound_out_l;
	reg		[12:0]	ff_sound_out_r;
	wire	[7:0]	w_rdata0;
	wire			w_rdata_en0;
	wire	[7:0]	w_rdata1;
	wire			w_rdata_en1;

	ssg_core #( 
		.core_number	( 1'b0				)
	) ssg_core0 (
		.clk			( clk				),
		.reset_n		( reset_n			),
		.enable			( enable			),
		.iorq_n			( iorq_n			),
		.wr_n			( wr_n				),
		.rd_n			( rd_n				),
		.address		( address			),
		.wdata			( wdata				),
		.rdata			( w_rdata0			),
		.rdata_en		( w_rdata_en0		),
		.ssg_ioa		( ssg_ioa			),
		.ssg_iob		( ssg_iob			),
		.keyboard_type	( keyboard_type		),
		.cmt_read		( cmt_read			),
		.kana_led		( kana_led			),
		.sound_out		( w_sound_out0		),
		.mode			( mode				)
	);

	ssg_core #( 
		.core_number	( 1'b1				)
	) ssg_core1 (
		.clk			( clk				),
		.reset_n		( reset_n			),
		.enable			( enable			),
		.iorq_n			( iorq_n			),
		.wr_n			( wr_n				),
		.rd_n			( rd_n				),
		.address		( address			),
		.wdata			( wdata				),
		.rdata			( w_rdata1			),
		.rdata_en		( w_rdata_en1		),
		.ssg_ioa		( 6'dz				),
		.ssg_iob		( 					),
		.keyboard_type	( 1'b0				),
		.cmt_read		( 1'b0				),
		.kana_led		( 					),
		.sound_out		( w_sound_out1		),
		.mode			( mode				)
	);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_sound_out_l <= 13'd0;
			ff_sound_out_r <= 13'd0;
		end
		else if( stereo ) begin
			//	stereo
			ff_sound_out_l <= { w_sound_out0, 1'b0 };
			ff_sound_out_r <= { w_sound_out1, 1'b0 };
		end
		else begin
			//	mono
			ff_sound_out_l <= { 1'b0, w_sound_out0 } + { 1'b0, w_sound_out1 };
			ff_sound_out_r <= { 1'b0, w_sound_out0 } + { 1'b0, w_sound_out1 };
		end
	end

	assign sound_out_l	= ff_sound_out_l;
	assign sound_out_r	= ff_sound_out_r;
	assign rdata		= w_rdata0 & w_rdata1;
	assign rdata_en		= w_rdata_en0 | w_rdata_en1;
endmodule
