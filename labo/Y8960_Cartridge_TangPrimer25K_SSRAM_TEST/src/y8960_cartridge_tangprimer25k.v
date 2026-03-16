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
	output	[3:0]	led						//	B10,B11,C10,C11
);
	wire			clk_129m;

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
    	.clkout0	( clk_129m	),	// output  clkout0
        .mdclk		( clk_50m	)	// input  mdclk
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
	reg				ff_burst_start = 1'b0;
	reg		[18:0]	ff_burst_address = 19'd0;
	reg		[16:0]	ff_burst_length = 17'd0;
	wire			w_ssram_burst_active;
	wire	[7:0]	w_burst_wdata;
	wire			w_burst_wdata_en;

	ssram u_ssram (
		.clk				( clk_28m				),
		.clk_129m			( clk_129m				),
		.reset_n			( w_reset_n				),
		.address			( ff_address			),
		.valid				( ff_valid				),
		.ready				( w_ssram_ready			),
		.write				( ff_write				),
		.wdata				( ff_wdata				),
		.rdata				( w_ssram_rdata			),
		.rdata_en			( w_ssram_rdata_en		),
		.burst_start		( ff_burst_start		),
		.burst_address		( ff_burst_address		),
		.burst_length		( ff_burst_length		),
		.burst_wdata		( w_burst_wdata			),
		.burst_wdata_en		( w_burst_wdata_en		),
		.burst_active		( w_ssram_burst_active	),
		.sram_sclk			( sram_sclk				),
		.sram_ce_n			( sram_ce_n				),
		.sram_sio			( sram_sio				)
	);

	// ---------------------------------------------------------
	//	Burst data feeder (posedge clk_129m domain)
	//	Generates incrementing byte values for burst write.
	//	Paced at 1 byte per 2 clk_129m cycles to avoid FIFO overflow.
	// ---------------------------------------------------------
	reg		[1:0]	ff_feed_sync = 2'b00;
	reg		[7:0]	ff_feed_data = 8'd0;
	reg				ff_feed_en = 1'b0;
	reg				ff_feed_pace = 1'b0;

	always @( posedge clk_129m ) begin
		if( !w_reset_n ) begin
			ff_feed_sync <= 2'b00;
			ff_feed_data <= 8'd0;
			ff_feed_en   <= 1'b0;
			ff_feed_pace <= 1'b0;
		end
		else begin
			ff_feed_sync <= { ff_feed_sync[0], w_ssram_burst_active };
			if( ff_feed_sync[1] ) begin
				ff_feed_pace <= ~ff_feed_pace;
				if( !ff_feed_pace ) begin
					ff_feed_en <= 1'b1;
				end
				else begin
					ff_feed_en   <= 1'b0;
					ff_feed_data <= ff_feed_data + 8'd1;
				end
			end
			else begin
				ff_feed_data <= 8'd0;
				ff_feed_en   <= 1'b0;
				ff_feed_pace <= 1'b0;
			end
		end
	end

	assign w_burst_wdata   = ff_feed_data;
	assign w_burst_wdata_en = ff_feed_en;

	// ---------------------------------------------------------
	//	Blink timer (toggle every 0.2s for error indication)
	// ---------------------------------------------------------
	reg		[22:0]	ff_blink_count = 23'd0;
	reg				ff_blink = 1'b0;

	always @( posedge clk_28m ) begin
		if( !w_reset_n ) begin
			ff_blink_count <= 23'd0;
			ff_blink       <= 1'b0;
		end
		else if( ff_blink_count == 23'd5727271 ) begin
			ff_blink_count <= 23'd0;
			ff_blink       <= ~ff_blink;
		end
		else begin
			ff_blink_count <= ff_blink_count + 23'd1;
		end
	end

	// ---------------------------------------------------------
	//	Test state machine (clk_28m domain)
	// ---------------------------------------------------------
	localparam	S_WAIT_READY	= 5'd0;
	localparam	S_BURST_START	= 5'd1;
	localparam	S_BURST_WAIT1	= 5'd2;
	localparam	S_BURST_WAIT2	= 5'd3;
	localparam	S_LED0			= 5'd4;
	localparam	S_READ1_REQ		= 5'd5;
	localparam	S_READ1_ACCEPT	= 5'd6;
	localparam	S_READ1_WAIT	= 5'd7;
	localparam	S_LED1			= 5'd8;
	localparam	S_WRITE_REQ		= 5'd9;
	localparam	S_WRITE_ACCEPT	= 5'd10;
	localparam	S_WRITE_WAIT	= 5'd11;
	localparam	S_LED2			= 5'd12;
	localparam	S_READ2_REQ		= 5'd13;
	localparam	S_READ2_ACCEPT	= 5'd14;
	localparam	S_READ2_WAIT	= 5'd15;
	localparam	S_LED3			= 5'd16;
	localparam	S_DONE			= 5'd17;

	reg		[4:0]	ff_state = S_WAIT_READY;
	reg		[18:0]	ff_addr = 19'd0;
	reg		[1:0]	ff_burst_idx = 2'd0;
	reg				ff_error1 = 1'b0;
	reg				ff_error2 = 1'b0;
	reg				ff_phase1_done = 1'b0;
	reg				ff_phase2_done = 1'b0;
	reg				ff_phase3_done = 1'b0;
	reg				ff_phase4_done = 1'b0;

	always @( posedge clk_28m ) begin
		if( !w_reset_n ) begin
			ff_state		<= S_WAIT_READY;
			ff_valid		<= 1'b0;
			ff_write		<= 1'b0;
			ff_wdata		<= 8'd0;
			ff_address		<= 19'd0;
			ff_burst_start	<= 1'b0;
			ff_burst_address <= 19'd0;
			ff_burst_length	<= 17'd0;
			ff_addr			<= 19'd0;
			ff_burst_idx	<= 2'd0;
			ff_error1		<= 1'b0;
			ff_error2		<= 1'b0;
			ff_phase1_done	<= 1'b0;
			ff_phase2_done	<= 1'b0;
			ff_phase3_done	<= 1'b0;
			ff_phase4_done	<= 1'b0;
		end
		else begin
			case( ff_state )
			// -------------------------------------------------
			//	Wait for SSRAM initialization to complete
			// -------------------------------------------------
			S_WAIT_READY: begin
				if( w_ssram_ready ) begin
					ff_state     <= S_BURST_START;
					ff_burst_idx <= 2'd0;
				end
			end

			// -------------------------------------------------
			//	Phase 1: Burst write (increment pattern)
			//	512KB = 4 bursts x 128KB (burst_length max = 17bit)
			// -------------------------------------------------
			S_BURST_START: begin
				ff_burst_start   <= 1'b1;
				ff_burst_address <= { ff_burst_idx, 17'd0 };
				ff_burst_length  <= 17'h1FFFF;
				ff_state         <= S_BURST_WAIT1;
			end
			S_BURST_WAIT1: begin
				ff_burst_start <= 1'b0;
				if( w_ssram_burst_active ) begin
					ff_state <= S_BURST_WAIT2;
				end
			end
			S_BURST_WAIT2: begin
				if( !w_ssram_burst_active ) begin
					if( ff_burst_idx == 2'd3 ) begin
						ff_state <= S_LED0;
					end
					else begin
						ff_burst_idx <= ff_burst_idx + 2'd1;
						ff_state     <= S_BURST_START;
					end
				end
			end
			S_LED0: begin
				ff_phase1_done <= 1'b1;
				ff_addr        <= 19'd0;
				ff_error1      <= 1'b0;
				ff_state       <= S_READ1_REQ;
			end

			// -------------------------------------------------
			//	Phase 2: Single read & verify (increment pattern)
			//	Expected: data = address[7:0]
			// -------------------------------------------------
			S_READ1_REQ: begin
				ff_address <= ff_addr;
				ff_write   <= 1'b0;
				ff_valid   <= 1'b1;
				ff_state   <= S_READ1_ACCEPT;
			end
			S_READ1_ACCEPT: begin
				if( w_ssram_ready ) begin
					ff_valid <= 1'b0;
					ff_state <= S_READ1_WAIT;
				end
			end
			S_READ1_WAIT: begin
				if( w_ssram_rdata_en ) begin
					if( w_ssram_rdata != ff_addr[7:0] ) begin
						ff_error1 <= 1'b1;
					end
					if( ff_addr == 19'h7FFFF ) begin
						ff_state <= S_LED1;
					end
					else begin
						ff_addr  <= ff_addr + 19'd1;
						ff_state <= S_READ1_REQ;
					end
				end
			end
			S_LED1: begin
				ff_phase2_done <= 1'b1;
				ff_addr        <= 19'd0;
				ff_state       <= S_WRITE_REQ;
			end

			// -------------------------------------------------
			//	Phase 3: Single write (decrement pattern)
			//	Data = ~address[7:0]  (0xFF, 0xFE, 0xFD, ...)
			// -------------------------------------------------
			S_WRITE_REQ: begin
				ff_address <= ff_addr;
				ff_write   <= 1'b1;
				ff_wdata   <= ~ff_addr[7:0];
				ff_valid   <= 1'b1;
				ff_state   <= S_WRITE_ACCEPT;
			end
			S_WRITE_ACCEPT: begin
				if( w_ssram_ready ) begin
					ff_valid <= 1'b0;
					ff_state <= S_WRITE_WAIT;
				end
			end
			S_WRITE_WAIT: begin
				if( w_ssram_ready ) begin
					if( ff_addr == 19'h7FFFF ) begin
						ff_state <= S_LED2;
					end
					else begin
						ff_addr  <= ff_addr + 19'd1;
						ff_state <= S_WRITE_REQ;
					end
				end
			end
			S_LED2: begin
				ff_phase3_done <= 1'b1;
				ff_addr        <= 19'd0;
				ff_error2      <= 1'b0;
				ff_state       <= S_READ2_REQ;
			end

			// -------------------------------------------------
			//	Phase 4: Single read & verify (decrement pattern)
			//	Expected: data = ~address[7:0]
			// -------------------------------------------------
			S_READ2_REQ: begin
				ff_address <= ff_addr;
				ff_write   <= 1'b0;
				ff_valid   <= 1'b1;
				ff_state   <= S_READ2_ACCEPT;
			end
			S_READ2_ACCEPT: begin
				if( w_ssram_ready ) begin
					ff_valid <= 1'b0;
					ff_state <= S_READ2_WAIT;
				end
			end
			S_READ2_WAIT: begin
				if( w_ssram_rdata_en ) begin
					if( w_ssram_rdata != ~ff_addr[7:0] ) begin
						ff_error2 <= 1'b1;
					end
					if( ff_addr == 19'h7FFFF ) begin
						ff_state <= S_LED3;
					end
					else begin
						ff_addr  <= ff_addr + 19'd1;
						ff_state <= S_READ2_REQ;
					end
				end
			end
			S_LED3: begin
				ff_phase4_done <= 1'b1;
				ff_state       <= S_DONE;
			end

			// -------------------------------------------------
			S_DONE: begin
			end
			endcase
		end
	end

	// ---------------------------------------------------------
	//	LED output (active low: 0=ON, 1=OFF)
	//	LED[0]: Phase 1 complete (burst write increment)
	//	LED[1]: Phase 2 result  (read verify: ON=OK, blink=NG)
	//	LED[2]: Phase 3 complete (single write decrement)
	//	LED[3]: Phase 4 result  (read verify: ON=OK, blink=NG)
	// ---------------------------------------------------------
	assign led[0] = ff_phase1_done ? 1'b0 : 1'b1;
	assign led[1] = ff_phase2_done ? (ff_error1 ? ff_blink : 1'b0) : 1'b1;
	assign led[2] = ff_phase3_done ? 1'b0 : 1'b1;
	assign led[3] = ff_phase4_done ? (ff_error2 ? ff_blink : 1'b0) : 1'b1;
endmodule
