//
//	msx_timer.v
//	MSX-TIMER
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

module msx_timer (
	input			clk,
	input			reset_n,
	input			bus_ioreq,
	input	[7:0]	bus_address,
	input			bus_write,
	input			bus_valid,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	output			intr_n
);
	localparam		c_register_index	= 8'hB0;
	localparam		c_register_value	= 8'hB1;
	localparam		c_interrupt_flag	= 8'hB2;
	localparam		c_counter_read		= 8'hB3;
	reg				ff_busy;
	reg		[7:0]	ff_register_index;
	reg		[7:0]	ff_register_value;
	reg				ff_register_valid;
	reg				ff_register_write;
	reg		[3:0]	ff_interrupt_clear;
	reg		[2:0]	ff_counter_select;
	reg				ff_intr_n;
	reg		[7:0]	ff_rdata;
	reg				ff_rdata_en;
	wire			w_register_valid0;
	wire			w_register_valid1;
	wire			w_register_valid2;
	wire			w_register_valid3;
	wire	[7:0]	w_counter0;
	wire	[7:0]	w_counter1;
	wire	[7:0]	w_counter2;
	wire	[7:0]	w_counter3;
	wire			w_intr0;
	wire			w_intr1;
	wire			w_intr2;
	wire			w_intr3;
	wire			w_intr_flag0;
	wire			w_intr_flag1;
	wire			w_intr_flag2;
	wire			w_intr_flag3;
	wire	[7:0]	w_rdata0;
	wire	[7:0]	w_rdata1;
	wire	[7:0]	w_rdata2;
	wire	[7:0]	w_rdata3;
	wire			w_rdata_en0;
	wire			w_rdata_en1;
	wire			w_rdata_en2;
	wire			w_rdata_en3;

	// ---------------------------------------------------------
	//	I/O Ports
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_busy				<= 1'b0;
			ff_register_index	<= 8'd0;
			ff_register_value	<= 8'd0;
			ff_counter_select	<= 3'd0;
			ff_register_valid	<= 1'b0;
			ff_register_write	<= 1'b0;
			ff_rdata			<= 8'hFF;
		end
		else if( ff_busy ) begin
			ff_register_valid	<= 1'b0;
			if( ff_rdata_en ) begin
				ff_busy			<= 1'b0;
			end
		end
		else if( bus_ioreq && bus_valid ) begin
			if( bus_write ) begin
				//	write access
				case( bus_address )
					c_register_index: begin
						ff_register_index	<= bus_wdata;
						ff_register_valid	<= 1'b0;
						ff_register_write	<= 1'b0;
					end
					c_register_value: begin
						ff_register_value	<= bus_wdata;
						ff_register_valid	<= 1'b1;
						ff_register_write	<= 1'b1;
					end
					c_counter_read: begin
						if( bus_wdata[7:2] == 6'd0 ) begin
							ff_counter_select	<= { 1'b0, bus_wdata[1:0] };
						end
						else begin
							ff_counter_select	<= { 1'b1, 2'd0 };
						end
						ff_register_valid	<= 1'b0;
						ff_register_write	<= 1'b0;
					end
					default: begin
						ff_register_valid	<= 1'b0;
						ff_register_write	<= 1'b0;
					end
				endcase
			end
			else begin
				//	read access
				case( bus_address )
					c_register_index: begin
						ff_rdata			<= ff_register_index;
						ff_register_valid	<= 1'b0;
						ff_register_write	<= 1'b0;
					end
					c_register_value: begin
						case( ff_register_index[3:2] )
						2'd0:		ff_rdata	<= w_rdata0;
						2'd1:		ff_rdata	<= w_rdata1;
						2'd2:		ff_rdata	<= w_rdata2;
						2'd3:		ff_rdata	<= w_rdata3;
						default:	ff_rdata	<= w_rdata0;
						endcase
						ff_register_valid	<= 1'b1;
						ff_register_write	<= 1'b0;
						ff_busy				<= 1'b1;
					end
					c_interrupt_flag: begin
						ff_rdata			<= { 4'd0, w_intr_flag3, w_intr_flag2, w_intr_flag1, w_intr_flag0 };
						ff_register_valid	<= 1'b0;
						ff_register_write	<= 1'b0;
					end
					c_counter_read: begin
						case( ff_counter_select )
						3'd0:		ff_rdata	<= w_counter0;
						3'd1:		ff_rdata	<= w_counter1;
						3'd2:		ff_rdata	<= w_counter2;
						3'd3:		ff_rdata	<= w_counter3;
						default:	ff_rdata	<= 8'hFF;
						endcase
					end
					default: begin
						ff_rdata			<= 8'hFF;
					end
				endcase
			end
		end
		else begin
			ff_register_valid	<= 1'b0;
			ff_register_write	<= 1'b0;
		end
	end

	assign bus_ready	= ~ff_busy;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_rdata_en		<= 1'b0;
		end
		else if( bus_write ) begin
			ff_rdata_en	<= 1'b0;
		end
		else begin
			//	read access
			case( bus_address )
			c_register_index:	ff_rdata_en	<= 1'b1;
			c_register_value:	ff_rdata_en	<= w_rdata_en0 | w_rdata_en1 | w_rdata_en2 | w_rdata_en3;
			c_interrupt_flag:	ff_rdata_en	<= 1'b1;
			c_counter_read:		ff_rdata_en	<= 1'b1;
			default:			ff_rdata_en	<= 1'b0;
			endcase
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_interrupt_clear <= 4'd0;
		end
		else if( bus_ioreq && bus_valid && bus_write && (bus_address == c_interrupt_flag) ) begin
			ff_interrupt_clear <= bus_wdata[3:0];
		end
		else begin
			ff_interrupt_clear <= 4'd0;
		end
	end

	assign bus_rdata			= ff_rdata;
	assign bus_rdata_en			= ff_rdata_en;

	// ---------------------------------------------------------
	//	Timer cores
	// ---------------------------------------------------------
	assign w_register_valid0	= (ff_register_index[3:2] == 2'd0) ? ff_register_valid: 1'b0;
	assign w_register_valid1	= (ff_register_index[3:2] == 2'd1) ? ff_register_valid: 1'b0;
	assign w_register_valid2	= (ff_register_index[3:2] == 2'd2) ? ff_register_valid: 1'b0;
	assign w_register_valid3	= (ff_register_index[3:2] == 2'd3) ? ff_register_valid: 1'b0;

	msx_timer_core u_msx_timer_core0 (
		.clk			( clk						),
		.reset_n		( reset_n					),
		.bus_address	( ff_register_index[1:0]	),
		.bus_write		( ff_register_write			),
		.bus_valid		( w_register_valid0			),
		.bus_wdata		( ff_register_value			),
		.bus_rdata		( w_rdata0					),
		.bus_rdata_en	( w_rdata_en0				),
		.intr_clear		( ff_interrupt_clear[0]		),
		.counter		( w_counter0				),
		.intr_flag		( w_intr_flag0				),
		.intr			( w_intr0					)
	);

	msx_timer_core u_msx_timer_core1 (
		.clk			( clk						),
		.reset_n		( reset_n					),
		.bus_address	( ff_register_index[1:0]	),
		.bus_write		( ff_register_write			),
		.bus_valid		( w_register_valid1			),
		.bus_wdata		( ff_register_value			),
		.bus_rdata		( w_rdata1					),
		.bus_rdata_en	( w_rdata_en1				),
		.intr_clear		( ff_interrupt_clear[1]		),
		.counter		( w_counter1				),
		.intr_flag		( w_intr_flag1				),
		.intr			( w_intr1					)
	);

	msx_timer_core u_msx_timer_core2 (
		.clk			( clk						),
		.reset_n		( reset_n					),
		.bus_address	( ff_register_index[1:0]	),
		.bus_write		( ff_register_write			),
		.bus_valid		( w_register_valid2			),
		.bus_wdata		( ff_register_value			),
		.bus_rdata		( w_rdata2					),
		.bus_rdata_en	( w_rdata_en2				),
		.intr_clear		( ff_interrupt_clear[2]		),
		.counter		( w_counter2				),
		.intr_flag		( w_intr_flag2				),
		.intr			( w_intr2					)
	);

	msx_timer_core u_msx_timer_core3 (
		.clk			( clk						),
		.reset_n		( reset_n					),
		.bus_address	( ff_register_index[1:0]	),
		.bus_write		( ff_register_write			),
		.bus_valid		( w_register_valid3			),
		.bus_wdata		( ff_register_value			),
		.bus_rdata		( w_rdata3					),
		.bus_rdata_en	( w_rdata_en3				),
		.intr_clear		( ff_interrupt_clear[3]		),
		.counter		( w_counter3				),
		.intr_flag		( w_intr_flag3				),
		.intr			( w_intr3					)
	);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_intr_n <= 1'b1;
		end
		else begin
			ff_intr_n <= ~(w_intr0 | w_intr1 | w_intr2 | w_intr3);
		end
	end

	assign intr_n		= ff_intr_n;
endmodule
