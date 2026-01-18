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
	input			clk_14m,				//	H5	14.31818MHz MSX clock
	input			clk_25m,				//	E2	50.00000MHz audio base clock (on board)
	//	slot
	input			slot_reset,				//	G11
	input	[15:0]	slot_a,					//	L11,K11,H8,H7,G7,G8,F5,G5,J11,J10,F6,F7,K8,J8,K9,L9
	inout	[7:0]	slot_d,					//	K10,L10,L8,L7,J7,K7,K6,L6
	input			slot_sltsl,				//	J5
	input			slot_mereq_n,			//	K5
	input			slot_ioreq_n,			//	L5
	input			slot_wr_n,				//	D11
	input			slot_rd_n,				//	D10
	output			slot_wait,				//	H10
	output			slot_intr,				//	H11
	output			slot_busdir,			//	G10
	//	audio
	output			audio_mclk,				//	B11
	output			audio_bclk,				//	E10
	output			audio_lrclk,			//	A11
	output			audio_sdata,			//	A10
	//	flash ROM
	output			flash_spi_clk,			//	E7
	output			flash_spi_cs_n,			//	E6
	output			flash_spi_wp_n,			//	D5
	output			flash_spi_hold_n,		//	E4
	input			flash_spi_miso,			//	E5
	output			flash_spi_mosi,			//	D6
	//	PSRAM
	output			psram_ce_n,				//	??
	output			psram_sclk,				//	??
	inout	[3:0]	psram_sio,				//	??,??,??,??
	//	DIP S/W
	
	//	LED
	
);

endmodule
