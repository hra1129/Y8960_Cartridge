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
	output			intr_n,
	//	ADPCM Memory I/F
	output			adpcm_oe_n,
	output			adpcm_we_n,
	output	[17:0]	adpcm_address,				//	256KB
	output	[7:0]	adpcm_wdata,
	input	[7:0]	adpcm_rdata,
	input			adpcm_rdata_en
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
	wire	[7:0]	w_bus_rdata0;
	wire	[7:0]	w_bus_rdata1;
	wire			w_bus_rdata0_en;
	wire			w_bus_rdata1_en;
	reg				ff_ready;
	reg		[7:0]	ff_rdata;
	reg				ff_rdata_en;
	wire	[15:0]	w_adpcm_sound_out_l0;
	wire	[15:0]	w_adpcm_sound_out_r0;
	wire	[15:0]	w_adpcm_sound_out_l1;
	wire	[15:0]	w_adpcm_sound_out_r1;
	reg		[15:0]	ff_adpcm_sound_out_l0;
	reg		[15:0]	ff_adpcm_sound_out_r0;
	reg		[15:0]	ff_adpcm_sound_out_l1;
	reg		[15:0]	ff_adpcm_sound_out_r1;
	reg		[9:0]	ff_clk50_cnt;
	wire			w_cen50_0;
	wire			w_cen50_1;
	wire			w_adpcm_oe_n0;
	wire			w_adpcm_oe_n1;
	wire			w_adpcm_we_n0;
	wire			w_adpcm_we_n1;
	wire	[23:0]	w_adpcm_address0;
	wire	[23:0]	w_adpcm_address1;
	wire	[7:0]	w_adpcm_wdata0;
	wire	[7:0]	w_adpcm_wdata1;

	// ---------------------------------------------------------
	//	49.7159kHz enabler
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_clk50_cnt <= 7'd0;
		end
		else if( !enable ) begin				//	3.579545MHz
			//	hold
		end
		else if( ff_clk50_cnt == 7'd71 ) begin	//	49.7159kHz
			ff_clk50_cnt <= 7'd0;
		end
		else begin
			ff_clk50_cnt <= ff_clk50_cnt + 7'd1;
		end
	end
	assign w_cen50_0	= (ff_clk50_cnt == 7'd0);
	assign w_cen50_1	= (ff_clk50_cnt == 7'd36);

	// --------------------------------------------------------------------
	//	Address decoder
	// --------------------------------------------------------------------
	assign w_cs0_n		= ( bus_cs && !bus_address[1] ) ? 1'b0: 1'b1;
	assign w_cs1_n		= ( bus_cs &&  bus_address[1] ) ? 1'b0: 1'b1;

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
		.dout			( w_opl_rdata1			),
		.irq_n			( w_intr_n1				),
		.snd			( w_opl2_sound_out1		),
		.sample			( w_opl2_sound_en1		)
	);

	// ---------------------------------------------------------
	//	JT ADPCM (TypeB) body
	// ---------------------------------------------------------
	adpcm u_adpcm0 (
		.clk				( clk					),
		.reset_n			( reset_n				),
		.enable				( enable				),
		.cen55				( w_cen50_0				),
		.bus_cs				( ~w_cs0_n				),
		.bus_address		( bus_address[0]		),
		.bus_write			( bus_write				),
		.bus_valid			( bus_valid				),
		.bus_wdata			( bus_wdata				),
		.bus_rdata			( w_bus_rdata0			),
		.bus_rdata_en		( w_bus_rdata0_en		),
		.opl2_status		( w_opl_rdata0			),
		.adpcm_sound_out_l	( w_adpcm_sound_out_l0	),
		.adpcm_sound_out_r	( w_adpcm_sound_out_r0	),
		.adpcm_oe_n			( w_adpcm_oe_n0			),
		.adpcm_we_n			( w_adpcm_we_n0			),
		.adpcm_address		( w_adpcm_address0		),
		.adpcm_wdata		( w_adpcm_wdata0		),
		.adpcm_rdata		( adpcm_rdata			),
		.adpcm_rdata_en		( adpcm_rdata_en		)
	);

	adpcm u_adpcm1 (
		.clk				( clk					),
		.reset_n			( reset_n				),
		.enable				( enable				),
		.cen55				( w_cen50_1				),
		.bus_cs				( ~w_cs1_n				),
		.bus_address		( bus_address[0]		),
		.bus_write			( bus_write				),
		.bus_valid			( bus_valid				),
		.bus_wdata			( bus_wdata				),
		.bus_rdata			( w_bus_rdata1			),
		.bus_rdata_en		( w_bus_rdata1_en		),
		.opl2_status		( w_opl_rdata1			),
		.adpcm_sound_out_l	( w_adpcm_sound_out_l1	),
		.adpcm_sound_out_r	( w_adpcm_sound_out_r1	),
		.adpcm_oe_n			( w_adpcm_oe_n1			),
		.adpcm_we_n			( w_adpcm_we_n1			),
		.adpcm_address		( w_adpcm_address1		),
		.adpcm_wdata		( w_adpcm_wdata1		),
		.adpcm_rdata		( adpcm_rdata			),
		.adpcm_rdata_en		( adpcm_rdata_en		)
	);

	// ---------------------------------------------------------
	//	BUS
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_rdata_en <= 1'd0;
		end
		else if( w_bus_rdata0_en || w_bus_rdata1_en ) begin
			ff_rdata_en <= 1'd1;
		end
		else begin
			ff_rdata_en <= 1'b0;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_rdata <= 8'd0;
		end
		else if( w_bus_rdata0_en ) begin
			ff_rdata <= w_bus_rdata0;
		end
		else if( w_bus_rdata1_en ) begin
			ff_rdata <= w_bus_rdata1;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ready <= 1'd1;
		end
		else if( w_bus_rdata0_en || w_bus_rdata1_en ) begin
			ff_ready <= 1'd1;
		end
		else if( ~(w_cs0_n & w_cs1_n) && ~bus_write && bus_valid ) begin
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
			if( w_opl2_sound_en0 ) begin
				ff_opl2_sound_out0		<= w_opl2_sound_out0;
			end
			if( w_opl2_sound_en1 ) begin
				ff_opl2_sound_out1		<= w_opl2_sound_out1;
			end
			if( w_cen50_0 ) begin
				ff_adpcm_sound_out_l0	<= w_adpcm_sound_out_l0;
				ff_adpcm_sound_out_r0	<= w_adpcm_sound_out_r0;
			end
			if( w_cen50_1 ) begin
				ff_adpcm_sound_out_l1	<= w_adpcm_sound_out_l1;
				ff_adpcm_sound_out_r1	<= w_adpcm_sound_out_r1;
			end
		end
	end

	assign bus_ready			= ff_ready;
	assign bus_rdata			= ff_rdata;
	assign bus_rdata_en			= ff_rdata_en;
	assign opl2_sound_out_0		= ff_opl2_sound_out0;
	assign opl2_sound_out_1		= ff_opl2_sound_out1;
	assign adpcm_sound_out_l0	= ff_adpcm_sound_out_l0;
	assign adpcm_sound_out_r0	= ff_adpcm_sound_out_r0;
	assign adpcm_sound_out_l1	= ff_adpcm_sound_out_l1;
	assign adpcm_sound_out_r1	= ff_adpcm_sound_out_r1;
	assign adpcm_address		= ( !(w_adpcm_we_n0 & w_adpcm_oe_n0) ) ? w_adpcm_address0: w_adpcm_address1;
	assign adpcm_wdata			= ( !w_adpcm_we_n0 ) ? w_adpcm_wdata0: w_adpcm_wdata1;
	assign adpcm_we_n			= w_adpcm_we_n0 & w_adpcm_we_n1;
	assign adpcm_oe_n			= w_adpcm_oe_n0 & w_adpcm_oe_n1;
	assign intr_n				= w_intr_n0 & w_intr_n1;
endmodule
