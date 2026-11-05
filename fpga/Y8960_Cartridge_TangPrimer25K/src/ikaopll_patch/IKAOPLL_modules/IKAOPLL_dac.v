module IKAOPLL_dac (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    input   wire            i_RST_n,

    //internal clock
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //timings
    input   wire            i_DAC_EN, i_CYCLE_00, i_MO_CTRL, i_RO_CTRL, i_INHIBIT_FDBK,

    //rhythm enable
    input   wire            i_RHYTHM_EN,

    //io
    output  wire    [8:0]   o_REG_TEST_SNDDATA,
    input   wire    [8:0]   i_DAC_OPDATA,

    //DAC enables
    output  wire                o_DAC_EN_MO,
    output  wire                o_DAC_EN_RO,

    //sign+magnitude output with no zero-level fluctuation
    output  wire                o_IMP_NOFLUC_SIGN,
    output  wire        [7:0]   o_IMP_NOFLUC_MAG,

    //signed output with zero-level fluctuation
    output  wire signed [9:0]   o_IMP_FLUC_SIGNED_MO,    
    output  wire signed [9:0]   o_IMP_FLUC_SIGNED_RO,

    //"accumulated" output
    input   wire signed [4:0]   i_ACC_SIGNED_MOVOL,
    input   wire signed [4:0]   i_ACC_SIGNED_ROVOL,
    input   wire        [7:0]   i_PAN,
    output  reg                 o_ACC_SIGNED_STRB,
    output  reg  signed [15:0]  o_ACC_SIGNED_L,
    output  reg  signed [15:0]  o_ACC_SIGNED_R
);


/*
    OP output
    5:  CH1 CAR
    8:  CH2 CAR
    9:  CH3 CAR
    13: CH4 CAR
    16: CH5 CAR
    17: CH6 CAR

    /FM 3ch
    21: CH7 CAR
    0:  CH8 CAR
    1:  CH9 CAR

    //precussion 5ch
    19: CH8 MOD
    20: CH9 MOD
    21: CH7 CAR
    22: CH8 CAR
    0:  CH9 CAR
*/


///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            phi1ncen_n = i_phi1_NCEN_n;



///////////////////////////////////////////////////////////
//////  Percussion sample storage
////

