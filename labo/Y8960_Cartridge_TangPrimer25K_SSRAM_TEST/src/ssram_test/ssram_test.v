// --------------------------------------------------------------------
//  ssram_test.v
//  512KB Serial SRAM write/read test controller
// --------------------------------------------------------------------

module ssram_test (
    input					n_reset,
    input					clk,
    input 			[1:0]	dipsw,
    output  reg				bus_cs,
    output  reg		[18:0]	bus_address,
    output  reg				bus_write,
    output  reg				bus_valid,
    output  reg		[7:0]	bus_wdata,
    input					bus_ready,
    input   [7:0]			bus_rdata,
    input					bus_rdata_en,
    output  reg		[7:0]	uart_data,
    output  reg				uart_valid,
    input					uart_ready,
    output  reg		[3:0]	led
);
    localparam [18:0] C_LAST_ADDR = 19'h7FFFF;
    localparam [22:0] C_RD_WAIT_TIMEOUT = 23'd4000000;

    localparam [4:0] ST_WAIT_DIP      = 5'd0;
    localparam [4:0] ST_MSG_START     = 5'd1;
    localparam [4:0] ST_WR_REQ        = 5'd2;
    localparam [4:0] ST_WR_WAIT       = 5'd3;
    localparam [4:0] ST_WR_NEXT       = 5'd4;
    localparam [4:0] ST_MSG_WR_DONE   = 5'd5;
    localparam [4:0] ST_RD_REQ        = 5'd6;
    localparam [4:0] ST_RD_WAIT_READY = 5'd7;
    localparam [4:0] ST_RD_WAIT_DATA  = 5'd8;
    localparam [4:0] ST_RD_CHECK      = 5'd9;
    localparam [4:0] ST_RD_NEXT       = 5'd10;
    localparam [4:0] ST_MSG_PASS      = 5'd11;
    localparam [4:0] ST_MSG_FAIL      = 5'd12;
    localparam [4:0] ST_DONE          = 5'd13;

    localparam [2:0] MSG_NONE         = 3'd0;
    localparam [2:0] MSG_START        = 3'd1;
    localparam [2:0] MSG_WR_DONE      = 3'd2;
    localparam [2:0] MSG_PASS         = 3'd3;
    localparam [2:0] MSG_FAIL         = 3'd4;
    localparam [2:0] MSG_FAIL_DETAIL  = 3'd5;

    localparam [7:0] FAIL_REASON_MISMATCH  = "M";
    localparam [7:0] FAIL_REASON_RD_READY  = "Q";
    localparam [7:0] FAIL_REASON_RD_DATA   = "T";

    reg [4:0]   ff_state;
    reg [2:0]   ff_msg_sel;
    reg [4:0]   ff_msg_index;
    reg [4:0]   ff_state_after_msg;
    reg [18:0]  ff_addr;
    reg [7:0]   ff_expected;
    reg [7:0]   ff_received;
    reg [18:0]  ff_fail_addr;
    reg [7:0]   ff_fail_expected;
    reg [7:0]   ff_fail_received;
    reg [7:0]   ff_fail_reason;
    reg [22:0]  ff_rd_wait_count;
    reg [1:0]   ff_dipsw_init;
    reg [1:0]   ff_dipsw_sync0;
    reg [1:0]   ff_dipsw_sync1;
    reg [1:0]   ff_dipsw_last;
    reg [15:0]  ff_dipsw_stable_count;
    reg         ff_dipsw_armed;
    reg         ff_uart_pending;
    reg [23:0]  ff_blink_count;

    function [7:0] f_test_data;
        input [18:0] adr;
        begin
            f_test_data = adr[7:0] ^ adr[15:8] ^ { 5'd0, adr[18:16] };
        end
    endfunction

    function [7:0] f_hex_char;
        input [3:0] hex;
        begin
            if( hex < 4'd10 ) begin
                f_hex_char = 8'h30 + { 4'd0, hex };
            end
            else begin
                f_hex_char = 8'h41 + { 4'd0, (hex - 4'd10) };
            end
        end
    endfunction

    function [7:0] f_msg_char;
        input [2:0] msg_sel;
        input [4:0] msg_index;
        begin
            case( msg_sel )
            MSG_START: begin
                case( msg_index )
                5'd0:  f_msg_char = "S";
                5'd1:  f_msg_char = "T";
                5'd2:  f_msg_char = "A";
                5'd3:  f_msg_char = "R";
                5'd4:  f_msg_char = "T";
                5'd5:  f_msg_char = 8'h0D;
                5'd6:  f_msg_char = 8'h0A;
                default: f_msg_char = 8'h00;
                endcase
            end
            MSG_WR_DONE: begin
                case( msg_index )
                5'd0:  f_msg_char = "W";
                5'd1:  f_msg_char = "R";
                5'd2:  f_msg_char = "D";
                5'd3:  f_msg_char = "O";
                5'd4:  f_msg_char = "N";
                5'd5:  f_msg_char = "E";
                5'd6:  f_msg_char = 8'h0D;
                5'd7:  f_msg_char = 8'h0A;
                default: f_msg_char = 8'h00;
                endcase
            end
            MSG_PASS: begin
                case( msg_index )
                5'd0:  f_msg_char = "P";
                5'd1:  f_msg_char = "A";
                5'd2:  f_msg_char = "S";
                5'd3:  f_msg_char = "S";
                5'd4:  f_msg_char = 8'h0D;
                5'd5:  f_msg_char = 8'h0A;
                default: f_msg_char = 8'h00;
                endcase
            end
            MSG_FAIL: begin
                case( msg_index )
                5'd0:  f_msg_char = "F";
                5'd1:  f_msg_char = "A";
                5'd2:  f_msg_char = "I";
                5'd3:  f_msg_char = "L";
                5'd4:  f_msg_char = 8'h0D;
                5'd5:  f_msg_char = 8'h0A;
                default: f_msg_char = 8'h00;
                endcase
            end
            MSG_FAIL_DETAIL: begin
                case( msg_index )
                5'd0:   f_msg_char = "F";
                5'd1:   f_msg_char = "A";
                5'd2:   f_msg_char = "I";
                5'd3:   f_msg_char = "L";
                5'd4:   f_msg_char = " ";
                5'd5:   f_msg_char = "C";
                5'd6:   f_msg_char = "=";
                5'd7:   f_msg_char = ff_fail_reason;
                5'd8:   f_msg_char = " ";
                5'd9:   f_msg_char = "A";
                5'd10:  f_msg_char = "=";
                5'd11:  f_msg_char = f_hex_char( { 1'b0, ff_fail_addr[18:16] } );
                5'd12:  f_msg_char = f_hex_char( ff_fail_addr[15:12] );
                5'd13:  f_msg_char = f_hex_char( ff_fail_addr[11:8] );
                5'd14:  f_msg_char = f_hex_char( ff_fail_addr[7:4] );
                5'd15:  f_msg_char = f_hex_char( ff_fail_addr[3:0] );
                5'd16:  f_msg_char = " ";
                5'd17:  f_msg_char = "E";
                5'd18:  f_msg_char = "=";
                5'd19:  f_msg_char = f_hex_char( ff_fail_expected[7:4] );
                5'd20:  f_msg_char = f_hex_char( ff_fail_expected[3:0] );
                5'd21:  f_msg_char = " ";
                5'd22:  f_msg_char = "R";
                5'd23:  f_msg_char = "=";
                5'd24:  f_msg_char = f_hex_char( ff_fail_received[7:4] );
                5'd25:  f_msg_char = f_hex_char( ff_fail_received[3:0] );
                5'd26:  f_msg_char = 8'h0D;
                5'd27:  f_msg_char = 8'h0A;
                default: f_msg_char = 8'h00;
                endcase
            end
            default: begin
                f_msg_char = 8'h00;
            end
            endcase
        end
    endfunction

    always @( posedge clk ) begin
        if( !n_reset ) begin
            ff_state         <= ST_WAIT_DIP;
            ff_msg_sel       <= MSG_NONE;
            ff_msg_index     <= 5'd0;
            ff_state_after_msg <= ST_WAIT_DIP;
            ff_addr          <= 19'd0;
            ff_expected      <= 8'd0;
            ff_received      <= 8'd0;
            ff_fail_addr     <= 19'd0;
            ff_fail_expected <= 8'd0;
            ff_fail_received <= 8'd0;
            ff_fail_reason   <= FAIL_REASON_MISMATCH;
            ff_rd_wait_count <= 23'd0;
            ff_dipsw_init    <= dipsw;
            ff_dipsw_sync0   <= dipsw;
            ff_dipsw_sync1   <= dipsw;
            ff_dipsw_last    <= dipsw;
            ff_dipsw_stable_count <= 16'd0;
            ff_dipsw_armed   <= 1'b0;
            ff_uart_pending  <= 1'b0;
            ff_blink_count   <= 24'd0;
            bus_cs           <= 1'b0;
            bus_address      <= 19'd0;
            bus_write        <= 1'b0;
            bus_valid        <= 1'b0;
            bus_wdata        <= 8'd0;
            uart_data        <= 8'd0;
            uart_valid       <= 1'b0;
            led              <= 4'b0000;
        end
        else begin
            ff_dipsw_sync0 <= dipsw;
            ff_dipsw_sync1 <= ff_dipsw_sync0;
            ff_blink_count <= ff_blink_count + 24'd1;

            bus_cs     <= bus_cs;
            bus_valid  <= bus_valid;
			if( !ff_uart_pending ) begin
				uart_valid <= 1'b0;
			end

            case( ff_state )
            ST_WAIT_DIP: begin
                led <= 4'b0001;
                // Arm only after DIPSW is stable for a short period after boot.
                if( !ff_dipsw_armed ) begin
                    if( ff_dipsw_sync1 != ff_dipsw_last ) begin
                        ff_dipsw_last <= ff_dipsw_sync1;
                        ff_dipsw_stable_count <= 16'd0;
                    end
                    else if( ff_dipsw_stable_count != 16'hFFFF ) begin
                        ff_dipsw_stable_count <= ff_dipsw_stable_count + 16'd1;
                    end

                    if( ff_dipsw_stable_count == 16'hFFFE ) begin
                        ff_dipsw_init <= ff_dipsw_sync1;
                        ff_dipsw_armed <= 1'b1;
                    end
                end
                else if( ff_dipsw_sync1 != ff_dipsw_init ) begin
                    ff_addr <= 19'd0;
                    ff_msg_sel <= MSG_START;
                    ff_msg_index <= 5'd0;
                    ff_state_after_msg <= ST_WR_REQ;
                    ff_state <= ST_MSG_START;
                    led <= 4'b0011;
                end
            end

            ST_MSG_START,
            ST_MSG_WR_DONE,
            ST_MSG_PASS,
            ST_MSG_FAIL: begin
                if( ff_uart_pending ) begin
                    if( !uart_ready ) begin
                        ff_uart_pending <= 1'b0;
                        ff_msg_index <= ff_msg_index + 5'd1;
                    end
                end
                else if( f_msg_char( ff_msg_sel, ff_msg_index ) == 8'h00 ) begin
                    ff_state <= ff_state_after_msg;
                end
                else if( uart_ready ) begin
                    uart_data <= f_msg_char( ff_msg_sel, ff_msg_index );
                    uart_valid <= 1'b1;
                    ff_uart_pending <= 1'b1;
                end
            end

            ST_WR_REQ: begin
                bus_cs      <= 1'b1;
                bus_valid   <= 1'b1;
                bus_write   <= 1'b1;
                bus_address <= ff_addr;
                bus_wdata   <= f_test_data( ff_addr );
                ff_state    <= ST_WR_WAIT;
                led         <= 4'b0011;
            end

            ST_WR_WAIT: begin
                bus_cs      <= 1'b1;
                bus_valid   <= 1'b1;
                bus_write   <= 1'b1;
                bus_address <= ff_addr;
                bus_wdata   <= f_test_data( ff_addr );
                if( bus_ready ) begin
                    bus_cs <= 1'b0;
                    bus_valid <= 1'b0;
                    ff_state <= ST_WR_NEXT;
                end
            end

            ST_WR_NEXT: begin
                if( ff_addr == C_LAST_ADDR ) begin
                    ff_addr <= 19'd0;
                    ff_msg_sel <= MSG_WR_DONE;
                    ff_msg_index <= 5'd0;
                    ff_state_after_msg <= ST_RD_REQ;
                    ff_state <= ST_MSG_WR_DONE;
                    led <= 4'b0111;
                end
                else begin
                    ff_addr <= ff_addr + 19'd1;
                    ff_state <= ST_WR_REQ;
                end
            end

            ST_RD_REQ: begin
                bus_cs      <= 1'b1;
                bus_valid   <= 1'b1;
                bus_write   <= 1'b0;
                bus_address <= ff_addr;
                bus_wdata   <= 8'h00;
                ff_rd_wait_count <= 23'd0;
                ff_state    <= ST_RD_WAIT_READY;
                led         <= 4'b0111;
            end

            ST_RD_WAIT_READY: begin
                bus_cs      <= 1'b1;
                bus_valid   <= 1'b1;
                bus_write   <= 1'b0;
                bus_address <= ff_addr;
                bus_wdata   <= 8'h00;
                if( bus_ready ) begin
                    bus_cs <= 1'b0;
                    bus_valid <= 1'b0;
                    ff_rd_wait_count <= 23'd0;
                    ff_state <= ST_RD_WAIT_DATA;
                end
                else if( ff_rd_wait_count == C_RD_WAIT_TIMEOUT - 23'd1 ) begin
                    ff_fail_addr <= ff_addr;
                    ff_fail_expected <= f_test_data( ff_addr );
                    ff_fail_received <= bus_rdata;
                    ff_fail_reason <= FAIL_REASON_RD_READY;
                    ff_msg_sel <= MSG_FAIL_DETAIL;
                    ff_msg_index <= 5'd0;
                    ff_state_after_msg <= ST_DONE;
                    ff_state <= ST_MSG_FAIL;
                    led <= 4'b1111;
                end
                else begin
                    ff_rd_wait_count <= ff_rd_wait_count + 23'd1;
                end
            end

            ST_RD_WAIT_DATA: begin
                if( bus_rdata_en ) begin
                    ff_received <= bus_rdata;
                    ff_expected <= f_test_data( ff_addr );

                    if( bus_rdata != f_test_data( ff_addr ) ) begin
                        ff_fail_addr <= ff_addr;
                        ff_fail_expected <= f_test_data( ff_addr );
                        ff_fail_received <= bus_rdata;
                        ff_fail_reason <= FAIL_REASON_MISMATCH;
                        ff_msg_sel <= MSG_FAIL_DETAIL;
                        ff_msg_index <= 5'd0;
                        ff_state_after_msg <= ST_DONE;
                        ff_state <= ST_MSG_FAIL;
                        led <= 4'b1111;
                    end
                    else if( ff_addr == C_LAST_ADDR ) begin
                        ff_msg_sel <= MSG_PASS;
                        ff_msg_index <= 5'd0;
                        ff_state_after_msg <= ST_DONE;
                        ff_state <= ST_MSG_PASS;
                        led <= 4'b1011;
                    end
                    else begin
                        // Pack read requests back-to-back for max throughput measurement.
                        ff_addr <= ff_addr + 19'd1;
                        bus_cs <= 1'b1;
                        bus_valid <= 1'b1;
                        bus_write <= 1'b0;
                        bus_address <= ff_addr + 19'd1;
                        bus_wdata <= 8'h00;
                        ff_rd_wait_count <= 23'd0;
                        ff_state <= ST_RD_WAIT_READY;
                    end
                end
                else if( ff_rd_wait_count == C_RD_WAIT_TIMEOUT - 23'd1 ) begin
                    ff_fail_addr <= ff_addr;
                    ff_fail_expected <= f_test_data( ff_addr );
                    ff_fail_received <= bus_rdata;
                    ff_fail_reason <= FAIL_REASON_RD_DATA;
                    ff_msg_sel <= MSG_FAIL_DETAIL;
                    ff_msg_index <= 5'd0;
                    ff_state_after_msg <= ST_DONE;
                    ff_state <= ST_MSG_FAIL;
                    led <= 4'b1111;
                end
                else begin
                    ff_rd_wait_count <= ff_rd_wait_count + 23'd1;
                end
            end

            ST_RD_CHECK: begin
                ff_state <= ST_RD_REQ;
            end

            ST_RD_NEXT: begin
                ff_state <= ST_RD_REQ;
            end

            ST_DONE: begin
                // Blink only when fail, hold steady when pass.
                if( led == 4'b1111 ) begin
                    led[3] <= ff_blink_count[23];
                    led[2:0] <= 3'b111;
                end
            end

            default: begin
                ff_state <= ST_WAIT_DIP;
            end
            endcase

			if( ff_uart_pending && !uart_ready ) begin
				uart_valid <= 1'b0;
			end
        end
    end
endmodule
