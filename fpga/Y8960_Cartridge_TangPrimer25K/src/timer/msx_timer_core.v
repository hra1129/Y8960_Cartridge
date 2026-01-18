//
//	msx_timer_core.v
//	MSX-TIMER core
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

module msx_timer_core (
	input			clk,			//	85.90908MHz
	input			reset_n,
	input	[1:0]	bus_address,
	input			bus_write,
	input			bus_valid,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	input			intr_clear,
	output	[7:0]	counter,
	output			intr_flag,
	output			intr
);
	localparam		c_mode_register			= 2'd0;
	localparam		c_count_register		= 2'd1;
	localparam		c_control_register		= 2'd2;

	reg		[31:0]	ff_counter;
	reg		[2:0]	ff_reso;
	reg		[7:0]	ff_count;
	reg				ff_repeat;
	reg				ff_intr_enable;
	reg				ff_count_enable;
	reg				ff_count_end;
	wire	[13:0]	w_count_high;
	wire			w_count_overflow;
	wire	[8:0]	w_count;
	wire	[23:0]	w_count_low;
	wire			w_count_end;

	// --------------------------------------------------------------------
	//	Registers
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_repeat		<= 1'b0;
			ff_reso			<= 3'd0;
			ff_intr_enable	<= 1'b0;
			ff_count		<= 8'd0;
		end
		else if( bus_valid && bus_write ) begin
			//	register write
			if( bus_address == c_mode_register ) begin
				ff_repeat		<= bus_wdata[0];
				ff_reso			<= bus_wdata[6:4];
				ff_intr_enable	<= bus_wdata[7];
			end
			else if( bus_address == c_count_register ) begin
				ff_count		<= bus_wdata;
			end
			else begin
				//	hold
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_count_enable	<= 1'b0;
		end
		else if( bus_valid && bus_write ) begin
			//	register write
			if( bus_address == c_control_register ) begin
				ff_count_enable	<= bus_wdata[0];
			end
			else begin
				//	hold
			end
		end
		else if( !ff_repeat && w_count_end ) begin
			ff_count_enable	<= 1'b0;
		end
	end

	assign bus_rdata	= (bus_address == c_mode_register		) ? { ff_intr_enable, ff_reso, 3'd0, ff_repeat } :
	                      (bus_address == c_count_register		) ? ff_count :
	                      (bus_address == c_control_register	) ? { 7'd0, ff_count_enable } : 8'd0;
	assign bus_rdata_en	= bus_valid & ~bus_write;

	// --------------------------------------------------------------------
	//	Counter
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_counter	<= 32'd0;
		end
		else if( bus_valid && bus_write && (bus_address == c_control_register) && bus_wdata[1] ) begin
			ff_counter	<= 32'd0;
		end
		else if( !ff_count_enable ) begin
			//	hold
		end
		else if( w_count_end ) begin
			if( ff_repeat ) begin
				ff_counter	<= 32'd0;
			end
			else begin
				//	hold
			end
		end
		else begin
			ff_counter	<= ff_counter + 32'd1;
		end
	end

	// =========================================================================================================================================
	//	[31][30][29][28][27][26][25][24][23][22][21][20][19][18][17][16][15][14][13][12][11][10][09][08][07][06][05][04][03][02][01][00]
	//	<--- high ---------------------------------------------><-- count ---------------------><-- low -------------------------------> reso=0
	//	<--- high -------------------------------------><-- count ---------------------><-- low ---------------------------------------> reso=1
	//	<--- high -----------------------------><-- count ---------------------><-- low -----------------------------------------------> reso=2
	//	<--- high ---------------------><-- count ---------------------><-- low -------------------------------------------------------> reso=3
	//	<--- high -------------><-- count ---------------------><-- low ---------------------------------------------------------------> reso=4
	//	<--- high -----><-- count ---------------------><-- low -----------------------------------------------------------------------> reso=5
	//	<------><-- count ---------------------><-- low -------------------------------------------------------------------------------> reso=6
	//	<-- count ---------------------><-- low ---------------------------------------------------------------------------------------> reso=7
	// =========================================================================================================================================
	assign w_count_high     = (ff_reso == 3'd0) ? ff_counter[31:18] :
	                          (ff_reso == 3'd1) ? { 2'd0, ff_counter[31:20] } :
	                          (ff_reso == 3'd2) ? { 4'd0, ff_counter[31:22] } :
	                          (ff_reso == 3'd3) ? { 6'd0, ff_counter[31:24] } :
	                          (ff_reso == 3'd4) ? { 8'd0, ff_counter[31:26] } :
	                          (ff_reso == 3'd5) ? { 10'd0, ff_counter[31:28] } :
	                          (ff_reso == 3'd6) ? { 12'd0, ff_counter[31:30] } : 14'd0;
	assign w_count_overflow = (w_count_high != 14'd0) ? 1'b1 : 1'b0;
	assign w_count[8]		= w_count_overflow;
	assign w_count[7:0]		= (ff_reso == 3'd0) ? ff_counter[17:10] :
	                          (ff_reso == 3'd1) ? { 2'd0, ff_counter[19:12] } :
	                          (ff_reso == 3'd2) ? { 4'd0, ff_counter[21:14] } :
	                          (ff_reso == 3'd3) ? { 6'd0, ff_counter[23:16] } :
	                          (ff_reso == 3'd4) ? { 8'd0, ff_counter[25:18] } :
	                          (ff_reso == 3'd5) ? { 10'd0, ff_counter[27:20] } :
	                          (ff_reso == 3'd6) ? { 12'd0, ff_counter[29:22] } : ff_counter[31:24];
	assign w_count_low		= (ff_reso == 3'd0) ? { 14'b11_1111_1111_1111, ff_counter[ 9:0] }: 
	                          (ff_reso == 3'd1) ? {    12'b1111_1111_1111, ff_counter[11:0] }: 
	                          (ff_reso == 3'd2) ? {      10'b11_1111_1111, ff_counter[13:0] }: 
	                          (ff_reso == 3'd3) ? {          8'b1111_1111, ff_counter[15:0] }: 
	                          (ff_reso == 3'd4) ? {            6'b11_1111, ff_counter[17:0] }: 
	                          (ff_reso == 3'd5) ? {               4'b1111, ff_counter[19:0] }: 
	                          (ff_reso == 3'd6) ? {                 2'b11, ff_counter[21:0] }: ff_counter[23:0];
	assign w_count_end		= (({1'b0, ff_count} <= w_count) && (w_count_low == 24'hFFFFFF)) ? 1'b1 : 1'b0;
	assign counter			= w_count[7:0];

	// --------------------------------------------------------------------
	//	Interrupt
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_count_end	<= 1'b0;
		end
		else if( intr_clear ) begin
			ff_count_end	<= 1'b0;
		end
		else if( ff_count_enable && w_count_end ) begin
			ff_count_end	<= 1'b1;
		end
	end

	assign intr_flag		= ff_count_end;
	assign intr				= ff_count_end & ff_intr_enable;
endmodule
