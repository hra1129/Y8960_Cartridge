// --------------------------------------------------------------------
//	IKAOPLL Wrapper
// ====================================================================
//	2024/09/15 t.hara
// --------------------------------------------------------------------

module dual_opll (
	input			clk,
	input			reset_n,
	input			bus_memreq,
	input			bus_ioreq,
	input	[15:0]	bus_address,
	input			bus_write,
	input			bus_valid,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[15:0]	sound_out0,				//	signed
	output	[15:0]	sound_out1				//	signed
);
	wire			w_cs0_n;
	wire			w_cs1_n;
	wire			w_enable_n;
	reg		[4:0]	ff_divider;
	wire	[15:0]	w_sound_out;

	// --------------------------------------------------------------------
	//	Address decoder
	// --------------------------------------------------------------------
	assign w_cs0_n		= ( bus_ioreq && ({ bus_address[7:1], 1'b0 } == 8'h7C) ) || ( bus_mereq && ({ bus_address[15:1], 1'b0 } == 16'h7FF4) ) ? ~bus_valid: 1'b1;
	assign w_cs1_n		= ( bus_ioreq && ({ bus_address[7:1], 1'b0 } == 8'h7A) ) || ( bus_mereq && ({ bus_address[15:1], 1'b0 } == 16'h7FF2) ) ? ~bus_valid: 1'b1;
	assign bus_ready	= (~(w_cs0_n & w_cs1_n) & (ff_divider == 5'd0 )) | (w_cs0_n & w_cs1_n);

	// --------------------------------------------------------------------
	//	Clock divider
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_divider <= 5'd0;
		end
		else if( ff_divider == 5'd23 ) begin
			ff_divider <= 5'd0;
		end
		else begin
			ff_divider <= ff_divider + 5'd1;
		end
	end

	assign w_enable_n	= (ff_divider == 5'd0 ) ? 1'b0 : 1'b1;

	// --------------------------------------------------------------------
	//	IKAOPLL body
	// --------------------------------------------------------------------
	IKAOPLL #(
		.FULLY_SYNCHRONOUS			( 1					),		//	use DFF only
		.FAST_RESET					( 1					),		//	speed up reset
		.ALTPATCH_CONFIG_MODE		( 0					),		//	0 to use external wire, 1 to use bit[4] of TEST register
		.USE_PIPELINED_MULTIPLIER	( 1					)		//	1 to add pipelined multiplier to increase fmax
	) u_ikaopll0 (
		.i_XIN_EMUCLK				( clk				),
		.o_XOUT						( 					),		//	no use: Clock output
		.i_phiM_PCEN_n				( w_enable_n		),
		.i_IC_n						( reset_n			),
		.i_ALTPATCH_EN				( 1'b0				),		//	VRC7 patch disable
		.i_CS_n						( w_cs0_n			),
		.i_WR_n						( ~bus_write		),
		.i_A0						( bus_address[0]	),
		.i_D						( bus_wdata			),
		.o_D						( 					),		//	no use: Read test bits
		.o_D_OE						( 					),		//	no use: o_D enable
		.o_DAC_EN_MO				( 					),		//	no use
		.o_DAC_EN_RO				( 					),		//	no use
		.o_IMP_NOFLUC_SIGN			( 					),		//	no use
		.o_IMP_NOFLUC_MAG			( 					),		//	no use
		.o_IMP_FLUC_SIGNED_MO		( 					),		//	no use
		.o_IMP_FLUC_SIGNED_RO		( 					),		//	no use
		.i_ACC_SIGNED_MOVOL			( 5'd10				),		//	Melody volume level: -16...15 (SIGNED)
		.i_ACC_SIGNED_ROVOL			( 5'd15				),		//	Drum volume level  : -16...15 (SIGNED)
		.o_ACC_SIGNED_STRB			( 					),		//	no use
		.o_ACC_SIGNED				( sound_out0		)		//	sound out
	);

	IKAOPLL #(
		.FULLY_SYNCHRONOUS			( 1					),		//	use DFF only
		.FAST_RESET					( 1					),		//	speed up reset
		.ALTPATCH_CONFIG_MODE		( 0					),		//	0 to use external wire, 1 to use bit[4] of TEST register
		.USE_PIPELINED_MULTIPLIER	( 1					)		//	1 to add pipelined multiplier to increase fmax
	) u_ikaopll1 (
		.i_XIN_EMUCLK				( clk				),
		.o_XOUT						( 					),		//	no use: Clock output
		.i_phiM_PCEN_n				( w_enable_n		),
		.i_IC_n						( reset_n			),
		.i_ALTPATCH_EN				( 1'b0				),		//	VRC7 patch disable
		.i_CS_n						( w_cs1_n			),
		.i_WR_n						( ~bus_write		),
		.i_A0						( bus_address[0]	),
		.i_D						( bus_wdata			),
		.o_D						( 					),		//	no use: Read test bits
		.o_D_OE						( 					),		//	no use: o_D enable
		.o_DAC_EN_MO				( 					),		//	no use
		.o_DAC_EN_RO				( 					),		//	no use
		.o_IMP_NOFLUC_SIGN			( 					),		//	no use
		.o_IMP_NOFLUC_MAG			( 					),		//	no use
		.o_IMP_FLUC_SIGNED_MO		( 					),		//	no use
		.o_IMP_FLUC_SIGNED_RO		( 					),		//	no use
		.i_ACC_SIGNED_MOVOL			( 5'd10				),		//	Melody volume level: -16...15 (SIGNED)
		.i_ACC_SIGNED_ROVOL			( 5'd15				),		//	Drum volume level  : -16...15 (SIGNED)
		.o_ACC_SIGNED_STRB			( 					),		//	no use
		.o_ACC_SIGNED				( sound_out1		)		//	sound out
	);
endmodule
