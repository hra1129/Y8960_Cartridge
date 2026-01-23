if exist work (
	rmdir /S /Q work
)
vlib work

vlog ..\ikaopll\src\IKAOPLL.v
vlog ..\ikaopll\src\IKAOPLL_modules\IKAOPLL_dac.v
vlog ..\ikaopll\src\IKAOPLL_modules\IKAOPLL_eg.v
vlog ..\ikaopll\src\IKAOPLL_modules\IKAOPLL_lfo.v
vlog ..\ikaopll\src\IKAOPLL_modules\IKAOPLL_op.v
vlog ..\ikaopll\src\IKAOPLL_modules\IKAOPLL_pg.v
vlog ..\ikaopll\src\IKAOPLL_modules\IKAOPLL_primitives.v
vlog ..\ikaopll\src\IKAOPLL_modules\IKAOPLL_reg.v
vlog ..\ikaopll\src\IKAOPLL_modules\IKAOPLL_timinggen.v
vlog ..\ikaopll_patch\IKAOPLL_reg.v
vlog ..\ikaopll_patch\opll.v

vlog ..\ikascc\src\IKASCC.v
vlog ..\ikascc\src\IKASCC_modules\IKASCC_player_a.v
vlog ..\ikascc\src\IKASCC_modules\IKASCC_player_s.v
vlog ..\ikascc\src\IKASCC_modules\IKASCC_primitives.v
vlog ..\ikascc\src\IKASCC_modules\IKASCC_vrc_a.v
vlog ..\ikascc\src\IKASCC_modules\IKASCC_vrc_s.v
vlog ..\ikascc_patch\scc.v

vlog ..\opl2\src\jtopl.v
vlog ..\opl2\src\jtopl2.v
vlog ..\opl2\src\jtopl_acc.v
vlog ..\opl2\src\jtopl_csr.v
vlog ..\opl2\src\jtopl_div.v
vlog ..\opl2\src\jtopl_eg.v
vlog ..\opl2\src\jtopl_eg_cnt.v
vlog ..\opl2\src\jtopl_eg_comb.v
vlog ..\opl2\src\jtopl_eg_ctrl.v
vlog ..\opl2\src\jtopl_eg_final.v
vlog ..\opl2\src\jtopl_eg_pure.v
vlog ..\opl2\src\jtopl_eg_step.v
vlog ..\opl2\src\jtopl_exprom.v
vlog ..\opl2\src\jtopl_lfo.v
vlog ..\opl2\src\jtopl_logsin.v
vlog ..\opl2\src\jtopl_mmr.v
vlog ..\opl2\src\jtopl_noise.v
vlog ..\opl2\src\jtopl_op.v
vlog ..\opl2\src\jtopl_pg.v
vlog ..\opl2\src\jtopl_pg_comb.v
vlog ..\opl2\src\jtopl_pg_inc.v
vlog ..\opl2\src\jtopl_pg_rhy.v
vlog ..\opl2\src\jtopl_pg_sum.v
vlog ..\opl2\src\jtopl_pm.v
vlog ..\opl2\src\jtopl_reg.v
vlog ..\opl2\src\jtopl_reg_ch.v
vlog ..\opl2\src\jtopl_sh.v
vlog ..\opl2\src\jtopl_sh_rst.v
vlog ..\opl2\src\jtopl_single_acc.v
vlog ..\opl2\src\jtopl_slot_cnt.v
vlog ..\opl2\src\jtopl_timers.v
vlog ..\opl2_patch\opl2.v

vlog ..\i2s_audio\i2s_audio.v
if errorlevel 1 (
	pause
	exit
)
vlog ..\msx_slot\msx_slot.v
if errorlevel 1 (
	pause
	exit
)
vlog ..\timer\msx_timer_core.v
if errorlevel 1 (
	pause
	exit
)
vlog ..\timer\msx_timer.v
if errorlevel 1 (
	pause
	exit
)
vlog ..\ssg\ssg_core.v
if errorlevel 1 (
	pause
	exit
)
vlog ..\ssg\dual_ssg.v
if errorlevel 1 (
	pause
	exit
)
vlog ..\y8960_cartridge_tangprimer25k.v
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
pause
