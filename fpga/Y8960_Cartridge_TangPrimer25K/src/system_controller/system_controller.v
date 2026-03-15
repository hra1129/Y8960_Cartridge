//
//	system_controller.v
//	 System Controller
//
//	Copyright (C) 2026 Takayuki Hara
//
//	譛ｬ繧ｽ繝輔ヨ繧ｦ繧ｧ繧｢縺翫ｈ縺ｳ譛ｬ繧ｽ繝輔ヨ繧ｦ繧ｧ繧｢縺ｫ蝓ｺ縺･縺・※菴懈・縺輔ｌ縺滓ｴｾ逕溽黄縺ｯ縲∽ｻ･荳九・譚｡莉ｶ繧・//	貅縺溘☆蝣ｴ蜷医↓髯舌ｊ縲∝・鬆貞ｸ・♀繧医・菴ｿ逕ｨ縺瑚ｨｱ蜿ｯ縺輔ｌ縺ｾ縺吶・//
//	1.繧ｽ繝ｼ繧ｹ繧ｳ繝ｼ繝牙ｽ｢蠑上〒蜀埼貞ｸ・☆繧句ｴ蜷医∽ｸ願ｨ倥・闡嶺ｽ懈ｨｩ陦ｨ遉ｺ縲∵悽譚｡莉ｶ荳隕ｧ縲√♀繧医・荳玖ｨ・//	  蜈崎ｲｬ譚｡鬆・ｒ縺昴・縺ｾ縺ｾ縺ｮ蠖｢縺ｧ菫晄戟縺吶ｋ縺薙→縲・//	2.繝舌う繝翫Μ蠖｢蠑上〒蜀埼貞ｸ・☆繧句ｴ蜷医・貞ｸ・黄縺ｫ莉伜ｱ槭・繝峨く繝･繝｡繝ｳ繝育ｭ峨・雉・侭縺ｫ縲∽ｸ願ｨ倥・
//	  闡嶺ｽ懈ｨｩ陦ｨ遉ｺ縲∵悽譚｡莉ｶ荳隕ｧ縲√♀繧医・荳玖ｨ伜・雋ｬ譚｡鬆・ｒ蜷ｫ繧√ｋ縺薙→縲・//	3.譖ｸ髱｢縺ｫ繧医ｋ莠句燕縺ｮ險ｱ蜿ｯ縺ｪ縺励↓縲∵悽繧ｽ繝輔ヨ繧ｦ繧ｧ繧｢繧定ｲｩ螢ｲ縲√♀繧医・蝠・･ｭ逧・↑陬ｽ蜩√ｄ豢ｻ蜍・//	  縺ｫ菴ｿ逕ｨ縺励↑縺・％縺ｨ縲・//
//	譛ｬ繧ｽ繝輔ヨ繧ｦ繧ｧ繧｢縺ｯ縲∬送菴懈ｨｩ閠・↓繧医▲縺ｦ縲檎樟迥ｶ縺ｮ縺ｾ縺ｾ縲肴署萓帙＆繧後※縺・∪縺吶り送菴懈ｨｩ閠・・縲・//	迚ｹ螳夂岼逧・∈縺ｮ驕ｩ蜷域ｧ縺ｮ菫晁ｨｼ縲∝膚蜩∵ｧ縺ｮ菫晁ｨｼ縲√∪縺溘◎繧後↓髯仙ｮ壹＆繧後↑縺・√＞縺九↑繧区・遉ｺ
//	逧・ｂ縺励￥縺ｯ證鈴ｻ吶↑菫晁ｨｼ雋ｬ莉ｻ繧りｲ縺・∪縺帙ｓ縲り送菴懈ｨｩ閠・・縲∽ｺ狗罰縺ｮ縺・°繧薙ｒ蝠上ｏ縺壹∵錐螳ｳ
//	逋ｺ逕溘・蜴溷屏縺・°繧薙ｒ蝠上ｏ縺壹√°縺､雋ｬ莉ｻ縺ｮ譬ｹ諡縺悟･醍ｴ・〒縺ゅｋ縺句宍譬ｼ雋ｬ莉ｻ縺ｧ縺ゅｋ縺具ｼ磯℃螟ｱ
//	縺昴・莉悶・・我ｸ肴ｳ戊｡檎ぜ縺ｧ縺ゅｋ縺九ｒ蝠上ｏ縺壹∽ｻｮ縺ｫ縺昴・繧医≧縺ｪ謳榊ｮｳ縺檎匱逕溘☆繧句庄閭ｽ諤ｧ繧堤衍繧・//	縺輔ｌ縺ｦ縺・◆縺ｨ縺励※繧ゅ∵悽繧ｽ繝輔ヨ繧ｦ繧ｧ繧｢縺ｮ菴ｿ逕ｨ縺ｫ繧医▲縺ｦ逋ｺ逕溘＠縺滂ｼ井ｻ｣譖ｿ蜩√∪縺溘・莉｣逕ｨ繧ｵ
//	繝ｼ繝薙せ縺ｮ隱ｿ驕斐∽ｽｿ逕ｨ縺ｮ蝟ｪ螟ｱ縲√ョ繝ｼ繧ｿ縺ｮ蝟ｪ螟ｱ縲∝茜逶翫・蝟ｪ螟ｱ縲∵･ｭ蜍吶・荳ｭ譁ｭ繧ょ性繧√√∪縺溘◎
//	繧後↓髯仙ｮ壹＆繧後↑縺・ｼ臥峩謗･謳榊ｮｳ縲・俣謗･謳榊ｮｳ縲∝・逋ｺ逧・↑謳榊ｮｳ縲∫音蛻･謳榊ｮｳ縲∵・鄂ｰ逧・錐螳ｳ縲√∪
//	縺溘・邨先棡謳榊ｮｳ縺ｫ縺､縺・※縲∽ｸ蛻・ｲｬ莉ｻ繧定ｲ繧上↑縺・ｂ縺ｮ縺ｨ縺励∪縺吶・//
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

