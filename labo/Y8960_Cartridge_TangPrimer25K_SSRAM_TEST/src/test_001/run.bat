if exist work (
	rmdir /S /Q work
)
vlib work

vlog +define+SIM gowin_pll_sim.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM ..\ssram\ssram.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM ..\ssram\ssram_test_model.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM ..\y8960_cartridge_tangprimer25k.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM tb.sv
if errorlevel 1 (
	pause
	exit
)
vsim -c -t 1ps -do run.do tb
move transcript log.txt
