// -----------------------------------------------------------------------------
//	Test of adpcm.v
//	Copyright (C)2026 Takayuki Hara (HRA!)
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
	localparam			clk_base		= 1_000_000_000/28_636_360;	//	ns

	// --------------------------------------------------------------------
	//	Signal declarations for DUT ports
	// --------------------------------------------------------------------
	reg					rst_n;
	reg					clk;
	wire				cen;			// 3.579545MHz cen
	wire				cen55;			// clk & cen55  =	 55 kHz
	reg					acmd_on_b;		// Control - Process start; Key On
	reg					acmd_rep_b;		// Control - Repeat
	reg					acmd_rst_b;		// Control - Reset
	reg					acmd_up_b;		// Control - New command received
	reg			[ 1:0]	alr_b;			// Left / Right
	reg			[15:0]	astart_b;		// Start address
	reg			[15:0]	aend_b;			// End	 address
	reg			[15:0]	adeltan_b;		// Delta-N
	reg			[ 7:0]	aeg_b;			// Envelope Generator Control
	wire				flag;
	reg					clr_flag;
	wire		[23:0]	addr;
	reg			[ 7:0]	data;
	wire				roe_n;
	wire signed	[15:0]  pcm55_l;
	wire signed	[15:0]  pcm55_r;

	// --------------------------------------------------------------------
	//	Internal signals
	// --------------------------------------------------------------------
	logic		[7:0]	adpcm_memory [0:128*1024];		// 128KB PCM
	logic		[2:0]	ff_clken;
	logic		[9:0]	ff_cen55;
	int					i;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	jt10_adpcm_drvB u_adpcm_drvB (
		.rst_n			( rst_n			),
		.clk			( clk			),
		.cen			( cen			),
		.cen55			( cen55			),
		.acmd_on_b		( acmd_on_b		),
		.acmd_rep_b		( acmd_rep_b	),
		.acmd_rst_b		( acmd_rst_b	),
		.acmd_up_b		( acmd_up_b		),
		.alr_b			( alr_b			),
		.astart_b		( astart_b		),
		.aend_b			( aend_b		),
		.adeltan_b		( adeltan_b		),
		.aeg_b			( aeg_b			),
		.flag			( flag			),
		.clr_flag		( clr_flag		),
		.addr			( addr			),
		.data			( data			),
		.roe_n			( roe_n			),
		.pcm55_l		( pcm55_l		),
		.pcm55_r		( pcm55_r		)
	);

	// --------------------------------------------------------------------
	//	Clock generation
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	always @( posedge clk ) begin
		if( !rst_n ) begin
			ff_clken <= 0;
		end
		else begin
			ff_clken <= ff_clken + 1;
		end
	end
	assign cen = (ff_clken == 7);

	always @( posedge clk ) begin
		if( !rst_n ) begin
			ff_cen55 <= 0;
		end
		else if( ff_cen55 == 515 ) begin
			ff_cen55 <= 0;
		end
		else begin
			ff_cen55 <= ff_cen55 + 1;
		end
	end
	assign cen55 = (ff_cen55 == 1);

	// --------------------------------------------------------------------
	//	ADPCM Memory Simulation
	// --------------------------------------------------------------------





	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		// Initialize signals
		rst_n = 0;
		clk = 0;
		acmd_on_b = 0;			// Control - Process start; Key On
		acmd_rep_b = 0;			// Control - Repeat
		acmd_rst_b = 0;			// Control - Reset
		acmd_up_b = 0;			// Control - New command received
		alr_b = 0;				// Left / Right
		astart_b = 0;			// Start address
		aend_b = 1000;			// End	 address
		adeltan_b = 1;			// Delta-N
		aeg_b = 0;				// Envelope Generator Control
		clr_flag = 0;
		data = 0;

		// Initialize VRAM
		for( i = 0; i < 128 * 1024; i++ ) begin
			adpcm_memory[i] = i & 255;
		end

		// Reset sequence
		repeat(10) @( posedge clk );
		rst_n <= 1;
		repeat(10000) @( posedge clk );

		$finish;
	end
endmodule
