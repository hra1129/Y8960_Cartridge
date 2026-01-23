// --------------------------------------------------------------------
//	IKASCC Wrapper
// ====================================================================
//	2026/01/22 t.hara
// --------------------------------------------------------------------

module scc (
	input			reset_n,
	input			clk,			//	base clock
	input			enable,			//	3.579545MHz
	input			bus_memreq,
	input	[15:0]	bus_address,
	input			bus_write,
	output			bus_ready,
    input           bus_valid,
	input	[7:0]	bus_wdata,
	output	[7:0]	bus_rdata,
	output			bus_rdata_en,
	output			scc_memory_cs,
	output	[18:13]	scc_ma,
	output	[10:0]	sound_out		//	signed
);
	wire			w_cs_n;
	wire			w_wr_n;
	wire			w_rd_n;
	wire	[10:0]	w_sound_out;

	// --------------------------------------------------------------------
	//	Address decode
	// --------------------------------------------------------------------
	assign w_cs_n		= bus_memreq & bus_valid;
	assign bus_ready	= w_cs_n & enable;

	assign w_wr_n		= ~bus_write;
	assign w_rd_n		= bus_write;

	// --------------------------------------------------------------------
	//	IKASCC body
	// --------------------------------------------------------------------
	IKASCC #(
		.IMPL_TYPE				( 0						),
		.RAM_BLOCK				( 1						)
	) u_ikascc (
		.i_EMUCLK				( clk					),
		.i_MCLK_PCEN_n			( enable				),
		.i_RST_n				( reset_n				),
		.i_CS_n					( w_cs_n				),
		.i_RD_n					( w_rd_n				),
		.i_WR_n					( w_wr_n				),
		.i_ABLO					( bus_address[7:0]		),
		.i_ABHI					( bus_address[15:11]	),
		.i_DB					( bus_wdata				),
		.o_DB					( bus_rdata				),
		.o_DB_OE				( bus_rdata_en			),
		.o_ROMCS_n				( scc_memory_cs			),
		.o_ROMADDR				( scc_ma				),
		.o_SOUND				( sound_out	    		),
		.o_TEST					(						)
	);
endmodule
