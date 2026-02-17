rmdir /S /Q work
vlib work
vlog ..\adpcm\src\jt10_adpcm_drvB.v
vlog ..\adpcm\src\jt10_adpcmb.v
vlog ..\adpcm\src\jt10_adpcmb_cnt.v
vlog ..\adpcm\src\jt10_adpcmb_gain.v
vlog ..\adpcm\src\jt10_adpcmb_interpol.v
vlog ..\adpcm\src\jt10_adpcm_div.v
vlog tb.sv
vsim -c -t 1ns -do run.do tb
move transcript log.txt
pause
