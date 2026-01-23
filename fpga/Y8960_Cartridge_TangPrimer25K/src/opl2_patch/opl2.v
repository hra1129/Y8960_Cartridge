// --------------------------------------------------------------------
//	JT OPL2 Wrapper
// ====================================================================
//	2026/01/22 t.hara
// --------------------------------------------------------------------

module dual_opl2 (
	input			clk,
	input			reset_n,
	input			enable,
	input			bus_ioreq,
	input	[7:0]	bus_address,
	input			bus_write,
	input			bus_valid,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	output	[15:0]	sound_out_l,			//	signed
	output	[15:0]	sound_out_r,			//	signed
	output			intr_n
);
	wire			w_cs0_n;
	wire			w_cs1_n;
	wire			w_sample;
	wire	[15:0]	w_sound_out0;
	wire	[15:0]	w_sound_out1;
	wire			w_sound_en0;
	wire			w_sound_en1;
    reg     [15:0]	ff_sound_out0;
	reg 	[15:0]	ff_sound_out1;
	wire			w_intr_n0;
	wire			w_intr_n1;
	wire	[7:0]	w_rdata0;
	wire	[7:0]	w_rdata1;
	reg				ff_ready;
	reg				ff_rdata_en;

	// --------------------------------------------------------------------
	//	Address decoder
	// --------------------------------------------------------------------
	assign w_cs0_n		= ( bus_ioreq && ({ bus_address[7:1], 1'b0 } == 8'hC0) ) ? ~bus_valid: 1'b1;
	assign w_cs1_n		= ( bus_ioreq && ({ bus_address[7:1], 1'b0 } == 8'hC2) ) ? ~bus_valid: 1'b1;

	// --------------------------------------------------------------------
	//	JT OPL2 body
	// --------------------------------------------------------------------
	jtopl2 u_opl2_0 (
		.rst			( reset_n			),
		.clk			( clk				),
		.cen			( enable			),
		.din			( bus_wdata			),
		.addr			( bus_address[0]	),
		.cs_n			( w_cs0_n			),
		.wr_n			( ~bus_write		),
		.dout			( w_rdata0			),
		.irq_n			( w_intr_n0			),
		.snd			( w_sound_out0		),
		.sample			( w_sound_en0		)
	);

	jtopl2 u_opl2_1 (
		.rst			( reset_n			),
		.clk			( clk				),
		.cen			( enable			),
		.din			( bus_wdata			),
		.addr			( bus_address[0]	),
		.cs_n			( w_cs1_n			),
		.wr_n			( ~bus_write		),
		.dout			( w_rdata1			),
		.irq_n			( w_intr_n1			),
		.snd			( w_sound_out1		),
		.sample			( w_sound_en1		)
	);

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
			ff_sound_out0 <= 16'd0;
		end
		else if( w_sound_en0 ) begin
			ff_sound_out0 <= w_sound_out0;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_sound_out1 <= 16'd0;
		end
		else if( w_sound_en0 ) begin
			ff_sound_out1 <= w_sound_out1;
		end
	end

	assign bus_ready	= ff_ready;
	assign bus_rdata	= w_rdata0 | w_rdata1;
	assign bus_rdata_en	= ff_rdata_en;
	assign sound_out_l	= ff_sound_out0;
	assign sound_out_r	= ff_sound_out1;
	assign intr_n		= w_intr_n0 & w_intr_n1;
endmodule
