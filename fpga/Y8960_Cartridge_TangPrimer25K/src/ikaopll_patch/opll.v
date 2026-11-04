// --------------------------------------------------------------------
//	IKAOPLL Wrapper
// ====================================================================
//	2026/01/22 t.hara
// --------------------------------------------------------------------

module opllex (
	input			clk,
	input			reset_n,
	input			enable,
	input			bus_cs,
	input			bus_address,			//	0x7C, 0x7D
	input			bus_write,
	input			bus_valid,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[15:0]	sound_l_out,			//	signed
	output	[15:0]	sound_r_out				//	signed
);
	wire			w_cs_n;
	wire			w_core_enable;
	wire			w_addrreg_wrrq;
	wire			w_datareg_wrrq;
	wire			w_d9reg_commit;
	wire			w_capture;
	wire			w_enqueue;
	wire			w_dequeue;
	wire			w_request_ack;
	reg				ff_bus_seen;
	reg		[3:0]	ff_queue_count;
	reg		[2:0]	ff_write_pointer;
	reg		[2:0]	ff_read_pointer;
	reg		[9:0]	ff_queue [0:7];
	reg				ff_processing;
	reg				ff_ack_seen;
	reg				ff_commit_seen;
	reg				ff_process_address;
	reg				ff_process_write;
	reg		[7:0]	ff_process_wdata;

	// --------------------------------------------------------------------
	//	Bus request queue
	// --------------------------------------------------------------------
	assign w_capture	= bus_cs && bus_valid && !ff_bus_seen && (ff_queue_count != 4'd8);
	assign w_enqueue	= w_capture && bus_write;
	assign w_dequeue	= !ff_processing && (ff_queue_count != 4'd0);
	assign bus_ready	= w_capture;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_bus_seen		<= 1'b0;
			ff_queue_count	<= 4'd0;
			ff_write_pointer	<= 3'd0;
			ff_read_pointer	<= 3'd0;
		end
		else begin
			if( !bus_cs || !bus_valid ) begin
				ff_bus_seen <= 1'b0;
			end
			else if( w_capture ) begin
				ff_bus_seen <= 1'b1;
			end

			if( w_enqueue ) begin
				ff_queue[ff_write_pointer]	<= {bus_address, bus_write, bus_wdata};
				ff_write_pointer				<= ff_write_pointer + 3'd1;
			end

			if( w_dequeue ) begin
				ff_read_pointer <= ff_read_pointer + 3'd1;
			end

			case( {w_enqueue, w_dequeue} )
				2'b01: ff_queue_count <= ff_queue_count - 4'd1;
				2'b10: ff_queue_count <= ff_queue_count + 4'd1;
				default: ff_queue_count <= ff_queue_count;
			endcase
		end
	end

	// --------------------------------------------------------------------
	//	IKAOPLL bus sequencer
	// --------------------------------------------------------------------
	assign w_request_ack	= ff_process_address ? w_datareg_wrrq : w_addrreg_wrrq;
	assign w_cs_n			= ~(ff_processing && !ff_ack_seen);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_processing		<= 1'b0;
			ff_ack_seen		<= 1'b0;
			ff_commit_seen	<= 1'b0;
			ff_process_address	<= 1'b0;
			ff_process_write	<= 1'b0;
			ff_process_wdata	<= 8'd0;
		end
		else begin
			if( w_dequeue ) begin
				ff_processing		<= 1'b1;
				ff_ack_seen		<= 1'b0;
				ff_commit_seen	<= 1'b0;
				ff_process_address	<= ff_queue[ff_read_pointer][9];
				ff_process_write	<= ff_queue[ff_read_pointer][8];
				ff_process_wdata	<= ff_queue[ff_read_pointer][7:0];
			end
			else if( ff_processing && !ff_ack_seen && w_request_ack ) begin
				ff_ack_seen <= 1'b1;
			end
			else if( ff_processing && ff_ack_seen ) begin
				if( ff_process_address && w_d9reg_commit ) begin
					ff_commit_seen <= 1'b1;
				end

				if( !w_addrreg_wrrq && !w_datareg_wrrq &&
					(!ff_process_address || ff_commit_seen) ) begin
					ff_processing <= 1'b0;
				end
			end
		end
	end

	// --------------------------------------------------------------------
	//	IKAOPLL body
	// --------------------------------------------------------------------
	assign w_core_enable = enable | ~reset_n;

	IKAOPLL #(
		.FULLY_SYNCHRONOUS			( 1					),		//	use DFF only
		.FAST_RESET					( 1					),		//	speed up reset
		.ALTPATCH_CONFIG_MODE		( 0					),		//	0 to use external wire, 1 to use bit[4] of TEST register
		.USE_PIPELINED_MULTIPLIER	( 1					)		//	1 to add pipelined multiplier to increase fmax
	) u_ikaopll (
		.i_XIN_EMUCLK				( clk				),
		.o_XOUT						( 					),		//	no use: Clock output
		.i_phiM_PCEN_n				( ~w_core_enable		),
		.i_IC_n						( reset_n			),
		.i_ALTPATCH_EN				( 1'b0				),		//	VRC7 patch disable
		.i_CS_n						( w_cs_n			),
		.i_WR_n						( ~ff_process_write	),
		.i_A0						( ff_process_address	),
		.i_D						( ff_process_wdata	),
		.o_D						( 					),		//	no use: Read test bits
		.o_D_OE						( 					),		//	no use: o_D enable
		.o_ADDRREG_WRRQ				( w_addrreg_wrrq	),
		.o_DATAREG_WRRQ				( w_datareg_wrrq	),
		.o_D9REG_COMMIT				( w_d9reg_commit		),
		.o_DAC_EN_MO				( 					),		//	no use
		.o_DAC_EN_RO				( 					),		//	no use
		.o_IMP_NOFLUC_SIGN			( 					),		//	no use
		.o_IMP_NOFLUC_MAG			( 					),		//	no use
		.o_IMP_FLUC_SIGNED_MO		( 					),		//	no use
		.o_IMP_FLUC_SIGNED_RO		( 					),		//	no use
		.i_ACC_SIGNED_MOVOL			( 5'd15				),		//	Melody volume level: -16...15 (SIGNED)
		.i_ACC_SIGNED_ROVOL			( 5'd15				),		//	Drum volume level  : -16...15 (SIGNED)
		.o_ACC_SIGNED_STRB			( 					),		//	no use
		.o_ACC_SIGNED_L				( sound_l_out		),		//	sound out
		.o_ACC_SIGNED_R				( sound_r_out		)		//	sound out
	);
endmodule
