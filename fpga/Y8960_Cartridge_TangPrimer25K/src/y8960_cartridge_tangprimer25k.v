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
	input			clk_50m,				//	E2	50.00000MHz audio base clock (on board)
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
	output			psram_ce_n,				//	F2
	output			psram_sclk,				//	F1
	inout	[3:0]	psram_sio,				//	D1,E1,C2,A1
	//	DIP S/W
	input	[1:0]	dipsw,					//	E3,E8
	//	LED
	output	[3:0]	led						//	B10,B11,C10,C11
);
	wire			reset_n;
	wire	[15:0]	bus_address;
	wire			bus_memreq;
	wire			bus_ioreq;
	wire			bus_write;
	wire			bus_valid;
	wire			bus_ready;
	wire	[7:0]	bus_wdata;
	wire	[7:0]	bus_rdata;
	wire			bus_rdata_en;

	wire			bus_timer_ready;
	wire	[7:0]	bus_timer_rdata;
	wire			bus_timer_rdata_en;

	wire			bus_opll_ready;
	wire	[7:0]	bus_opll_rdata;
	wire			bus_opll_rdata_en;

	wire			bus_ssg_ready;
	wire	[7:0]	bus_ssg_rdata;
	wire			bus_ssg_rdata_en;

	wire	[11:0]	w_ssg_out_l;
	wire	[11:0]	w_ssg_out_r;

	reg		[4:0]	ff_divider;
	reg				ff_enable;
	wire			w_int_n;
	wire	[7:0]	w_led;
	wire	[15:0]	w_sound_out;

	assign flash_spi_clk        = 1'b0;
	assign flash_spi_cs_n       = 1'b1;
	assign flash_spi_wp_n       = 1'b0;
	assign flash_spi_hold_n     = 1'b1;
	assign flash_spi_mosi       = 1'b0;
	assign psram_ce_n           = 1'b1;
	assign psram_sclk           = 1'b0;
	assign psram_sio            = 4'd0;

	assign slot_wait            = 1'b0;

	// ---------------------------------------------------------
	always @( posedge clk_14m ) begin
		if( !reset_n ) begin
			ff_divider	<= 5'd0;
			ff_enable	<= 1'b0;
		end
		else if( ff_divider == 5'd23 ) begin
			ff_divider	<= 5'd0;
			ff_enable	<= 1'b1;				//	3.579545MHz
		end
		else begin
			ff_divider	<= ff_divider + 5'd1;
			ff_enable	<= 1'b0;
		end
	end

	// ---------------------------------------------------------
	msx_slot u_msx_slot (
		.clk				( clk_14m					),
		.reset_n			( reset_n					),
		.p_slot_reset		( slot_reset				),
		.p_slot_ioreq_n		( slot_ioreq_n				),
		.p_slot_wr_n		( slot_wr_n					),
		.p_slot_rd_n		( slot_rd_n					),
		.p_slot_address		( slot_a	    			),
		.p_slot_data		( slot_d					),
		.p_slot_int			( slot_intr					),
		.p_slot_data_dir	( slot_busdir				),
		.int_n				( w_int_n					),
		.bus_address		( bus_address				),
		.bus_ioreq			( bus_ioreq					),
		.bus_write			( bus_write					),
		.bus_valid			( bus_valid					),
		.bus_ready			( bus_ready					),
		.bus_wdata			( bus_wdata					),
		.bus_rdata			( bus_rdata					),
		.bus_rdata_en		( bus_rdata_en				)
	);

    assign bus_ready    = bus_timer_ready | bus_ssg_ready;
    assign bus_rdata    = bus_timer_rdata & bus_ssg_rdata;
    assign bus_rdata_en = bus_timer_rdata_en | bus_ssg_rdata_en;

	// ---------------------------------------------------------
	msx_timer u_msx_timer (
		.clk				( clk_14m					),
		.reset_n			( reset_n					),
		.bus_ioreq			( bus_ioreq					),
		.bus_address		( bus_address[7:0]			),
		.bus_write			( bus_write					),
		.bus_valid			( bus_valid					),
		.bus_ready			( bus_timer_ready			),
		.bus_wdata			( bus_wdata					),
		.bus_rdata			( bus_timer_rdata			),
		.bus_rdata_en		( bus_timer_rdata_en		),
		.intr_n				( w_int_n					)
	);

	// ---------------------------------------------------------
//	dual_opll u_dual_opll (
//		.clk				( clk_14m					),
//		.reset_n			( reset_n					),
//		.enable				( ff_enable					),
//		.bus_memreq			( bus_memreq				),
//		.bus_ioreq			( bus_ioreq					),
//		.bus_address		( bus_address				),
//		.bus_write			( bus_write					),
//		.bus_valid			( bus_valid					),
//		.bus_ready			( bus_opll_ready			),
//		.bus_wdata			( bus_wdata					),
//		.sound_out0			( sound_out0				),
//		.sound_out1			( sound_out1				)
//	);

	// ---------------------------------------------------------
	dual_ssg #(
		.BUILTIN			( 0							)
	) u_dual_ssg (
		.clk				( clk_14m					),
		.reset_n			( reset_n					),
		.enable				( ff_enable					),
		.bus_ioreq			( bus_ioreq					),
		.bus_valid			( bus_valid					),
		.bus_write			( bus_write					),
		.bus_address		( bus_address[7:0]			),
		.bus_ready			( bus_ssg_ready				),
		.bus_wdata			( bus_wdata					),
		.bus_rdata			( bus_ssg_rdata				),
		.bus_rdata_en		( bus_ssg_rdata_en			),
		.ssg_ioa0			( 8'd0						),
		.ssg_iob0			( 							),
		.ssg_ioa1			( { 6'd0, dipsw }			),
		.ssg_iob1			( w_led						),
		.sound_out_l		( w_ssg_out_l				),
		.sound_out_r		( w_ssg_out_r				),
		.mode				( 2'b11						)
	);

	assign led		= w_led[3:0];

	// ---------------------------------------------------------
	assign w_sound_out	= { 4'd0, w_ssg_out_l } + { 4'd0, w_ssg_out_r };

	i2s_audio u_i2s (
		.clk				( clk_14m					),
		.reset_n			( reset_n					),
		.sound_in			( w_sound_out				),
		.i2s_audio_en		( audio_mclk				),
		.i2s_audio_din		( audio_sdata				),
		.i2s_audio_lrclk	( audio_lrclk				),
		.i2s_audio_bclk		( audio_bclk				)
	);

endmodule
