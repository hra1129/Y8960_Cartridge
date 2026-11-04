; -----------------------------------------------------------------------------
;   SCCDIAG [Y8960 SCC diagnostic]
;
;   1. Writes a sawtooth to the wave RAM of SCC ch.A and reads it back.
;   2. Plays ch.A (about 440Hz, volume 15) for about 3 seconds.
;   3. Prints the read back data.
;
;   Build:
;       zma sccdiag.asm SCCDIAG.COM
; -----------------------------------------------------------------------------

BDOS			:= 0x0005
_TERM0			:= 0x00
_CONOUT			:= 0x02
RDSLT			:= 0x000C
WRSLT			:= 0x0014
ENASLT			:= 0x0024
RAMAD1			:= 0xF342
RAMAD2			:= 0xF343
EXPTBL			:= 0xFCC1
VDP_STATUS		:= 0x99

SC_ENABLER		:= 0x40
SC_DEVSEL		:= 0x41
SC_ENABLE_KEY	:= 0x80
SC_ENABLED		:= 0x7F
SC_DEVICE_ID	:= 0x02
SC_DEVICE_ACK	:= 0xFD

EN2_OPL2		:= 0x01
EN2_OPM			:= 0x04
OPL_ADDR		:= 0xC0

MIXER_SCC		:= 0x7FFA
SCC_BANK2		:= 0x9000
SCC_BANK2_RM	:= 0x4FFE
SCC_WAVE		:= 0x9800
SCC_FREQ		:= 0x9880
SCC_VOLUME		:= 0x988A
SCC_ENABLE		:= 0x988F

PLAY_FRAMES		:= 180

			org		0x100
			scope	entry_point
entry_point::
			ld		de, title_message
			call	puts

			call	sc_detect
			ld		de, not_detected_message
			jp		c, puts_and_exit

			call	find_slot
			ld		de, slot_error_message
			jp		c, puts_and_exit

			ld		de, playing_message
			call	puts

			di
			call	map_cartridge

			ld		hl, MIXER_SCC
			ld		[hl], 0x80

			ld		hl, SCC_BANK2_RM	; RAM Mode=1 (left by the Y8960 BIOS)
			ld		[hl], 0x3F
			ld		hl, SCC_BANK2		; RAM Mode=0
			ld		[hl], 0x3F

			ld		hl, SCC_WAVE
			ld		a, 0x80
			ld		b, 32
wave_loop:
			ld		[hl], a
			inc		hl
			add		a, 8
			djnz	wave_loop

			ld		hl, SCC_WAVE
			ld		de, readback
			ld		bc, 32
			ldir

			ld		hl, SCC_FREQ
			ld		[hl], 0xFD
			inc		hl
			ld		[hl], 0x00
			ld		hl, SCC_VOLUME
			ld		[hl], 0x0F
			ld		hl, SCC_ENABLE
			ld		[hl], 0x01

			ld		b, PLAY_FRAMES
play_loop:
			call	wait_vsync
			djnz	play_loop

			ld		hl, SCC_VOLUME
			ld		[hl], 0x00
			ld		hl, SCC_ENABLE
			ld		[hl], 0x00
			ld		hl, SCC_BANK2
			ld		[hl], 0x02
			ld		hl, SCC_BANK2_RM
			ld		[hl], 0x02

			call	unmap_cartridge
			ei

			ld		de, readback_message
			call	puts
			ld		hl, readback
			ld		c, 0				; C = number of errors
			ld		a, 0x80
			ld		[expect], a
			ld		b, 32
dump_loop:
			ld		a, [expect]
			cp		a, [hl]
			jr		z, match
			inc		c
match:
			add		a, 8
			ld		[expect], a
			ld		a, [hl]
			push	bc
			push	hl
			call	puthex
			ld		a, ' '
			call	putc
			pop		hl
			pop		bc
			ld		a, b
			and		a, 0x07
			cp		a, 1
			jr		nz, no_crlf
			push	bc
			push	hl
			ld		de, crlf_message
			call	puts
			pop		hl
			pop		bc
no_crlf:
			inc		hl
			djnz	dump_loop

			ld		a, c
			or		a, a
			ld		de, ok_message
			jp		z, puts_and_exit
			ld		de, ng_message
			jp		puts_and_exit
			endscope

			scope	puts_and_exit
puts_and_exit::
			call	puts
			ld		c, _TERM0
			jp		BDOS
			endscope

; -----------------------------------------------------------------------------
; sc_detect: Cf = 1 if the System Controller is not detected
; -----------------------------------------------------------------------------
			scope	sc_detect
