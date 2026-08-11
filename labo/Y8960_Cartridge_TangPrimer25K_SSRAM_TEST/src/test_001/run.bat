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
vlog +define+SIM ..\ssram_test\ssram_test.v
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
vlog +define+SIM ..\uart\ip_uart.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM ..\uart\ip_uart_inst.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM ..\cz80\cz80.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM ..\cz80\cz80_alu.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM ..\cz80\cz80_inst.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM ..\cz80\cz80_mcode.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM ..\cz80\cz80_reg.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM ..\rom\rom.v
if errorlevel 1 (
	pause
	exit
)
vlog +define+SIM ..\ram\ram.v
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
