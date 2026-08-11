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
	input			bus_io,
	input			bus_cs,
	input	[15:0]	bus_address,
	input			bus_write,
	input			bus_valid,
	output			bus_ready,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	output			uart_tx,
	output	[3:0]	led
);
	reg				ff_valid;
	reg				ff_bus_wr_req;
	reg				ff_bus_rd_req;
	reg				ff_rd_pending;
	reg				ff_rd_ready;
	reg				ff_rdata_en;
	wire			w_ready;
	reg		[7:0]	ff_rdata;
	reg		[3:0]	ff_led;
	wire			w_uart_wr_req;
	wire			w_uart_wr_edge;
	wire			w_uart_tx_wr;
	wire			w_uart_led_wr;
	wire			w_uart_rd_req;
	wire			w_uart_rd_edge;

	assign w_uart_wr_req = bus_io && bus_cs && bus_valid && bus_write;
	assign w_uart_wr_edge = w_uart_wr_req && !ff_bus_wr_req;
	assign w_uart_tx_wr = w_uart_wr_edge && (bus_address[0] == 1'b0);
	assign w_uart_led_wr = w_uart_wr_edge && (bus_address[0] == 1'b1);
	assign w_uart_rd_req = bus_io && bus_cs && bus_valid && !bus_write;
	assign w_uart_rd_edge = w_uart_rd_req && !ff_bus_rd_req;
	assign bus_ready = w_uart_rd_req ? ff_rd_ready :
					  ((bus_io && bus_cs && bus_valid && bus_write && (bus_address[0] == 1'b0)) ? ~(ff_valid && ~w_ready) : 1'b1);
	assign bus_rdata = ff_rdata;
	assign bus_rdata_en = ff_rdata_en;

	always @( posedge clk ) begin
		if( !n_reset ) begin
			ff_bus_wr_req <= 1'b0;
			ff_bus_rd_req <= 1'b0;
			ff_rd_pending <= 1'b0;
			ff_rd_ready <= 1'b0;
			ff_rdata_en <= 1'b0;
			ff_rdata <= 8'd0;
			ff_valid <= 1'b0;
			ff_led <= 4'd0;
		end
		else begin
			ff_bus_wr_req <= w_uart_wr_req;
			ff_bus_rd_req <= w_uart_rd_req;
			ff_rd_ready <= 1'b0;
			ff_rdata_en <= 1'b0;

			if( ff_valid && w_ready ) begin
				ff_valid <= 1'b0;
			end

			if( w_uart_tx_wr ) begin
				ff_valid <= 1'b1;
			end
			else if( w_uart_led_wr ) begin
				ff_led <= bus_wdata[3:0];
			end

			if( w_uart_rd_edge && !ff_rd_pending ) begin
				ff_rd_pending <= 1'b1;
				ff_rd_ready <= 1'b1;
				ff_rdata <= (bus_address[0] == 1'b0) ? { 7'd0, w_ready } : { 4'd0, ff_led };
			end
			else if( ff_rd_pending ) begin
				ff_rd_pending <= 1'b0;
				ff_rdata_en <= 1'b1;
			end
		end
	end

	assign led		= ~ff_led;

	ip_uart #(
		.clk_freq		( 28636360		),
		.uart_freq		( 115200		)
	) u_uart (
		.n_reset		( n_reset		),
		.clk			( clk			),
		.send_data		( bus_wdata		),
		.send_valid		( ff_valid		),
		.send_ready		( w_ready		),
		.uart_tx		( uart_tx		)
	);
endmodule
