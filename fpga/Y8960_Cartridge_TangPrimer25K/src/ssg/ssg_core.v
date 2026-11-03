//
//	ssg_core.v
//	SSG core (YM2149. AY-3-8910 Compatible Processor)
//
//	Copyright (C) 2024-2026 Takayuki Hara
//
//	本ソフトウェアおよび本ソフトウェアに基づいて作成された派生物は、以下の条件を
//	満たす場合に限り、再頒布および使用が許可されます。
//
//	1.ソースコード形式で再頒布する場合、上記の著作権表示、本条件一覧、および下記
//	  免責条項をそのままの形で保持すること。
//	2.バイナリ形式で再頒布する場合、頒布物に付属のドキュメント等の資料に、上記の
//	  著作権表示、本条件一覧、および下記免責条項を含めること。
//	3.書面による事前の許可なしに、本ソフトウェアを販売、および商業的な製品や活動
//	  に使用しないこと。
//
//	本ソフトウェアは、著作権者によって「現状のまま」提供されています。著作権者は、
//	特定目的への適合性の保証、商品性の保証、またそれに限定されない、いかなる明示
//	的もしくは暗黙な保証責任も負いません。著作権者は、事由のいかんを問わず、損害
//	発生の原因いかんを問わず、かつ責任の根拠が契約であるか厳格責任であるか（過失
//	その他の）不法行為であるかを問わず、仮にそのような損害が発生する可能性を知ら
//	されていたとしても、本ソフトウェアの使用によって発生した（代替品または代用サ
//	ービスの調達、使用の喪失、データの喪失、利益の喪失、業務の中断も含め、またそ
//	れに限定されない）直接損害、間接損害、偶発的な損害、特別損害、懲罰的損害、ま
//	たは結果損害について、一切責任を負わないものとします。
//
//	Note that above Japanese version license is the formal document.
//	The following translation is only for reference.
//
//	Redistribution and use of this software or any derivative works,
//	are permitted provided that the following conditions are met:
//
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above
//	   copyright notice, this list of conditions and the following
//	   disclaimer in the documentation and/or other materials
//	   provided with the distribution.
//	3. Redistributions may not be sold, nor may they be used in a
//	   commercial product or activity without specific prior written
//	   permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//	COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//	LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//	POSSIBILITY OF SUCH DAMAGE.
//
//-----------------------------------------------------------------------------

