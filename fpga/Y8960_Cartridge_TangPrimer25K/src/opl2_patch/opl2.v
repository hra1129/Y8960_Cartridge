// --------------------------------------------------------------------
//	JT OPL2 Wrapper
// ====================================================================
//	2026/01/22 t.hara
// --------------------------------------------------------------------

module opl2 (
	input			clk,
	input			reset_n,
	input			enable,
	input			bus_cs,
	input			bus_address,
	input			bus_write,
	input			bus_valid,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	output	[15:0]	opl2_sound_out_l,			//	signed
	output	[15:0]	opl2_sound_out_r,			//	signed
	output			intr_n,
	//	ADPCM Memory I/F
	output			adpcm_write,
	output			adpcm_valid,
	input			adpcm_ready,
	output	[17:0]	adpcm_address,				//	256KB
	output	[7:0]	adpcm_wdata,
	input	[7:0]	adpcm_rdata,
	input			adpcm_rdata_en
);
	wire			w_cs_n;
	wire			w_core_enable;
	wire	[15:0]	w_opl2_sound_out_l;
	wire	[15:0]	w_opl2_sound_out_r;
	wire			w_opl2_sound_en;
	reg		[15:0]	ff_opl2_sound_out_l;
	reg		[15:0]	ff_opl2_sound_out_r;
	wire	[7:0]	w_opl_rdata;
	wire			w_opl_irq_n;
	wire			w_adpcm_irq;
	wire	[7:0]	w_bus_rdata;
	wire			w_bus_rdata_en;
	reg				ff_ready;
	reg		[7:0]	ff_rdata;
	reg				ff_rdata_en;
	wire	[15:0]	w_adpcm_sound_out_l;
	wire	[15:0]	w_adpcm_sound_out_r;
	reg		[15:0]	ff_adpcm_sound_out_l;
	reg		[15:0]	ff_adpcm_sound_out_r;
	reg		[9:0]	ff_clk50_cnt;
	wire			w_cen50;
	wire	[23:0]	w_adpcm_address;
	wire signed [16:0]	w_sound_sum_l;
	wire signed [16:0]	w_sound_sum_r;

	function signed [15:0] saturate_16;
		input signed [16:0] value;
		begin
			if( value[16:15] == {2{value[15]}} ) begin
				saturate_16 = value[15:0];
			end
			else if( value[16] ) begin
				saturate_16 = 16'sh8000;
			end
			else begin
				saturate_16 = 16'sh7FFF;
			end
		end
	endfunction

	// ---------------------------------------------------------
	//	49.7159kHz enabler
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_clk50_cnt <= 10'd0;
		end
		else if( !enable ) begin				//	3.579545MHz
			//	hold
		end
		else if( ff_clk50_cnt == 10'd71 ) begin	//	49.7159kHz
			ff_clk50_cnt <= 10'd0;
		end
		else begin
			ff_clk50_cnt <= ff_clk50_cnt + 10'd1;
		end
	end
	//	ff_clk50_cnt stays 0 for a whole enable period, so gate it with enable
	//	to make a one clock pulse. Otherwise the ADPCM address counter advances
	//	up to 12 times per sample.
	assign w_cen50		= enable && (ff_clk50_cnt == 10'd0);

	// --------------------------------------------------------------------
	//	Address decoder
	// --------------------------------------------------------------------
	assign w_cs_n		= ~bus_cs;

	// --------------------------------------------------------------------
	//	JT OPL2 body
	// --------------------------------------------------------------------
	assign w_core_enable = enable | ~reset_n;

	jtopl2 u_opl2 (
		.rst			( ~reset_n				),
		.clk			( clk					),
		.cen			( w_core_enable			),
		.din			( bus_wdata				),
		.addr			( bus_address			),
		.cs_n			( w_cs_n				),
		.wr_n			( ~bus_write			),
		.dout			( w_opl_rdata			),
		.irq_n			( w_opl_irq_n			),
		.snd_l			( w_opl2_sound_out_l	),
		.snd_r			( w_opl2_sound_out_r	),
		.sample			( w_opl2_sound_en		)
	);

	// ---------------------------------------------------------
	//	JT ADPCM (TypeB) body
	// ---------------------------------------------------------
	adpcm u_adpcm (
		.clk				( clk					),
		.reset_n			( reset_n				),
		.enable				( enable				),
		.cen55				( w_cen50				),
		.bus_cs				( bus_cs				),
		.bus_address		( bus_address			),
		.bus_write			( bus_write				),
		.bus_valid			( bus_valid				),
		.bus_wdata			( bus_wdata				),
		.bus_rdata			( w_bus_rdata			),
		.bus_rdata_en		( w_bus_rdata_en		),
		.opl2_status		( w_opl_rdata			),
		.adpcm_irq			( w_adpcm_irq			),
		.adpcm_sound_out_l	( w_adpcm_sound_out_l	),
		.adpcm_sound_out_r	( w_adpcm_sound_out_r	),
		.adpcm_write		( adpcm_write			),
		.adpcm_valid		( adpcm_valid			),
		.adpcm_ready		( adpcm_ready			),
		.adpcm_address		( w_adpcm_address		),
		.adpcm_wdata		( adpcm_wdata			),
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
		else if( w_bus_rdata_en ) begin
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
		else if( w_bus_rdata_en ) begin
			ff_rdata <= w_bus_rdata;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ready <= 1'd1;
		end
		else if( w_bus_rdata_en ) begin
			ff_ready <= 1'd1;
		end
		else if( ~w_cs_n && ~bus_write && bus_valid ) begin
			ff_ready <= 1'd0;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_opl2_sound_out_l		<= 16'd0;
			ff_opl2_sound_out_r		<= 16'd0;
			ff_adpcm_sound_out_l	<= 16'd0;
			ff_adpcm_sound_out_r	<= 16'd0;
		end
		else begin
			if( w_opl2_sound_en ) begin
				ff_opl2_sound_out_l		<= w_opl2_sound_out_l;
				ff_opl2_sound_out_r		<= w_opl2_sound_out_r;
			end
			if( w_cen50 ) begin
				ff_adpcm_sound_out_l	<= w_adpcm_sound_out_l;
				ff_adpcm_sound_out_r	<= w_adpcm_sound_out_r;
			end
		end
	end

	assign bus_ready			= ff_ready;
	assign bus_rdata			= ff_rdata_en ? ff_rdata : 8'hFF;
	assign bus_rdata_en			= ff_rdata_en;
	assign w_sound_sum_l			= $signed( ff_opl2_sound_out_l ) + $signed( ff_adpcm_sound_out_l );
	assign w_sound_sum_r			= $signed( ff_opl2_sound_out_r ) + $signed( ff_adpcm_sound_out_r );
	assign opl2_sound_out_l		= saturate_16( w_sound_sum_l );
	assign opl2_sound_out_r		= saturate_16( w_sound_sum_r );
	assign adpcm_address		= w_adpcm_address[17:0];
	//	Y8950: unmasked ADPCM flags (EOS/BUF_RDY) also assert IRQ.
	assign intr_n				= w_opl_irq_n & ~w_adpcm_irq;
endmodule
