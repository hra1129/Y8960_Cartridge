@echo off
if not exist work (
	vlib work
	if errorlevel 1 exit /b 1
)
vlog ..\..\adpcm_patch\jt10_adpcmb.v
if errorlevel 1 exit /b 1
vlog ..\..\adpcm_patch\jt10_adpcmb_cnt.v
if errorlevel 1 exit /b 1
vlog ..\..\adpcm\src\jt10_adpcmb_gain.v
if errorlevel 1 exit /b 1
vlog ..\..\adpcm_patch\jt10_adpcmb_interpol.v
if errorlevel 1 exit /b 1
if errorlevel 1 exit /b 1
vlog ..\..\adpcm_patch\jt10_adpcm_drvB.v
if errorlevel 1 exit /b 1
vlog ..\..\adpcm_patch\adpcm_lpf.v
if errorlevel 1 exit /b 1
vlog ..\..\adpcm_patch\adpcm.v
if errorlevel 1 exit /b 1
vlog ..\jtopl.v
if errorlevel 1 exit /b 1
vlog ..\jtopl2.v
if errorlevel 1 exit /b 1
vlog ..\jtopl_acc.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_csr.v
if errorlevel 1 exit /b 1
vlog +define+SIMULATION ..\..\opl2\src\jtopl_div.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_eg.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_eg_cnt.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_eg_comb.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_eg_ctrl.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_eg_final.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_eg_pure.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_eg_step.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_exprom.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_lfo.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_logsin.v
if errorlevel 1 exit /b 1
vlog ..\jtopl_mmr.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_noise.v
if errorlevel 1 exit /b 1
vlog ..\jtopl_op.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_pg.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_pg_comb.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_pg_inc.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_pg_rhy.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_pg_sum.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_pm.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_reg.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_reg_ch.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_sh.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_sh_rst.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_single_acc.v
if errorlevel 1 exit /b 1
vlog +define+SIMULATION ..\..\opl2\src\jtopl_slot_cnt.v
if errorlevel 1 exit /b 1
vlog ..\..\opl2\src\jtopl_timers.v
if errorlevel 1 exit /b 1
vlog ..\..\pan\pan_lut.v
if errorlevel 1 exit /b 1
vlog ..\opl2.v
if errorlevel 1 exit /b 1
vlog -sv tb.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ps -onfinish stop -voptargs=+acc -do run.do tb
if errorlevel 1 exit /b 1
exit /b 0
