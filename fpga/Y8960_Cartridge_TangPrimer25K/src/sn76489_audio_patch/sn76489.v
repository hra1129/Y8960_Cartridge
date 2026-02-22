// --------------------------------------------------------------------
//	SN76489AN Wrapper
// ====================================================================
//	2026/01/24 t.hara
// --------------------------------------------------------------------

module dual_dcsg (
	input			clk,
	input			reset_n,
	input			enable,
	input			bus_cs,
	input			bus_address,
	input			bus_write,
	input			bus_valid,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[13:0]	sound_out0,				//	signed
	output	[13:0]	sound_out1				//	signed
);
	wire			w_cs0_n;
	wire			w_cs1_n;

	// --------------------------------------------------------------------
	//	Address decoder
	// --------------------------------------------------------------------
	assign w_cs0_n		= ( bus_cs && !bus_address ) ? 1'b0: 1'b1;
	assign w_cs1_n		= ( bus_cs &&  bus_address ) ? 1'b0: 1'b1;
	assign bus_ready	= bus_cs & enable;

	// --------------------------------------------------------------------
	//	sn76489an body
	// --------------------------------------------------------------------
	sn76489_audio #(
		.FAST_IO_G			( 1					),		//	0: normal I/O, 32 clocks per write, 1: fast I/O
		.MIN_PERIOD_CNT_G	( 6					)		//	6: 18643.46Hz First audible count, 17: 6580.04Hz Counts at 16 are known to be used for amplitude-modulation.
	) u_sn76489_0 (
		.clk_i				( clk				),
		.en_clk_psg_i		( enable			),
		.ce_n_i				( w_cs0_n			),
		.wr_n_i				( ~bus_write		),
		.ready_o			( 					),
		.data_i				( bus_wdata			),
		.ch_a_o				( 					),
		.ch_b_o				( 					),
		.ch_c_o				( 					),
		.noise_o			( 					),
		.mix_audio_o		( sound_out0		),
		.pcm14s_o			( 					)
	);

	sn76489_audio #(
		.FAST_IO_G			( 1					),		//	0: normal I/O, 32 clocks per write, 1: fast I/O
		.MIN_PERIOD_CNT_G	( 6					)		//	6: 18643.46Hz First audible count, 17: 6580.04Hz Counts at 16 are known to be used for amplitude-modulation.
	) u_sn76489_1 (
		.clk_i				( clk				),
		.en_clk_psg_i		( enable			),
		.ce_n_i				( w_cs1_n			),
		.wr_n_i				( ~bus_write		),
		.ready_o			( 					),
		.data_i				( bus_wdata			),
		.ch_a_o				( 					),
		.ch_b_o				( 					),
		.ch_c_o				( 					),
		.noise_o			( 					),
		.mix_audio_o		( sound_out1		),
		.pcm14s_o			( 					)
	);
endmodule