sc_detect::
			ld		a, SC_ENABLE_KEY
			out		[SC_ENABLER], a
			in		a, [SC_ENABLER]
			cp		a, SC_ENABLED
			jr		nz, not_detected
			ld		a, SC_DEVICE_ID
			out		[SC_DEVSEL], a
			in		a, [SC_DEVSEL]
			cp		a, SC_DEVICE_ACK
			jr		nz, not_detected
			or		a, a
			ret
not_detected:
			xor		a, a
			out		[SC_ENABLER], a
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; find_slot: same search as CANCAN. cur_slot = slot of the cartridge.
; output: Cf = 1 if not found
; -----------------------------------------------------------------------------
			scope	find_slot
find_slot::
			ld		b, 0
prim_loop:
			ld		hl, EXPTBL
			ld		c, b
			ld		b, 0
			add		hl, bc
			ld		b, c
			ld		a, [hl]
			and		a, 0x80
			jr		nz, expanded
			ld		a, b
			ld		[cur_slot], a
			push	bc
			call	try_slot
			pop		bc
			ret		nc
			jr		next_prim
expanded:
			ld		c, 0
sub_loop:
			ld		a, c
			rlca
			rlca
			and		a, 0x0C
			or		a, b
			or		a, 0x80
			ld		[cur_slot], a
			push	bc
			call	try_slot
			pop		bc
			ret		nc
			inc		c
			ld		a, c
			cp		a, 4
			jr		nz, sub_loop
next_prim:
			inc		b
			ld		a, b
			cp		a, 4
			jr		nz, prim_loop
			scf
			ret

try_slot:
			ld		a, [cur_slot]
			ld		hl, 0x4000
			call	RDSLT
			cp		a, 'A'
			scf
			ret		nz
			ld		a, [cur_slot]
			ld		hl, 0x4001
			call	RDSLT
			cp		a, 'B'
			scf
			ret		nz
			ld		a, [cur_slot]
			ld		hl, 0x7FFF
			call	RDSLT
			ld		[saved_en2], a
			or		a, EN2_OPL2 | EN2_OPM
			ld		e, a
			ld		a, [cur_slot]
			ld		hl, 0x7FFF
			call	WRSLT
			ld		a, [cur_slot]
			ld		hl, 0x7FFF
			call	RDSLT
			and		a, EN2_OPL2 | EN2_OPM
			cp		a, EN2_OPL2 | EN2_OPM
			jr		nz, restore_fail
			in		a, [OPL_ADDR]
			and		a, 0x07
			cp		a, 0x06
			jr		z, found
restore_fail:
			ld		a, [saved_en2]
			ld		e, a
			ld		a, [cur_slot]
			ld		hl, 0x7FFF
			call	WRSLT
			scf
			ret
found:
			or		a, a
			ret
			endscope

			scope	map_cartridge
map_cartridge::
			ld		a, [cur_slot]
			ld		h, 0x40
			call	ENASLT
			ld		a, [cur_slot]
			ld		h, 0x80
			jp		ENASLT
			endscope

			scope	unmap_cartridge
unmap_cartridge::
			ld		a, [RAMAD1]
			ld		h, 0x40
			call	ENASLT
			ld		a, [RAMAD2]
			ld		h, 0x80
			jp		ENASLT
			endscope

			scope	wait_vsync
wait_vsync::
			in		a, [VDP_STATUS]
			rlca
			jr		nc, wait_vsync
			ret
			endscope

			scope	puthex
puthex::
			push	af
			rrca
			rrca
			rrca
			rrca
			call	nibble
			pop		af
nibble:
			and		a, 0x0F
			add		a, '0'
			cp		a, '9' + 1
			jr		c, putc
			add		a, 'A' - '0' - 10
			jr		putc
			endscope

			scope	puts
puts::
			ld		a, [de]
			or		a, a
			ret		z
			inc		de
			push	de
			call	putc
			pop		de
			jr		puts
			endscope

			scope	putc
putc::
			ld		e, a
			ld		c, _CONOUT
			jp		BDOS
			endscope

title_message:
			ds		"SCCDIAG [Y8960 SCC diagnostic]\r\n"
			db		0
not_detected_message:
			ds		"Y8960 is not detected.\r\n"
			db		0
slot_error_message:
			ds		"Cartridge slot is not found.\r\n"
			db		0
playing_message:
			ds		"Playing SCC ch.A 440Hz (3 sec)...\r\n"
			db		0
readback_message:
			ds		"Wave RAM read back (expect 80 88 90 ... F8 00 08 ... 78):\r\n"
			db		0
crlf_message:
			ds		"\r\n"
			db		0
ok_message:
			ds		"Wave RAM: OK\r\n"
			db		0
ng_message:
			ds		"Wave RAM: NG\r\n"
			db		0
cur_slot:
			db		0
saved_en2:
			db		0
expect:
			db		0
readback:
			space	32
