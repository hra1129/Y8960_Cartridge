onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {Top Level}
add wave -noupdate -radix unsigned /tb/clk_28m
add wave -noupdate -radix unsigned /tb/clk_50m
add wave -noupdate -radix unsigned /tb/u_dut/clk_129m
add wave -noupdate -radix binary  /tb/dipsw
add wave -noupdate -radix binary  /tb/led
add wave -noupdate -divider {Reset}
add wave -noupdate -radix unsigned /tb/u_dut/w_reset_n
add wave -noupdate -radix unsigned /tb/u_dut/ff_reset_count
add wave -noupdate -divider {SRAM Interface}
add wave -noupdate -radix unsigned /tb/sram_sclk
add wave -noupdate -radix unsigned /tb/sram_ce_n
add wave -noupdate -radix hexadecimal /tb/sram_sio
add wave -noupdate -divider {DUT State Machine}
add wave -noupdate -radix unsigned /tb/u_dut/ff_state
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_addr
add wave -noupdate -radix unsigned /tb/u_dut/ff_burst_idx
add wave -noupdate -radix unsigned /tb/u_dut/ff_phase1_done
add wave -noupdate -radix unsigned /tb/u_dut/ff_phase2_done
add wave -noupdate -radix unsigned /tb/u_dut/ff_phase3_done
add wave -noupdate -radix unsigned /tb/u_dut/ff_phase4_done
add wave -noupdate -radix unsigned /tb/u_dut/ff_error1
add wave -noupdate -radix unsigned /tb/u_dut/ff_error2
add wave -noupdate -divider {SSRAM Controller}
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_address
add wave -noupdate -radix unsigned /tb/u_dut/ff_valid
add wave -noupdate -radix unsigned /tb/u_dut/w_ssram_ready
add wave -noupdate -radix unsigned /tb/u_dut/ff_write
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_wdata
add wave -noupdate -radix hexadecimal /tb/u_dut/w_ssram_rdata
add wave -noupdate -radix unsigned /tb/u_dut/w_ssram_rdata_en
add wave -noupdate -divider {Burst Write}
add wave -noupdate -radix unsigned /tb/u_dut/ff_burst_start
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_burst_address
add wave -noupdate -radix hexadecimal /tb/u_dut/ff_burst_length
add wave -noupdate -radix unsigned /tb/u_dut/w_ssram_burst_active
add wave -noupdate -radix hexadecimal /tb/u_dut/w_burst_wdata
add wave -noupdate -radix unsigned /tb/u_dut/w_burst_wdata_en
add wave -noupdate -divider {SSRAM Internal}
add wave -noupdate -radix unsigned /tb/u_dut/u_ssram/ff_state
add wave -noupdate -radix unsigned /tb/u_dut/u_ssram/ff_ready
add wave -noupdate -radix unsigned /tb/u_dut/u_ssram/ff_active
add wave -noupdate -radix unsigned /tb/u_dut/u_ssram/ff_ce_n
add wave -noupdate -radix hexadecimal /tb/u_dut/u_ssram/ff_so
add wave -noupdate -radix unsigned /tb/u_dut/u_ssram/ff_burst_mode
add wave -noupdate -radix unsigned /tb/u_dut/u_ssram/ff_burst_active
add wave -noupdate -radix hexadecimal /tb/u_dut/u_ssram/ff_burst_count
add wave -noupdate -divider {SRAM Model}
add wave -noupdate -radix unsigned /tb/u_sram_model/quad_mode
add wave -noupdate -radix hexadecimal /tb/u_sram_model/cmd
add wave -noupdate -radix hexadecimal /tb/u_sram_model/addr
add wave -noupdate -radix hexadecimal /tb/u_sram_model/wr_data
add wave -noupdate -radix hexadecimal /tb/u_sram_model/rd_data
add wave -noupdate -radix unsigned /tb/u_sram_model/count
add wave -noupdate -radix unsigned /tb/u_sram_model/driving
add wave -noupdate -radix hexadecimal /tb/u_sram_model/sio_out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 280
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 2
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {100000000 ps}