wire            perc_sr_shift_n = ~(~i_RHYTHM_EN | i_RO_CTRL) & i_RST_n;
wire    [8:0]   perc_sr_q;
wire    [8:0]   perc_sr_d = i_INHIBIT_FDBK ? ((i_RHYTHM_EN & i_RST_n) ? perc_sr_q : 9'd0) : i_DAC_OPDATA;

IKAOPLL_sr #(.WIDTH(9), .LENGTH(5)) u_percussion_sr
(.i_EMUCLK(emuclk), .i_CEN_n(phi1ncen_n | perc_sr_shift_n), .i_D(perc_sr_d), .o_Q_LAST(perc_sr_q),
 .o_Q_TAP0(), .o_Q_TAP1(), .o_Q_TAP2());



///////////////////////////////////////////////////////////
//////  Impulse DAC(1-bit sign + 8-bit magnitude)
////

//latch sign+magnitude
reg     [8:0]   snddata_signmag;
assign  o_REG_TEST_SNDDATA = snddata_signmag;
always @(posedge emuclk) if(!phi1ncen_n) begin
    snddata_signmag[8] <= perc_sr_d[8];
    snddata_signmag[7:0] <= perc_sr_d[8] ? ~perc_sr_d[7:0] : perc_sr_d[7:0];
end

//impulse control
reg             mo_ctrl_z, ro_ctrl_z;
wire            fm_dac_en = mo_ctrl_z & i_DAC_EN;
wire            perc_dac_en = ro_ctrl_z & i_DAC_EN;
assign  o_DAC_EN_MO = fm_dac_en;
assign  o_DAC_EN_RO = perc_dac_en;
always @(posedge emuclk) if(!phi1ncen_n) begin
    mo_ctrl_z <= i_MO_CTRL;
    ro_ctrl_z <= i_RO_CTRL;
end

//dac - no fluctuation
assign  o_IMP_NOFLUC_SIGN = snddata_signmag[8];
assign  o_IMP_NOFLUC_MAG = snddata_signmag[7:0];

//dac
wire signed [9:0]   dac_out = snddata_signmag[8] ? {2'b11, ~snddata_signmag[7:0]}: {2'b00, snddata_signmag[7:0]} + 10'b1;
wire signed [9:0]   dac_zlv = snddata_signmag[8] ? 10'h3FF : 10'h1; //zero level
assign  o_IMP_FLUC_SIGNED_MO = fm_dac_en   ? dac_out : dac_zlv;
assign  o_IMP_FLUC_SIGNED_RO = perc_dac_en ? dac_out : dac_zlv;



///////////////////////////////////////////////////////////
//////  Accumulation DAC(16-bit signed)
////

reg         [2:0]   cyc0_dly;
reg                 dac_acc_en;
reg         [7:0]   pan_dly[0:2];
reg         [7:0]   pan_z;
reg signed  [16:0]  dac_acc_l;
reg signed  [16:0]  dac_acc_r;
wire signed [8:0]   dac_acc_sample = $signed(snddata_signmag[8] ? {1'b1, ~snddata_signmag[7:0]} : {1'b0, snddata_signmag[7:0]});
wire signed [4:0]   dac_acc_volume = ro_ctrl_z ? i_ACC_SIGNED_ROVOL : i_ACC_SIGNED_MOVOL;
wire signed [13:0]  dac_acc_mono = dac_acc_sample * dac_acc_volume;
wire        [8:0]   dac_acc_gain_l;
wire        [8:0]   dac_acc_gain_r;
wire signed [23:0]  dac_acc_product_l = dac_acc_mono * $signed({1'b0, dac_acc_gain_l});
wire signed [23:0]  dac_acc_product_r = dac_acc_mono * $signed({1'b0, dac_acc_gain_r});
wire signed [16:0]  dac_acc_sample_l = dac_acc_product_l >>> 8;
wire signed [16:0]  dac_acc_sample_r = dac_acc_product_r >>> 8;
//  The real chip outputs every rhythm sample twice on RO (the percussion shift
//  register replays it in the modulator slots), so rhythm has twice the gain of
//  melody at the pins. The replay slots carry the PAN of melody channels, so
//  they are not accumulated here; instead the rhythm sample is doubled.
wire signed [16:0]  dac_acc_add_l = ro_ctrl_z ? (dac_acc_sample_l <<< 1) : dac_acc_sample_l;
wire signed [16:0]  dac_acc_add_r = ro_ctrl_z ? (dac_acc_sample_r <<< 1) : dac_acc_sample_r;

pan_lut u_pan_lut (
    .i_clk      ( emuclk           ),
    .i_pan      ( pan_z            ),
    .o_gain_l   ( dac_acc_gain_l   ),
    .o_gain_r   ( dac_acc_gain_r   )
);
always @(posedge emuclk) if(!phi1ncen_n) begin
    if(!i_RST_n) begin
        pan_dly[0] <= 8'd128;
        pan_dly[1] <= 8'd128;
        pan_dly[2] <= 8'd128;
        pan_z <= 8'd128;
    end
    else begin
        pan_dly[0] <= i_PAN;
        pan_dly[1] <= pan_dly[0];
        pan_dly[2] <= pan_dly[1];
        pan_z <= pan_dly[2];
    end
end

always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc0_dly[0] <= i_CYCLE_00;
    cyc0_dly[2:1] <= cyc0_dly[1:0];

    dac_acc_en <= ~i_INHIBIT_FDBK;
    
    if(cyc0_dly[2]) begin
        dac_acc_l <= 17'sd0;
        dac_acc_r <= 17'sd0;

             if(dac_acc_l >  17'sd32767) o_ACC_SIGNED_L <= 16'sd32767;
        else if(dac_acc_l < -17'sd32768) o_ACC_SIGNED_L <= -16'sd32768;
        else o_ACC_SIGNED_L <= dac_acc_l[15:0];

             if(dac_acc_r >  17'sd32767) o_ACC_SIGNED_R <= 16'sd32767;
        else if(dac_acc_r < -17'sd32768) o_ACC_SIGNED_R <= -16'sd32768;
        else o_ACC_SIGNED_R <= dac_acc_r[15:0];
    end
    else begin if(dac_acc_en) begin
        dac_acc_l <= dac_acc_l + dac_acc_add_l;
        dac_acc_r <= dac_acc_r + dac_acc_add_r;
    end end
end

reg     [4:0]   dac_acc_outcyc;
always @(posedge emuclk) if(!phi1ncen_n) begin
    if(cyc0_dly[2]) dac_acc_outcyc <= 5'd0;
    else dac_acc_outcyc <= dac_acc_outcyc + 5'd1;

    if(dac_acc_outcyc == 5'd1) o_ACC_SIGNED_STRB <= 1'b1;
    else if(dac_acc_outcyc == 5'd10) o_ACC_SIGNED_STRB <= 1'b0;
end

endmodule