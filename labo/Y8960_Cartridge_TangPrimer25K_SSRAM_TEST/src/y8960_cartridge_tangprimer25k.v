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
	//	SRAM
	output			sram_ce_n,				//	F2
	output			sram_sclk,				//	F1
	inout	[3:0]	sram_sio,				//	D1,E1,C2,A1
	//	DIP S/W
	input	[1:0]	dipsw,					//	E3,E8
	//	LED
	output	[3:0]	led,					//	B10,B11,C10,C11
	//	UART TX
	output			uart_tx					//	C3
);
	wire			clk_100m;				//	PLL output (100.22726MHz for SSRAM controller)

	// ---------------------------------------------------------
	//	Reset generator
	// ---------------------------------------------------------
	reg		[3:0]	ff_reset_count = 4'd0;
	wire			w_reset_n;

	always @( posedge clk_28m ) begin
		if( ff_reset_count != 4'd15 ) begin
			ff_reset_count <= ff_reset_count + 4'd1;
		end
	end
	assign w_reset_n = (ff_reset_count == 4'd15);

	// ---------------------------------------------------------
	//	PLL
	// ---------------------------------------------------------
	Gowin_PLL u_pll (
		.clkin		( clk_28m	),	// input  clkin
		.clkout0	( clk_100m	),	// output  clkout0
		.mdclk		( clk_50m	)	// input  mdclk
	);

	// ---------------------------------------------------------
	//	CPU
	// ---------------------------------------------------------
	cz80_inst u_cz80 (
		.reset_n			( w_reset_n				),
		.clk_n				( clk_28m				),
		.enable				( enable				),
		.wait_n				( w_wait_n				),
		.int_n				( w_int_n				),
		.nmi_n				( w_nmi_n				),
		.busrq_n			( w_busrq_n				),
		.m1_n				( w_m1_n				),
		.mreq_n				( w_mreq_n				),
		.iorq_n				( w_iorq_n				),
		.rd_n				( w_rd_n				),
		.wr_n				( w_wr_n				),
		.rfsh_n				( w_rfsh_n				),
		.halt_n				( w_halt_n				),
		.busak_n			( w_busak_n				),
		.a					( w_address				),
		.di					( w_di					),
		.do					( w_do					)
	);

	// ---------------------------------------------------------
	//	ROM/RAM
	// ---------------------------------------------------------
	wire		w_rom_mreq_n;
	wire		w_ram_mreq_n;

	assign w_rom_mreq_n = ~(~w_mreq_n & ( w_address[15:14] == 2'b00 ));
	rom u_rom (
		.clk				( clk_28m				),
		.address			( w_address[13:0]		),
		.mreq_n				( w_rom_mreq_n			),
		.rd_n				( w_rd_n				),
		.di					( w_di					),
		.do					( w_do					)
	);

	assign w_ram_mreq_n = ~(~w_mreq_n & ( w_address[15:12] == 4'h4 ));
	ram u_ram (
		.clk				( clk_28m				),
		.address			( w_address[11:0]		),
		.mreq_n				( w_ram_mreq_n			),
		.rd_n				( w_rd_n				),
		.wr_n				( w_wr_n				),
		.di					( w_di					),
		.do					( w_do					)
	);

	// ---------------------------------------------------------
	//	SSRAM controller
	// ---------------------------------------------------------
	reg		[18:0]	ff_address = 19'd0;
	reg				ff_valid = 1'b0;
	reg				ff_write = 1'b0;
	reg		[7:0]	ff_wdata = 8'd0;
	wire			w_ssram_ready;
	wire	[7:0]	w_ssram_rdata;
	wire			w_ssram_rdata_en;

	ssram u_ssram (
		.clk				( clk_28m				),
		.clk_100m			( clk_100m				),
		.reset_n			( w_reset_n				),
		.address			( ff_address			),
		.valid				( ff_valid				),
		.ready				( w_ssram_ready			),
		.write				( ff_write				),
		.wdata				( ff_wdata				),
		.rdata				( w_ssram_rdata			),
		.rdata_en			( w_ssram_rdata_en		),
		.sram_sclk			( sram_sclk				),
		.sram_ce_n			( sram_ce_n				),
		.sram_sio			( sram_sio				)
	);


	// ---------------------------------------------------------
	//	UART
	// ---------------------------------------------------------
	ip_uart_inst u_uart (
		.n_reset		( w_reset_n		),
		.clk			( clk_28m		),
		.address		( w_address[0]	),
		.iorq_n			( w_iorq_n		),
		.wait_n			( w_wait_n		),
		.wr_n			( w_wr_n		),
		.di				( w_di			),
		.uart_tx		( uart_tx		),
		.led			( led			)
	);
endmodule