module ssg_core #( 
	parameter		builtin		= 1'b1,		//	1: register read enable, 0: read is never answered
	parameter		core_number	= 1'b0,
	parameter		read_others	= 1'b1		//	1: answer every read (FFh if not own register), 0: answer only own register reads
) (
	input			clk,
	input			reset_n,
	input			enable,
	input			bus_ioreq,
	input			bus_valid,
	input			bus_write,
	input	[1:0]	bus_address,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,

	input	[7:0]	ssg_ioa,			//	[7]: CMT in, [6]: Keyboard type, [5]: 7pin, [4]: 6pin, [3]: 4pin, [2]: 3pin, [1]: 2pin, [0]: 1pin
	output	[7:0]	ssg_iob,			//	[7]: Kana LED, [6]: PortA SEL, [5]: Joy2 8pin, [4]: Joy1 8pin, [3]: Joy2 7pin, [2]: Joy2 6pin, [1]: Joy1 7pin, [0]: Joy1 6pin

	output	[11:0]	sound_l_out,		//	10bit/ch * 3ch = 12bit
	output	[11:0]	sound_r_out,
	input	[1:0]	mode				//	0: disable, 1: single(core0), 2: single(core1), 3: dual
);
	reg		[7:0]	ff_port_a;
	reg		[7:0]	ff_port_b;

	reg		[4:0]	ff_ssg_state;
	reg		[5:0]	ff_ssg_register_ptr;

	reg		[11:0]	ff_ssg_ch_a_counter;
	reg		[11:0]	ff_ssg_ch_b_counter;
	reg		[11:0]	ff_ssg_ch_c_counter;
	reg				ff_ssg_ch_a_tone_wave;
	reg				ff_ssg_ch_b_tone_wave;
	reg				ff_ssg_ch_c_tone_wave;

	reg				ff_ssg_noise;
	reg		[4:0]	ff_ssg_noise_counter;
	reg		[17:0]	ff_ssg_noise_generator;

	wire			w_ssg_tone_disable;
	wire			w_ssg_noise_disable;
	wire			w_ssg_tone_wave;
	wire	[4:0]	w_ssg_volume;
	wire	[4:0]	w_ssg_ch_level;

	reg		[15:0]	ff_ssg_envelope_counter;
	reg		[5:0]	ff_ssg_envelope_ptr;
	reg		[4:0]	ff_ssg_envelope_volume;
	reg				ff_ssg_envelope_req;
	reg				ff_ssg_envelope_ack;

	reg		[11:0]	ff_ssg_ch_a_frequency;
	reg		[11:0]	ff_ssg_ch_b_frequency;
	reg		[11:0]	ff_ssg_ch_c_frequency;
	reg		[4:0]	ff_ssg_noise_frequency;
	reg		[5:0]	ff_ssg_ch_select;
	reg		[4:0]	ff_ssg_ch_a_volume;
	reg		[4:0]	ff_ssg_ch_b_volume;
	reg		[4:0]	ff_ssg_ch_c_volume;
	reg		[7:0]	ff_ssg_ch_a_pan;
	reg		[7:0]	ff_ssg_ch_b_pan;
	reg		[7:0]	ff_ssg_ch_c_pan;
	reg		[7:0]	ff_ssg_ch_a_gain;
	reg		[7:0]	ff_ssg_ch_b_gain;
	reg		[7:0]	ff_ssg_ch_c_gain;
	reg		[15:0]	ff_ssg_envelope_frequency;
	wire	[9:0]	w_out_level;
	wire	[7:0]	w_ssg_gain;
	wire	[7:0]	w_ssg_gain_clip;
	wire	[17:0]	w_gain_product;
	wire	[9:0]	w_out_level_gained;
	wire	[7:0]	w_ssg_pan;
	wire	[8:0]	w_pan_gain_l;
	wire	[8:0]	w_pan_gain_r;
	wire	[18:0]	w_pan_product_l;
	wire	[18:0]	w_pan_product_r;
	wire	[10:0]	w_out_level_l;
	wire	[10:0]	w_out_level_r;
	reg				ff_hold;
	reg				ff_alternate;
	reg				ff_attack;
	reg				ff_continue;

	reg		[11:0]	ff_ssg_mixer_l;
	reg		[11:0]	ff_ssg_mixer_r;
	reg		[11:0]	ff_sound_l_out;
	reg		[11:0]	ff_sound_r_out;
	wire			w_wr;
	wire			w_rd;
	reg				ff_ready;
	reg		[7:0]	ff_rdata;
	reg				ff_rdata_en;

	assign w_wr		= bus_ioreq & bus_valid & bus_write;
	assign w_rd		= bus_ioreq & bus_valid & ~bus_write;

	//	Read of a register owned by this core: R#0-15 (+16 for core1), gain and pan registers
	wire			w_own_reg	= (ff_ssg_register_ptr[5:4] == { 1'b0, core_number }) |
								  ((ff_ssg_register_ptr[5:4] == 2'b10) & (ff_ssg_register_ptr[2] == core_number));
	wire			w_rd_answer	= w_rd & (read_others | ((bus_address == 2'd2) & w_own_reg));

	generate
		if( builtin ) begin
			always @( posedge clk ) begin
				if( !reset_n ) begin
					ff_ready <= 1'b1;
				end
				else if( ff_rdata_en ) begin
					ff_ready <= 1'b1;
				end
				else if( w_rd ) begin
					ff_ready <= 1'b0;
				end
			end
		end
		else begin
			always @( posedge clk ) begin
				ff_ready <= 1'b1;
			end
		end
	endgenerate

	//--------------------------------------------------------------
	// Miscellaneous control / clock enable (divider)
	//--------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_state <= 5'd0;
		end
		else if( enable ) begin
			ff_ssg_state <= ff_ssg_state - 5'd1;
		end
		else begin
			//	hold
		end
	end

	// -------------------------------------------------------------
	// Interface port
	// -------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_port_a		<= 8'd0;
		end
		else begin
			ff_port_a[7:0]	<= ssg_ioa;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_port_b <= 8'd0;
		end
		else if( w_wr && bus_address == 2'd1 && ff_ssg_register_ptr == { 1'b0, core_number, 4'd15 } ) begin
			ff_port_b <= bus_wdata;
		end
		else begin
			//	hold
		end
	end

    assign bus_ready            = bus_valid;
	assign bus_rdata			= ff_rdata;
	assign bus_rdata_en			= ff_rdata_en;

	assign ssg_iob				= ff_port_b;

	assign sound_l_out			= ff_sound_l_out;
	assign sound_r_out			= ff_sound_r_out;

	//--------------------------------------------------------------
	// Register read
	//--------------------------------------------------------------
	generate
		if( builtin ) begin
			always @( posedge clk ) begin
				if( !reset_n ) begin
					ff_rdata_en <= 1'b0;
				end
				else if( w_rd_answer ) begin
					ff_rdata_en <= enable | ff_rdata_en;
				end
				else begin
					ff_rdata_en <= 1'b0;
				end
			end
		end
		else begin
			always @( posedge clk ) begin
				ff_rdata_en <= 1'b0;
			end
		end
	endgenerate

	generate
		if( builtin ) begin
			always @( posedge clk ) begin
				if( !reset_n ) begin
					ff_rdata <= 8'hFF;
				end
				else if( mode[core_number] == 1'b0 ) begin
					ff_rdata <= 8'hFF;
				end
				else if( !enable ) begin
					//	hold
				end
				else if( w_rd ) begin
					if( bus_address == 2'd2 ) begin
						case( ff_ssg_register_ptr )
						{ 1'b0, core_number, 4'd0  }:	ff_rdata <= ff_ssg_ch_a_frequency[7:0];
						{ 1'b0, core_number, 4'd1  }:	ff_rdata <= { 4'd0, ff_ssg_ch_a_frequency[11:8] };
						{ 1'b0, core_number, 4'd2  }:	ff_rdata <= ff_ssg_ch_b_frequency[7:0];
						{ 1'b0, core_number, 4'd3  }:	ff_rdata <= { 4'd0, ff_ssg_ch_b_frequency[11:8] };
						{ 1'b0, core_number, 4'd4  }:	ff_rdata <= ff_ssg_ch_c_frequency[7:0];
						{ 1'b0, core_number, 4'd5  }:	ff_rdata <= { 4'd0, ff_ssg_ch_c_frequency[11:8] };
						{ 1'b0, core_number, 4'd6  }:	ff_rdata <= { 3'd0, ff_ssg_noise_frequency };
						{ 1'b0, core_number, 4'd7  }:	ff_rdata <= { 2'd2, ff_ssg_ch_select };
						{ 1'b0, core_number, 4'd8  }:	ff_rdata <= { 3'd0, ff_ssg_ch_a_volume };
						{ 1'b0, core_number, 4'd9  }:	ff_rdata <= { 3'd0, ff_ssg_ch_b_volume };
						{ 1'b0, core_number, 4'd10 }:	ff_rdata <= { 3'd0, ff_ssg_ch_c_volume };
						{ 1'b0, core_number, 4'd11 }:	ff_rdata <= ff_ssg_envelope_frequency[7:0];
						{ 1'b0, core_number, 4'd12 }:	ff_rdata <= ff_ssg_envelope_frequency[15:8];
						{ 1'b0, core_number, 4'd13 }:	ff_rdata <= { 4'd0, ff_continue, ff_attack, ff_alternate, ff_hold };
						{ 1'b0, core_number, 4'd14 }:	ff_rdata <= ff_port_a;
						{ 1'b0, core_number, 4'd15 }:	ff_rdata <= ff_port_b;
						{ 3'b100, core_number, 2'd0 }:	ff_rdata <= ff_ssg_ch_a_gain;
						{ 3'b100, core_number, 2'd1 }:	ff_rdata <= ff_ssg_ch_b_gain;
						{ 3'b100, core_number, 2'd2 }:	ff_rdata <= ff_ssg_ch_c_gain;
						{ 3'b101, core_number, 2'd0 }:	ff_rdata <= ff_ssg_ch_a_pan;
						{ 3'b101, core_number, 2'd1 }:	ff_rdata <= ff_ssg_ch_b_pan;
						{ 3'b101, core_number, 2'd2 }:	ff_rdata <= ff_ssg_ch_c_pan;
						default:					ff_rdata <= 8'hFF;
						endcase
					end
					else begin
						ff_rdata <= 8'hFF;
					end
				end
				else begin
					ff_rdata <= 8'hFF;
				end
			end
		end
		else begin
			always @( posedge clk ) begin
				ff_rdata <= 8'hFF;
			end
		end
	endgenerate

	//--------------------------------------------------------------
	// Register write
	//--------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_register_ptr			<= 6'd0;
			ff_ssg_ch_a_frequency		<= 12'hFFF;
			ff_ssg_ch_b_frequency		<= 12'hFFF;
			ff_ssg_ch_c_frequency		<= 12'hFFF;
			ff_ssg_noise_frequency		<= 5'd0;
			ff_ssg_ch_select			<= 6'd0;
			ff_ssg_ch_a_volume			<= 5'd0;
			ff_ssg_ch_b_volume			<= 5'd0;
			ff_ssg_ch_c_volume			<= 5'd0;
			ff_ssg_ch_a_pan				<= 8'd128;
			ff_ssg_ch_b_pan				<= 8'd128;
			ff_ssg_ch_c_pan				<= 8'd128;
			ff_ssg_ch_a_gain			<= 8'd128;
			ff_ssg_ch_b_gain			<= 8'd128;
			ff_ssg_ch_c_gain			<= 8'd128;
			ff_ssg_envelope_frequency	<= 16'hFFFF;
			ff_hold 					<= 1'b1;
			ff_alternate				<= 1'b1;
			ff_attack					<= 1'b1;
			ff_continue					<= 1'b1;
			ff_ssg_envelope_req			<= 1'b0;
		end
		else if( w_wr && bus_address == 2'd0 ) begin
			if( mode[core_number] && !mode[~core_number] ) begin
				ff_ssg_register_ptr <= { 1'b0, core_number, bus_wdata[3:0] };
			end
			else if( mode == 2'd3 ) begin
				ff_ssg_register_ptr <= bus_wdata[5:0];
			end
		end
		else if( w_wr && bus_address == 2'd1 ) begin
			case( ff_ssg_register_ptr )
			{ 1'b0, core_number, 4'd0  }:	ff_ssg_ch_a_frequency[7:0]		<= bus_wdata;
			{ 1'b0, core_number, 4'd1  }:	ff_ssg_ch_a_frequency[11:8]		<= bus_wdata[3:0];
			{ 1'b0, core_number, 4'd2  }:	ff_ssg_ch_b_frequency[7:0]		<= bus_wdata;
			{ 1'b0, core_number, 4'd3  }:	ff_ssg_ch_b_frequency[11:8]		<= bus_wdata[3:0];
			{ 1'b0, core_number, 4'd4  }:	ff_ssg_ch_c_frequency[7:0]		<= bus_wdata;
			{ 1'b0, core_number, 4'd5  }:	ff_ssg_ch_c_frequency[11:8]		<= bus_wdata[3:0];
			{ 1'b0, core_number, 4'd6  }:	ff_ssg_noise_frequency			<= bus_wdata[4:0];
			{ 1'b0, core_number, 4'd7  }:	ff_ssg_ch_select				<= bus_wdata[5:0];
			{ 1'b0, core_number, 4'd8  }:	ff_ssg_ch_a_volume				<= bus_wdata[4:0];
			{ 1'b0, core_number, 4'd9  }:	ff_ssg_ch_b_volume				<= bus_wdata[4:0];
			{ 1'b0, core_number, 4'd10 }:	ff_ssg_ch_c_volume				<= bus_wdata[4:0];
			{ 1'b0, core_number, 4'd11 }:	ff_ssg_envelope_frequency[7:0]	<= bus_wdata;
			{ 1'b0, core_number, 4'd12 }:	ff_ssg_envelope_frequency[15:8]	<= bus_wdata;
			{ 1'b0, core_number, 4'd13 }:
				begin
					ff_hold							<= bus_wdata[0];
					ff_alternate					<= bus_wdata[1];
					ff_attack						<= bus_wdata[2];
					ff_continue						<= bus_wdata[3];
					ff_ssg_envelope_req				<= ~ff_ssg_envelope_ack;
				end
			{ 3'b100, core_number, 2'd0 }:	ff_ssg_ch_a_gain <= bus_wdata;
			{ 3'b100, core_number, 2'd1 }:	ff_ssg_ch_b_gain <= bus_wdata;
			{ 3'b100, core_number, 2'd2 }:	ff_ssg_ch_c_gain <= bus_wdata;
			{ 3'b101, core_number, 2'd0 }:	ff_ssg_ch_a_pan <= bus_wdata;
			{ 3'b101, core_number, 2'd1 }:	ff_ssg_ch_b_pan <= bus_wdata;
			{ 3'b101, core_number, 2'd2 }:	ff_ssg_ch_c_pan <= bus_wdata;
			default:
				begin
					//	hold
				end
			endcase
		end
	end

	//--------------------------------------------------------------
	// Tone generator (Port A)
	//--------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_ch_a_counter		<= 12'd0;
		end
		else if( enable && (ff_ssg_state[3:0] == 4'd0) ) begin
			if( ff_ssg_ch_a_counter != 12'd0) begin
				ff_ssg_ch_a_counter <= ff_ssg_ch_a_counter - 12'd1;
			end
			else if( ff_ssg_ch_a_frequency != 12'd0 ) begin
				ff_ssg_ch_a_counter <= ff_ssg_ch_a_frequency - 12'd1;
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_ch_a_tone_wave	<= 1'b0;
		end
		else if( enable && (ff_ssg_state[3:0] == 4'd0) ) begin
			if( ff_ssg_ch_a_counter == 12'd0 ) begin
				ff_ssg_ch_a_tone_wave <= ~ff_ssg_ch_a_tone_wave;
			end
			else begin
				//	hold
			end
		end
	end

	//--------------------------------------------------------------
	// Tone generator (Port B)
	//--------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_ch_b_counter		<= 12'd0;
		end
		else if( enable && (ff_ssg_state[3:0] == 4'd0) ) begin
			if( ff_ssg_ch_b_counter != 12'd0) begin
				ff_ssg_ch_b_counter <= ff_ssg_ch_b_counter - 12'd1;
			end
			else if( ff_ssg_ch_b_frequency != 12'd0 ) begin
				ff_ssg_ch_b_counter <= ff_ssg_ch_b_frequency - 12'd1;
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_ch_b_tone_wave	<= 1'b0;
		end
		else if( enable && (ff_ssg_state[3:0] == 4'd0) ) begin
			if( ff_ssg_ch_b_counter == 12'd0 ) begin
				ff_ssg_ch_b_tone_wave <= ~ff_ssg_ch_b_tone_wave;
			end
			else begin
				//	hold
			end
		end
	end

	//--------------------------------------------------------------
	// Tone generator (Port C)
	//--------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_ch_c_counter		<= 12'd0;
		end
		else if( enable && (ff_ssg_state[3:0] == 4'd0) ) begin
			if( ff_ssg_ch_c_counter != 12'd0 ) begin
				ff_ssg_ch_c_counter <= ff_ssg_ch_c_counter - 12'd1;
			end
			else if( ff_ssg_ch_c_frequency != 12'd0 ) begin
				ff_ssg_ch_c_counter <= ff_ssg_ch_c_frequency - 12'd1;
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_ch_c_tone_wave	<= 1'b0;
		end
		else if( enable && (ff_ssg_state[3:0] == 4'd0) ) begin
			if( ff_ssg_ch_c_counter == 12'd0 ) begin
				ff_ssg_ch_c_tone_wave <= ~ff_ssg_ch_c_tone_wave;
			end
			else begin
				//	hold
			end
		end
	end

	//--------------------------------------------------------------
	// Noise generator
	//--------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_noise_counter <= 5'd0;
		end
		else begin
			if( enable && (ff_ssg_state == 5'd0) ) begin
				if( ff_ssg_noise_counter != 5'd0 ) begin
					ff_ssg_noise_counter <= ff_ssg_noise_counter - 5'd1;
				end
				else if( ff_ssg_noise_frequency != 5'd0 ) begin
					ff_ssg_noise_counter <= ff_ssg_noise_frequency - 5'd1;
				end
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_noise_generator	<= 18'd0;
		end
		else begin
			if( enable && (ff_ssg_state == 5'd0) ) begin
				if( ff_ssg_noise_counter == 5'd0 ) begin
					if( ff_ssg_noise_generator == 18'd0 ) begin
						ff_ssg_noise_generator[0]		<= 1'b1;
						ff_ssg_noise_generator[17:1]	<= ff_ssg_noise_generator[16:0];
					end
					else begin
						ff_ssg_noise_generator[0]		<= ff_ssg_noise_generator[16] ^ ff_ssg_noise_generator[13];
						ff_ssg_noise_generator[17:1]	<= ff_ssg_noise_generator[16:0];
					end
				end
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_noise <= 1'b0;
		end
		else if( enable ) begin
			ff_ssg_noise <= ff_ssg_noise_generator[17];
		end
		else begin
			//	hold
		end
	end

	//--------------------------------------------------------------
	// Envelope generator
	//--------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_envelope_counter	<= 16'd0;
		end
		else if( enable && ff_ssg_state[3:0] == 4'd0 ) begin
			// Envelope period counter
			if( ff_ssg_envelope_counter != 16'd0 && ff_ssg_envelope_req == ff_ssg_envelope_ack ) begin
				ff_ssg_envelope_counter <= ff_ssg_envelope_counter - 16'd1;
			end
			else if( ff_ssg_envelope_frequency != 16'd0) begin
				ff_ssg_envelope_counter <= ff_ssg_envelope_frequency - 16'd1;
			end
		end
		else begin
			//	hold
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_envelope_ptr		<= 6'b111111;
		end
		else if( enable && ff_ssg_state[3:0] == 4'd0 ) begin
			if( ff_ssg_envelope_req != ff_ssg_envelope_ack ) begin
				ff_ssg_envelope_ptr <= 6'b111111;
			end
			else if( ff_ssg_envelope_counter == 16'd0 && (ff_ssg_envelope_ptr[5] || (!ff_hold && ff_continue)) ) begin
				ff_ssg_envelope_ptr <= ff_ssg_envelope_ptr - 6'd1;
			end
		end
		else begin
			//	hold
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_envelope_volume	<= 5'd0;
		end
		else if( enable && ff_ssg_state[3:0] == 4'd0 ) begin
			if( !ff_ssg_envelope_ptr[5] && !ff_continue ) begin
				ff_ssg_envelope_volume <= 5'd0;
			end
			else if( ff_ssg_envelope_ptr[5] || !(ff_alternate ^ ff_hold) ) begin
				ff_ssg_envelope_volume <= ff_attack ? ~ff_ssg_envelope_ptr[4:0] : ff_ssg_envelope_ptr[4:0];
			end
			else begin
				ff_ssg_envelope_volume <= ff_attack ? ff_ssg_envelope_ptr[4:0] : ~ff_ssg_envelope_ptr[4:0];
			end
		end
		else begin
			//	hold
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_envelope_ack		<= 1'b0;
		end
		else if( enable && ff_ssg_state[3:0] == 4'd0 ) begin
			ff_ssg_envelope_ack <= ff_ssg_envelope_req;
		end
		else begin
			//	hold
		end
	end

	//--------------------------------------------------------------
	// Mixer control
	//--------------------------------------------------------------
	function [9:0] func_out_level(
		input	[4:0]	w_ssg_ch_level
	);
		case( w_ssg_ch_level )
		5'd31:		func_out_level = 10'd1023;
		5'd30:		func_out_level = 10'd860;
		5'd29:		func_out_level = 10'd723;
		5'd28:		func_out_level = 10'd608;
		5'd27:		func_out_level = 10'd511;
		5'd26:		func_out_level = 10'd430;
		5'd25:		func_out_level = 10'd361;
		5'd24:		func_out_level = 10'd304;
		5'd23:		func_out_level = 10'd255;
		5'd22:		func_out_level = 10'd215;
		5'd21:		func_out_level = 10'd180;
		5'd20:		func_out_level = 10'd152;
		5'd19:		func_out_level = 10'd127;
		5'd18:		func_out_level = 10'd107;
		5'd17:		func_out_level = 10'd90;
		5'd16:		func_out_level = 10'd76;
		5'd15:		func_out_level = 10'd63;
		5'd14:		func_out_level = 10'd53;
		5'd13:		func_out_level = 10'd45;
		5'd12:		func_out_level = 10'd38;
		5'd11:		func_out_level = 10'd31;
		5'd10:		func_out_level = 10'd26;
		5'd9:		func_out_level = 10'd22;
		5'd8:		func_out_level = 10'd19;
		5'd7:		func_out_level = 10'd15;
		5'd6:		func_out_level = 10'd13;
		5'd5:		func_out_level = 10'd11;
		5'd4:		func_out_level = 10'd9;
		5'd3:		func_out_level = 10'd6;
		5'd2:		func_out_level = 10'd2;
		5'd1:		func_out_level = 10'd0;
		default:	func_out_level = 10'd0;
		endcase
	endfunction

	assign w_ssg_tone_disable	= ( ff_ssg_state[1:0] == 2'd3 ) ? ff_ssg_ch_select[0] : 
								  ( ff_ssg_state[1:0] == 2'd2 ) ? ff_ssg_ch_select[1] : 
								  ( ff_ssg_state[1:0] == 2'd1 ) ? ff_ssg_ch_select[2] : 1'b1;

	assign w_ssg_noise_disable	= ( ff_ssg_state[1:0] == 2'd3 ) ? ff_ssg_ch_select[3] : 
								  ( ff_ssg_state[1:0] == 2'd2 ) ? ff_ssg_ch_select[4] : 
								  ( ff_ssg_state[1:0] == 2'd1 ) ? ff_ssg_ch_select[5] : 1'b1;

	assign w_ssg_tone_wave		= ( ff_ssg_state[1:0] == 2'd3 ) ? ff_ssg_ch_a_tone_wave : 
								  ( ff_ssg_state[1:0] == 2'd2 ) ? ff_ssg_ch_b_tone_wave : 
								  ( ff_ssg_state[1:0] == 2'd1 ) ? ff_ssg_ch_c_tone_wave : 1'b1;

	assign w_ssg_volume			= ( ff_ssg_state[1:0] == 2'd3 ) ? ff_ssg_ch_a_volume : 
								  ( ff_ssg_state[1:0] == 2'd2 ) ? ff_ssg_ch_b_volume : 
								  ( ff_ssg_state[1:0] == 2'd1 ) ? ff_ssg_ch_c_volume : 5'd0;

	assign w_ssg_pan			= ( ff_ssg_state[1:0] == 2'd3 ) ? ff_ssg_ch_a_pan :
								  ( ff_ssg_state[1:0] == 2'd2 ) ? ff_ssg_ch_b_pan :
								  ( ff_ssg_state[1:0] == 2'd1 ) ? ff_ssg_ch_c_pan : 8'd128;

	assign w_ssg_gain			= ( ff_ssg_state[1:0] == 2'd3 ) ? ff_ssg_ch_a_gain :
								  ( ff_ssg_state[1:0] == 2'd2 ) ? ff_ssg_ch_b_gain :
								  ( ff_ssg_state[1:0] == 2'd1 ) ? ff_ssg_ch_c_gain : 8'd128;

	assign w_ssg_gain_clip		= w_ssg_gain[7] ? 8'd128 : { 1'b0, w_ssg_gain[6:0] };

	assign w_ssg_ch_level		= ( !( w_ssg_tone_disable  || w_ssg_tone_wave ) ) ? 4'd0 :
								  ( !( w_ssg_noise_disable || ff_ssg_noise    ) ) ? 4'd0 :
								  ( w_ssg_volume[4]                             ) ? ff_ssg_envelope_volume : { w_ssg_volume[3:0], 1'b1 };

	assign w_out_level			= func_out_level( w_ssg_ch_level );
	assign w_gain_product		= w_out_level * w_ssg_gain_clip;
	assign w_out_level_gained	= w_gain_product[16:7];
	assign w_pan_product_l		= w_out_level_gained * w_pan_gain_l;
	assign w_pan_product_r		= w_out_level_gained * w_pan_gain_r;
	assign w_out_level_l		= w_pan_product_l >> 8;
	assign w_out_level_r		= w_pan_product_r >> 8;

	pan_lut u_pan_lut (
		.i_clk					( clk					),
		.i_pan					( w_ssg_pan				),
		.o_gain_l				( w_pan_gain_l			),
		.o_gain_r				( w_pan_gain_r			)
	);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_ssg_mixer_l	<= 12'd0;
			ff_ssg_mixer_r	<= 12'd0;
		end
		else if( enable ) begin
			if( ff_ssg_state[1:0] == 2'd0 ) begin
				ff_ssg_mixer_l		<= 12'd0;
				ff_ssg_mixer_r		<= 12'd0;
			end
			else begin
				ff_ssg_mixer_l		<= { 1'b0, w_out_level_l } + ff_ssg_mixer_l;
				ff_ssg_mixer_r		<= { 1'b0, w_out_level_r } + ff_ssg_mixer_r;
			end
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_sound_l_out	<= 12'd0;
			ff_sound_r_out	<= 12'd0;
		end
		else if( mode[core_number] == 1'd0 ) begin
			ff_sound_l_out	<= 12'd0;
			ff_sound_r_out	<= 12'd0;
		end
		else if( enable ) begin
			if( ff_ssg_state[1:0] == 2'd0 ) begin
				ff_sound_l_out	<= ff_ssg_mixer_l;
				ff_sound_r_out	<= ff_ssg_mixer_r;
			end
			else begin
				//	hold
			end
		end
	end
endmodule
