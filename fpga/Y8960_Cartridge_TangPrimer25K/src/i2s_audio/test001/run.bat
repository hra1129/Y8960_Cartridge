@echo off
if not exist work (
	vlib work
	if errorlevel 1 exit /b 1
)
vlog ..\i2s_audio.v
if errorlevel 1 exit /b 1
vlog -sv tb.sv
if errorlevel 1 exit /b 1
vsim -c -t 1ps -onfinish stop -voptargs=+acc -do run.do tb
if errorlevel 1 exit /b 1
exit /b 0
