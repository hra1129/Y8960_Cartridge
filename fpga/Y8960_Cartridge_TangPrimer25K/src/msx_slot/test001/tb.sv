// -----------------------------------------------------------------------------
//	Test of msx_slot.v
//	Copyright (C)2025 Takayuki Hara (HRA!)
//	
//	譛ｬ繧ｽ繝輔ヨ繧ｦ繧ｧ繧｢縺翫ｈ縺ｳ譛ｬ繧ｽ繝輔ヨ繧ｦ繧ｧ繧｢縺ｫ蝓ｺ縺･縺・※菴懈・縺輔ｌ縺滓ｴｾ逕溽黄縺ｯ縲∽ｻ･荳九・譚｡莉ｶ繧・
//	貅縺溘☆蝣ｴ蜷医↓髯舌ｊ縲∝・鬆貞ｸ・♀繧医・菴ｿ逕ｨ縺瑚ｨｱ蜿ｯ縺輔ｌ縺ｾ縺吶・
//
//	1.繧ｽ繝ｼ繧ｹ繧ｳ繝ｼ繝牙ｽ｢蠑上〒蜀埼貞ｸ・☆繧句ｴ蜷医∽ｸ願ｨ倥・闡嶺ｽ懈ｨｩ陦ｨ遉ｺ縲∵悽譚｡莉ｶ荳隕ｧ縲√♀繧医・荳玖ｨ・
//	  蜈崎ｲｬ譚｡鬆・ｒ縺昴・縺ｾ縺ｾ縺ｮ蠖｢縺ｧ菫晄戟縺吶ｋ縺薙→縲・
//	2.繝舌う繝翫Μ蠖｢蠑上〒蜀埼貞ｸ・☆繧句ｴ蜷医・貞ｸ・黄縺ｫ莉伜ｱ槭・繝峨く繝･繝｡繝ｳ繝育ｭ峨・雉・侭縺ｫ縲∽ｸ願ｨ倥・
//	  闡嶺ｽ懈ｨｩ陦ｨ遉ｺ縲∵悽譚｡莉ｶ荳隕ｧ縲√♀繧医・荳玖ｨ伜・雋ｬ譚｡鬆・ｒ蜷ｫ繧√ｋ縺薙→縲・
//	3.譖ｸ髱｢縺ｫ繧医ｋ莠句燕縺ｮ險ｱ蜿ｯ縺ｪ縺励↓縲∵悽繧ｽ繝輔ヨ繧ｦ繧ｧ繧｢繧定ｲｩ螢ｲ縲√♀繧医・蝠・･ｭ逧・↑陬ｽ蜩√ｄ豢ｻ蜍・
//	  縺ｫ菴ｿ逕ｨ縺励↑縺・％縺ｨ縲・
//
//	譛ｬ繧ｽ繝輔ヨ繧ｦ繧ｧ繧｢縺ｯ縲∬送菴懈ｨｩ閠・↓繧医▲縺ｦ縲檎樟迥ｶ縺ｮ縺ｾ縺ｾ縲肴署萓帙＆繧後※縺・∪縺吶り送菴懈ｨｩ閠・・縲・
//	迚ｹ螳夂岼逧・∈縺ｮ驕ｩ蜷域ｧ縺ｮ菫晁ｨｼ縲∝膚蜩∵ｧ縺ｮ菫晁ｨｼ縲√∪縺溘◎繧後↓髯仙ｮ壹＆繧後↑縺・√＞縺九↑繧区・遉ｺ
//	逧・ｂ縺励￥縺ｯ證鈴ｻ吶↑菫晁ｨｼ雋ｬ莉ｻ繧りｲ縺・∪縺帙ｓ縲り送菴懈ｨｩ閠・・縲∽ｺ狗罰縺ｮ縺・°繧薙ｒ蝠上ｏ縺壹∵錐螳ｳ
//	逋ｺ逕溘・蜴溷屏縺・°繧薙ｒ蝠上ｏ縺壹√°縺､雋ｬ莉ｻ縺ｮ譬ｹ諡縺悟･醍ｴ・〒縺ゅｋ縺句宍譬ｼ雋ｬ莉ｻ縺ｧ縺ゅｋ縺具ｼ磯℃螟ｱ
//	縺昴・莉悶・・我ｸ肴ｳ戊｡檎ぜ縺ｧ縺ゅｋ縺九ｒ蝠上ｏ縺壹∽ｻｮ縺ｫ縺昴・繧医≧縺ｪ謳榊ｮｳ縺檎匱逕溘☆繧句庄閭ｽ諤ｧ繧堤衍繧・
//	縺輔ｌ縺ｦ縺・◆縺ｨ縺励※繧ゅ∵悽繧ｽ繝輔ヨ繧ｦ繧ｧ繧｢縺ｮ菴ｿ逕ｨ縺ｫ繧医▲縺ｦ逋ｺ逕溘＠縺滂ｼ井ｻ｣譖ｿ蜩√∪縺溘・莉｣逕ｨ繧ｵ
//	繝ｼ繝薙せ縺ｮ隱ｿ驕斐∽ｽｿ逕ｨ縺ｮ蝟ｪ螟ｱ縲√ョ繝ｼ繧ｿ縺ｮ蝟ｪ螟ｱ縲∝茜逶翫・蝟ｪ螟ｱ縲∵･ｭ蜍吶・荳ｭ譁ｭ繧ょ性繧√√∪縺溘◎
//	繧後↓髯仙ｮ壹＆繧後↑縺・ｼ臥峩謗･謳榊ｮｳ縲・俣謗･謳榊ｮｳ縲∝・逋ｺ逧・↑謳榊ｮｳ縲∫音蛻･謳榊ｮｳ縲∵・鄂ｰ逧・錐螳ｳ縲√∪
//	縺溘・邨先棡謳榊ｮｳ縺ｫ縺､縺・※縲∽ｸ蛻・ｲｬ莉ｻ繧定ｲ繧上↑縺・ｂ縺ｮ縺ｨ縺励∪縺吶・
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
	localparam		clk_base		= 1_000_000_000_000.0/28_636_360;	//	ps
	localparam		cpu_clk_base	= 1_000_000_000_000.0/ 3_579_545;	//	ps
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
	wire			bus_sysctrl_cs;
	wire			bus_timer_ready;
	wire			bus_opll_ready;
	wire			bus_opl2_ready;
	wire			bus_ssg_ready;
	wire			bus_scc_ready;
	wire			bus_dcsg_ready;
	wire			bus_sysctrl_ready;
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
		.bus_write				( bus_write				),
		.bus_valid				( bus_valid				),
		.bus_timer_ready		( bus_timer_ready		),
		.bus_opll_ready			( bus_opll_ready		),
		.bus_opl2_ready			( bus_opl2_ready		),
		.bus_ssg_ready			( bus_ssg_ready			),
		.bus_scc_ready			( bus_scc_ready			),
		.bus_dcsg_ready			( bus_dcsg_ready		),
		.bus_sysctrl_ready		( bus_sysctrl_ready		),
		.bus_wdata				( bus_wdata				),
		.bus_rdata				( bus_rdata				),
		.bus_rdata_en			( bus_rdata_en			),
		.bus_timer_cs			( bus_timer_cs			),
		.bus_opll_cs			( bus_opll_cs			),
		.bus_opl2_cs			( bus_opl2_cs			),
		.bus_ssg_cs				( bus_ssg_cs			),
		.bus_scc_cs				( bus_scc_cs			),
		.bus_sysctrl_cs			( bus_sysctrl_cs		),
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
	assign w_bus_ready			= ff_bus_valid[0];
	assign bus_timer_ready		= w_bus_ready;
	assign bus_opll_ready		= w_bus_ready;
	assign bus_opl2_ready		= w_bus_ready;
	assign bus_ssg_ready		= w_bus_ready;
	assign bus_scc_ready		= w_bus_ready;
	assign bus_dcsg_ready		= w_bus_ready;
	assign bus_sysctrl_ready	= w_bus_ready;

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
