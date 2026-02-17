// -----------------------------------------------------------------------------
//	Test of adpcm.v
//	Copyright (C)2026 Takayuki Hara (HRA!)
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
