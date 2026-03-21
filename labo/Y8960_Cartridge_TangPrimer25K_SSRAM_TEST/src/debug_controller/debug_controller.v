// --------------------------------------------------------------------
//	Debug Controller
// ====================================================================
//	2026/01/26 t.hara
// --------------------------------------------------------------------

module debug_controller (
	input			clk,
	input			reset_n,
	//	SRAM interface
	output	[18:0]	address,
	output			valid,
	input			ready,
	output			write,
	output	[7:0]	wdata,
	input	[7:0]	rdata,
	input			rdata_en,
	//	UART interface
	output	[7:0]	send_data,
	output			send_valid,
	input			send_ready,
	//	DIPSW
	input			dipsw
);
	reg		[7:0]	rom_image [0:255];
	reg		[7:0]	hex_table [0:15];
	reg		[7:0]	ff_rom_address_req;
	reg		[7:0]	ff_rom_address;
	reg				ff_rom_send_en;
	reg				ff_rom_send_start;
	reg		[7:0]	ff_rom_image;
	reg		[7:0]	ff_hex_table;
	reg		[3:0]	ff_send_hex;

	localparam	c_title_message = 0;
	localparam	c_write = 24;
	localparam	c_read = 33;

	localparam	c_code_term = 8'h00;
	localparam	c_code_address = 8'h01;
	localparam	c_code_data = 8'h02;
	initial begin
		//	Title message
		rom_image[0]	= 'S';
		rom_image[1]	= 'R';
		rom_image[2]	= 'A';
		rom_image[3]	= 'M';
		rom_image[4]	= ' ';
		rom_image[5]	= 'T';
		rom_image[6]	= 'E';
		rom_image[7]	= 'S';
		rom_image[8]	= 'T';
		rom_image[9]	= 8'h0D;
		rom_image[10]	= 8'h0A;
		rom_image[11]	= '-';
		rom_image[12]	= '-';
		rom_image[13]	= '-';
		rom_image[14]	= '-';
		rom_image[15]	= '-';
		rom_image[16]	= '-';
		rom_image[17]	= '-';
		rom_image[18]	= '-';
		rom_image[19]	= '-';
		rom_image[20]	= '-';
		rom_image[21]	= 8'h0D;
		rom_image[22]	= 8'h0A;
		rom_image[23]	= c_code_term;
		//	write
		rom_image[24]	= 'W';
		rom_image[25]	= 'R';
		rom_image[26]	= ':';
		rom_image[27]	= c_code_address;
		rom_image[28]	= '=';
		rom_image[29]	= c_code_data;
		rom_image[30]	= 8'h0D;
		rom_image[31]	= 8'h0A;
		rom_image[32]	= c_code_term;
		//	read
		rom_image[33]	= 'R';
		rom_image[34]	= 'D';
		rom_image[35]	= ':';
		rom_image[36]	= c_code_address;
		rom_image[37]	= '=';
		rom_image[38]	= c_code_data;
		rom_image[39]	= 8'h0D;
		rom_image[40]	= 8'h0A;
		rom_image[41]	= c_code_term;
	end

	initial begin
		hex_table[0]	= '0';
		hex_table[1]	= '1';
		hex_table[2]	= '2';
		hex_table[3]	= '3';
		hex_table[4]	= '4';
		hex_table[5]	= '5';
		hex_table[6]	= '6';
		hex_table[7]	= '7';
		hex_table[8]	= '8';
		hex_table[9]	= '9';
		hex_table[10]	= 'A';
		hex_table[11]	= 'B';
		hex_table[12]	= 'C';
		hex_table[13]	= 'D';
		hex_table[14]	= 'E';
		hex_table[15]	= 'F';
	end

	always @( posedge clk ) begin
		ff_rom_image <= rom_image[ ff_rom_address ];
		ff_hex_table <= hex_table[ ff_send_hex ];
	end

	// ---------------------------------------------------------
	//	message sender
	// ---------------------------------------------------------
	reg		[3:0]		ff_rom_sender_state;

	localparam c_rs_wait				= 4'd0;
	localparam c_rs_sending				= 4'd1;
	localparam c_rs_char				= 4'd2;
	localparam c_rs_wait_char_ready		= 4'd3;
	localparam c_rs_next_char			= 4'd4;
	localparam c_rs_send_hex			= 4'd5;
	localparam c_rs_send_hex1			= 4'd6;
	localparam c_rs_wait_send_hex_ready	= 4'd7;
	localparam c_rs_address				= 4'd8;
	localparam c_rs_address1			= 4'd9;
	localparam c_rs_address2			= 4'd10;
	localparam c_rs_address3			= 4'd11;
	localparam c_rs_address4			= 4'd12;
	localparam c_rs_address5			= 4'd13;
	localparam c_rs_data				= 4'd14;
	localparam c_rs_data1				= 4'd15;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_rom_sender_state	<= c_rs_wait;
			ff_rom_address <= 8'd0;
		end
		else begin
			case( ff_rom_sender_state )
				c_rs_wait: begin
					if( ff_rom_send_start ) begin
						ff_rom_sender_state <= c_rs_sending;
						ff_rom_address <= ff_rom_address_req;
					end
				end
				c_rs_sending: begin
					if( ff_rom_image == c_code_term ) begin
						ff_rom_sender_state <= c_rs_wait;
					end
					else if( ff_rom_image == c_code_address ) begin
						ff_rom_sender_state <= c_rs_address;
					end
					else if( ff_rom_image == c_code_data ) begin
						ff_rom_sender_state <= c_rs_data;
					end
					else begin
						ff_rom_sender_state <= c_rs_char;
						ff_rom_sender_state_next <= c_rs_sending;
					end
				end
				// ------------------------------------------------------------
				//	putc( ff_rom_image );
				c_rs_char: begin
					ff_rom_sender_state <= c_rs_wait_char_ready;
					ff_send_data <= ff_rom_image;
					ff_send_valid <= 1'b1;
				end
				c_rs_wait_char_ready: begin
					if( send_ready ) begin
						ff_send_valid <= 1'b0;
						ff_rom_sender_state <= c_rs_next_char;
						ff_rom_address <= ff_rom_address + 8'd1;
					end
				end
				c_rs_next_char: begin
					ff_rom_sender_state <= ff_rom_sender_state_next;
				end
				// ---------------------------------------------------------
				//	put_hex( ff_send_hex );
				c_rs_send_hex: begin
					ff_rom_sender_state <= c_rs_send_hex1;
				end
				c_rs_send_hex1: begin
					ff_rom_sender_state <= c_rs_wait_send_hex_ready;
					ff_send_data <= ff_hex_table;
					ff_send_valid <= 1'b1;
				end
				c_rs_wait_send_hex_ready: begin
					if( send_ready ) begin
						ff_send_valid <= 1'b0;
						ff_rom_sender_state <= c_rs_next_char;
					end
				end
				// ------------------------------------------------------------
				//	puts( s_address );
				c_rs_address: begin
					ff_rom_sender_state_next <= c_rs_address1;
					ff_rom_sender_state <= c_rs_send_hex;
					ff_send_hex <= { 1'b0, ff_sram_address[18:16] };
				end
				c_rs_address1: begin
					ff_rom_sender_state_next <= c_rs_address2;
					ff_rom_sender_state <= c_rs_send_hex;
					ff_send_hex <= ff_sram_address[15:12];
				end
				c_rs_address2: begin
					ff_rom_sender_state_next <= c_rs_address3;
					ff_rom_sender_state <= c_rs_send_hex;
					ff_send_hex <= ff_sram_address[11:8];
				end
				c_rs_address3: begin
					ff_rom_sender_state_next <= c_rs_address4;
					ff_rom_sender_state <= c_rs_send_hex;
					ff_send_hex <= ff_sram_address[7:4];
				end
				c_rs_address4: begin
					ff_rom_sender_state_next <= c_rs_address5;
					ff_rom_sender_state <= c_rs_send_hex;
					ff_send_hex <= ff_sram_address[3:0];
				end
				c_rs_address5: begin
					ff_rom_sender_state_next <= c_rs_sending;
					ff_rom_sender_state <= c_rs_next_char;
					ff_rom_address <= ff_rom_address + 8'd1;
				end
				// ------------------------------------------------------------
				//	puts( s_data );
				c_rs_data: begin
					ff_rom_sender_state_next <= c_rs_data1;
					ff_rom_sender_state <= c_rs_send_hex;
					ff_send_hex <= ff_sram_data[7:4];
				end
				c_rs_data1: begin
					ff_rom_sender_state_next <= c_rs_address5;
					ff_rom_sender_state <= c_rs_send_hex;
					ff_send_hex <= ff_sram_data[3:0];
				end
			endcase
		end
	end

	// ---------------------------------------------------------
	//	start trigger
	// ---------------------------------------------------------
	reg			ff_dipsw;
	wire		w_trigger;

	always @( posedge clk ) begin
		ff_dipsw <= dipsw;
	end
	assign w_trigger	= ff_dipsw ^ dipsw;

	// ---------------------------------------------------------
	//	state machine
	// ---------------------------------------------------------
	reg		[3:0]	ff_state;
	reg		[3:0]	ff_next_state;

	localparam	c_state_init				= 4'd0;
	localparam	c_start_wait_send_complete	= 4'd1;
	localparam	c_wait_send_complete_loop	= 4'd2;
	localparam	c_write_byte				= 4'd3;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_state <= c_state_init;
			ff_rom_send_start <= 1'b0;
		end
		else begin
			case( ff_state )
				c_state_init: begin
					if( w_trigger ) begin
						ff_state			<= c_start_wait_send_complete;
						ff_next_state		<= c_write_byte;
						ff_rom_address_req	<= c_title_message;
						ff_rom_send_start	<= 1'b1;
					end
				end
				// ---------------------------------------------------------
				//	start and wait complete, send message
				c_start_wait_send_complete: begin
					ff_rom_send_start	<= 1'b0;
					ff_state			<= c_wait_send_complete_loop;
				end
				c_wait_send_complete_loop: begin
					if( ff_rom_sender_state == c_rs_wait ) begin
						ff_state			<= ff_next_state;
					end
				end
				// ---------------------------------------------------------
				//	write byte data
				c_write_byte: begin
				end
			endcase
		end
	end
endmodule
