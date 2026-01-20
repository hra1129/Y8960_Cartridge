if exist work (
	rmdir /S /Q work
)
vlib work
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
