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
	input			slot_reset_n,				//	G11
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
	wire 			clk_171m;				//	171.81816MHz for serial clock (for 3.579545MHz)
	wire 			clk_42m;				//	42.95454MHz for system bus clock
	wire 			clk_24m;				//	24.16193MHz for I2S audio
	wire			w_reset_n;
	wire	[15:0]	w_bus_address;
	wire			w_bus_io;
	wire			w_bus_write;
	wire			w_bus_valid;
	wire			w_bus_ready;
	wire	[7:0]	w_bus_wdata;
	wire	[7:0]	w_bus_rdata;
	wire			w_bus_rdata_en;
	wire			w_scc_bank_wait_n;

	wire			w_bus_timer_cs;
	wire			w_bus_opl2_cs;
	wire			w_bus_opll_cs;
	wire			w_bus_ssg_cs;
	wire			w_bus_scc_cs;
	wire			w_bus_opm_cs;

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
	wire			w_bus_opm_ready;
	wire	[7:0]	w_bus_opm_rdata;
	wire			w_bus_opm_rdata_en;
	wire	[7:0]	w_bus_decode_rdata;
	wire			w_bus_decode_rdata_en;
	wire			w_opm_wait_n;
	wire			w_opm_intr_n;
	wire			w_scc_memory_cs;
	wire	[5:0]	w_scc_ma;
	wire			w_mixer_reg_en;
	wire	[7:0]	w_ssg_volume;
	wire	[7:0]	w_opll_volume;
	wire	[7:0]	w_opl2_volume;
	wire	[7:0]	w_scc_volume;
	wire	[7:0]	w_opm_volume;
	wire	[7:0]	w_master_volume;

	wire	[7:0]	w_bus_scc_bank_rdata;
	wire			w_bus_scc_bank_rdata_en;

	wire	[15:0]	w_opl2_sound_out_l;
	wire	[15:0]	w_opl2_sound_out_r;
	wire			w_adpcm_write;
	wire			w_adpcm_valid;
	wire			w_adpcm_ready;
	wire	[17:0]	w_adpcm_address;
	wire	[7:0]	w_adpcm_wdata;
	wire	[7:0]	w_adpcm_rdata;
	wire			w_adpcm_rdata_en;

	wire	[15:0]	w_opll_sound_l_out;
	wire	[15:0]	w_opll_sound_r_out;

	wire	[12:0]	w_ssg_sound_l_out;
	wire	[12:0]	w_ssg_sound_r_out;

	wire	[10:0]	w_scc_sound_l_out;
	wire	[10:0]	w_scc_sound_r_out;

	wire	[15:0]	w_opm_sound_l_out;
	wire	[15:0]	w_opm_sound_r_out;

	reg		[3:0]	ff_divider;
	reg				ff_enable;
	wire			w_int_n;
	wire			w_timer_intr_n;
	wire			w_opl2_intr_n;
	wire	[3:0]	w_led;
	wire signed	[23:0]	w_audio_l;
	wire signed	[23:0]	w_audio_r;
	wire			w_audio_valid;
	wire			w_audio_request;
	wire			w_audio_reset_n;
	wire	[23:0]	w_i2s_audio_l;
	wire	[23:0]	w_i2s_audio_r;

	wire	[17:0]	w_cpu_address;
	wire			w_cpu_valid;
	wire			w_cpu_ready;
	wire			w_cpu_write;
	wire	[7:0]	w_cpu_wdata;
	wire	[7:0]	w_cpu_rdata;
	wire			w_cpu_rdata_en;

	wire			w_rom_bus_address;
	wire			w_rom_bus_valid;
	wire			w_rom_bus_ready;
	wire			w_rom_bus_write;
	wire	[7:0]	w_rom_bus_wdata;
	wire	[7:0]	w_rom_bus_rdata;
	wire			w_rom_bus_rdata_en;
	wire			w_init_rom_bus_address;
	wire			w_init_rom_bus_valid;
	wire			w_init_rom_bus_ready;
	wire			w_init_rom_bus_write;
	wire	[7:0]	w_init_rom_bus_wdata;
	wire	[7:0]	w_init_rom_stream_rdata;
	wire			w_init_rom_stream_valid;
	wire			w_init_rom_stream_ready;
	wire			w_init_rom_stream_stop;
	wire			w_rom_bus_address_sel;
	wire			w_rom_bus_valid_sel;
	wire			w_rom_bus_write_sel;
	wire	[7:0]	w_rom_bus_wdata_sel;

	wire	[18:0]	w_sram_address;
	wire			w_sram_valid;
	wire			w_sram_ready;
	wire			w_sram_write;
	wire	[7:0]	w_sram_wdata;
	wire	[7:0]	w_sram_rdata;
	wire			w_sram_rdata_en;
	wire	[18:0]	w_init_sram_bus_address;
	wire			w_init_sram_bus_valid;
	wire			w_init_sram_bus_ready;
	wire			w_init_sram_bus_write;
	wire			w_init_sram_bus_burst;
	wire	[7:0]	w_init_sram_bus_wdata;
	wire	[18:0]	w_sram_address_sel;
	wire			w_sram_valid_sel;
	wire			w_sram_write_sel;
	wire			w_sram_burst_sel;
	wire	[7:0]	w_sram_wdata_sel;
	wire			w_arb_sram_ready;
	wire			w_arb_sram_rdata_en;
	wire			w_sysctrl_rom_bus_ready;
	wire			w_sysctrl_rom_bus_rdata_en;

	wire			w_bus_sysctrl_cs;
	wire			w_bus_sysctrl_ready;
	wire	[7:0]	w_bus_sysctrl_rdata;
	wire			w_bus_sysctrl_rdata_en;
	wire			w_wait_n;
	wire			w_sram_initialize;
	reg		[1:0]	ff_slot_switch_sync = 2'b11;
	reg		[15:0]	ff_slot_switch_count = 16'd0;
	reg				ff_slot_connect_request = 1'b0;
	reg		[1:0]	ff_slot_idle_sync = 2'b00;
	reg				ff_slot_connected = 1'b0;

	//	SLOT_WAIT: 1 or HiZ -> /WAIT=0 (MSX waits), 0 -> /WAIT=HiZ
	assign slot_wait	= ff_slot_connected & ~(w_wait_n & w_scc_bank_wait_n & w_opm_wait_n);

	//	DIPSW[1]: OFF/open = disconnected, ON/GND = connected.
	//	Debounce for about 1.5ms; connect only between /RD and /WR cycles.
	always @( posedge clk_42m ) begin
		if( !w_reset_n ) begin
			ff_slot_switch_sync		<= 2'b11;
			ff_slot_switch_count	<= 16'd0;
			ff_slot_connect_request	<= 1'b0;
			ff_slot_idle_sync		<= 2'b00;
			ff_slot_connected		<= 1'b0;
		end
		else begin
			ff_slot_switch_sync	<= { ff_slot_switch_sync[0], dipsw[1] };
			ff_slot_idle_sync	<= { ff_slot_idle_sync[0], slot_rd_n & slot_wr_n };
			if( ff_slot_connect_request == ~ff_slot_switch_sync[1] ) begin
				ff_slot_switch_count <= 16'd0;
			end
			else if( ff_slot_switch_count == 16'hFFFF ) begin
				ff_slot_connect_request <= ~ff_slot_switch_sync[1];
				ff_slot_switch_count <= 16'd0;
			end
			else begin
				ff_slot_switch_count <= ff_slot_switch_count + 16'd1;
			end

			if( !ff_slot_connect_request ) begin
				ff_slot_connected <= 1'b0;
			end
			else if( ff_slot_idle_sync[1] && slot_rd_n && slot_wr_n ) begin
				ff_slot_connected <= 1'b1;
			end
		end
	end

	// ---------------------------------------------------------
	always @( posedge clk_42m ) begin
		if( !w_reset_n ) begin
			ff_divider	<= 4'd0;
			ff_enable	<= 1'b0;
		end
		else if( ff_divider == 4'd11 ) begin
			ff_divider	<= 4'd0;
			ff_enable	<= 1'b1;				//	3.579545MHz
		end
		else begin
			ff_divider	<= ff_divider + 4'd1;
			ff_enable	<= 1'b0;
		end
	end

	Gowin_PLL u_pll(
		.clkin					( clk_28m					),	//	 28.63636MHz (x1: 28.64MHz)
		.clkout0				( clk_171m					),	//	171.81816MHz (x6: 171.84MHz)
		.clkout1				( clk_24m					),	//	 24.16193MHz (x27/32: 24.165MHz)
		.mdclk					( clk_50m					)	//	 50MHz
	);

    Gowin_CLKDIV u_div4 (
        .clkout					( clk_42m					),	//	42.95454MHz  (x6/4: 42.96MHz)
        .hclkin					( clk_171m					),	//	171.81816MHz (x6: 171.84MHz)
        .resetn					( 1'b1						)	//	free-running: w_reset_n depends on clk_42m itself, would deadlock
    );

	// ---------------------------------------------------------
	msx_slot u_msx_slot (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.slot_enable			( ff_slot_connected			),
		.p_slot_reset_n			( slot_reset_n				),
		.p_slot_sltsl_n			( slot_sltsl_n				),
		.p_slot_memreq_n		( slot_mereq_n				),
		.p_slot_ioreq_n			( slot_ioreq_n				),
		.p_slot_wr_n			( slot_wr_n | ~ff_slot_connected	),
		.p_slot_rd_n			( slot_rd_n | ~ff_slot_connected	),
		.p_slot_address			( slot_a					),
		.p_slot_data			( slot_d					),
		.p_slot_int				( slot_intr					),
		.p_slot_data_dir		( slot_busdir				),
		.int_n					( w_int_n					),
		.bus_address			( w_bus_address				),
		.bus_io					( w_bus_io					),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_ready				),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_rdata				),
		.bus_rdata_en			( w_bus_rdata_en			),
		.mixer_reg_en			( w_mixer_reg_en			),
		.ssg_volume				( w_ssg_volume				),
		.opll_volume			( w_opll_volume				),
		.opl2_volume			( w_opl2_volume				),
		.scc_volume				( w_scc_volume				),
		.opm_volume				( w_opm_volume				),
		.master_volume			( w_master_volume			)
	);

	//	Memory mapped I/O (7FF0h-7FFFh) is visible when RAM Mode = 0, or when
	//	BANK1 selects a ROM bank (#0-#15, including the #32-#47 mirror).
	//	w_scc_ma = { RAM Mode, BANK#[4:0] } of the bank selected by the current address.
	assign w_mixer_reg_en = ~w_scc_ma[5] | ~w_scc_ma[4];

	// ---------------------------------------------------------
	y8960_address_decode u_y8960_address_decode (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.bus_address			( w_bus_address				),
		.bus_io					( w_bus_io					),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_ready				),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_decode_rdata		),
		.bus_rdata_en			( w_bus_decode_rdata_en		),
		.bus_timer_cs			( w_bus_timer_cs			),
		.bus_opll_cs			( w_bus_opll_cs				),
		.bus_opl2_cs			( w_bus_opl2_cs				),
		.bus_ssg_cs				( w_bus_ssg_cs				),
		.bus_scc_cs				( w_bus_scc_cs				),
		.bus_opm_cs				( w_bus_opm_cs				),
		.bus_sysctrl_cs			( w_bus_sysctrl_cs			),
		.bus_timer_ready		( w_bus_timer_ready			),
		.bus_opll_ready			( w_bus_opll_ready			),
		.bus_opl2_ready			( w_bus_opl2_ready			),
		.bus_ssg_ready			( w_bus_ssg_ready			),
		.bus_scc_ready			( w_bus_scc_ready			),
		.bus_opm_ready			( w_bus_opm_ready			),
		.bus_sysctrl_ready		( w_bus_sysctrl_ready		),
		.memory_io_en			( w_mixer_reg_en			),
		.led					(							)
	);

	assign w_bus_rdata		= w_bus_timer_rdata & w_bus_opl2_rdata & w_bus_ssg_rdata & w_bus_scc_rdata & w_bus_sysctrl_rdata & w_bus_scc_bank_rdata & w_bus_opm_rdata & w_bus_decode_rdata;
	assign w_bus_rdata_en	= w_bus_timer_rdata_en | w_bus_opl2_rdata_en | w_bus_ssg_rdata_en | w_bus_scc_rdata_en | w_bus_sysctrl_rdata_en | w_bus_scc_bank_rdata_en | w_bus_opm_rdata_en | w_bus_decode_rdata_en;
	assign w_int_n			= w_timer_intr_n & w_opl2_intr_n & w_opm_intr_n;

	scc_bank u_scc_bank (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.bus_cs					( w_bus_scc_cs				),
		.bus_address			( w_bus_address				),
		.bus_io					( w_bus_io					),
		.bus_valid				( w_bus_valid				),
		.bus_write				( w_bus_write				),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_scc_bank_rdata		),
		.bus_rdata_en			( w_bus_scc_bank_rdata_en	),
		.wait_n					( w_scc_bank_wait_n			),
		.scc_memory_cs_n		( w_scc_memory_cs			),
		.scc_ma					( w_scc_ma					),
		.cpu_address			( w_cpu_address				),
		.cpu_valid				( w_cpu_valid				),
		.cpu_ready				( w_cpu_ready				),
		.cpu_write				( w_cpu_write				),
		.cpu_wdata				( w_cpu_wdata				),
		.cpu_rdata				( w_cpu_rdata				),
		.cpu_rdata_en			( w_cpu_rdata_en			)
	);

	// ---------------------------------------------------------
	msx_timer u_msx_timer (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.bus_cs					( w_bus_timer_cs			),
		.bus_address			( w_bus_address[1:0]		),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_timer_ready			),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_timer_rdata			),
		.bus_rdata_en			( w_bus_timer_rdata_en		),
		.intr_n					( w_timer_intr_n			)
	);

	// ---------------------------------------------------------
	opl2 u_opl2 (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.enable					( ff_enable					),
		.bus_cs					( w_bus_opl2_cs				),
		.bus_address			( w_bus_address[0]			),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_opl2_ready			),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_opl2_rdata			),
		.bus_rdata_en			( w_bus_opl2_rdata_en		),
		.opl2_sound_out_l		( w_opl2_sound_out_l		),
		.opl2_sound_out_r		( w_opl2_sound_out_r		),
		.intr_n					( w_opl2_intr_n				),
		.adpcm_write			( w_adpcm_write				),
		.adpcm_valid			( w_adpcm_valid				),
		.adpcm_ready			( w_adpcm_ready				),
		.adpcm_address			( w_adpcm_address			),
		.adpcm_wdata			( w_adpcm_wdata				),
		.adpcm_rdata			( w_adpcm_rdata				),
		.adpcm_rdata_en			( w_adpcm_rdata_en			)
	);

	// ---------------------------------------------------------
	opm u_opm (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.enable					( ff_enable					),
		.bus_cs					( w_bus_opm_cs				),
		.bus_io					( w_bus_io					),
		.bus_address			( w_bus_address[0]			),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_opm_ready			),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_opm_rdata			),
		.bus_rdata_en			( w_bus_opm_rdata_en		),
		.wait_n					( w_opm_wait_n				),
		.intr_n					( w_opm_intr_n				),
		.sound_l_out			( w_opm_sound_l_out			),
		.sound_r_out			( w_opm_sound_r_out			)
	);

	// ---------------------------------------------------------
	opllex u_opllex (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.enable					( ff_enable					),
		.bus_cs					( w_bus_opll_cs				),
		.bus_address			( w_bus_address[0]			),
		.bus_write				( w_bus_write				),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_opll_ready			),
		.bus_wdata				( w_bus_wdata				),
		.sound_l_out			( w_opll_sound_l_out		),
		.sound_r_out			( w_opll_sound_r_out		)
	);

	// ---------------------------------------------------------
	dual_ssg #(
		.BUILTIN				( 0							)	//	Cartridge: SSG1 read is blocked (MSX main PSG exists)
	) u_dual_ssg (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.enable					( ff_enable					),
		.bus_cs					( w_bus_ssg_cs				),
		.bus_valid				( w_bus_valid				),
		.bus_write				( w_bus_write				),
		.bus_address			( w_bus_address[1:0]		),
		.bus_ready				( w_bus_ssg_ready			),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_ssg_rdata			),
		.bus_rdata_en			( w_bus_ssg_rdata_en		),
		.ssg_ioa0				( 8'd0						),
		.ssg_iob0				( 							),
		.ssg_ioa1				( { 6'd0, dipsw }			),
		.ssg_iob1				(							),
		.sound_l_out			( w_ssg_sound_l_out			),
		.sound_r_out			( w_ssg_sound_r_out			),
		.mode					( 2'b11						)
	);

	assign led		= w_led;

	// ---------------------------------------------------------
	scc u_scc (
		.reset_n				( w_reset_n					),
		.clk					( clk_42m					),
		.enable					( ff_enable					),
		.bus_cs					( w_bus_scc_cs				),
		.bus_address			( w_bus_address				),
		.bus_write				( w_bus_write				),
		.bus_ready				( w_bus_scc_ready			),
        .bus_valid				( w_bus_valid				),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_scc_rdata			),
		.bus_rdata_en			( w_bus_scc_rdata_en		),
		.scc_memory_cs			( w_scc_memory_cs			),
		.scc_ma					( w_scc_ma					),
		.sound_l_out			( w_scc_sound_l_out			),
		.sound_r_out			( w_scc_sound_r_out			)
	);

	// ---------------------------------------------------------
	//	System Controller
	// ---------------------------------------------------------
	system_controller #(
		.device_id				( 8'h02						)
	) u_system_controller (
		.clk					( clk_42m					),
		.reset_n				( w_reset_n					),
		.bus_cs					( w_bus_sysctrl_cs			),
		.bus_address			( w_bus_address[3:0]		),
		.bus_valid				( w_bus_valid				),
		.bus_ready				( w_bus_sysctrl_ready		),
		.bus_write				( w_bus_write				),
		.bus_wdata				( w_bus_wdata				),
		.bus_rdata				( w_bus_sysctrl_rdata		),
		.bus_rdata_en			( w_bus_sysctrl_rdata_en	),
		.rom_bus_address		( w_rom_bus_address			),
		.rom_bus_valid			( w_rom_bus_valid			),
		.rom_bus_ready			( w_sysctrl_rom_bus_ready	),
		.rom_bus_write			( w_rom_bus_write			),
		.rom_bus_wdata			( w_rom_bus_wdata			),
		.rom_bus_rdata			( w_rom_bus_rdata			),
		.rom_bus_rdata_en		( w_sysctrl_rom_bus_rdata_en	),
		.init_rom_bus_address	( w_init_rom_bus_address	),
		.init_rom_bus_valid		( w_init_rom_bus_valid		),
		.init_rom_bus_ready		( w_init_rom_bus_ready		),
		.init_rom_bus_write		( w_init_rom_bus_write		),
		.init_rom_bus_wdata		( w_init_rom_bus_wdata		),
		.init_rom_stream_rdata	( w_init_rom_stream_rdata	),
		.init_rom_stream_valid	( w_init_rom_stream_valid	),
		.init_rom_stream_ready	( w_init_rom_stream_ready	),
		.init_rom_stream_stop	( w_init_rom_stream_stop	),
		.sram_ready				( w_sram_ready				),
		.init_sram_bus_address	( w_init_sram_bus_address	),
		.init_sram_bus_valid	( w_init_sram_bus_valid		),
		.init_sram_bus_ready	( w_init_sram_bus_ready		),
		.init_sram_bus_write	( w_init_sram_bus_write		),
		.init_sram_bus_burst	( w_init_sram_bus_burst		),
		.init_sram_bus_wdata	( w_init_sram_bus_wdata		),
		.sram_initialize		( w_sram_initialize			),
		.wait_n					( w_wait_n					)
	);

	assign w_rom_bus_address_sel	= w_sram_initialize ? w_init_rom_bus_address : w_rom_bus_address;
	assign w_rom_bus_valid_sel		= w_sram_initialize ? w_init_rom_bus_valid : w_rom_bus_valid;
	assign w_rom_bus_write_sel		= w_sram_initialize ? w_init_rom_bus_write : w_rom_bus_write;
	assign w_rom_bus_wdata_sel		= w_sram_initialize ? w_init_rom_bus_wdata : w_rom_bus_wdata;
	assign w_init_rom_bus_ready		= w_rom_bus_ready;

	assign w_sram_address_sel		= w_sram_initialize ? w_init_sram_bus_address : w_sram_address;
	assign w_sram_valid_sel			= w_sram_initialize ? w_init_sram_bus_valid : w_sram_valid;
	assign w_sram_write_sel			= w_sram_initialize ? w_init_sram_bus_write : w_sram_write;
	assign w_sram_burst_sel			= w_sram_initialize & w_init_sram_bus_burst;
	assign w_sram_wdata_sel			= w_sram_initialize ? w_init_sram_bus_wdata : w_sram_wdata;
	assign w_init_sram_bus_ready	= w_sram_ready;

	//	While booting, SPI ROM and SerialSRAM are owned by the boot copy sequencer.
	assign w_sysctrl_rom_bus_ready		= w_rom_bus_ready & ~w_sram_initialize;
	assign w_sysctrl_rom_bus_rdata_en	= w_rom_bus_rdata_en & ~w_sram_initialize;
	assign w_arb_sram_ready				= w_sram_ready & ~w_sram_initialize;
	assign w_arb_sram_rdata_en			= w_sram_rdata_en & ~w_sram_initialize;

	// ---------------------------------------------------------
	//	SRAM Arbiter
	// ---------------------------------------------------------
	sram_arbiter u_sram_arbiter (
		.clk				( clk_42m					),
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
		.ssram_ready		( w_arb_sram_ready			),
		.ssram_write		( w_sram_write				),
		.ssram_wdata		( w_sram_wdata				),
		.ssram_rdata		( w_sram_rdata				),
		.ssram_rdata_en		( w_arb_sram_rdata_en		)
	);

	// ---------------------------------------------------------
	//	Serial Flash ROM
	// ---------------------------------------------------------
	ip_spi_rom u_spi_rom (
		.reset_n			( w_reset_n					),
		.clk				( clk_42m					),
		.clk_serial			( clk_171m					),
		.bus_cs				( 1'b1						),
		.bus_address		( w_rom_bus_address_sel		),
		.bus_write			( w_rom_bus_write_sel		),
		.bus_valid			( w_rom_bus_valid_sel		),
		.bus_ready			( w_rom_bus_ready			),
		.bus_wdata			( w_rom_bus_wdata_sel		),
		.bus_rdata			( w_rom_bus_rdata			),
		.bus_rdata_en		( w_rom_bus_rdata_en		),
		.stream_rdata		( w_init_rom_stream_rdata	),
		.stream_valid		( w_init_rom_stream_valid	),
		.stream_ready		( w_init_rom_stream_ready	),
		.stream_stop		( w_init_rom_stream_stop	),
		.srom_cs_n			( flash_spi_cs_n			),
		.srom_clk			( flash_spi_clk				),
		.srom_hold_n		( flash_spi_io[3]			),
		.srom_wp_n			( flash_spi_io[2]			),
		.srom_do			( flash_spi_io[1]			),
		.srom_di			( flash_spi_io[0]			)
	);

	// ---------------------------------------------------------
	//	Serial SRAM
	// ---------------------------------------------------------
	ssram u_ssram (
		.n_reset			( w_reset_n					),
		.clk				( clk_42m					),
		.clk_serial			( clk_171m					),
		.bus_cs				( 1'b1						),
		.bus_address		( w_sram_address_sel		),
		.bus_write			( w_sram_write_sel			),
		.bus_burst			( w_sram_burst_sel			),
		.bus_valid			( w_sram_valid_sel			),
		.bus_wdata			( w_sram_wdata_sel			),
		.bus_ready			( w_sram_ready				),
		.bus_rdata			( w_sram_rdata				),
		.bus_rdata_en		( w_sram_rdata_en			),
		.sram_sclk			( sram_sclk					),
		.sram_ce_n			( sram_ce_n					),
		.sram_sio			( sram_sio					)
	);

	// ---------------------------------------------------------
	//	Time-multiplexed audio mixer
	// ---------------------------------------------------------
	mixier u_mixier (
		.clk				( clk_42m					),
		.reset_n			( w_reset_n					),
		.ssg_l				( w_ssg_sound_l_out			),
		.ssg_r				( w_ssg_sound_r_out			),
		.opll_l				( w_opll_sound_l_out		),
		.opll_r				( w_opll_sound_r_out		),
		.opl2_l				( w_opl2_sound_out_l		),
		.opl2_r				( w_opl2_sound_out_r		),
		.scc_l				( w_scc_sound_l_out			),
		.scc_r				( w_scc_sound_r_out			),
		.opm_l				( w_opm_sound_l_out			),
		.opm_r				( w_opm_sound_r_out			),
		.ssg_volume			( w_ssg_volume				),
		.opll_volume		( w_opll_volume				),
		.opl2_volume		( w_opl2_volume				),
		.scc_volume			( w_scc_volume				),
		.opm_volume			( w_opm_volume				),
		.master_volume		( w_master_volume			),
		.audio_l_out		( w_audio_l					),
		.audio_r_out		( w_audio_r					),
		.audio_valid		( w_audio_valid				)
	);

	audio_cdc u_audio_cdc (
		.clk_src			( clk_42m					),
		.clk_dst			( clk_24m					),
		.reset_n			( w_reset_n					),
		.src_valid			( w_audio_valid				),
		.src_l				( w_audio_l					),
		.src_r				( w_audio_r					),
		.dst_request		( w_audio_request			),
		.dst_reset_n		( w_audio_reset_n			),
		.dst_l				( w_i2s_audio_l				),
		.dst_r				( w_i2s_audio_r				)
	);

	i2s_audio u_i2s (
		.clk				( clk_24m					),
		.reset_n			( w_audio_reset_n			),
		.sound_l_in			( w_i2s_audio_l				),
		.sound_r_in			( w_i2s_audio_r				),
		.sample_request		( w_audio_request			),
		.i2s_audio_din		( audio_sdata				),
		.i2s_audio_lrclk	( audio_lrclk				),
		.i2s_audio_bclk		( audio_bclk				)
	);

	assign audio_mclk	= 1'bz;
	assign w_led		= w_audio_l[3:0];
endmodule
