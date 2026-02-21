// --------------------------------------------------------------------
//	ADPCM Wrapper
// ====================================================================
//	2026/02/19 t.hara
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
	output	[15:0]	adpcm_sound_out_l,			//	signed
	output	[15:0]	adpcm_sound_out_r,			//	signed
	//	ADPCM Memory I/F
	output			adpcm_oe_n,
	output			adpcm_we_n,
	output	[23:0]	adpcm_address,
	output	[ 7:0]	adpcm_wdata,
	input	[ 7:0]	adpcm_rdata,
	input			adpcm_rdata_en
);
	reg		[7:0]	ff_reg_select;
	reg		[7:0]	ff_rdata;
	reg		[7:0]	ff_adpcm_data;
	reg				ff_bus_valid;
	reg				reg_mask_eds;				// 04h [4]
	reg				reg_mask_buffer_ready;		// 04h [3]
	reg				reg_start;					// 07h [7]
	reg				reg_record;					// 07h [6]
	reg				reg_memory_data;			// 07h [5]
	reg				reg_repeat;					// 07h [4]
	reg				reg_reset;					// 07h [0]
	reg		[15:0]	reg_start_address;			// 09h, 0Ah
	reg		[15:0]	reg_stop_address;			// 0Bh, 0Ch
	reg		[7:0]	reg_adpcm_data;				// 0Fh
	reg		[15:0]	reg_delta_n;				// 10h, 11h
	reg		[7:0]	reg_envelope_control;		// 12h
	wire			w_flag;
	wire			w_adpcm_oe_n;
	wire			w_adpcm_we_n;

	// ---------------------------------------------------------
	//	JT ADPCM (TypeB) body
	// ---------------------------------------------------------
	jt10_adpcm_drvB u_adpcm (
		.rst_n			( reset_n				),
		.clk			( clk					),
		.cen			( enable				),
		.cen55			( w_cen55				),
		.acmd_on_b		( reg_start				),
		.acmd_rep_b		( reg_repeat			),
		.acmd_rst_b		( reg_reset				),
		.acmd_up_b		( reg_record			),
		.alr_b			( 2'b11					),		//	always enable
		.astart_b		( reg_start_address		),
		.aend_b			( reg_stop_address		),
		.adeltan_b		( reg_delta_n			),
		.aeg_b			( reg_envelope_control	),
		.flag			( w_flag				),
		.clr_flag		( reg_mask_eds			),
		.addr			( adpcm_address			),
		.data			( ff_adpcm_data			),
		.roe_n			( w_adpcm_oe_n			),
		.pcm55_l		( adpcm_sound_out_l		),
		.pcm55_r		( adpcm_sound_out_r		)
	);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_reg_select			<= 8'd0;
			reg_mask_eds			<= 1'b1;
			reg_mask_buffer_ready	<= 1'b1;
			reg_start				<= 1'b0;
			reg_record				<= 1'b0;
			reg_memory_data			<= 1'b0;
			reg_repeat				<= 1'b0;
			reg_reset				<= 1'b0;
			reg_start_address		<= 16'd0;
			reg_stop_address		<= 16'd0;
			reg_delta_n				<= 16'd0;
			reg_envelope_control	<= 8'd0;
		end
		else if( bus_cs || !bus_valid ) begin
		end
		else if( bus_write ) begin
			if( !bus_address ) begin
				ff_reg_select	<= bus_wdata;
			end
			else begin
				case( ff_reg_select )
					8'h04: begin
						reg_mask_eds			<= bus_wdata[4];
						reg_mask_buffer_ready	<= bus_wdata[3];
					end
					8'h07: begin
						reg_start				<= bus_wdata[7];
						reg_record				<= bus_wdata[6];
						reg_memory_data			<= bus_wdata[5];
						reg_repeat				<= bus_wdata[4];
						reg_reset				<= bus_wdata[0];
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
				endcase
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_bus_valid <= 1'b0;
		end
		else if( bus_cs ) begin
			if( !bus_address ) begin
				//	read status
				ff_bus_valid <= bus_valid;
			end
			else begin
				//	read register
				if( ff_reg_select == 8'h0F ) begin
					//	ADPCM-DATA register
					ff_bus_valid <= adpcm_rdata_en;
				end
				else begin
					//	others
					ff_bus_valid <= bus_valid;
				end
			end
		end
		else begin
			ff_bus_valid <= 1'b0;
		end
	end

	assign w_adpcm_we_n	= 1'b1;

	assign bus_rdata	= !bus_address ? { opl2_status[7:4], w_flag, 2'b11, reg_start }:
						  (ff_reg_select == 8'h0F) ? ff_rdata : 8'hFF;
	assign bus_rdata_en	= ~bus_write & ff_bus_valid;

	assign adpcm_oe_n	= w_adpcm_oe_n;
	assign adpcm_we_n	= w_adpcm_we_n;
endmodule
