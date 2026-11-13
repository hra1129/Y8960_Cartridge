// --------------------------------------------------------------------
//	ADPCM Wrapper (Y8950 / MSX-AUDIO compatible register interface)
// ====================================================================
//	2026/02/19 t.hara
//	2026/11/01 t.hara  Y8950 compatible playback start, address units,
//	                   status flags, memory read/write and R#08.
//	2026/11/03 t.hara  ADPCM synthesis from CPU (R#07 = 80h).
// --------------------------------------------------------------------

module adpcm (
	input			clk,
	input			reset_n,
	input			enable,
	input			cen55,
	input			bus_cs,
	input			bus_address,
	input			bus_write,
	input			bus_valid,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	input	[7:0]	opl2_status,
	output			adpcm_irq,
	output	[15:0]	adpcm_sound_out_l,			//	signed
	output	[15:0]	adpcm_sound_out_r,			//	signed
	//	ADPCM Memory I/F
	output			adpcm_write,
	output			adpcm_valid,
	input			adpcm_ready,
	output	[23:0]	adpcm_address,
	output	[ 7:0]	adpcm_wdata,
	input	[ 7:0]	adpcm_rdata,
	input			adpcm_rdata_en
);
	localparam		[1:0]	c_owner_core		= 2'd0;
	localparam		[1:0]	c_owner_prefetch	= 2'd1;
	localparam		[1:0]	c_owner_cpu_write	= 2'd2;

	//	Registers
	reg		[7:0]	ff_reg_select;
	reg				reg_mask_eos;				//	04h [4]
	reg				reg_mask_buf_rdy;			//	04h [3]
	reg				reg_start;					//	07h [7]
	reg				reg_record;					//	07h [6]
	reg				reg_memory_data;			//	07h [5]
	reg				reg_repeat;					//	07h [4]
	reg				reg_sp_off;					//	07h [3]
	reg				reg_64k;					//	08h [1]
	reg				reg_rom;					//	08h [0]
	reg		[15:0]	reg_start_address;			//	09h, 0Ah (4 bytes unit)
	reg		[15:0]	reg_stop_address;			//	0Bh, 0Ch (4 bytes unit)
	reg		[7:0]	reg_adpcm_data;				//	0Fh (last written value)
	reg		[15:0]	reg_delta_n;				//	10h, 11h
	reg		[7:0]	reg_envelope_control;		//	12h
	reg		[7:0]	reg_pan;					//	FFh

	//	Status flags and CPU memory access
	reg				ff_eos;
	reg				ff_buf_rdy;
	reg				ff_start_pulse;
	reg		[18:0]	ff_mem_ptr;					//	byte address
	reg		[1:0]	ff_read_delay;
	reg				ff_prefetch_valid;
	reg		[7:0]	ff_prefetch_data;
	reg				ff_cpu_write_pending;
	reg		[17:0]	ff_cpu_write_address;
	reg		[7:0]	ff_cpu_write_data;
	reg		[7:0]	ff_rdata;
	reg				ff_rdata_en;

	//	ADPCM memory interface
	reg				ff_mem_valid;
	reg				ff_mem_write;
	reg				ff_mem_wait_data;
	reg		[1:0]	ff_mem_owner;
	reg		[17:0]	ff_mem_address;
	reg		[7:0]	ff_mem_wdata;
	reg				ff_core_pending;
	reg		[17:0]	ff_core_address;
	reg		[7:0]	ff_core_data;

	wire			w_access;
	wire			w_select_write;
	wire			w_reg_write;
	wire			w_reg_read;
	wire			w_status_read;
	wire			w_data_read;
	wire			w_mode_idle;
	wire			w_mode_mem_write;
	wire			w_mode_mem_read;
	wire			w_mode_play;
	wire			w_mode_cpu_synth;
	wire			w_playing;
	wire			w_buf_rdy_hold;
	wire	[18:0]	w_start_ptr;
	wire	[18:0]	w_stop_ptr;
	wire			w_ptr_over;
	wire	[18:0]	w_write_ptr;
	wire			w_eos_visible;
	wire			w_buf_rdy_visible;
	wire	[7:0]	w_status;
	wire			w_mem_idle;
	wire			w_need_prefetch;
	wire			w_issue_cpu_write;
	wire			w_issue_core;
	wire			w_issue_prefetch;
	wire			w_prefetch_busy;
	wire			w_prefetch_done;
	wire			w_cpu_write_done;
	wire			w_core_eos;
	wire			w_adpcm_oe_n;
	wire			w_core_nibble_sel;
	wire			w_core_chon;
	wire			w_cpu_data_follow;
	wire			w_cpu_data_used;
	wire			w_core_enable;
	wire	[23:0]	w_core_address;
	wire	[15:0]	w_core_pcm;
	wire	[15:0]	w_pcm;
	wire	[8:0]	w_pan_gain_l;
	wire	[8:0]	w_pan_gain_r;
	wire	[8:0]	w_pan_gain;
	wire signed [25:0]	w_pan_product;
	reg				ff_pan_phase;				//	0: Lch, 1: Rch
	reg		[15:0]	ff_pan_out_l;
	reg		[15:0]	ff_pan_out_r;

	function [17:0] mask_address;
		input	[18:0]	address;
		input			is_64k;
		begin
			mask_address = is_64k ? { 2'd0, address[15:0] } : address[17:0];
		end
	endfunction

	// ---------------------------------------------------------
	//	Decode
	// ---------------------------------------------------------
	assign w_access				= bus_cs & bus_valid;
	assign w_select_write		= w_access &  bus_write & ~bus_address;
	assign w_reg_write			= w_access &  bus_write &  bus_address;
	assign w_reg_read			= w_access & ~bus_write &  bus_address;
	assign w_status_read		= w_access & ~bus_write & ~bus_address;
	assign w_data_read			= w_reg_read & (ff_reg_select == 8'h0F);

	//	R#07 bit7-5 (START, REC, MEMORY DATA)
	assign w_mode_idle			= ~reg_start & ~reg_record & ~reg_memory_data;
	assign w_mode_mem_write		= ~reg_start &  reg_record &  reg_memory_data;
	assign w_mode_mem_read		= ~reg_start & ~reg_record &  reg_memory_data;
	assign w_mode_play			=  reg_start & ~reg_record &  reg_memory_data;
	assign w_mode_cpu_synth		=  reg_start & ~reg_record & ~reg_memory_data;
	assign w_playing			=  reg_start & ~reg_record;
	//	BUF_RDY stays 1 in "no function" and memory transfer modes
	assign w_buf_rdy_hold		= w_mode_idle | (~reg_start & reg_memory_data);

	assign w_start_ptr			= { 1'b0, reg_start_address, 2'b00 };
	assign w_stop_ptr			= { 1'b0, reg_stop_address,  2'b11 };
	assign w_ptr_over			= (ff_mem_ptr > w_stop_ptr);
	assign w_write_ptr			= (ff_read_delay != 2'd0) ? w_start_ptr : ff_mem_ptr;

	//	Status register: IRQ, T1, T2, EOS, BUF_RDY, 1, 1, PCM_BSY
	assign w_eos_visible		= ff_eos     & ~reg_mask_eos;
	assign w_buf_rdy_visible	= ff_buf_rdy & ~reg_mask_buf_rdy;
	assign adpcm_irq			= w_eos_visible | w_buf_rdy_visible;
	assign w_status				= { opl2_status[7] | adpcm_irq, opl2_status[6:5],
									w_eos_visible, w_buf_rdy_visible, 2'b11, reg_start };

	// ---------------------------------------------------------
	//	JT ADPCM (TypeB) body
	// ---------------------------------------------------------
	assign w_core_enable = enable | ~reset_n;

	jt10_adpcm_drvB u_adpcm (
		.rst_n			( reset_n							),
		.clk			( clk								),
		.cen			( w_core_enable						),
		.cen55			( cen55								),
		.acmd_on_b		( w_playing							),
		.acmd_rep_b		( reg_repeat						),
		.acmd_rst_b		( 1'b0								),
		.acmd_up_b		( ff_start_pulse					),
		.cpu_mode		( ~reg_memory_data					),
		.alr_b			( 2'b11								),		//	always enable
		.astart_b		( reg_start_address					),
		.aend_b			( reg_stop_address					),
		.adeltan_b		( reg_delta_n						),
		.aeg_b			( reg_envelope_control				),
		.flag			( w_core_eos						),		//	one clock pulse
		.clr_flag		( 1'b1								),
		.addr			( w_core_address					),
		.data			( ff_core_data						),
		.roe_n			( w_adpcm_oe_n						),
		.nibble_sel		( w_core_nibble_sel					),
		.chon			( w_core_chon						),
		.pcm55_l		( w_core_pcm						),
		.pcm55_r		(									)
	);

	//	ADPCM synthesis from CPU (R#07 = 80h):
	//	While the next nibble to decode is an upper nibble, the decoder data
	//	follows R#0F. The byte is fixed when the upper nibble is decoded,
	//	and BUF_RDY is set to request the next byte (same as Y8950).
	assign w_cpu_data_follow	= w_mode_cpu_synth & (~w_core_chon | ~w_core_nibble_sel);
	assign w_cpu_data_used		= w_mode_cpu_synth & ~w_adpcm_oe_n & w_core_chon & w_core_nibble_sel;

	//	Y8950: no output while not playing, or when SP-OFF is set.
	assign w_pcm				= (reg_sp_off | ~w_playing) ? 16'd0 : w_core_pcm;

	// ---------------------------------------------------------
	//	Stereo panning (register FFh)
	// ---------------------------------------------------------
	pan_lut u_pan_lut (
		.i_clk			( clk								),
		.i_pan			( reg_pan							),
		.o_gain_l		( w_pan_gain_l						),
		.o_gain_r		( w_pan_gain_r						)
	);

	//	One multiplier is shared by Lch and Rch alternately.
	assign w_pan_gain			= ff_pan_phase ? w_pan_gain_r : w_pan_gain_l;
	assign w_pan_product		= $signed( w_pcm ) * $signed( { 1'b0, w_pan_gain } );

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_pan_phase	<= 1'b0;
			ff_pan_out_l	<= 16'd0;
			ff_pan_out_r	<= 16'd0;
		end
		else begin
			ff_pan_phase	<= ~ff_pan_phase;
			if( ff_pan_phase ) begin
				ff_pan_out_r	<= w_pan_product[23:8];
			end
			else begin
				ff_pan_out_l	<= w_pan_product[23:8];
			end
		end
	end

	assign adpcm_sound_out_l	= ff_pan_out_l;
	assign adpcm_sound_out_r	= ff_pan_out_r;

	// ---------------------------------------------------------
	//	Registers, status flags and CPU memory access
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_reg_select			<= 8'd0;
			reg_mask_eos			<= 1'b1;
			reg_mask_buf_rdy		<= 1'b1;
			reg_start				<= 1'b0;
			reg_record				<= 1'b0;
			reg_memory_data			<= 1'b0;
			reg_repeat				<= 1'b0;
			reg_sp_off				<= 1'b0;
			reg_64k					<= 1'b0;
			reg_rom					<= 1'b0;
			reg_start_address		<= 16'd0;
			reg_stop_address		<= 16'd0;
			reg_adpcm_data			<= 8'd0;
			reg_delta_n				<= 16'd0;
			reg_envelope_control	<= 8'd255;
			reg_pan					<= 8'd128;
			ff_eos					<= 1'b0;
			ff_buf_rdy				<= 1'b1;
			ff_start_pulse			<= 1'b0;
			ff_mem_ptr				<= 19'd0;
			ff_read_delay			<= 2'd0;
			ff_prefetch_valid		<= 1'b0;
			ff_prefetch_data		<= 8'd0;
			ff_cpu_write_pending	<= 1'b0;
			ff_cpu_write_address	<= 18'd0;
			ff_cpu_write_data		<= 8'd0;
			ff_rdata				<= 8'hFF;
			ff_rdata_en				<= 1'b0;
		end
		else begin
			ff_start_pulse	<= 1'b0;
			ff_rdata_en		<= w_status_read | w_reg_read;

			//	Memory side events
			if( w_issue_cpu_write ) begin
				ff_cpu_write_pending	<= 1'b0;
			end
			if( w_cpu_write_done ) begin
				ff_buf_rdy				<= 1'b1;
			end
			if( w_mode_mem_read && !ff_prefetch_valid && !w_ptr_over ) begin
				if( reg_rom ) begin
					//	ROM bank is not readable: returns 0
					ff_prefetch_data	<= 8'd0;
					ff_prefetch_valid	<= 1'b1;
					ff_buf_rdy			<= 1'b1;
				end
				else if( w_prefetch_done && (ff_mem_address == mask_address( ff_mem_ptr, reg_64k )) ) begin
					ff_prefetch_data	<= adpcm_rdata;
					ff_prefetch_valid	<= 1'b1;
					ff_buf_rdy			<= 1'b1;
				end
			end

			//	ADPCM synthesis from CPU: the byte in R#0F has been used.
			//	A R#0F write in the same clock clears BUF_RDY below.
			if( w_cpu_data_used ) begin
				ff_buf_rdy				<= 1'b1;
			end

			//	End of sample in playback mode
			if( w_core_eos ) begin
				ff_eos					<= 1'b1;
				if( !reg_repeat ) begin
					reg_start			<= 1'b0;
					reg_record			<= 1'b0;
					reg_memory_data		<= 1'b0;
					reg_repeat			<= 1'b0;
					reg_sp_off			<= 1'b0;
				end
			end

			//	CPU access
			if( w_select_write ) begin
				ff_reg_select	<= bus_wdata;
			end
			else if( w_reg_write ) begin
				case( ff_reg_select )
				8'h04: begin
					if( bus_wdata[7] ) begin
						//	IRQ RESET: clear all flags (masks are kept)
						ff_eos				<= 1'b0;
						ff_buf_rdy			<= w_buf_rdy_hold;
					end
					else begin
						reg_mask_eos		<= bus_wdata[4];
						reg_mask_buf_rdy	<= bus_wdata[3];
						if( bus_wdata[4] ) begin
							ff_eos			<= 1'b0;
						end
						if( bus_wdata[3] ) begin
							ff_buf_rdy		<= w_buf_rdy_hold;
						end
						else if( w_buf_rdy_hold ) begin
							ff_buf_rdy		<= 1'b1;
						end
					end
				end
				8'h07: begin
					ff_prefetch_valid	<= 1'b0;
					if( bus_wdata[0] ) begin
						//	RESET
						reg_start		<= 1'b0;
						reg_record		<= 1'b0;
						reg_memory_data	<= 1'b0;
						reg_repeat		<= 1'b0;
						reg_sp_off		<= 1'b0;
						ff_mem_ptr		<= 19'd0;
					end
					else begin
						reg_start		<= bus_wdata[7];
						reg_record		<= bus_wdata[6];
						reg_memory_data	<= bus_wdata[5];
						reg_repeat		<= bus_wdata[4];
						reg_sp_off		<= bus_wdata[3];
						ff_start_pulse	<= bus_wdata[7];
						if( bus_wdata[5] ) begin
							ff_mem_ptr		<= w_start_ptr;
							ff_read_delay	<= 2'd2;
							if( !bus_wdata[7] ) begin
								ff_buf_rdy	<= 1'b1;
							end
						end
						else begin
							ff_mem_ptr		<= 19'd0;
						end
					end
				end
				8'h08: begin
					reg_64k					<= bus_wdata[1];
					reg_rom					<= bus_wdata[0];
				end
				8'h09: begin
					reg_start_address[7:0]	<= bus_wdata;
				end
				8'h0A: begin
					reg_start_address[15:8]	<= bus_wdata;
				end
				8'h0B: begin
					reg_stop_address[7:0]	<= bus_wdata;
				end
				8'h0C: begin
					reg_stop_address[15:8]	<= bus_wdata;
				end
				8'h0F: begin
					reg_adpcm_data			<= bus_wdata;
					if( w_mode_mem_write ) begin
						ff_read_delay		<= 2'd0;
						if( w_write_ptr <= w_stop_ptr ) begin
							if( w_write_ptr == w_stop_ptr ) begin
								//	Last byte: EOS, and the pointer wraps to the start address.
								ff_eos		<= 1'b1;
								ff_mem_ptr	<= w_start_ptr;
							end
							else begin
								ff_mem_ptr	<= w_write_ptr + 19'd1;
							end
							if( reg_rom ) begin
								ff_buf_rdy	<= 1'b1;
							end
							else begin
								ff_buf_rdy				<= 1'b0;
								ff_cpu_write_pending	<= 1'b1;
								ff_cpu_write_address	<= mask_address( w_write_ptr, reg_64k );
								ff_cpu_write_data		<= bus_wdata;
							end
						end
					end
					else if( w_mode_cpu_synth ) begin
						ff_buf_rdy			<= 1'b0;
					end
				end
				8'h10: begin
					reg_delta_n[7:0]		<= bus_wdata;
				end
				8'h11: begin
					reg_delta_n[15:8]		<= bus_wdata;
				end
				8'h12: begin
					reg_envelope_control	<= bus_wdata;
				end
				8'hFF: begin
					reg_pan					<= bus_wdata;
				end
				default: begin
					//	hold
				end
				endcase
			end
			else if( w_status_read ) begin
				ff_rdata	<= w_status;
			end
			else if( w_data_read ) begin
				if( !w_mode_mem_read ) begin
					ff_rdata	<= 8'h00;
				end
				else if( ff_read_delay != 2'd0 ) begin
					//	Two dummy reads after setting R#07
					ff_rdata		<= reg_adpcm_data;
					ff_read_delay	<= ff_read_delay - 2'd1;
					ff_buf_rdy		<= 1'b1;
				end
				else if( w_ptr_over ) begin
					ff_rdata	<= 8'h00;
					ff_eos		<= 1'b1;
				end
				else begin
					ff_rdata			<= ff_prefetch_data;
					ff_mem_ptr			<= ff_mem_ptr + 19'd1;
					ff_prefetch_valid	<= 1'b0;
					//	BUF_RDY returns to 1 when the next data has been prefetched.
					ff_buf_rdy			<= (ff_mem_ptr == w_stop_ptr);
				end
			end
			else if( w_reg_read ) begin
				ff_rdata	<= 8'hFF;
			end
		end
	end

	assign bus_rdata	= ff_rdata;
	assign bus_rdata_en	= ff_rdata_en;

	// ---------------------------------------------------------
	//	ADPCM memory arbitration (CPU write > playback > prefetch)
	// ---------------------------------------------------------
	assign w_mem_idle			= ~ff_mem_valid & ~ff_mem_wait_data;
	assign w_prefetch_busy		= (ff_mem_valid | ff_mem_wait_data) & (ff_mem_owner == c_owner_prefetch);
	assign w_need_prefetch		= w_mode_mem_read & ~reg_rom & ~ff_prefetch_valid & ~w_prefetch_busy & ~w_ptr_over;
	assign w_issue_cpu_write	= w_mem_idle & ff_cpu_write_pending;
	assign w_issue_core			= w_mem_idle & ~ff_cpu_write_pending & ff_core_pending;
	assign w_issue_prefetch		= w_mem_idle & ~ff_cpu_write_pending & ~ff_core_pending & w_need_prefetch;
	assign w_prefetch_done		= ff_mem_wait_data & adpcm_rdata_en & (ff_mem_owner == c_owner_prefetch);
	assign w_cpu_write_done		= ff_mem_valid & adpcm_ready & ff_mem_write;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_mem_valid		<= 1'b0;
			ff_mem_write		<= 1'b0;
			ff_mem_wait_data	<= 1'b0;
			ff_mem_owner		<= c_owner_core;
			ff_mem_address		<= 18'd0;
			ff_mem_wdata		<= 8'd0;
			ff_core_pending		<= 1'b0;
			ff_core_address		<= 18'd0;
			ff_core_data		<= 8'd0;
		end
		else begin
			if( !w_adpcm_oe_n && w_mode_play ) begin
				ff_core_pending	<= 1'b1;
				ff_core_address	<= mask_address( w_core_address[18:0], reg_64k );
			end
			else if( w_issue_core ) begin
				ff_core_pending	<= 1'b0;
			end

			if( ff_mem_valid ) begin
				if( adpcm_ready ) begin
					ff_mem_valid		<= 1'b0;
					ff_mem_wait_data	<= ~ff_mem_write;
				end
			end
			else if( ff_mem_wait_data ) begin
				if( adpcm_rdata_en ) begin
					ff_mem_wait_data	<= 1'b0;
					if( ff_mem_owner == c_owner_core ) begin
						ff_core_data	<= adpcm_rdata;
					end
				end
			end
			else if( w_issue_cpu_write ) begin
				ff_mem_valid		<= 1'b1;
				ff_mem_write		<= 1'b1;
				ff_mem_owner		<= c_owner_cpu_write;
				ff_mem_address		<= ff_cpu_write_address;
				ff_mem_wdata		<= ff_cpu_write_data;
			end
			else if( w_issue_core ) begin
				if( reg_rom ) begin
					ff_core_data		<= 8'd0;
				end
				else begin
					ff_mem_valid		<= 1'b1;
					ff_mem_write		<= 1'b0;
					ff_mem_owner		<= c_owner_core;
					ff_mem_address		<= ff_core_address;
				end
			end
			else if( w_issue_prefetch ) begin
				ff_mem_valid		<= 1'b1;
				ff_mem_write		<= 1'b0;
				ff_mem_owner		<= c_owner_prefetch;
				ff_mem_address		<= mask_address( ff_mem_ptr, reg_64k );
			end

			if( w_cpu_data_follow ) begin
				ff_core_data		<= reg_adpcm_data;
			end
		end
	end

	assign adpcm_write		= ff_mem_write;
	assign adpcm_valid		= ff_mem_valid;
	assign adpcm_address	= { 6'd0, ff_mem_address };
	assign adpcm_wdata		= ff_mem_wdata;
endmodule
