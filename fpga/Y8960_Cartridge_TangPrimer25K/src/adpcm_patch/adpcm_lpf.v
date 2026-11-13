// --------------------------------------------------------------------
//	ADPCM output low pass filter
// ====================================================================
//	2026/11/13 t.hara
//
//	Y8950 hides the high frequency quantization noise of ADPCM with the
//	low pass filter of its analog output stage. Y8960 outputs the digital
//	value directly, so this fixed FIR filter takes the place of it.
//
//	25 taps, linear phase, Kaiser window (beta = 5), fc = 5.5kHz,
//	fs = 49.716kHz (cen55). Coefficients are Q15 and the sum is 32768
//	(DC gain = 1).
//	  1kHz: 0.0dB, 4kHz: -1.4dB, 6kHz: -8.6dB, 7kHz: -16.2dB, 8kHz: -28.9dB
//
//	The coefficients are symmetric, so 13 pairs (x[k] + x[24-k]) are
//	multiplied by a shift-and-add sequence on clk. Neither a hardware
//	multiplier nor a divider is used. One sample takes 197 clk
//	(cen55 comes every 864 clk).
//
//	The filter works on the cen55 samples after the interpolator, so the
//	cutoff frequency is fixed in Hz and does not depend on DELTA-N.
//	(Measured with the decoder + interpolator for DELTA-N = 1800h-FFFFh,
//	 the response matches the design within 0.3dB up to 8kHz.)
// --------------------------------------------------------------------

module adpcm_lpf (
	input			clk,
	input			reset_n,
	input			cen55,
	input	[15:0]	pcm_in,						//	signed
	output	[15:0]	pcm_out						//	signed
);
	localparam		[2:0]	c_state_idle		= 3'd0;
	localparam		[2:0]	c_state_load		= 3'd1;
	localparam		[2:0]	c_state_mul			= 3'd2;
	localparam		[2:0]	c_state_acc			= 3'd3;
	localparam		[2:0]	c_state_out			= 3'd4;

	reg		[15:0]			ff_tap [0:24];
	reg		[2:0]			ff_state;
	reg		[3:0]			ff_index;
	reg		[3:0]			ff_bit;
	reg signed	[16:0]		ff_pair;
	reg signed	[30:0]		ff_prod;
	reg signed	[32:0]		ff_acc;
	reg		[15:0]			ff_out;

	wire	[12:0]			w_coef;
	wire					w_coef_neg;
	wire	[15:0]			w_tap_pair;
	wire signed	[30:0]		w_prod_next;
	wire signed	[32:0]		w_round;
	wire signed	[17:0]		w_result;
	integer					i;

	//	|coefficient| and sign of tap k (= tap 24-k)
	function [13:0] coef;
		input	[3:0]	index;
		begin
			case( index )
			4'd0:		coef = { 1'b0, 13'd28   };
			4'd1:		coef = { 1'b0, 13'd78   };
			4'd2:		coef = { 1'b0, 13'd96   };
			4'd3:		coef = { 1'b1, 13'd7    };
			4'd4:		coef = { 1'b1, 13'd283  };
			4'd5:		coef = { 1'b1, 13'd645  };
			4'd6:		coef = { 1'b1, 13'd825  };
			4'd7:		coef = { 1'b1, 13'd458  };
			4'd8:		coef = { 1'b0, 13'd716  };
			4'd9:		coef = { 1'b0, 13'd2632 };
			4'd10:		coef = { 1'b0, 13'd4830 };
			4'd11:		coef = { 1'b0, 13'd6591 };
			default:	coef = { 1'b0, 13'd7262 };
			endcase
		end
	endfunction

	assign { w_coef_neg, w_coef }	= coef( ff_index );

	//	the center tap (k = 12) has no pair
	assign w_tap_pair		= (ff_index == 4'd12) ? 16'd0 : ff_tap[ 5'd24 - { 1'b0, ff_index } ];

	assign w_prod_next		= (ff_prod <<< 1) + ( w_coef[ ff_bit ] ? { {14{ff_pair[16]}}, ff_pair } : 31'sd0 );

	//	round to nearest, Q15 -> integer, and saturate
	assign w_round			= ff_acc + 33'sd16384;
	assign w_result			= w_round[32:15];

	always @( posedge clk ) begin
		if( !reset_n ) begin
			for( i = 0; i < 25; i = i + 1 ) begin
				ff_tap[i]	<= 16'd0;
			end
			ff_state	<= c_state_idle;
			ff_index	<= 4'd0;
			ff_bit		<= 4'd0;
			ff_pair		<= 17'sd0;
			ff_prod		<= 31'sd0;
			ff_acc		<= 33'sd0;
			ff_out		<= 16'd0;
		end
		else begin
			case( ff_state )
			c_state_idle: begin
				if( cen55 ) begin
					ff_tap[0]	<= pcm_in;
					for( i = 1; i < 25; i = i + 1 ) begin
						ff_tap[i]	<= ff_tap[i - 1];
					end
					ff_index	<= 4'd0;
					ff_acc		<= 33'sd0;
					ff_state	<= c_state_load;
				end
			end
			c_state_load: begin
				ff_pair		<= $signed( { ff_tap[ ff_index ][15], ff_tap[ ff_index ] } ) + $signed( { w_tap_pair[15], w_tap_pair } );
				ff_prod		<= 31'sd0;
				ff_bit		<= 4'd12;
				ff_state	<= c_state_mul;
			end
			c_state_mul: begin
				ff_prod		<= w_prod_next;
				if( ff_bit == 4'd0 ) begin
					ff_state	<= c_state_acc;
				end
				else begin
					ff_bit		<= ff_bit - 4'd1;
				end
			end
			c_state_acc: begin
				if( w_coef_neg ) begin
					ff_acc		<= ff_acc - { {2{ff_prod[30]}}, ff_prod };
				end
				else begin
					ff_acc		<= ff_acc + { {2{ff_prod[30]}}, ff_prod };
				end
				if( ff_index == 4'd12 ) begin
					ff_state	<= c_state_out;
				end
				else begin
					ff_index	<= ff_index + 4'd1;
					ff_state	<= c_state_load;
				end
			end
			default: begin
				if( w_result > 18'sd32767 ) begin
					ff_out		<= 16'h7FFF;
				end
				else if( w_result < -18'sd32768 ) begin
					ff_out		<= 16'h8000;
				end
				else begin
					ff_out		<= w_result[15:0];
				end
				ff_state	<= c_state_idle;
			end
			endcase
		end
	end

	assign pcm_out	= ff_out;
endmodule
