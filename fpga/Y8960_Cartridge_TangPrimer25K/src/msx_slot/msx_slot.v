//
//	msx_slot.v
//	 MSX Slot top entity
//
//	Copyright (C) 2025 Takayuki Hara
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

module msx_slot(
	input			clk,
	output			reset_n,
	//	MSX Slot Signal
	input			p_slot_reset_n,
	input			p_slot_sltsl_n,
	input			p_slot_memreq_n,
	input			p_slot_ioreq_n,
	input			p_slot_wr_n,
	input			p_slot_rd_n,
	input	[15:0]	p_slot_address,
	inout	[7:0]	p_slot_data,
	output			p_slot_int,				//	0 or HiZ: Normal, 1: Interrupt
	output			p_slot_data_dir,		//	0: MSX竊辰artridge (Write), 1: Cartridge竊樽SX (Read)
	//	Local BUS
	input			int_n,
	output	[15:0]	bus_address,
	output			bus_write,
	output			bus_valid,
	input			bus_timer_ready,
	input			bus_opll_ready,
	input			bus_opl2_ready,
	input			bus_ssg_ready,
	input			bus_scc_ready,
	input			bus_dcsg_ready,
	input			bus_sysctrl_ready,
	output	[7:0]	bus_wdata,
	input	[7:0]	bus_rdata,
	input			bus_rdata_en,
	//	Module chip select
	output			bus_timer_cs,
	output			bus_opll_cs,
	output			bus_opl2_cs,
	output			bus_ssg_cs,
	output			bus_scc_cs,
	output			bus_dcsg_cs,
	output			bus_sysctrl_cs,
	//	Memory Mapped I/O enabler
	input			memory_io_en
);
	//	I/O interface is disconnect at power on and reset.
	localparam		c_timer1_io				= 8'hB0;	//	MSX-TIMER: B0h-B1h
	localparam		c_timer2_io				= 8'hB2;	//	MSX-TIMER: B2h-B3h
	localparam		c_ssg1_io				= 8'hA0;	//	SSG      : A0h-A1h
	localparam		c_ssg2_io				= 8'hA2;	//	SSG      : A2h-A3h
	localparam		c_opll1_io				= 8'h7A;	//	MSX-MUSIC: 7Ah-7Bh
	localparam		c_opll2_io				= 8'h7C;	//	MSX-MUSIC: 7Ch-7Dh
	localparam		c_opl2_1_io				= 8'hC0;	//	MSX-AUDIO: C0h-C1h
	localparam		c_opl2_2_io				= 8'hC2;	//	MSX-AUDIO: C2h-C3h
	localparam		c_dcsg_io				= 8'h7E;	//	DCSG     : 7Eh-7Fh
	localparam		c_sysctrl_io			= 4'h4;		//	SYSCTRL  : 40h-4Fh
	//	Memory interface is always connect.
	localparam		c_ssg_mio				= 5'h0A;	//	SSG         : 7FEAh-7FEBh (Mirror 3FFAh-3FFBh)
	localparam		c_opl2_1_mio			= 5'h0C;	//	MSX-AUDIO   : 7FECh-7FEDh (Mirror 3FECh-3FEDh)
	localparam		c_opl2_2_mio			= 5'h0E;	//	MSX-AUDIO   : 7FEEh-7FEFh (Mirror 3FEEh-3FEFh)
	localparam		c_dcsg_mio				= 5'h10;	//	DCSG        : 7FF0h-7FF1h (Mirror 3FF0h-3FF1h)
	localparam		c_opll1_mio				= 5'h12;	//	MSX-MUSIC   : 7FF2h-7FF3h (Mirror 3FF2h-3FF3h)
	localparam		c_opll2_mio				= 5'h14;	//	MSX-MUSIC   : 7FF4h-7FF5h (Mirror 3FF4h-3FF5h)
	localparam		c_io_en1				= 5'h16;	//	I/O Enabler1: 7FF6h (Mirror 3FF6h)
	localparam		c_io_en2				= 5'h1F;	//	I/O Enabler2: 7FFFh (Mirror 3FFFh)

	reg				ff_reset_n				= 1'b0;
	reg				ff_pre_slot_sltsl_n		= 1'b1;
	reg				ff_pre_slot_memreq_n	= 1'b1;
	reg				ff_pre_slot_ioreq_n		= 1'b1;
	reg				ff_pre_slot_wr_n		= 1'b1;
	reg				ff_pre_slot_rd_n		= 1'b1;

	reg				ff_slot_memreq			= 1'b0;
	reg				ff_slot_ioreq			= 1'b0;
	reg				ff_slot_wr				= 1'b0;
	reg				ff_slot_rd				= 1'b0;

	reg		[15:0]	ff_slot_address;
	reg		[7:0]	ff_slot_data;
	wire			w_active;
	reg				ff_active			= 1'b0;
	reg				ff_write			= 1'b0;
	reg				ff_valid			= 1'b0;
	reg				ff_bus_timer_cs		= 1'b0;
	reg				ff_bus_opl2_cs		= 1'b0;
	reg				ff_bus_opll_cs		= 1'b0;
	reg				ff_bus_ssg_cs		= 1'b0;
	reg				ff_bus_scc_cs		= 1'b0;
	reg				ff_bus_dcsg_cs		= 1'b0;
	reg				ff_bus_sysctrl_cs	= 1'b0;
	reg 			ff_bus_io_en_cs		= 1'b0;
	reg		[7:0]	ff_rdata			= 8'd0;
	reg 			ff_timer_io_en		= 1'b0;
	reg 			ff_opll1_io_en		= 1'b0;
	reg 			ff_opll2_io_en		= 1'b0;
	reg 			ff_opl2_1_io_en		= 1'b0;
	reg 			ff_opl2_2_io_en		= 1'b0;
	reg 			ff_dcsg1_io_en		= 1'b0;
	reg 			ff_dcsg2_io_en		= 1'b0;
	reg 			ff_ssg_io_en		= 1'b0;

	// --------------------------------------------------------------------
	//	reset signal
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		ff_reset_n	<= p_slot_reset_n;
	end

	assign reset_n		= ff_reset_n;

	// --------------------------------------------------------------------
	//	Pass through FF twice for asynchronous replacement.
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		ff_pre_slot_sltsl_n		<= p_slot_sltsl_n;
		ff_pre_slot_memreq_n	<= p_slot_memreq_n;
		ff_pre_slot_ioreq_n		<= p_slot_ioreq_n;
		ff_pre_slot_wr_n		<= p_slot_wr_n;
		ff_pre_slot_rd_n		<= p_slot_rd_n;

		ff_slot_memreq			<= ~ff_pre_slot_memreq_n & ~ff_pre_slot_sltsl_n;
		ff_slot_ioreq			<= ~ff_pre_slot_ioreq_n;
		ff_slot_wr				<= ~ff_pre_slot_wr_n;
		ff_slot_rd				<= ~ff_pre_slot_rd_n;

		ff_slot_address			<= p_slot_address;
	end

	// --------------------------------------------------------------------
	//	書込みであれば、p_slot_data をラッチする
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( ff_slot_wr ) begin
			ff_slot_data		<= p_slot_data;
		end
	end

	// --------------------------------------------------------------------
	//	Transaction active signal
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !ff_reset_n ) begin
			ff_active		<= 1'b0;
		end
		else begin
			ff_active		<= w_active;
		end
	end

	assign w_active		= (ff_slot_ioreq | ff_slot_memreq) & (ff_slot_wr | ff_slot_rd);

	// --------------------------------------------------------------------
	//	Address latch
	// --------------------------------------------------------------------
	assign w_bus_ready	= (ff_bus_timer_cs & bus_timer_ready) 
						| (ff_bus_opl2_cs & bus_opl2_ready) 
						| (ff_bus_opll_cs & bus_opll_ready) 
						| (ff_bus_ssg_cs & bus_ssg_ready) 
						| (ff_bus_scc_cs & bus_scc_ready) 
						| (ff_bus_dcsg_cs & bus_dcsg_ready)
						| (ff_bus_sysctrl_cs & bus_sysctrl_ready)
						| ff_bus_io_en_cs;

	always @( posedge clk ) begin
		if( !ff_reset_n ) begin
			ff_bus_timer_cs		<= 1'b0;
			ff_bus_opl2_cs		<= 1'b0;
			ff_bus_opll_cs		<= 1'b0;
			ff_bus_ssg_cs		<= 1'b0;
			ff_bus_scc_cs		<= 1'b0;
			ff_bus_dcsg_cs		<= 1'b0;
			ff_bus_sysctrl_cs	<= 1'b0;
			ff_bus_io_en_cs		<= 1'b0;
			ff_valid			<= 1'b0;
			ff_write			<= 1'b1;
		end
		else if( ff_valid ) begin
			if( w_bus_ready ) begin
				ff_valid	<= 1'b0;
				if( ff_write ) begin
					ff_bus_timer_cs		<= 1'b0;
					ff_bus_opl2_cs		<= 1'b0;
					ff_bus_opll_cs		<= 1'b0;
					ff_bus_ssg_cs		<= 1'b0;
					ff_bus_scc_cs		<= 1'b0;
					ff_bus_dcsg_cs		<= 1'b0;
					ff_bus_sysctrl_cs	<= 1'b0;
					ff_bus_io_en_cs		<= 1'b0;
				end
			end
		end
		else if( bus_rdata_en ) begin
			ff_bus_timer_cs		<= 1'b0;
			ff_bus_opl2_cs		<= 1'b0;
			ff_bus_opll_cs		<= 1'b0;
			ff_bus_ssg_cs		<= 1'b0;
			ff_bus_scc_cs		<= 1'b0;
			ff_bus_dcsg_cs		<= 1'b0;
			ff_bus_sysctrl_cs	<= 1'b0;
			ff_bus_io_en_cs		<= 1'b0;
		end
		else if( !ff_active && w_active ) begin
			if( ff_slot_ioreq ) begin
				case( { ff_slot_address[7:1], 1'd0 } )
				c_ssg1_io, c_ssg2_io: begin
					if( ff_ssg_io_en ) begin
						ff_write		<= ff_slot_wr;
						ff_valid		<= 1'b1;
						ff_bus_ssg_cs	<= 1'b1;
					end
				end
				c_opll1_io: begin
					if( ff_opll1_io_en ) begin
						ff_write		<= ff_slot_wr;
						ff_valid		<= 1'b1;
						ff_bus_opll_cs	<= 1'b1;
					end
				end
				c_opll2_io: begin
					if( ff_opll2_io_en ) begin
						ff_write		<= ff_slot_wr;
						ff_valid		<= 1'b1;
						ff_bus_opll_cs	<= 1'b1;
					end
				end
				c_opl2_1_io: begin
					if( ff_opl2_1_io_en ) begin
						ff_write		<= ff_slot_wr;
						ff_valid		<= 1'b1;
						ff_bus_opl2_cs	<= 1'b1;
					end
				end
				c_opl2_2_io: begin
					if( ff_opl2_2_io_en ) begin
						ff_write		<= ff_slot_wr;
						ff_valid		<= 1'b1;
						ff_bus_opl2_cs	<= 1'b1;
					end
				end
				c_dcsg_io: begin
					if( ff_dcsg1_io_en || ff_dcsg2_io_en ) begin
						ff_write		<= ff_slot_wr;
						ff_valid		<= 1'b1;
						ff_bus_dcsg_cs	<= 1'b1;
					end
				end
				c_timer1_io, c_timer2_io: begin
					if( ff_timer_io_en ) begin
						ff_write		<= ff_slot_wr;
						ff_valid		<= 1'b1;
						ff_bus_timer_cs	<= 1'b1;
					end
				end
				default: begin
					if( ff_slot_address[7:4] == c_sysctrl_io ) begin
						ff_write			<= ff_slot_wr;
						ff_valid			<= 1'b1;
						ff_bus_sysctrl_cs	<= 1'b1;
					end
				end
				endcase
			end
			else if( memory_io_en && ff_slot_memreq && ff_slot_wr && ff_slot_address[15] == 1'b0 && ff_slot_address[13:5] == 9'b11_1111_111 ) begin
				case( { ff_slot_address[4:1], 1'b0 } )
				c_ssg_mio: begin
					ff_write		<= 1'b1;
					ff_valid		<= 1'b1;
					ff_bus_ssg_cs	<= 1'b1;
				end
				c_opll1_mio, c_opll2_mio: begin
					ff_write		<= 1'b1;
					ff_valid		<= 1'b1;
					ff_bus_opll_cs	<= 1'b1;
				end
				c_opl2_1_mio, c_opl2_2_mio: begin
					ff_write		<= 1'b1;
					ff_valid		<= 1'b1;
					ff_bus_opl2_cs	<= 1'b1;
				end
				c_dcsg_mio: begin
					ff_write		<= 1'b1;
					ff_valid		<= 1'b1;
					ff_bus_dcsg_cs	<= 1'b1;
				end
				c_io_en1: begin
					if( ff_slot_address[0] == 1'b0 ) begin
						ff_write		<= 1'b1;
						ff_valid		<= 1'b1;
						ff_bus_io_en_cs	<= 1'b1;
					end
					else begin
						ff_write		<= 1'b1;
						ff_valid		<= 1'b1;
						ff_bus_scc_cs	<= 1'b1;
					end
				end
				c_io_en2: begin
					if( ff_slot_address[0] == 1'b1 ) begin
						ff_write		<= 1'b1;
						ff_valid		<= 1'b1;
						ff_bus_io_en_cs	<= 1'b1;
					end
					else begin
						ff_write		<= 1'b1;
						ff_valid		<= 1'b1;
						ff_bus_scc_cs	<= 1'b1;
					end
				end
				default: begin
					ff_write		<= 1'b1;
					ff_valid		<= 1'b1;
					ff_bus_scc_cs	<= 1'b1;
				end
				endcase
			end
			else if( ff_slot_memreq ) begin
				ff_write		<= ff_slot_wr;
				ff_valid		<= 1'b1;
				ff_bus_scc_cs	<= 1'b1;
			end
		end
	end

	// --------------------------------------------------------------------
	//	Bus I/O enable latch
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !ff_reset_n ) begin
			ff_timer_io_en		<= 1'b0;
			ff_opll1_io_en		<= 1'b0;
			ff_opll2_io_en		<= 1'b0;
			ff_opl2_1_io_en		<= 1'b0;
			ff_opl2_2_io_en		<= 1'b0;
			ff_dcsg1_io_en		<= 1'b0;
			ff_dcsg2_io_en		<= 1'b0;
			ff_ssg_io_en		<= 1'b0;
		end
		else if( ff_bus_io_en_cs && ff_valid ) begin
			if( ff_slot_address[0] == 1'b0 ) begin
				//	7FF6h (Mirror 3FF6h): I/O Enabler1
				ff_opll1_io_en		<= ff_slot_data[0];
				ff_opll2_io_en		<= ff_slot_data[1];
			end
			else begin
				//	7FFFh (Mirror 3FFFh): I/O Enabler2
				ff_opl2_1_io_en		<= ff_slot_data[0];
				ff_opl2_2_io_en		<= ff_slot_data[1];
				ff_dcsg1_io_en		<= ff_slot_data[2];
				ff_dcsg2_io_en		<= ff_slot_data[3];
				ff_ssg_io_en		<= ff_slot_data[4];
				ff_timer_io_en		<= ff_slot_data[7];
			end
		end
	end

	// --------------------------------------------------------------------
	//	Read data
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !ff_reset_n ) begin
			ff_rdata	<= 8'h00;
		end
		else if( bus_rdata_en ) begin
			ff_rdata	<= bus_rdata;
		end
	end

	assign bus_timer_cs		= ff_bus_timer_cs;
	assign bus_opl2_cs		= ff_bus_opl2_cs;
	assign bus_opll_cs		= ff_bus_opll_cs;
	assign bus_ssg_cs		= ff_bus_ssg_cs;
	assign bus_scc_cs		= ff_bus_scc_cs;
	assign bus_dcsg_cs		= ff_bus_dcsg_cs;
	assign bus_sysctrl_cs	= ff_bus_sysctrl_cs;
	assign bus_address		= ff_slot_address;
	assign bus_wdata		= ff_slot_data;
	assign bus_write		= ff_write;
	assign bus_valid		= ff_valid;
	assign p_slot_data		= ((ff_slot_ioreq | ff_slot_memreq) & ff_slot_rd) ? ff_rdata: 8'hZZ;
	assign p_slot_int		= ~int_n;

	//	0: Cartridge <- CPU (Write or Idle), 1: Cartridge -> CPU (Read)
	assign p_slot_data_dir	= ((ff_slot_ioreq | ff_slot_memreq) & ff_slot_rd) ? 1'b1 : 1'b0;
endmodule
