// --------------------------------------------------------------------
//	IKAOPM Wrapper
// ====================================================================
//	2026/10/20 t.hara
// --------------------------------------------------------------------
//	I/O port        : 7Eh = Register Address, 7Fh = Register Data / Status(read)
//	Memory mapped IO: 7FFBh = Register Address, 7FFCh = Register Data (write only)
//
//	YM2151 drops a write that arrives while the previous one is still being
//	processed. Writes are queued here and fed to IKAOPM one by one, waiting
//	for each to be finished. While the queue is full, /WAIT is asserted.
// --------------------------------------------------------------------

module opm (
	input			clk,
	input			reset_n,
	input			enable,					//	3.579545MHz (phiM) clock enable
	input			bus_cs,
	input			bus_io,					//	1: I/O 7Eh-7Fh, 0: Memory 7FFBh-7FFCh
	input			bus_address,			//	bus_address[0]
	input			bus_write,
	input			bus_valid,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	output			wait_n,
	output			intr_n,
	output	[15:0]	sound_l_out,			//	signed
	output	[15:0]	sound_r_out				//	signed
);
	//	Hold-off time after each write, in phiM cycles.
	//	Address: request is taken within about 4 phiM.
	//	Data   : request (about 4 phiM) + busy period (64 phiM) + margin.
	localparam		[6:0]	c_address_holdoff	= 7'd8;
	localparam		[6:0]	c_data_holdoff		= 7'd80;
	localparam		[2:0]	c_pulse_width		= 3'd4;

	wire			w_a0;
	wire			w_capture;
	wire			w_enqueue;
	wire			w_dequeue;
	wire			w_full;
	wire			w_busy;
	wire			w_core_enable;
	wire	[7:0]	w_status;
	reg				ff_bus_seen = 1'b0;
	reg		[4:0]	ff_queue_count = 5'd0;
	reg		[3:0]	ff_write_pointer = 4'd0;
	reg		[3:0]	ff_read_pointer = 4'd0;
	reg		[8:0]	ff_queue [0:15];
	reg		[2:0]	ff_pulse = 3'd0;
	reg		[6:0]	ff_holdoff = c_data_holdoff;
	reg				ff_cs_n = 1'b1;
	reg				ff_a0 = 1'b0;
	reg		[7:0]	ff_wdata = 8'd0;
	reg		[7:0]	ff_rdata = 8'hFF;
	reg				ff_rdata_en = 1'b0;

	//	7Eh(A0=0)/7Fh(A0=1), 7FFBh(A0=0)/7FFCh(A0=1)
	assign w_a0			= bus_io ? bus_address : ~bus_address;

	// --------------------------------------------------------------------
	//	Bus request queue
	// --------------------------------------------------------------------
	assign w_full		= (ff_queue_count == 5'd16);
	assign w_capture	= bus_cs && bus_valid && !ff_bus_seen && !(bus_write && w_full);
	assign w_enqueue	= w_capture && bus_write;
	assign w_dequeue	= (ff_queue_count != 5'd0) && (ff_pulse == 3'd0) && (ff_holdoff == 7'd0);
	assign bus_ready	= w_capture;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_bus_seen			<= 1'b0;
			ff_queue_count		<= 5'd0;
			ff_write_pointer	<= 4'd0;
			ff_read_pointer		<= 4'd0;
		end
		else begin
			if( !bus_cs || !bus_valid ) begin
				ff_bus_seen <= 1'b0;
			end
			else if( w_capture ) begin
				ff_bus_seen <= 1'b1;
			end

			if( w_enqueue ) begin
				ff_queue[ff_write_pointer]	<= { w_a0, bus_wdata };
				ff_write_pointer			<= ff_write_pointer + 4'd1;
			end

			if( w_dequeue ) begin
				ff_read_pointer <= ff_read_pointer + 4'd1;
			end

			case( { w_enqueue, w_dequeue } )
				2'b01:   ff_queue_count <= ff_queue_count - 5'd1;
				2'b10:   ff_queue_count <= ff_queue_count + 5'd1;
				default: ff_queue_count <= ff_queue_count;
			endcase
		end
	end

	// --------------------------------------------------------------------
	//	IKAOPM write sequencer
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_pulse	<= 3'd0;
			//	Also gives IKAOPM time to leave its reset state.
			ff_holdoff	<= c_data_holdoff;
			ff_cs_n		<= 1'b1;
			ff_a0		<= 1'b0;
			ff_wdata	<= 8'd0;
		end
		else if( w_dequeue ) begin
			ff_pulse	<= c_pulse_width;
			ff_holdoff	<= ff_queue[ff_read_pointer][8] ? c_data_holdoff : c_address_holdoff;
			ff_cs_n		<= 1'b0;
			ff_a0		<= ff_queue[ff_read_pointer][8];
			ff_wdata	<= ff_queue[ff_read_pointer][7:0];
		end
		else if( ff_pulse != 3'd0 ) begin
			ff_pulse	<= ff_pulse - 3'd1;
			if( ff_pulse == 3'd1 ) begin
				ff_cs_n	<= 1'b1;
			end
		end
		else if( enable && (ff_holdoff != 7'd0) ) begin
			ff_holdoff	<= ff_holdoff - 7'd1;
		end
	end

	assign w_busy		= (ff_queue_count != 5'd0) || (ff_pulse != 3'd0) || (ff_holdoff != 7'd0);
	assign wait_n		= ~w_full;

	// --------------------------------------------------------------------
	//	Status read (I/O 7Fh only)
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_rdata	<= 8'hFF;
			ff_rdata_en	<= 1'b0;
		end
		else if( w_capture && !bus_write && bus_io && w_a0 ) begin
			ff_rdata	<= w_status | { w_busy, 7'd0 };
			ff_rdata_en	<= 1'b1;
		end
		else begin
			ff_rdata	<= 8'hFF;
			ff_rdata_en	<= 1'b0;
		end
	end

	assign bus_rdata	= ff_rdata;
	assign bus_rdata_en	= ff_rdata_en;

	// --------------------------------------------------------------------
	//	IKAOPM body
	// --------------------------------------------------------------------
	assign w_core_enable = enable | ~reset_n;

	IKAOPM #(
		.FULLY_SYNCHRONOUS		( 1					),		//	use DFF only
		.FAST_RESET				( 1					),		//	speed up reset
		.USE_BRAM				( 0					)
	) u_ikaopm (
		.i_EMUCLK				( clk				),
		.i_phiM_PCEN_n			( ~w_core_enable	),
		.i_IC_n					( reset_n			),
		.o_phi1					( 					),		//	no use
		.i_CS_n					( ff_cs_n			),
		.i_RD_n					( 1'b1				),		//	o_D is used directly as the status
		.i_WR_n					( ff_cs_n			),
		.i_A0					( ff_a0				),
		.i_D					( ff_wdata			),
		.o_D					( w_status			),
		.o_D_OE					( 					),		//	no use
		.o_CT2					( 					),		//	no use
		.o_CT1					( 					),		//	no use
		.o_IRQ_n				( intr_n			),
		.o_SH1					( 					),		//	no use
		.o_SH2					( 					),		//	no use
		.o_SO					( 					),		//	no use
		.o_EMU_R_SAMPLE			( 					),		//	no use
		.o_EMU_L_SAMPLE			( 					),		//	no use
		.o_EMU_R_EX				( 					),		//	no use
		.o_EMU_L_EX				( 					),		//	no use
		.o_EMU_R				( sound_r_out		),
		.o_EMU_L				( sound_l_out		)
	);
endmodule
