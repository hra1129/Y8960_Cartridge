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
	//	slot
	input			slot_reset,				//	G11
	input	[15:0]	slot_a,					//	L11,K11,H8,H7,G7,G8,F5,G5,J11,J10,F6,F7,K8,J8,K9,L9
	inout	[7:0]	slot_d,					//	K10,L10,L8,L7,J7,K7,K6,L6
	input			slot_sltsl_n,			//	J5
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
	inout	[3:0]	flash_spi_io,			//	E4,D5,E5,D6
	//	SRAM
	output			sram_ce_n,				//	F2
	output			sram_sclk,				//	F1
	inout	[3:0]	sram_sio,				//	D1,E1,C2,A1
	//	DIP S/W
	input	[1:0]	dipsw,					//	E3,E8
	//	LED
	output	[3:0]	led						//	B10,B11,C10,C11
);
	wire 			clk_258m;				//	257.72724MHz for internal timing (for 3.579545MHz)
	wire 			clk_25m;				//	24.576MHz for I2S audio
	wire			w_reset_n;
	wire	[15:0]	w_bus_address;
	wire			w_bus_write;
	wire			w_bus_valid;
	wire	[7:0]	w_bus_wdata;
	wire	[7:0]	w_bus_rdata;
	wire			w_bus_rdata_en;

	wire			w_bus_timer_cs;
	wire			w_bus_opl2_cs;
	wire			w_bus_opll_cs;
	wire			w_bus_ssg_cs;
	wire			w_bus_scc_cs;
	wire			w_bus_dcsg_cs;

	wire			w_bus_timer_ready;
	wire	[7:0]	w_bus_timer_rdata;
	wire			w_bus_timer_rdata_en;

	wire			w_bus_opl2_ready;
	wire	[7:0]	w_bus_opl2_rdata;
	wire			w_bus_opl2_rdata_en;

	wire			w_bus_opll_ready;

	wire			w_bus_ssg_ready;
	wire	[7:0]	w_bus_ssg_rdata;
	wire			w_bus_ssg_rdata_en;

	wire			w_bus_scc_ready;
	wire	[7:0]	w_bus_scc_rdata;
	wire			w_bus_scc_rdata_en;
	wire			w_scc_memory_cs;
	wire	[5:0]	w_scc_ma;

	wire	[7:0]	w_bus_scc_bank_rdata;
	wire			w_bus_scc_bank_rdata_en;

	wire			w_bus_dcsg_ready;

	wire	[15:0]	w_opl2_sound_out0;
	wire	[15:0]	w_opl2_sound_out1;
	wire	[15:0]	w_adpcm_sound_out_l0;
	wire	[15:0]	w_adpcm_sound_out_r0;
	wire	[15:0]	w_adpcm_sound_out_l1;
	wire	[15:0]	w_adpcm_sound_out_r1;
	wire			w_adpcm_write;
	wire			w_adpcm_valid;
	wire			w_adpcm_ready;
	wire	[17:0]	w_adpcm_address;
	wire	[7:0]	w_adpcm_wdata;
	wire	[7:0]	w_adpcm_rdata;
	wire			w_adpcm_rdata_en;

	wire	[15:0]	w_opll_sound_out0;
	wire	[15:0]	w_opll_sound_out1;

	wire	[11:0]	w_ssg_sound_out0;
	wire	[11:0]	w_ssg_sound_out1;

	wire	[10:0]	w_scc_sound_out;

	wire	[13:0]	w_dcsg_sound_out0;
	wire	[13:0]	w_dcsg_sound_out1;

	reg		[2:0]	ff_divider;
	reg				ff_enable;
	wire			w_int_n;
	wire			w_timer_intr_n;
	wire			w_opl2_intr_n;
	wire	[7:0]	w_led;
	wire	[23:0]	w_sound_l;
	wire	[23:0]	w_sound_r;

	wire	[17:0]	w_cpu_address;
	wire			w_cpu_valid;
	wire			w_cpu_ready;
	wire			w_cpu_write;
	wire	[7:0]	w_cpu_wdata;
	wire	[7:0]	w_cpu_rdata;
	wire			w_cpu_rdata_en;

	wire	[22:0]	w_rom_address;
	wire			w_rom_valid;
	wire			w_rom_ready;
	wire	[1:0]	w_rom_command;
	wire	[7:0]	w_rom_wdata;
	wire	[7:0]	w_rom_rdata;
	wire			w_rom_rdata_en;

	wire	[18:0]	w_sram_address;
	wire			w_sram_valid;
	wire			w_sram_ready;
	wire			w_sram_write;
	wire	[7:0]	w_sram_wdata;
	wire	[7:0]	w_sram_rdata;
	wire			w_sram_rdata_en;

	wire			w_bus_sysctrl_cs;
	wire			w_bus_sysctrl_ready;
	wire	[7:0]	w_bus_sysctrl_rdata;
	wire			w_bus_sysctrl_rdata_en;
	wire			w_wait_n;

	// ---------------------------------------------------------
	//	Burst interface wires
	// ---------------------------------------------------------
	wire			w_burst_rom_start;
	wire	[22:0]	w_burst_rom_address;
	wire	[16:0]	w_burst_rom_length;
	wire			w_burst_rom_active;
	wire			w_burst_sram_start;
	wire	[18:0]	w_burst_sram_address;
	wire	[16:0]	w_burst_sram_length;
	wire			w_burst_sram_active;
	wire	[7:0]	w_burst_data;				// sfrom burst_rdata -> ssram burst_wdata
	wire			w_burst_data_en;			// sfrom burst_rdata_en -> ssram burst_wdata_en

	assign slot_wait = w_wait_n;

	// ---------------------------------------------------------
	always @( posedge clk_28m ) begin
		if( !w_reset_n ) begin
			ff_divider	<= 3'd0;
			ff_enable	<= 1'b0;
		end
		else if( ff_divider == 3'd7 ) begin
			ff_divider	<= 3'd0;
			ff_enable	<= 1'b1;				//	3.579545MHz
		end
		else begin
			ff_divider	<= ff_divider + 3'd1;
			ff_enable	<= 1'b0;
		end
	end

	Gowin_PLL u_pll(
		.clkin				( clk_28m					),	//	28.63636MHz
		.clkout0			( clk_258m					),	//	257.72724MHz
		.clkout1			( clk_25m					),	//	24.576MHz
		.mdclk				( clk_50m					)	//	50MHz
	);

	// ---------------------------------------------------------
	msx_slot u_msx_slot (
		.clk				( clk_28m					),
		.reset_n			( w_reset_n					),
		.p_slot_reset		( slot_reset				),
		.p_slot_sltsl_n		( slot_sltsl_n				),
		.p_slot_memreq_n	( slot_mereq_n				),
		.p_slot_ioreq_n		( slot_ioreq_n				),
		.p_slot_wr_n		( slot_wr_n					),
		.p_slot_rd_n		( slot_rd_n					),
		.p_slot_address		( slot_a					),
		.p_slot_data		( slot_d					),
		.p_slot_int			( slot_intr					),
		.p_slot_data_dir	( slot_busdir				),
		.int_n				( w_int_n					),
		.bus_address		( w_bus_address				),
		.bus_write			( w_bus_write				),
		.bus_valid			( w_bus_valid				),
		.bus_timer_ready	( w_bus_timer_ready			),
		.bus_opll_ready		( w_bus_opll_ready			),
		.bus_opl2_ready		( w_bus_opl2_ready			),
		.bus_ssg_ready		( w_bus_ssg_ready			),
		.bus_scc_ready		( w_bus_scc_ready			),
		.bus_dcsg_ready		( w_bus_dcsg_ready			),
		.bus_sysctrl_ready	( w_bus_sysctrl_ready		),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_rdata				),
		.bus_rdata_en		( w_bus_rdata_en			),
		.bus_timer_cs		( w_bus_timer_cs			),
		.bus_opl2_cs		( w_bus_opl2_cs				),
		.bus_opll_cs		( w_bus_opll_cs				),
		.bus_ssg_cs			( w_bus_ssg_cs				),
		.bus_scc_cs			( w_bus_scc_cs				),
		.bus_dcsg_cs		( w_bus_dcsg_cs				),
		.bus_sysctrl_cs		( w_bus_sysctrl_cs			),
		.memory_io_en		( ~w_scc_ma[5]				)
	);

	assign w_bus_rdata		= w_bus_timer_rdata & w_bus_opl2_rdata & w_bus_ssg_rdata & w_bus_scc_rdata & w_bus_sysctrl_rdata & w_bus_scc_bank_rdata;
	assign w_bus_rdata_en	= w_bus_timer_rdata_en | w_bus_opl2_rdata_en | w_bus_ssg_rdata_en | w_bus_scc_rdata_en | w_bus_sysctrl_rdata_en | w_bus_scc_bank_rdata_en;
	assign w_int_n			= w_timer_intr_n & w_opl2_intr_n;

	scc_bank u_scc_bank (
		.clk				( clk_28m					),
		.reset_n			( w_reset_n					),
		.bus_cs				( w_bus_scc_cs				),
		.bus_address		( w_bus_address				),
		.bus_valid			( w_bus_valid				),
		.bus_ready			( w_bus_ready				),
		.bus_write			( w_bus_write				),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_scc_bank_rdata		),
		.bus_rdata_en		( w_bus_scc_bank_rdata_en	),
		.scc_memory_cs		( w_scc_memory_cs			),
		.scc_ma				( w_scc_ma					),
		.cpu_address		( w_cpu_address				),
		.cpu_valid			( w_cpu_valid				),
		.cpu_ready			( w_cpu_ready				),
		.cpu_write			( w_cpu_write				),
		.cpu_wdata			( w_cpu_wdata				),
		.cpu_rdata			( w_cpu_rdata				),
		.cpu_rdata_en		( w_cpu_rdata_en			)
	);

	// ---------------------------------------------------------
	msx_timer u_msx_timer (
		.clk				( clk_28m					),
		.reset_n			( w_reset_n					),
		.bus_cs				( w_bus_timer_cs			),
		.bus_address		( w_bus_address[1:0]		),
		.bus_write			( w_bus_write				),
		.bus_valid			( w_bus_valid				),
		.bus_ready			( w_bus_timer_ready			),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_timer_rdata			),
		.bus_rdata_en		( w_bus_timer_rdata_en		),
		.intr_n				( w_timer_intr_n			)
	);

	// ---------------------------------------------------------
	dual_opl2 u_dual_opl2 (
		.clk				( clk_28m					),
		.reset_n			( w_reset_n					),
		.enable				( ff_enable					),
		.bus_cs				( w_bus_opl2_cs				),
		.bus_address		( w_bus_address[1:0]		),
		.bus_write			( w_bus_write				),
		.bus_valid			( w_bus_valid				),
		.bus_ready			( w_bus_opl2_ready			),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_opl2_rdata			),
		.bus_rdata_en		( w_bus_opl2_rdata_en		),
		.opl2_sound_out_0	( w_opl2_sound_out0			),
		.opl2_sound_out_1	( w_opl2_sound_out1			),
		.adpcm_sound_out_l0	( w_adpcm_sound_out_l0		),
		.adpcm_sound_out_r0	( w_adpcm_sound_out_r0		),
		.adpcm_sound_out_l1	( w_adpcm_sound_out_l1		),
		.adpcm_sound_out_r1	( w_adpcm_sound_out_r1		),
		.intr_n				( w_opl2_intr_n				),
		.adpcm_write		( w_adpcm_write				),
		.adpcm_valid		( w_adpcm_valid				),
		.adpcm_ready		( w_adpcm_ready				),
		.adpcm_address		( w_adpcm_address			),
		.adpcm_wdata		( w_adpcm_wdata				),
		.adpcm_rdata		( w_adpcm_rdata				),
		.adpcm_rdata_en		( w_adpcm_rdata_en			)
	);

	// ---------------------------------------------------------
	dual_opll u_dual_opll (
		.clk				( clk_28m					),
		.reset_n			( w_reset_n					),
		.enable				( ff_enable					),
		.bus_cs				( w_bus_opll_cs				),
		.bus_address		( w_bus_address[1:0]		),
		.bus_write			( w_bus_write				),
		.bus_valid			( w_bus_valid				),
		.bus_ready			( w_bus_opll_ready			),
		.bus_wdata			( w_bus_wdata				),
		.sound_out0			( w_opll_sound_out0			),
		.sound_out1			( w_opll_sound_out1			)
	);

	// ---------------------------------------------------------
	dual_ssg #(
		.BUILTIN			( 0							)
	) u_dual_ssg (
		.clk				( clk_28m					),
		.reset_n			( w_reset_n					),
		.enable				( ff_enable					),
		.bus_cs				( w_bus_ssg_cs				),
		.bus_valid			( w_bus_valid				),
		.bus_write			( w_bus_write				),
		.bus_address		( w_bus_address[1:0]		),
		.bus_ready			( w_bus_ssg_ready			),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_ssg_rdata			),
		.bus_rdata_en		( w_bus_ssg_rdata_en		),
		.ssg_ioa0			( 8'd0						),
		.ssg_iob0			( 							),
		.ssg_ioa1			( { 6'd0, dipsw }			),
		.ssg_iob1			( w_led						),
		.sound_out0			( w_ssg_sound_out0			),
		.sound_out1			( w_ssg_sound_out1			),
		.mode				( 2'b11						)
	);

	assign led		= w_led[3:0];

	// ---------------------------------------------------------
	scc u_scc (
		.reset_n			( w_reset_n					),
		.clk				( clk_28m					),
		.enable				( ff_enable					),
		.bus_cs				( w_bus_scc_cs				),
		.bus_address		( w_bus_address				),
		.bus_write			( w_bus_write				),
		.bus_ready			( w_bus_scc_ready			),
        .bus_valid          ( w_bus_valid				),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_scc_rdata			),
		.bus_rdata_en		( w_bus_scc_rdata_en		),
		.scc_memory_cs		( w_scc_memory_cs			),
		.scc_ma				( w_scc_ma					),
		.sound_out			( w_scc_sound_out			)
	);

	// ---------------------------------------------------------
	dual_dcsg u_dcsg (
		.clk				( clk_28m					),
		.reset_n			( w_reset_n					),
		.enable				( ff_enable					),
		.bus_cs				( w_bus_dcsg_cs				),
		.bus_address		( w_bus_address[0]			),
		.bus_write			( w_bus_write				),
		.bus_valid			( w_bus_valid				),
		.bus_ready			( w_bus_dcsg_ready			),
		.bus_wdata			( w_bus_wdata				),
		.sound_out0			( w_dcsg_sound_out0			),
		.sound_out1			( w_dcsg_sound_out1			)
	);

	// ---------------------------------------------------------
	//	System Controller
	// ---------------------------------------------------------
	system_controller #(
		.device_id			( 8'h61						)
	) u_system_controller (
		.clk				( clk_28m					),
		.reset_n			( w_reset_n					),
		.bus_cs				( w_bus_sysctrl_cs			),
		.bus_address		( w_bus_address[3:0]		),
		.bus_valid			( w_bus_valid				),
		.bus_ready			( w_bus_sysctrl_ready		),
		.bus_write			( w_bus_write				),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_sysctrl_rdata		),
		.bus_rdata_en		( w_bus_sysctrl_rdata_en	),
		.rom_address		( w_rom_address				),
		.rom_valid			( w_rom_valid				),
		.rom_ready			( w_rom_ready				),
		.rom_command		( w_rom_command				),
		.rom_wdata			( w_rom_wdata				),
		.rom_rdata			( w_rom_rdata				),
		.rom_rdata_en		( w_rom_rdata_en			),
		.sram_ready			( w_sram_ready				),
		.burst_rom_start	( w_burst_rom_start			),
		.burst_rom_address	( w_burst_rom_address		),
		.burst_rom_length	( w_burst_rom_length		),
		.burst_rom_active	( w_burst_rom_active		),
		.burst_sram_start	( w_burst_sram_start		),
		.burst_sram_address	( w_burst_sram_address		),
		.burst_sram_length	( w_burst_sram_length		),
		.burst_sram_active	( w_burst_sram_active		),
		.wait_n				( w_wait_n					)
	);

	// ---------------------------------------------------------
	//	SRAM Arbiter
	// ---------------------------------------------------------
	sram_arbiter u_sram_arbiter (
		.clk				( clk_28m					),
		.reset_n			( w_reset_n					),
		.cpu_address		( w_cpu_address				),
		.cpu_valid			( w_cpu_valid				),
		.cpu_ready			( w_cpu_ready				),
		.cpu_write			( w_cpu_write				),
		.cpu_wdata			( w_cpu_wdata				),
		.cpu_rdata			( w_cpu_rdata				),
		.cpu_rdata_en		( w_cpu_rdata_en			),
		.adpcm_address		( w_adpcm_address			),
		.adpcm_valid		( w_adpcm_valid				),
		.adpcm_ready		( w_adpcm_ready				),
		.adpcm_write		( w_adpcm_write				),
		.adpcm_wdata		( w_adpcm_wdata				),
		.adpcm_rdata		( w_adpcm_rdata				),
		.adpcm_rdata_en		( w_adpcm_rdata_en			),
		.ssram_address		( w_sram_address			),
		.ssram_valid		( w_sram_valid				),
		.ssram_ready		( w_sram_ready				),
		.ssram_write		( w_sram_write				),
		.ssram_wdata		( w_sram_wdata				),
		.ssram_rdata		( w_sram_rdata				),
		.ssram_rdata_en		( w_sram_rdata_en			)
	);

	// ---------------------------------------------------------
	//	Serial Flash ROM
	// ---------------------------------------------------------
	sfrom u_sfrom (
		.clk				( clk_28m					),
		.clk_258m			( clk_258m					),
		.reset_n			( w_reset_n					),
		.address			( w_rom_address				),
		.valid				( w_rom_valid				),
		.ready				( w_rom_ready				),
		.command			( w_rom_command				),
		.wdata				( w_rom_wdata				),
		.rdata				( w_rom_rdata				),
		.rdata_en			( w_rom_rdata_en			),
		.burst_start		( w_burst_rom_start			),
		.burst_address		( w_burst_rom_address		),
		.burst_length		( w_burst_rom_length		),
		.burst_rdata		( w_burst_data				),
		.burst_rdata_en		( w_burst_data_en			),
		.burst_active		( w_burst_rom_active		),
		.flash_spi_clk		( flash_spi_clk				),
		.flash_spi_cs_n		( flash_spi_cs_n			),
		.flash_spi_io		( flash_spi_io				)
	);

	// ---------------------------------------------------------
	//	Serial SRAM
	// ---------------------------------------------------------
	ssram u_ssram (
		.clk				( clk_28m					),
		.clk_258m			( clk_258m					),
		.reset_n			( w_reset_n					),
		.address			( w_sram_address			),
		.valid				( w_sram_valid				),
		.ready				( w_sram_ready				),
		.write				( w_sram_write				),
		.wdata				( w_sram_wdata				),
		.rdata				( w_sram_rdata				),
		.rdata_en			( w_sram_rdata_en			),
		.burst_start		( w_burst_sram_start		),
		.burst_address		( w_burst_sram_address		),
		.burst_length		( w_burst_sram_length		),
		.burst_wdata		( w_burst_data				),
		.burst_wdata_en		( w_burst_data_en			),
		.burst_active		( w_burst_sram_active		),
		.sram_ce_n			( sram_ce_n					),
		.sram_sclk			( sram_sclk					),
		.sram_sio			( sram_sio					)
	);

	// ---------------------------------------------------------
	assign w_sound_l	= 
			{ 4'd0, w_ssg_sound_out0 } + { 4'd0, w_ssg_sound_out1 } + 
			w_opll_sound_out0 + w_opll_sound_out1 + 
			w_opl2_sound_out0 + w_opl2_sound_out1 + 
			w_adpcm_sound_out_l0 + w_adpcm_sound_out_l1 +
			w_adpcm_sound_out_r0 + w_adpcm_sound_out_r1 +
			w_dcsg_sound_out0 + w_dcsg_sound_out1 + 
			{ 3'd0, w_scc_sound_out, 2'd0 };

	assign w_sound_r	= 
			{ 4'd0, w_ssg_sound_out0 } + { 4'd0, w_ssg_sound_out1 } + 
			w_opll_sound_out0 + w_opll_sound_out1 + 
			w_opl2_sound_out0 + w_opl2_sound_out1 + 
			w_adpcm_sound_out_l0 + w_adpcm_sound_out_l1 +
			w_adpcm_sound_out_r0 + w_adpcm_sound_out_r1 +
			w_dcsg_sound_out0 + w_dcsg_sound_out1 + 
			{ 3'd0, w_scc_sound_out, 2'd0 };

	i2s_audio u_i2s (
		.clk				( clk_25m					),
		.reset_n			( w_reset_n					),
		.sound_l_in			( w_sound_l					),
		.sound_r_in			( w_sound_r					),
		.i2s_audio_din		( audio_sdata				),
		.i2s_audio_lrclk	( audio_lrclk				),
		.i2s_audio_bclk		( audio_bclk				)
	);

	assign audio_mclk	= 1'bz;

endmodule
