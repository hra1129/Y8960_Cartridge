// --------------------------------------------------------------------
//	IKASCC Wrapper
// ====================================================================
//	2026/01/22 t.hara
//	2026/10/19 Stereo panning (9900h-9904h: Ch.A-E PAN)
//	2026/10/20 PAN also at 7900h-7904h in RAM Mode=1
//	2026/11/04 Posted write (a memory write cycle may end before the enable)
//	2026/11/04 Read timing for the posedge wave RAM (FAST_CLOCK)
// --------------------------------------------------------------------

module scc (
	input			reset_n,
	input			clk,			//	base clock
	input			enable,			//	3.579545MHz
	input			bus_cs,
	input	[15:0]	bus_address,
	input			bus_write,
	output			bus_ready,
    input           bus_valid,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	output			scc_memory_cs,	//	active low: 4000h-BFFFh mapper memory (not SCC registers)
	output	[18:13]	scc_ma,
	output	[10:0]	sound_l_out,	//	signed
	output	[10:0]	sound_r_out		//	signed
);
	wire			w_cs;
	wire			w_live;
	wire			w_wr_accept;
	wire			w_core_active;
	wire			w_core_write;
	wire	[15:0]	w_core_address;
	wire	[7:0]	w_core_wdata;
	wire			w_core_cs;
	wire			w_db_oe;
	reg				ff_rd_seen;
	reg				ff_wr_pending;
	reg				ff_wr_gap;
	reg		[15:0]	ff_wr_address;
	reg		[7:0]	ff_wr_wdata;
	wire			w_wr_n;
	wire			w_rd_n;
	wire	[39:0]	w_sound_ch;
	wire	[7:0]	w_db;
	wire			w_sccreg_en;
	wire			w_pan_address;
	wire			w_pan_window;
	wire			w_pan_write;

	reg		[7:0]	ff_pan_a;
	reg		[7:0]	ff_pan_b;
	reg		[7:0]	ff_pan_c;
	reg		[7:0]	ff_pan_d;
	reg		[7:0]	ff_pan_e;

	reg		[3:0]	ff_step;
	reg		[7:0]	w_pan;
	reg signed	[7:0]	w_ch_sound;
	reg signed	[7:0]	ff_sample;
	reg				ff_side_r;
	reg				ff_first;
	reg				ff_last;
	wire	[8:0]	w_gain_l;
	wire	[8:0]	w_gain_r;
	wire	[8:0]	w_gain;
	wire signed	[17:0]	w_product;
	reg signed	[19:0]	ff_acc_l;
	reg signed	[19:0]	ff_acc_r;
	wire signed	[19:0]	w_sum;
	reg		[10:0]	ff_sound_l;
	reg		[10:0]	ff_sound_r;

	// --------------------------------------------------------------------
	//	Address decode
	// --------------------------------------------------------------------
	assign w_cs			= bus_cs & bus_valid;

	//	Posted write
	//	/WR of a memory write cycle is only about 280ns, and msx_slot starts the
	//	access about 100ns after /WR. Waiting for enable (every 280ns) could miss
	//	the end of the cycle, so writes are accepted immediately and held until
	//	IKASCC samples them at the next enable.
	//	IKASCC detects a write by the falling edge of /CS sampled at enable, so
	//	/CS must be inactive at the enable after a write (ff_wr_gap). A write
	//	accepted in that period is presented at the following enable.
	assign w_live		= w_cs & ~ff_wr_pending;
	assign w_wr_accept	= w_live & bus_write;
	//	Read: the wave RAM is a posedge RAM, so the read data is valid from the
	//	2nd clock of the access (ff_rd_seen).
	assign bus_ready	= w_wr_accept | (w_live & ~bus_write & ff_rd_seen);
	assign bus_rdata_en	= w_db_oe & ff_rd_seen;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_rd_seen		<= 1'b0;
		end
		else begin
			ff_rd_seen		<= w_live & ~bus_write;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_wr_pending	<= 1'b0;
			ff_wr_gap		<= 1'b0;
		end
		else begin
			if( enable && !ff_wr_gap ) begin
				ff_wr_pending	<= 1'b0;
			end
			else if( w_wr_accept ) begin
				ff_wr_pending	<= 1'b1;
			end

			if( enable ) begin
				ff_wr_gap		<= ~ff_wr_gap & (ff_wr_pending | w_wr_accept);
			end
		end
	end

	always @( posedge clk ) begin
		if( w_wr_accept ) begin
			ff_wr_address	<= bus_address;
			ff_wr_wdata		<= bus_wdata;
		end
	end

	assign w_core_active	= ff_wr_pending | w_live;
	assign w_core_write		= ff_wr_pending | bus_write;
	assign w_core_address	= ff_wr_pending ? ff_wr_address : bus_address;
	assign w_core_wdata		= ff_wr_pending ? ff_wr_wdata   : bus_wdata;

	assign w_wr_n		= ~w_core_write;
	assign w_rd_n		= w_core_write;

	//	PAN registers at x900h-x904h in the SCC register window
	//	(BANK2: 9900h-9904h, RAM Mode=1 BANK1: 7900h-7904h). Writes are not passed
	//	to IKASCC, because IKASCC decodes only A7-A0 and would treat them as x800h-x804h.
	assign w_pan_address	= (w_core_address[10:8] == 3'b001) && (w_core_address[7:3] == 5'd0) && (w_core_address[2:0] <= 3'd4);
	assign w_pan_window		= w_core_active & w_core_write & w_sccreg_en & w_pan_address;
	assign w_pan_write		= w_pan_window & enable & ~ff_wr_gap;
	//	/CS stays combinational for o_ROMCS_n (scc_bank), but is forced inactive
	//	for a write at the gap enable.
	assign w_core_cs		= w_core_active & ~w_pan_window & ~(enable & ff_wr_gap & w_core_write);

	// --------------------------------------------------------------------
	//	IKASCC body
	// --------------------------------------------------------------------
	IKASCC #(
		.IMPL_TYPE				( 0						),
		.RAM_BLOCK				( 1						)
	) u_ikascc (
		.i_EMUCLK				( clk					),
		.i_MCLK_PCEN_n			( ~enable				),		//	negative logic
		.i_RST_n				( reset_n				),
		.i_CS_n					( ~w_core_cs			),
		.i_RD_n					( w_rd_n				),
		.i_WR_n					( w_wr_n				),
		.i_ABLO					( w_core_address[7:0]	),
		.i_ABHI					( w_core_address[15:11]	),
		.i_DB					( w_core_wdata			),
		.o_DB					( w_db					),
		.o_DB_OE				( w_db_oe				),
		.o_ROMCS_n				( scc_memory_cs			),
		.o_ROMADDR				( scc_ma				),
		.o_SOUND				( 						),
		.o_SOUND_CH				( w_sound_ch			),
		.o_SCCREG_EN			( w_sccreg_en			),
		.o_TEST					(						)
	);

	//	bus_rdata of all devices are ANDed at the top level.
	assign bus_rdata	= bus_rdata_en ? w_db : 8'hFF;

	// --------------------------------------------------------------------
	//	PAN registers: 1 = left, 128 = center, 255 = right
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_pan_a	<= 8'd128;
			ff_pan_b	<= 8'd128;
			ff_pan_c	<= 8'd128;
			ff_pan_d	<= 8'd128;
			ff_pan_e	<= 8'd128;
		end
		else if( w_pan_write ) begin
			case( w_core_address[2:0] )
			3'd0:		ff_pan_a <= w_core_wdata;
			3'd1:		ff_pan_b <= w_core_wdata;
			3'd2:		ff_pan_c <= w_core_wdata;
			3'd3:		ff_pan_d <= w_core_wdata;
			default:	ff_pan_e <= w_core_wdata;
			endcase
		end
	end

	// --------------------------------------------------------------------
	//	Time-multiplexed panning with one multiplier
	//	step 0-9: { channel A-E, L/R }
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_step <= 4'd0;
		end
		else if( ff_step == 4'd9 ) begin
			ff_step <= 4'd0;
		end
		else begin
			ff_step <= ff_step + 4'd1;
		end
	end

	always @(*) begin
		case( ff_step[3:1] )
		3'd0:		begin w_pan = ff_pan_a; w_ch_sound = w_sound_ch[ 7: 0]; end
		3'd1:		begin w_pan = ff_pan_b; w_ch_sound = w_sound_ch[15: 8]; end
		3'd2:		begin w_pan = ff_pan_c; w_ch_sound = w_sound_ch[23:16]; end
		3'd3:		begin w_pan = ff_pan_d; w_ch_sound = w_sound_ch[31:24]; end
		default:	begin w_pan = ff_pan_e; w_ch_sound = w_sound_ch[39:32]; end
		endcase
	end

	pan_lut u_pan_lut (
		.i_clk					( clk					),
		.i_pan					( w_pan					),
		.o_gain_l				( w_gain_l				),
		.o_gain_r				( w_gain_r				)
	);

	//	Align the sample with the registered pan_lut output.
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_sample	<= 8'sd0;
			ff_side_r	<= 1'b0;
			ff_first	<= 1'b0;
			ff_last		<= 1'b0;
		end
		else begin
			ff_sample	<= w_ch_sound;
			ff_side_r	<= ff_step[0];
			ff_first	<= (ff_step[3:1] == 3'd0);
			ff_last		<= (ff_step[3:1] == 3'd4);
		end
	end

	assign w_gain		= ff_side_r ? w_gain_r : w_gain_l;
	assign w_product	= ff_sample * $signed( { 1'b0, w_gain } );
	assign w_sum		= (ff_first ? 20'sd0 : (ff_side_r ? ff_acc_r : ff_acc_l)) + w_product;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_acc_l	<= 20'sd0;
			ff_acc_r	<= 20'sd0;
			ff_sound_l	<= 11'd0;
			ff_sound_r	<= 11'd0;
		end
		else if( ff_side_r ) begin
			ff_acc_r	<= w_sum;
			if( ff_last ) begin
				ff_sound_r	<= w_sum[18:8];
			end
		end
		else begin
			ff_acc_l	<= w_sum;
			if( ff_last ) begin
				ff_sound_l	<= w_sum[18:8];
			end
		end
	end

	assign sound_l_out	= ff_sound_l;
	assign sound_r_out	= ff_sound_r;
endmodule