onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/u_i2s_audio/clk
add wave -noupdate /tb/u_i2s_audio/reset_n
add wave -noupdate -radix hexadecimal /tb/u_i2s_audio/sound_l_in
add wave -noupdate -radix hexadecimal /tb/u_i2s_audio/sound_r_in
add wave -noupdate -radix unsigned /tb/u_i2s_audio/sample_request
add wave -noupdate -radix unsigned /tb/u_i2s_audio/i2s_audio_din
add wave -noupdate -radix unsigned /tb/u_i2s_audio/i2s_audio_lrclk
add wave -noupdate -radix unsigned /tb/u_i2s_audio/i2s_audio_bclk
add wave -noupdate -radix unsigned /tb/u_i2s_audio/ff_bclk_count
add wave -noupdate -radix unsigned /tb/u_i2s_audio/ff_bit_count
add wave -noupdate -radix unsigned /tb/u_i2s_audio/w_frame_start
add wave -noupdate -radix hexadecimal /tb/u_i2s_audio/ff_frame_r
add wave -noupdate -radix hexadecimal /tb/u_i2s_audio/ff_shift_reg
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0} {{Cursor 2} {10000000 ps} 0}
quietly wave cursor active 2
configure wave -namecolwidth 192
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
WaveRestoreZoom {0 ps} {30000000 ps}