module system_controller#(
	parameter		device_id = 8'h61
) (
	input			clk,
	input			reset_n,
	//	I/O
	input			bus_cs,				//	I/O 40h...4Fh ChipSelect
	input	[3:0]	bus_address,		//	I/O Address LSB
	input			bus_valid,
	output			bus_ready,
	input			bus_write,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	//	SerialFrashROM I/F
	output	[22:0]	rom_address,		//	8MB
	output			rom_valid,
	input			rom_ready,
	output	[1:0]	rom_command,
	output	[7:0]	rom_wdata,
	input	[7:0]	rom_rdata,
	input			rom_rdata_en,
	//	SerialSRAM I/F
	output	[18:0]	sram_address,		//	512KB
	output			sram_valid,
	input			sram_ready,
	output			sram_write,
	output	[7:0]	sram_wdata,
	input	[7:0]	sram_rdata,
	input			sram_rdata_en,
	//	Burst copy control
	output			burst_rom_start,
	output	[22:0]	burst_rom_address,
	output	[16:0]	burst_rom_length,
	input			burst_rom_active,
	output			burst_sram_start,
	output	[18:0]	burst_sram_address,
	output	[16:0]	burst_sram_length,
	input			burst_sram_active,
	//	Wait signal
	output			wait_n
);
	// ------------------------------------------------------------------------
	//	I/O
	//	40h Enabler   : 40h 繧呈嶌縺崎ｾｼ繧縺ｨ譛牙柑縺ｫ縺ｪ繧九よ怏蜉ｹ縺ｪ譎ゅ↓隱ｭ縺ｿ蜃ｺ縺吶→ BFh 繧定ｿ斐☆縲・	//
	//	41h SubFunc   : 讖溯・驕ｸ謚・	//		SubFunc 縺ｫ謖・ｮ壹☆繧区ｩ溯・逡ｪ蜿ｷ
	//		00h : Device Information
	//		01h : Config ROM interface
	//		02h-FFh : Reserved
	//
	//	- 00h Device Information
	//		42h DeviceID : 荳玖ｨ倥・繝・ヰ繧､繧ｹID繧呈欠螳壹☆繧九→縲∝ｭ伜惠縺吶ｋ蝣ｴ蜷医・蜿崎ｻ｢縺励◆蛟､繧定ｪｭ縺ｿ蜃ｺ縺帙ｋ縲・	//			00h: N/A
	//			01h: CPU Module
	//			02h: SOUND Module
	//			03h: VIDEO Module
	//			04h-3Fh: Reserved
	//			40h: BIOS
	//			41h-5Fh: Reserved
	//			60h: VDP Cartridge
	//			61h: SOUND Cartridge
	//			62h-FEh: Reserved
	//			FFh: N/A
	//			辟｡蜉ｹ縺ｪ蝣ｴ蜷医∬ｪｭ縺ｿ蜃ｺ縺吶→ FFh 縺瑚ｿ斐ｋ縲・	//		43h System Information (42h=CPU Module 縺ｮ蝣ｴ蜷・ : Read Only
	//			bit0: 0=FPGA Hardware, 1=Software Emulator
	//
	//	- 01h Config ROM interface
	//		42h DeviceID : 荳玖ｨ倥・繝・ヰ繧､繧ｹID繧呈欠螳壹☆繧九→縲∝ｭ伜惠縺吶ｋ蝣ｴ蜷医・蜿崎ｻ｢縺励◆蛟､繧定ｪｭ縺ｿ蜃ｺ縺帙ｋ縲・	//			00h: N/A
	//			01h: CPU Module (Config ROM) [FPGA Hardware only]
	//			02h: SOUND Module (Config ROM) [FPGA Hardware only]
	//			03h: VIDEO Module (Config ROM) [FPGA Hardware only]
	//			04h-3Fh: Reserved
	//			40h: BIOS
	//			41h-5Fh: Reserved
	//			60h: VDP Cartridge (Config ROM)
	//			61h: SOUND Cartridge (Config ROM + BIOS)
	//			62h-FEh: Reserved
	//			FFh: N/A
	//			辟｡蜉ｹ縺ｪ蝣ｴ蜷医∬ｪｭ縺ｿ蜃ｺ縺吶→ FFh 縺瑚ｿ斐ｋ縲・	//		43h Address(L): 繧ｿ繝ｼ繧ｲ繝・ヨ繧｢繝峨Ξ繧ｹ謖・ｮ壹｜it7-0
	//		44h Address(M): 繧ｿ繝ｼ繧ｲ繝・ヨ繧｢繝峨Ξ繧ｹ謖・ｮ壹｜it15-8
	//		45h Address(H): 繧ｿ繝ｼ繧ｲ繝・ヨ繧｢繝峨Ξ繧ｹ謖・ｮ壹｜it23-16
	//		46h Command   : Command螳溯｡・	//			Command逡ｪ蜿ｷ
	//			00h: Read
	//			01h: Write
	//			02h: Sector Erase
	//			03h: All Erase
	//			04h-FFh: Reserved
	//		47h Read/Write: Command Read/Write 縺ｮ隱ｭ縺ｿ譖ｸ縺阪ョ繝ｼ繧ｿ
	//
	// ------------------------------------------------------------------------
	localparam		c_io_enabler			= 4'h0;		//	40h
	localparam		c_io_devsel				= 4'h1;		//	41h
	localparam		c_io_address_l			= 4'h2;		//	42h
	localparam		c_io_address_m			= 4'h3;		//	43h
	localparam		c_io_address_h			= 4'h4;		//	44h
	localparam		c_io_command			= 4'h5;		//	45h
	localparam		c_io_data				= 4'h6;		//	46h

	localparam		c_command_read			= 8'h00;
	localparam		c_command_write			= 8'h01;
	localparam		c_command_sector_erase	= 8'h02;
	localparam		c_command_all_erase		= 8'h03;

	reg				ff_enable = 1'b0;
	reg				ff_devsel = 1'b0;
	reg		[22:0]	ff_address;
	reg		[7:0]	ff_data;
	reg		[7:0]	ff_rdata;
	reg				ff_rdata_en;

	// ---------------------------------------------------------
	//	State machine
	// ---------------------------------------------------------
	localparam		c_st_boot_burst_start		= 4'd0;
	localparam		c_st_boot_burst_wait_act	= 4'd1;
	localparam		c_st_boot_burst_wait_done	= 4'd2;
	localparam		c_st_idle					= 4'd3;
	localparam		c_st_cmd_req				= 4'd4;
	localparam		c_st_cmd_accept				= 4'd5;
	localparam		c_st_cmd_read_wait			= 4'd6;
	localparam		c_st_cmd_done_wait			= 4'd7;

	localparam	[22:0]	c_boot_rom_base		= 23'h7E0000;

	reg		[3:0]	ff_state;
	reg		[1:0]	ff_rom_command;
	reg				ff_rom_valid;
	reg				ff_wait_n;
	reg				ff_burst_start;

	// ---------------------------------------------------------
	//	Enabler
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_enable <= 1'b0;
		end
		else if( bus_cs && bus_valid && bus_write && bus_address == c_io_enabler ) begin
			if( bus_wdata == 8'h40 ) begin
				ff_enable <= 1'b1;
			end
			else begin
				ff_enable <= 1'b0;
			end
		end
	end

	// ---------------------------------------------------------
	//	device select
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_devsel <= 1'b0;
		end
		else if( !ff_enable ) begin
			//	hold
		end
		else if( bus_cs && bus_valid && bus_write && bus_address == c_io_devsel ) begin
			if( bus_wdata == device_id ) begin
				ff_devsel <= 1'b1;
			end
			else begin
				ff_devsel <= 1'b0;
			end
		end
	end

	// ---------------------------------------------------------
	//	address latch
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_address <= 23'd0;
		end
		else if( !ff_enable || !ff_devsel ) begin
			//	hold
		end
		else if( bus_cs && bus_valid && bus_write ) begin
			case( bus_address )
			c_io_address_l:		ff_address[ 7: 0] <= bus_wdata;
			c_io_address_m:		ff_address[15: 8] <= bus_wdata;
			c_io_address_h:		ff_address[22:16] <= bus_wdata[6:0];
			default:			;
			endcase
		end
	end

	// ---------------------------------------------------------
	//	Data register (46h)
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_data <= 8'd0;
		end
		else if( rom_rdata_en && (ff_state == c_st_cmd_read_wait) ) begin
			ff_data <= rom_rdata;
		end
		else if( ff_enable && ff_devsel && bus_cs && bus_valid && bus_write && bus_address == c_io_data ) begin
			ff_data <= bus_wdata;
		end
	end

	// ---------------------------------------------------------
	//	Main state machine
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_state          <= (device_id == 8'h61) ? c_st_boot_burst_start : c_st_idle;
			ff_wait_n         <= (device_id == 8'h61) ? 1'b0 : 1'b1;
			ff_rom_command    <= 2'd0;
			ff_rom_valid      <= 1'b0;
			ff_burst_start    <= 1'b0;
		end
		else begin
			case( ff_state )
			// --- Boot burst: wait for SRAM init, then assert start signal ---
			c_st_boot_burst_start: begin
				if( sram_ready ) begin
					ff_burst_start <= 1'b1;
					ff_state       <= c_st_boot_burst_wait_act;
				end
			end
			// --- Boot burst: wait for burst to become active ---
			c_st_boot_burst_wait_act: begin
				ff_burst_start <= 1'b0;
				if( burst_rom_active || burst_sram_active ) begin
					ff_state <= c_st_boot_burst_wait_done;
				end
			end
			// --- Boot burst: wait for burst to complete ---
			c_st_boot_burst_wait_done: begin
				if( !burst_rom_active && !burst_sram_active ) begin
					ff_wait_n <= 1'b1;
					ff_state  <= c_st_idle;
				end
			end
			// --- Idle ---
			c_st_idle: begin
				ff_rom_valid  <= 1'b0;
				if( ff_enable && ff_devsel && bus_cs && bus_valid && bus_write && bus_address == c_io_command ) begin
					case( bus_wdata )
					c_command_read: begin
						ff_rom_command <= 2'd0;
						ff_state       <= c_st_cmd_req;
					end
					c_command_write: begin
						ff_rom_command <= 2'd1;
						ff_state       <= c_st_cmd_req;
					end
					c_command_sector_erase: begin
						ff_rom_command <= 2'd2;
						ff_state       <= c_st_cmd_req;
					end
					c_command_all_erase: begin
						ff_rom_command <= 2'd3;
						ff_state       <= c_st_cmd_req;
					end
					default: ;
					endcase
				end
			end
			// --- Command: ROM request ---
			c_st_cmd_req: begin
				if( rom_ready ) begin
					ff_rom_valid <= 1'b1;
					ff_state     <= c_st_cmd_accept;
				end
			end
			// --- Command: wait ROM accept ---
			c_st_cmd_accept: begin
				if( !rom_ready ) begin
					ff_rom_valid <= 1'b0;
					if( ff_rom_command == 2'd0 ) begin
						ff_state <= c_st_cmd_read_wait;
					end
					else begin
						ff_state <= c_st_cmd_done_wait;
					end
				end
			end
			// --- Command: wait ROM read data ---
			c_st_cmd_read_wait: begin
				if( rom_rdata_en ) begin
					// ff_data is updated in the data register always block
					ff_state <= c_st_idle;
				end
			end
			// --- Command: wait ROM write/erase complete ---
			c_st_cmd_done_wait: begin
				if( rom_ready ) begin
					ff_state <= c_st_idle;
				end
			end
			default: begin
				ff_state <= c_st_idle;
			end
			endcase
		end
	end

	// ---------------------------------------------------------
	//	Bus read data
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_rdata <= 8'hFF;
		end
		else if( bus_cs && !bus_write ) begin
			case( bus_address )
			c_io_enabler:	ff_rdata <= ff_enable ? 8'hBF : 8'hFF;
			c_io_devsel:	ff_rdata <= (ff_enable && ff_devsel) ? ~device_id[7:0] : 8'hFF;
			c_io_address_l:	ff_rdata <= (ff_enable && ff_devsel) ? ff_address[ 7: 0] : 8'hFF;
			c_io_address_m:	ff_rdata <= (ff_enable && ff_devsel) ? ff_address[15: 8] : 8'hFF;
			c_io_address_h:	ff_rdata <= (ff_enable && ff_devsel) ? { 1'b0, ff_address[22:16] } : 8'hFF;
			c_io_command:	ff_rdata <= 8'hFF;
			c_io_data:		ff_rdata <= (ff_enable && ff_devsel) ? ff_data : 8'hFF;
			default:		ff_rdata <= 8'hFF;
			endcase
		end
		else begin
			ff_rdata <= 8'hFF;
		end
	end

	// ---------------------------------------------------------
	//	Bus read data enable
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_rdata_en <= 1'b0;
		end
		else if( bus_cs && !bus_write && ff_state == c_st_idle ) begin
			ff_rdata_en <= 1'b1;
		end
		else begin
			ff_rdata_en <= 1'b0;
		end
	end

	// ---------------------------------------------------------
	//	Output assignments
	// ---------------------------------------------------------

	assign bus_ready	= (ff_state == c_st_idle);
	assign bus_rdata	= ff_rdata;
	assign bus_rdata_en	= ff_rdata_en;

	assign rom_address	= ff_address;
	assign rom_valid	= ff_rom_valid;
	assign rom_command	= ff_rom_command;
	assign rom_wdata	= ff_data;

	assign sram_address	= 19'd0;
	assign sram_valid	= 1'b0;
	assign sram_write	= 1'b0;
	assign sram_wdata	= 8'd0;

	assign burst_rom_start		= ff_burst_start;
	assign burst_rom_address	= c_boot_rom_base;
	assign burst_rom_length		= 17'h1FFFF;
	assign burst_sram_start		= ff_burst_start;
	assign burst_sram_address	= 19'h00000;
	assign burst_sram_length	= 17'h1FFFF;

	assign wait_n		= ff_wait_n;

endmodule
