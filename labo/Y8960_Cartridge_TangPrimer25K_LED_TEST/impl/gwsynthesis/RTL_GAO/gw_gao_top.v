module gw_gao(
    \dipsw[1] ,
    \ff_cnt28[24] ,
    \ff_cnt28[23] ,
    \ff_cnt28[22] ,
    \ff_cnt28[21] ,
    \ff_cnt28[20] ,
    \ff_cnt28[19] ,
    \ff_cnt28[18] ,
    \ff_cnt28[17] ,
    \ff_cnt28[16] ,
    \ff_cnt28[15] ,
    \ff_cnt28[14] ,
    \ff_cnt28[13] ,
    \ff_cnt28[12] ,
    \ff_cnt28[11] ,
    \ff_cnt28[10] ,
    \ff_cnt28[9] ,
    \ff_cnt28[8] ,
    \ff_cnt28[7] ,
    \ff_cnt28[6] ,
    \ff_cnt28[5] ,
    \ff_cnt28[4] ,
    \ff_cnt28[3] ,
    \ff_cnt28[2] ,
    \ff_cnt28[1] ,
    \ff_cnt28[0] ,
    clk_28m,
    tms_pad_i,
    tck_pad_i,
    tdi_pad_i,
    tdo_pad_o
);

input \dipsw[1] ;
input \ff_cnt28[24] ;
input \ff_cnt28[23] ;
input \ff_cnt28[22] ;
input \ff_cnt28[21] ;
input \ff_cnt28[20] ;
input \ff_cnt28[19] ;
input \ff_cnt28[18] ;
input \ff_cnt28[17] ;
input \ff_cnt28[16] ;
input \ff_cnt28[15] ;
input \ff_cnt28[14] ;
input \ff_cnt28[13] ;
input \ff_cnt28[12] ;
input \ff_cnt28[11] ;
input \ff_cnt28[10] ;
input \ff_cnt28[9] ;
input \ff_cnt28[8] ;
input \ff_cnt28[7] ;
input \ff_cnt28[6] ;
input \ff_cnt28[5] ;
input \ff_cnt28[4] ;
input \ff_cnt28[3] ;
input \ff_cnt28[2] ;
input \ff_cnt28[1] ;
input \ff_cnt28[0] ;
input clk_28m;
input tms_pad_i;
input tck_pad_i;
input tdi_pad_i;
output tdo_pad_o;

wire \dipsw[1] ;
wire \ff_cnt28[24] ;
wire \ff_cnt28[23] ;
wire \ff_cnt28[22] ;
wire \ff_cnt28[21] ;
wire \ff_cnt28[20] ;
wire \ff_cnt28[19] ;
wire \ff_cnt28[18] ;
wire \ff_cnt28[17] ;
wire \ff_cnt28[16] ;
wire \ff_cnt28[15] ;
wire \ff_cnt28[14] ;
wire \ff_cnt28[13] ;
wire \ff_cnt28[12] ;
wire \ff_cnt28[11] ;
wire \ff_cnt28[10] ;
wire \ff_cnt28[9] ;
wire \ff_cnt28[8] ;
wire \ff_cnt28[7] ;
wire \ff_cnt28[6] ;
wire \ff_cnt28[5] ;
wire \ff_cnt28[4] ;
wire \ff_cnt28[3] ;
wire \ff_cnt28[2] ;
wire \ff_cnt28[1] ;
wire \ff_cnt28[0] ;
wire clk_28m;
wire tms_pad_i;
wire tck_pad_i;
wire tdi_pad_i;
wire tdo_pad_o;
wire tms_i_c;
wire tck_i_c;
wire tdi_i_c;
wire tdo_o_c;
wire [9:0] control0;
wire gao_jtag_tck;
wire gao_jtag_reset;
wire run_test_idle_er1;
wire run_test_idle_er2;
wire shift_dr_capture_dr;
wire update_dr;
wire pause_dr;
wire enable_er1;
wire enable_er2;
wire gao_jtag_tdi;
wire tdo_er1;

IBUF tms_ibuf (
    .I(tms_pad_i),
    .O(tms_i_c)
);

IBUF tck_ibuf (
    .I(tck_pad_i),
    .O(tck_i_c)
);

IBUF tdi_ibuf (
    .I(tdi_pad_i),
    .O(tdi_i_c)
);

OBUF tdo_obuf (
    .I(tdo_o_c),
    .O(tdo_pad_o)
);

GW_JTAG  u_gw_jtag(
    .tms_pad_i(tms_i_c),
    .tck_pad_i(tck_i_c),
    .tdi_pad_i(tdi_i_c),
    .tdo_pad_o(tdo_o_c),
    .tck_o(gao_jtag_tck),
    .test_logic_reset_o(gao_jtag_reset),
    .run_test_idle_er1_o(run_test_idle_er1),
    .run_test_idle_er2_o(run_test_idle_er2),
    .shift_dr_capture_dr_o(shift_dr_capture_dr),
    .update_dr_o(update_dr),
    .pause_dr_o(pause_dr),
    .enable_er1_o(enable_er1),
    .enable_er2_o(enable_er2),
    .tdi_o(gao_jtag_tdi),
    .tdo_er1_i(tdo_er1),
    .tdo_er2_i(1'b0)
);

gw_con_top  u_icon_top(
    .tck_i(gao_jtag_tck),
    .tdi_i(gao_jtag_tdi),
    .tdo_o(tdo_er1),
    .rst_i(gao_jtag_reset),
    .control0(control0[9:0]),
    .enable_i(enable_er1),
    .shift_dr_capture_dr_i(shift_dr_capture_dr),
    .update_dr_i(update_dr)
);

ao_top_0  u_la0_top(
    .control(control0[9:0]),
    .trig0_i(\dipsw[1] ),
    .data_i({\dipsw[1] ,\ff_cnt28[24] ,\ff_cnt28[23] ,\ff_cnt28[22] ,\ff_cnt28[21] ,\ff_cnt28[20] ,\ff_cnt28[19] ,\ff_cnt28[18] ,\ff_cnt28[17] ,\ff_cnt28[16] ,\ff_cnt28[15] ,\ff_cnt28[14] ,\ff_cnt28[13] ,\ff_cnt28[12] ,\ff_cnt28[11] ,\ff_cnt28[10] ,\ff_cnt28[9] ,\ff_cnt28[8] ,\ff_cnt28[7] ,\ff_cnt28[6] ,\ff_cnt28[5] ,\ff_cnt28[4] ,\ff_cnt28[3] ,\ff_cnt28[2] ,\ff_cnt28[1] ,\ff_cnt28[0] }),
    .clk_i(clk_28m)
);

endmodule
