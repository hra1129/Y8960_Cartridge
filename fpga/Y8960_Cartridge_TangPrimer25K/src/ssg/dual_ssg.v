//
//	dual_ssg.v
//	DualSSG (YM2149. AY-3-8910 Compatible Processor)
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

module dual_ssg #(
	parameter		BUILTIN = 1
) (
	input			clk,
	input			reset_n,
	input			enable,
	input			bus_ioreq,
	input			bus_valid,
	input			bus_write,
	input	[7:0]	bus_address,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,

	input	[7:0]	ssg_ioa,
	output	[7:0]	ssg_iob,

	output	[11:0]	sound_out_l,		//	10bit/ch * 3ch = 12bit
	output	[11:0]	sound_out_r,		//	10bit/ch * 3ch = 12bit
	input	[1:0]	mode				//	0: disable, 1: single(core0), 2: single(core1), 3: dual
);
	localparam		c_ssg_port	= 8'hA0;
	wire			w_ioreq;
	wire	[7:0]	w_rdata0;
	wire			w_rdata_en0;
	wire	[7:0]	w_rdata1;
	wire			w_rdata_en1;

	assign w_ioreq	= ( {bus_address[7:2], 2'd0} == c_ssg_port ) ? bus_ioreq: 1'b0;

	ssg_core #( 
		.builtin		( BUILTIN			),
		.core_number	( 1'b0				)
	) ssg_core0 (
		.clk			( clk				),
		.reset_n		( reset_n			),
		.enable			( enable			),
		.bus_ioreq		( w_ioreq			),
		.bus_valid		( bus_valid			),
		.bus_write		( bus_write			),
		.bus_address	( bus_address[1:0]	),
		.bus_ready		( bus_ssg_ready		),
		.bus_wdata		( bus_wdata			),
		.bus_rdata		( w_rdata0			),
		.bus_rdata_en	( w_rdata_en0		),
		.ssg_ioa		( ssg_ioa			),
		.ssg_iob		( ssg_iob			),
		.sound_out		( sound_out_l		),
		.mode			( mode				)
	);

	ssg_core #( 
		.builtin		( 1'b1				),
		.core_number	( 1'b1				)
	) ssg_core1 (
		.clk			( clk				),
		.reset_n		( reset_n			),
		.enable			( enable			),
		.bus_ioreq		( w_ioreq			),
		.bus_valid		( bus_valid			),
		.bus_write		( bus_write			),
		.bus_address	( bus_address[1:0]	),
		.bus_ready		( bus_ssg_ready		),
		.bus_wdata		( bus_wdata			),
		.bus_rdata		( w_rdata1			),
		.bus_rdata_en	( w_rdata_en1		),
		.ssg_ioa		( 8'hFF				),
		.ssg_iob		( 					),
		.sound_out		( sound_out_r		),
		.mode			( mode				)
	);

	assign rdata		= w_rdata0 & w_rdata1;
	assign rdata_en		= w_rdata_en0 | w_rdata_en1;
endmodule
