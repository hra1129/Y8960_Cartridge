// --------------------------------------------------------------------
//	JT OPL2 Wrapper
// ====================================================================
//	2026/01/22 t.hara
// --------------------------------------------------------------------

module dual_opl2 (
	input			clk,
	input			reset_n,
	input			enable,
	input			bus_cs,
	input	[1:0]	bus_address,
	input			bus_write,
	input			bus_valid,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	output	[15:0]	opl2_sound_out_0,			//	signed
	output	[15:0]	opl2_sound_out_1,			//	signed
	output	[15:0]	adpcm_sound_out_l0,			//	signed
	output	[15:0]	adpcm_sound_out_r0,			//	signed
	output	[15:0]	adpcm_sound_out_l1,			//	signed
	output	[15:0]	adpcm_sound_out_r1,			//	signed
	output			intr_n
	//	ADPCM Memory I/F
	output   [23:0] addr,
	input    [ 7:0] data,
	output reg roe_n,
);
	wire			w_cs0_n;
	wire			w_cs1_n;
	wire			w_sample;
	wire	[15:0]	w_opl2_sound_out0;
	wire	[15:0]	w_opl2_sound_out1;
	wire			w_opl2_sound_en0;
	wire			w_opl2_sound_en1;
	reg		[15:0]	ff_opl2_sound_out0;
	reg		[15:0]	ff_opl2_sound_out1;
	wire			w_intr_n0;
	wire			w_intr_n1;
	wire	[7:0]	w_opl_rdata0;
	wire	[7:0]	w_opl_rdata1;
	wire	[3:0]	w_pcm_rdata0;
	wire	[3:0]	w_pcm_rdata1;
	reg				ff_ready;
	reg				ff_rdata_en;
	// ADPCM registers and signals
	wire	[7:0]	ff_reg_select0;
	wire			reg_acmd_on0;		// Control - Process start, Key On
	wire			reg_acmd_rep0;		// Control - Repeat
	wire			reg_acmd_rst0;		// Control - Reset
	wire			reg_acmd_up0;		// Control - New command received
	wire	[1:0]	reg_alr0;			// Left / Right
	wire	[15:0]	reg_astart0;		// Start address
	wire	[15:0]	reg_aend0;			// End	 address
	wire	[15:0]	reg_adeltan0;		// Delta-N
	wire	[7:0]	reg_aeg0;			// Envelope Generator Control
	wire			w_pcm_busy0;
	wire	[15:0]	w_pcm55_l0;
	wire	[15:0]	w_pcm55_r0;

	wire	[7:0]	ff_reg_select1;
	wire			reg_acmd_on1;		// Control - Process start, Key On
	wire			reg_acmd_rep1;		// Control - Repeat
	wire			reg_acmd_rst1;		// Control - Reset
	wire			reg_acmd_up1;		// Control - New command received
	wire	[1:0]	reg_alr1;			// Left / Right
	wire	[15:0]	reg_astart1;		// Start address
	wire	[15:0]	reg_aend1;			// End	 address
	wire	[15:0]	reg_adeltan1;		// Delta-N
	wire	[7:0]	reg_aeg1;			// Envelope Generator Control
	wire			w_pcm_busy1;
	wire	[15:0]	w_pcm55_l1;
	wire	[15:0]	w_pcm55_r1;

	reg		[9:0]	ff_clk55_cnt;
	wire			w_cen55;

	// ---------------------------------------------------------
	//	55.5kHz enabler
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_clk55_cnt <= 10'd0;
		end
		else if( w_cen55 ) begin
			ff_clk55_cnt <= 10'd0;
		end
		else begin
			ff_clk55_cnt <= ff_clk55_cnt + 10'd1;
		end
	end
	assign w_cen55	= (ff_clk55_cnt == 10'd515);

	// --------------------------------------------------------------------
	//	Address decoder
	// --------------------------------------------------------------------
	assign w_cs0_n		= ( bus_cs && !bus_address[1] ) ? ~bus_valid: 1'b1;
	assign w_cs1_n		= ( bus_cs &&  bus_address[1] ) ? ~bus_valid: 1'b1;

	// --------------------------------------------------------------------
	//	JT OPL2 body
	// --------------------------------------------------------------------
	jtopl2 u_opl2_0 (
		.rst			( reset_n				),
		.clk			( clk					),
		.cen			( enable				),
		.din			( bus_wdata				),
		.addr			( bus_address[0]		),
		.cs_n			( w_cs0_n				),
		.wr_n			( ~bus_write			),
		.dout			( w_opl_rdata0			),
		.irq_n			( w_intr_n0				),
		.snd			( w_opl2_sound_out0		),
		.sample			( w_opl2_sound_en0		)
	);

	jtopl2 u_opl2_1 (
		.rst			( reset_n				),
		.clk			( clk					),
		.cen			( enable				),
		.din			( bus_wdata				),
		.addr			( bus_address[0]		),
		.cs_n			( w_cs1_n				),
		.wr_n			( ~bus_write			),
		.dout			( w_rdata1				),
		.irq_n			( w_intr_n1				),
		.snd			( w_opl2_sound_out1		),
		.sample			( w_opl2_sound_en1		)
	);

	// ---------------------------------------------------------
	//	JT ADPCM (TypeB) body
	// ---------------------------------------------------------
	jt10_adpcm_drvB u_adpcm_0 (
		.rst_n			( reset_n				),
		.clk			( clk					),
		.cen			( enable				),
		.cen55			( w_cen55				),
		.acmd_on_b		( reg_acmd_on0			),
		.acmd_rep_b		( reg_acmd_rep0			),
		.acmd_rst_b		( reg_acmd_rst0			),
		.acmd_up_b		( reg_acmd_up0			),
		.alr_b			( reg_alr0				),
		.astart_b		( reg_astart0			),
		.aend_b			( reg_aend0				),
		.adeltan_b		( reg_adeltan0			),
		.aeg_b			( reg_aeg0				),
		.flag			( w_pcm_busy0			),
		.clr_flag		( clr_flag				),
		.addr			( addr					),
		.data			( data					),
		.roe_n			( roe_n					),
		.pcm55_l		( w_pcm55_l0			),
		.pcm55_r		( w_pcm55_r0			)
	);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_reg_select0		<= 8'd0;
			reg_mask_eds		<= 1'b1;
			reg_mask_buf_rdy	<= 1'b1;
			reg_start
		end
		else if( !w_cs0_n || !bus_valid ) begin
		end
		else if( bus_write ) begin
			if( !bus_address[0] ) begin
				ff_reg_select0	<= bus_wdata;
			end
			else begin
				case( ff_reg_select0 )
					8'h04: begin
						reg_mask_eds		<= bus_wdata[4];
						reg_mask_buf_rdy	<= bus_wdata[3];
					end
				endcase
			end
		end
	end

	jt10_adpcm_drvB u_adpcm_1 (
		.rst_n			( reset_n				),
		.clk			( clk					),
		.cen			( enable				),
		.cen55			( w_cen55				),
		.acmd_on_b		( reg_acmd_on1			),
		.acmd_rep_b		( reg_acmd_rep1			),
		.acmd_rst_b		( reg_acmd_rst1			),
		.acmd_up_b		( reg_acmd_up1			),
		.alr_b			( reg_alr1				),
		.astart_b		( reg_astart1			),
		.aend_b			( reg_aend1				),
		.adeltan_b		( reg_adeltan1			),
		.aeg_b			( reg_aeg1				),
		.flag			( w_pcm_busy1			),
		.clr_flag		( clr_flag				),
		.addr			( addr					),
		.data			( data					),
		.roe_n			( roe_n					),
		.pcm55_l		( w_pcm55_l1			),
		.pcm55_r		( w_pcm55_r1			)
	);

	assign w_pcm_rdata0		= { 1'b0, 2'b11, w_pcm_busy0 };
	assign w_pcm_rdata1		= { 1'b0, 2'b11, w_pcm_busy1 };

	// ---------------------------------------------------------
	//	BUS
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_rdata_en <= 1'd0;
		end
		else if( !enable ) begin
			//	hold
		end
		else if( ff_rdata_en ) begin
			ff_rdata_en <= 1'd0;
		end
		else if( ~(w_cs0_n & w_cs1_n) && ~bus_write ) begin
			ff_rdata_en <= 1'b1;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ready <= 1'd1;
		end
		else if( !enable ) begin
			//	hold
		end
		else if( ff_rdata_en ) begin
			ff_ready <= 1'd1;
		end
		else if( ~(w_cs0_n & w_cs1_n) && ~bus_write ) begin
			ff_ready <= 1'd0;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_opl2_sound_out0		<= 16'd0;
			ff_opl2_sound_out1		<= 16'd0;
			ff_adpcm_sound_out_l0	<= 16'd0;
			ff_adpcm_sound_out_r0	<= 16'd0;
			ff_adpcm_sound_out_l1	<= 16'd0;
			ff_adpcm_sound_out_r1	<= 16'd0;
		end
		else begin
			ff_opl2_sound_out0		<= w_opl2_sound_en0  ? w_opl2_sound_out0: 16'd0;
			ff_opl2_sound_out1		<= w_opl2_sound_en1  ? w_opl2_sound_out1: 16'd0;
			ff_adpcm_sound_out_l0	<= w_adpcm_sound_en0 ? w_pcm55_l0: 16'd0;
			ff_adpcm_sound_out_r0	<= w_adpcm_sound_en0 ? w_pcm55_r0: 16'd0;
			ff_adpcm_sound_out_l1	<= w_adpcm_sound_en1 ? w_pcm55_l1: 16'd0;
			ff_adpcm_sound_out_r1	<= w_adpcm_sound_en1 ? w_pcm55_r1: 16'd0;
		end
	end

	assign bus_ready			= ff_ready;
	assign bus_rdata			= ( w_cs0_n == 1'b0 ) ? {w_opl_rdata0[7:4], w_pcm_rdata0} : {w_opl_rdata1[7:4], w_pcm_rdata1};
	assign bus_rdata_en			= ff_rdata_en;
	assign opl2_sound_out_0		= ff_opl2_sound_out0;
	assign opl2_sound_out_1		= ff_opl2_sound_out1;
	assign adpcm_sound_out_l0	= ff_adpcm_sound_out_l0;
	assign adpcm_sound_out_r0	= ff_adpcm_sound_out_r0;
	assign adpcm_sound_out_l1	= ff_adpcm_sound_out_l1;
	assign adpcm_sound_out_r1	= ff_adpcm_sound_out_r1;

	assign intr_n			= w_intr_n0 & w_intr_n1;
endmodule
