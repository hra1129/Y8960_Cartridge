//
//	system_controller.v
//	 System Controller
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
	//	Burst copy control
	input			sram_ready,
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
	//	40h Enabler   : 40h を書き込むと有効になる。有効な時に読み出すと BFh を返す。
	//
	//	41h SubFunc   : 機能選択
	//		SubFunc に指定する機能番号
	//		00h : Device Information
	//		01h : Config ROM interface
	//		02h-FFh : Reserved
	//
	//	- 00h Device Information
	//		42h DeviceID : 下記のデバイスIDを指定すると、存在する場合は反転した値を読み出せる。
	//			00h: N/A
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
	//			無効な場合、読み出すと FFh が返る。
	//		43h System Information (42h=CPU Module の場合) : Read Only
	//			bit0: 0=FPGA Hardware, 1=Software Emulator
	//
	//	- 01h Config ROM interface
	//		42h DeviceID : 下記のデバイスIDを指定すると、存在する場合は反転した値を読み出せる。
	//			00h: N/A
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
	//			無効な場合、読み出すと FFh が返る。
	//		43h Address(L): ターゲットアドレス指定、bit7-0
	//		44h Address(M): ターゲットアドレス指定、bit15-8
	//		45h Address(H): ターゲットアドレス指定、bit23-16
	//		46h Command   : Command実行
	//			Command番号
	//			00h: Read
	//			01h: Write
	//			02h: Sector Erase
	//			03h: All Erase
	//			04h-FFh: Reserved
	//		47h Read/Write: Command Read/Write の読み書きデータ
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

	assign burst_rom_start		= ff_burst_start;
	assign burst_rom_address	= c_boot_rom_base;
	assign burst_rom_length		= 17'h1FFFF;
	assign burst_sram_start		= ff_burst_start;
	assign burst_sram_address	= 19'h00000;
	assign burst_sram_length	= 17'h1FFFF;

	assign wait_n		= ff_wait_n;

endmodule
