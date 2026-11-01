@echo off
if exist work (
	rmdir /S /Q work
)
vlib work
vlog ..\..\adpcm\src\jt10_adpcm_drvB.v
vlog ..\..\adpcm\src\jt10_adpcmb.v
vlog ..\jt10_adpcmb_cnt.v
vlog ..\..\adpcm\src\jt10_adpcmb_gain.v
vlog ..\..\adpcm\src\jt10_adpcmb_interpol.v
vlog ..\..\adpcm\src\jt10_adpcm_div.v
vlog ..\..\pan\pan_lut.v
vlog ..\adpcm.v
if errorlevel 1 exit /b 1
vlog -sv tb.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ps -do run.do tb
move /Y transcript log.txt