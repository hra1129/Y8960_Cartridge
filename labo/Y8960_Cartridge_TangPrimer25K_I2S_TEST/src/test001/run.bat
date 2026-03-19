vlib work
vlog ..\y8960_cartridge_tangprimer25k.v
vlog ..\sound\sound.v
vlog ..\i2s_audio\i2s_audio.v
vlog tb.sv
vsim -c -t 1ps -do run.do tb
move transcript log.txt
pause
