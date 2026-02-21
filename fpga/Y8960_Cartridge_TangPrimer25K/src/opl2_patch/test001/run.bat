if exist work (
	rmdir /S /Q work
)
vlib work

vlog ..\..\adpcm\src\jt10_adpcmb.v
vlog ..\..\adpcm\src\jt10_adpcmb_cnt.v
vlog ..\..\adpcm\src\jt10_adpcmb_gain.v
vlog ..\..\adpcm\src\jt10_adpcmb_interpol.v
vlog ..\..\adpcm\src\jt10_adpcm_div.v
vlog ..\..\adpcm\src\jt10_adpcm_drvB.v

vlog ..\..\adpcm_patch\adpcm.v

vlog ..\..\opl2\src\jtopl.v
vlog ..\..\opl2\src\jtopl2.v
vlog ..\..\opl2\src\jtopl_acc.v
vlog ..\..\opl2\src\jtopl_csr.v
vlog ..\..\opl2\src\jtopl_div.v
vlog ..\..\opl2\src\jtopl_eg.v
vlog ..\..\opl2\src\jtopl_eg_cnt.v
vlog ..\..\opl2\src\jtopl_eg_comb.v
vlog ..\..\opl2\src\jtopl_eg_ctrl.v
vlog ..\..\opl2\src\jtopl_eg_final.v
vlog ..\..\opl2\src\jtopl_eg_pure.v
vlog ..\..\opl2\src\jtopl_eg_step.v
vlog ..\..\opl2\src\jtopl_exprom.v
vlog ..\..\opl2\src\jtopl_lfo.v
vlog ..\..\opl2\src\jtopl_logsin.v
vlog ..\..\opl2\src\jtopl_mmr.v
vlog ..\..\opl2\src\jtopl_noise.v
vlog ..\..\opl2\src\jtopl_op.v
vlog ..\..\opl2\src\jtopl_pg.v
vlog ..\..\opl2\src\jtopl_pg_comb.v
vlog ..\..\opl2\src\jtopl_pg_inc.v
vlog ..\..\opl2\src\jtopl_pg_rhy.v
vlog ..\..\opl2\src\jtopl_pg_sum.v
vlog ..\..\opl2\src\jtopl_pm.v
vlog ..\..\opl2\src\jtopl_reg.v
vlog ..\..\opl2\src\jtopl_reg_ch.v
vlog ..\..\opl2\src\jtopl_sh.v
vlog ..\..\opl2\src\jtopl_sh_rst.v
vlog ..\..\opl2\src\jtopl_single_acc.v
vlog ..\..\opl2\src\jtopl_slot_cnt.v
vlog ..\..\opl2\src\jtopl_timers.v

vlog ..\opl2.v
if errorlevel 1 (
	pause
	exit
)
vlog tb.sv
if errorlevel 1 (
	pause
	exit
)
vsim -c -t 1ps -do run.do tb
move transcript log.txt
