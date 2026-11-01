//
//	Transfer a stereo mixer sample to the I2S clock domain.
//	reset_n is synchronous to clk_src.
//
module audio_cdc (
	input			clk_src,
	input			clk_dst,
	input			reset_n,
	input			src_valid,
	input	[23:0]	src_l,
	input	[23:0]	src_r,
	input			dst_request,
	output			dst_reset_n,
	output reg [23:0]	dst_l,
	output reg [23:0]	dst_r
);
	reg		[1:0]	ff_reset_sync /* synthesis syn_preserve=1 */;
	reg				ff_request;
	reg				ff_request_meta /* synthesis syn_preserve=1 */;
	reg				ff_request_sync /* synthesis syn_preserve=1 */;
	reg				ff_request_served;

	reg		[47:0]	ff_rail_zero;
	reg		[47:0]	ff_rail_one;
	reg		[47:0]	ff_zero_meta /* synthesis syn_preserve=1 */;
	reg		[47:0]	ff_zero_sync /* synthesis syn_preserve=1 */;
	reg		[47:0]	ff_one_meta /* synthesis syn_preserve=1 */;
	reg		[47:0]	ff_one_sync /* synthesis syn_preserve=1 */;
	reg		[47:0]	ff_one_previous;
	reg				ff_sample_parity;
	reg				ff_request_complete;
	wire	[47:0]	w_src_sample;
	wire	[47:0]	w_arrived;

	//	After each completed transfer, every rail pair's XOR equals the
	//	sample parity. A mismatch means that bit of the next sample arrived.
	assign w_src_sample	= { src_l, src_r };
	assign w_arrived	= ff_zero_sync ^ ff_one_sync ^ { 48{ ff_sample_parity } };
	assign dst_reset_n	= ff_reset_sync[1];

	//	Assert reset asynchronously and release it on the I2S clock.
	always @( posedge clk_dst or negedge reset_n ) begin
		if( !reset_n ) begin
			ff_reset_sync <= 2'b00;
		end
		else begin
			ff_reset_sync <= { ff_reset_sync[0], 1'b1 };
		end
	end

	//	Exactly one of the two rails toggles for each bit of a sample.
	//	The rails remain unchanged until the next destination request.
	always @( posedge clk_src ) begin
		if( !reset_n ) begin
			ff_request_meta		<= 1'b0;
			ff_request_sync		<= 1'b0;
			ff_request_served	<= 1'b0;
			ff_rail_zero		<= 48'd0;
			ff_rail_one			<= 48'd0;
		end
		else begin
			ff_request_meta	<= ff_request;
			ff_request_sync	<= ff_request_meta;
			if( (ff_request_sync != ff_request_served) && src_valid ) begin
				ff_rail_zero		<= ff_rail_zero ^ ~w_src_sample;
				ff_rail_one			<= ff_rail_one ^ w_src_sample;
				ff_request_served	<= ff_request_sync;
			end
		end
	end

	always @( posedge clk_dst ) begin
		if( !dst_reset_n ) begin
			ff_zero_meta		<= 48'd0;
			ff_zero_sync		<= 48'd0;
			ff_one_meta			<= 48'd0;
			ff_one_sync			<= 48'd0;
			ff_one_previous		<= 48'd0;
			ff_sample_parity	<= 1'b0;
			ff_request			<= 1'b0;
			ff_request_complete	<= 1'b0;
			dst_l				<= 24'd0;
			dst_r				<= 24'd0;
		end
		else begin
			ff_zero_meta	<= ff_rail_zero;
			ff_zero_sync	<= ff_zero_meta;
			ff_one_meta		<= ff_rail_one;
			ff_one_sync		<= ff_one_meta;

			//	Wait for a synchronized transition on every bit. This avoids
			//	assuming a relative arrival time for the asynchronous bus.
			if( (ff_request != ff_request_complete) && (&w_arrived) ) begin
				//	A changed "one" rail encodes a 1; the other rail encodes 0.
				{ dst_l, dst_r }	<= ff_one_sync ^ ff_one_previous;
				ff_one_previous		<= ff_one_sync;
				ff_sample_parity	<= ~ff_sample_parity;
				ff_request_complete	<= ff_request;
			end

			if( dst_request && (ff_request == ff_request_complete) ) begin
				ff_request <= ~ff_request;
			end
		end
	end
endmodule
