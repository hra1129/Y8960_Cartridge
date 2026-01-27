// ---------------------------------------------------------
//	input   wire    [7:0]   i_ABLO, //address bus low(AB7:0), for the SCC
//	input   wire    [4:0]   i_ABHI, //address bus high(AB15:11), for the mapper
//	Patch Contents
//	(1) SCC Compatible Mode
//		Bank Registers
//			5000h-57FFh ... BANK0
//			7000h-77FFh ... BANK1
//			9000h-97FFh ... BANK2
//			B000h-B7FFh ... BANK3
//			(!) BANK0...3 is ROM only
//	(2) Y8960 Mode
//		Bank Registers
//			4FFBh (48FB, 49FB ... 4EFBh is mirror) ... mode register
//			4FFCh (48FC, 48FC ... 4EFCh is mirror) ... BANK0
//			4FFDh (48FD, 48FD ... 4EFDh is mirror) ... BANK1
//			4FFEh (48FE, 48FE ... 4EFEh is mirror) ... BANK2
//			4FFFh (48FF, 48FF ... 4EFFh is mirror) ... BANK3
//			(!) BANK0 is ROM only
//
//	BANK#0-#7 .... ROM
//	BANK#8-#15 ... RAM
// ---------------------------------------------------------

module IKASCC_vrc_s #(parameter RAMCTRL_ASYNC = 0) (
	//chip clock
	input	wire			i_EMUCLK, //emulator master clock

	//clock endables
	input	wire			i_MCLK_PCEN_n, //phiM positive edge clock enable(negative logic)

	//reset
	input	wire			i_RST_n, //synchronous reset

	//vrc decoder
	input	wire			i_CS_n, //asynchronous bus control signal
	input	wire			i_RD_n, 

	//SCC mapper output
	output	wire			o_ROMCS_n,
	output	reg		[5:0]	o_ROMADDR,

	//vrc register
	input	wire			i_WRRQ, //synchronous write request
	input	wire	[7:0]	i_DB,
	input	wire	[4:0]	i_ABHI,
	input	wire	[7:0]	i_ABLO,

	//SCC sound register enable
	output	reg				o_SCCREG_EN
);



///////////////////////////////////////////////////////////
//////	Clock and reset
////

wire			emuclk = i_EMUCLK;
wire			mclkpcen_n = i_MCLK_PCEN_n;
wire			rst_n = i_RST_n;



///////////////////////////////////////////////////////////
//////	ROM bank registers
////

assign	o_ROMCS_n = i_CS_n;

//synchronizer
reg		[7:0]	db_z;
reg		[4:0]	abhi_z;
reg		[7:0]	ablo_z;
always @(posedge emuclk) if(!mclkpcen_n) begin
	db_z   <= i_DB;
	abhi_z <= i_ABHI;
	ablo_z <= i_ABLO;
end

reg		[5:0]	bankreg0, bankreg1, bankreg2, bankreg3;
reg				rammode;
always @(posedge emuclk) begin
	if(!rst_n) begin
		rammode  <= 1'b0;
		bankreg0 <= 6'h00;
		bankreg1 <= 6'h01;
		bankreg2 <= 6'h02;
		bankreg3 <= 6'h03;
	end
	else begin if(!mclkpcen_n) begin
		if(i_WRRQ && abhi_z[4:0] == 5'b0100_1) begin
			if( ablo_z == 8'hFB ) begin		  // MR, 0x4?FB (? is 8,9,A,B,C,D,E,F)
				rammode <= db_z[0];
			end
			else if( ablo_z[7:2] == 6'b1111_11 && rammode ) begin
				case(ablo_z[1:0])
				2'b00: bankreg0 <= db_z[5:0]; //BR0, 0x4?FC (? is 8,9,A,B,C,D,E,F)
				2'b01: bankreg1 <= db_z[5:0]; //BR1, 0x4?FD (? is 8,9,A,B,C,D,E,F)
				2'b10: bankreg2 <= db_z[5:0]; //BR2, 0x4?FE (? is 8,9,A,B,C,D,E,F)
				2'b11: bankreg3 <= db_z[5:0]; //BR3, 0x4?FF (? is 8,9,A,B,C,D,E,F)
				default: ;
				endcase
			end
		end
		else if(i_WRRQ && abhi_z[1:0] == 2'b10 && !rammode) begin
			case(abhi_z[4:2])
				3'b010: bankreg0 <= db_z[5:0]; //BR0, 0x5000-0x57FF
				3'b011: bankreg1 <= db_z[5:0]; //BR1, 0x7000-0x77FF
				3'b100: bankreg2 <= db_z[5:0]; //BR2, 0x9000-0x97FF
				3'b101: bankreg3 <= db_z[5:0]; //BR3, 0xB000-0xB7FF
				default: ;
			endcase
		end
	end end
end



///////////////////////////////////////////////////////////
//////	Bank register output select
////

always @(*) begin
	case({~i_ABHI[3], i_ABHI[2]})
		2'b00: o_ROMADDR = { rammode, bankreg0[4:0] };
		2'b01: o_ROMADDR = { rammode, bankreg1[4:0] };
		2'b10: o_ROMADDR = { rammode, bankreg2[4:0] };
		2'b11: o_ROMADDR = { rammode, bankreg3[4:0] };
	endcase
end



///////////////////////////////////////////////////////////
//////	SCC register enable
////

generate
if(RAMCTRL_ASYNC == 0) begin : ramctrl_sync
always @(posedge emuclk) if(!mclkpcen_n) o_SCCREG_EN = (bankreg2 == 6'h3F) & (i_ABHI == 5'b10011); //synchronized
end
else begin : ramctrl_async
always @(*) o_SCCREG_EN = (bankreg2 == 6'h3F) & (i_ABHI == 5'b10011);
end
endgenerate



endmodule