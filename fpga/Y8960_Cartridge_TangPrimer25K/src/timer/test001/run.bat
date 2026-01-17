vlib work
vlog ..\msx_timer_core.v
vlog ..\msx_timer.v
vlog tb.sv
vsim -c -t 1ps -do run.do tb
move transcript log.txt
pause
