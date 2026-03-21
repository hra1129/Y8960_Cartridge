// -----------------------------------------------------------------------------
//	ip_uart_inst.v
//	Copyright (C)2026 Takayuki Hara (HRA!)
//	
//	 Permission is hereby granted, free of charge, to any person obtaining a 
//	copy of this software and associated documentation files (the "Software"), 
//	to deal in the Software without restriction, including without limitation 
//	the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//	and/or sell copies of the Software, and to permit persons to whom the 
//	Software is furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in 
//	all copies or substantial portions of the Software.
//	
//	The Software is provided "as is", without warranty of any kind, express or 
//	implied, including but not limited to the warranties of merchantability, 
//	fitness for a particular purpose and noninfringement. In no event shall the 
//	authors or copyright holders be liable for any claim, damages or other 
//	liability, whether in an action of contract, tort or otherwise, arising 
//	from, out of or in connection with the Software or the use or other dealings 
//	in the Software.
// -----------------------------------------------------------------------------
//	Description:
//		UART (TX ONLY)
// -----------------------------------------------------------------------------

module ip_uart_inst (
	input			n_reset,
	input			clk,
	input			address,
	input			iorq_n,
	output			wait_n,
	input			wr_n,
	input	[7:0]	di,
	output			uart_tx,
	output	[3:0]	led
);
	reg				ff_valid;
	reg				ff_wr_n;
	wire			w_ready;
	reg		[3:0]	ff_led;

	always @( posedge clk ) begin
		if( !n_reset ) begin
			ff_wr_n <= 1'b1;
		end
		else begin
			ff_wr_n <= wr_n;
		end
	end

	always @( posedge clk ) begin
		if( !n_reset ) begin
			ff_valid <= 1'b0;
		end
		else if( ff_valid ) begin
			if( w_ready ) begin
				ff_valid <= 1'b0;
			end
		end
		else if( !wr_n && ff_wr_n ) begin
			if( address == 1'b0 ) begin
				ff_valid <= 1'b1;
			end
			else begin
				ff_led <= di[3:0];
			end
		end
		else begin
			//	hold
		end
	end

	assign wait_n	= ~(ff_valid && ~w_ready);
	assign led		= ~ff_led;

	ip_uart #(
		.clk_freq		( 28636360		),
		.uart_freq		( 115200		)
	) u_uart (
		.n_reset		( n_reset		),
		.clk			( clk			),
		.send_data		( di			),
		.send_valid		( ff_valid		),
		.send_ready		( w_ready		),
		.uart_tx		( uart_tx		)
	);
endmodule
