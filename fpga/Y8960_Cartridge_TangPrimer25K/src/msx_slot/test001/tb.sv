// -----------------------------------------------------------------------------
//	Test of msx_slot.v
//	Copyright (C)2025 Takayuki Hara (HRA!)
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
// --------------------------------------------------------------------

module tb ();
	localparam		clk_base		= 1_000_000_000/85_909_080;	//	ps
	localparam		cpu_clk_base	= 1_000_000_000/ 3_579_545;	//	ps
	reg				clk;
	reg				p_slot_clk;
	reg				p_slot_reset;
	reg				p_slot_sltsl_n;
	reg				p_slot_memreq_n;
	reg				p_slot_ioreq_n;
	reg				p_slot_wr_n;
	reg				p_slot_rd_n;
	reg		[15:0]	p_slot_address;
	wire	[7:0]	p_slot_data;
	reg		[7:0]	ff_slot_data;
	wire			p_slot_int;
	wire			p_slot_data_dir;
	wire			reset_n;
	reg				int_n;
	wire	[15:0]	bus_address;
	wire			bus_memreq;
	wire			bus_ioreq;
	wire			bus_write;
	wire			bus_valid;
	wire	[7:0]	bus_wdata;
	reg		[7:0]	bus_rdata;
	reg				bus_rdata_en;
	wire			bus_timer_cs;
	wire			bus_opll_cs;
	wire			bus_opl2_cs;
	wire			bus_ssg_cs;
	wire			bus_scc_cs;
	wire			bus_dcsg_cs;
	wire			bus_timer_ready;
	wire			bus_opll_ready;
	wire			bus_opl2_ready;
	wire			bus_ssg_ready;
	wire			bus_scc_ready;
	wire			bus_dcsg_ready;
	reg				memory_io_en;
	string			s_state;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	msx_slot u_msx_slot (
		.clk					( clk					),
		.reset_n				( reset_n				),
		.p_slot_reset			( p_slot_reset			),
		.p_slot_sltsl_n			( p_slot_sltsl_n		),
		.p_slot_memreq_n		( p_slot_memreq_n		),
		.p_slot_ioreq_n			( p_slot_ioreq_n		),
		.p_slot_wr_n			( p_slot_wr_n			),
		.p_slot_rd_n			( p_slot_rd_n			),
		.p_slot_address			( p_slot_address		),
		.p_slot_data			( p_slot_data			),
		.p_slot_int				( p_slot_int			),
		.p_slot_data_dir		( p_slot_data_dir		),
		.int_n					( int_n					),
		.bus_address			( bus_address			),
		.bus_memreq				( bus_memreq			),
		.bus_ioreq				( bus_ioreq				),
		.bus_write				( bus_write				),
		.bus_valid				( bus_valid				),
		.bus_timer_ready		( bus_timer_ready		),
		.bus_opll_ready			( bus_opll_ready		),
		.bus_opl2_ready			( bus_opl2_ready		),
		.bus_ssg_ready			( bus_ssg_ready			),
		.bus_scc_ready			( bus_scc_ready			),
		.bus_dcsg_ready			( bus_dcsg_ready		),
		.bus_wdata				( bus_wdata				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_en			( bus_rdata_en			),
		.bus_timer_cs			( bus_timer_cs			),
		.bus_opll_cs			( bus_opll_cs			),
		.bus_opl2_cs			( bus_opl2_cs			),
		.bus_ssg_cs				( bus_ssg_cs			),
		.bus_scc_cs				( bus_scc_cs			),
		.bus_dcsg_cs			( bus_dcsg_cs			),
		.memory_io_en			( memory_io_en			)
	);

	//	1: Read, 0: Write
	assign p_slot_data	= (p_slot_data_dir == 1'b1) ? 8'hZZ: ff_slot_data;

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	response
	// --------------------------------------------------------------------
	reg		[2:0]	ff_bus_valid = 0;

	always @( clk ) begin
		ff_bus_valid = { bus_valid, ff_bus_valid[2:1] };
	end

	wire w_bus_ready;
	assign w_bus_ready		= ff_bus_valid[0];
	assign bus_timer_ready	= w_bus_ready;
	assign bus_opll_ready	= w_bus_ready;
	assign bus_opl2_ready	= w_bus_ready;
	assign bus_ssg_ready	= w_bus_ready;
	assign bus_scc_ready	= w_bus_ready;
	assign bus_dcsg_ready	= w_bus_ready;

	// --------------------------------------------------------------------
	//	tasks
	// --------------------------------------------------------------------
	task write_io(
		input	[7:0]	address,
		input	[7:0]	wdata
	);
		fork
			//	CPU clock
			begin
				//	T1
				s_state		= "T1";
				p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T2
				s_state		= "T2";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	TW
				s_state		= "TW";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T3
				s_state		= "T3";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T4
				s_state		= "T4";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T5
				s_state		= "T5";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
			end
			//	Address
			begin
				#170ns p_slot_address = address;
			end
			//	/IORQ
			begin
				p_slot_ioreq_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#135ns p_slot_ioreq_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#145ns p_slot_ioreq_n = 1'b1;
			end
			//	/WR
			begin
				p_slot_wr_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#125ns p_slot_wr_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#120ns p_slot_wr_n = 1'b1;
			end
			//	others
			begin
				ff_slot_data	= wdata;
			end
		join
	endtask

	// --------------------------------------------------------------------
	task write_io_ex(
		input	[7:0]	address,
		input	[7:0]	wdata
	);
		fork
			//	CPU clock
			begin
				//	T1
				s_state		= "T1";
				p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T2
				s_state		= "T2";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	TW
				s_state		= "TW";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T3
				s_state		= "T3";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T4
				s_state		= "T4";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T5
				s_state		= "T5";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
			end
			//	Address
			begin
				#170ns p_slot_address = address;
			end
			//	/IORQ
			begin
				p_slot_ioreq_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#175ns p_slot_ioreq_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#185ns p_slot_ioreq_n = 1'b1;
			end
			//	/WR
			begin
				p_slot_wr_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#165ns p_slot_wr_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#150ns p_slot_wr_n = 1'b1;
			end
			//	others
			begin
				ff_slot_data	= wdata;
			end
		join
	endtask

	// --------------------------------------------------------------------
	task read_io(
		input	[7:0]	address,
		output	[7:0]	rdata
	);
		fork
			//	CPU clock
			begin
				//	T1
				s_state		= "T1";
				p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T2
				s_state		= "T2";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	TW
				s_state		= "TW";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T3
				s_state		= "T3";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T4
				s_state		= "T4";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
				//	T5
				s_state		= "T5";
				#(cpu_clk_base/2) p_slot_clk	= 1'b1;
				#(cpu_clk_base/2) p_slot_clk	= 1'b0;
			end
			//	Address
			begin
				#170ns p_slot_address = address;
			end
			//	/IORQ
			begin
				p_slot_ioreq_n = 1'b1;
				//	T1
				@( negedge p_slot_clk );
				@( posedge p_slot_clk );
				#135ns p_slot_ioreq_n = 1'b0;
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				@( negedge p_slot_clk );
				#145ns p_slot_ioreq_n = 1'b1;
			end
			//	/RD
			begin
				p_slot_rd_n = 1'b1;
				//	T1
				@( negedge p_slot_ioreq_n );
				#10ns p_slot_rd_n = 1'b0;
				@( posedge p_slot_ioreq_n );
				rdata = p_slot_data;
				p_slot_rd_n = 1'b1;
			end
		join
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		logic [7:0] rdata;

		clk					= 0;			//	42.95454MHz
		p_slot_clk			= 0;
		p_slot_reset		= 1;
		p_slot_sltsl_n		= 1;
		p_slot_memreq_n		= 1;
		p_slot_ioreq_n		= 1;
		p_slot_wr_n			= 1;
		p_slot_rd_n			= 1;
		p_slot_address		= 0;
		bus_rdata			= 0;
		bus_rdata_en		= 0;
		int_n				= 1;
		memory_io_en		= 0;

		@( negedge clk );
		@( negedge clk );

		p_slot_reset		= 0;
		@( posedge clk );
		@( posedge clk );

		// --------------------------------------------------------------------
		write_io( 8'h88, 8'h12 );
		write_io( 8'h89, 8'h23 );
		write_io( 8'h8A, 8'h34 );
		write_io( 8'h8B, 8'h45 );
		write_io( 8'h88, 8'h56 );
		write_io( 8'h89, 8'h67 );

		write_io_ex( 8'h88, 8'h12 );
		write_io_ex( 8'h89, 8'h23 );
		write_io_ex( 8'h8A, 8'h34 );
		write_io_ex( 8'h8B, 8'h45 );
		write_io_ex( 8'h88, 8'h56 );
		write_io_ex( 8'h89, 8'h67 );

		read_io( 8'h88, rdata );
		read_io( 8'h89, rdata );
		read_io( 8'h8A, rdata );
		read_io( 8'h8B, rdata );

		write_io( 8'h00, 8'h12 );
		write_io( 8'h11, 8'h23 );
		write_io( 8'h22, 8'h34 );
		write_io( 8'h33, 8'h45 );
		write_io( 8'h99, 8'h56 );
		write_io( 8'hAA, 8'h67 );
		write_io( 8'hBB, 8'h67 );
		write_io( 8'hCC, 8'h67 );
		write_io( 8'hDD, 8'h67 );
		write_io( 8'hEE, 8'h67 );

		repeat( 10 ) @( posedge clk );
		$finish;
	end
endmodule
