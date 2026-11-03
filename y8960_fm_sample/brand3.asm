; -----------------------------------------------------------------------------
;   BRAND3 [Y8960 OPM + OPL2 Sample]
;
;   J.S.Bach: Brandenburg Concerto No.3 in G major, BWV 1048
;   played with the OPM (YM2151) and the OPL2 (YM3812) of the Y8960 Cartridge.
;
;   Usage:
;       BRAND3
;
;       ESC stops the playback.
;
;   Build:
;       python mksong.py           (brand3.ly sources -> brand3.inc)
;       zma brand3.asm BRAND3.COM
; -----------------------------------------------------------------------------
; History
; Nov/3rd/2026  First release (v1.0)
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
;	MSX Defines
; -----------------------------------------------------------------------------
BDOS			:= 0x0005
_TERM0			:= 0x00
_CONOUT			:= 0x02
RDSLT			:= 0x000C
WRSLT			:= 0x0014
MSXVER_FREQ		:= 0x002B		; MAIN-ROM: bit7 = 1 for 50Hz
EXPTBL			:= 0xFCC1

VDP_STATUS		:= 0x99			; S#0 bit7: VSYNC flag (R#15 = 0)

PPI_KEY_DATA	:= 0xA9			; keyboard matrix column input
PPI_PORT_C		:= 0xAA			; bit3-0: keyboard row select
KEY_ROW_ESC		:= 7
KEY_BIT_ESC		:= 0x04

; -----------------------------------------------------------------------------
;	System Controller (I/O 40h)
; -----------------------------------------------------------------------------
SC_ENABLER		:= 0x40
SC_DEVSEL		:= 0x41
SC_ENABLE_KEY	:= 0x80
SC_ENABLED		:= 0x7F			; ~SC_ENABLE_KEY
SC_DEVICE_ID	:= 0x02			; Y8960 Cartridge
SC_DEVICE_ACK	:= 0xFD			; ~SC_DEVICE_ID

EN2_OPL2		:= 0x01			; I/O Enabler2 (7FFFh) bits
EN2_OPM			:= 0x04

; -----------------------------------------------------------------------------
;	OPL2 (I/O C0h/C1h) / OPM (I/O 7Eh/7Fh)
; -----------------------------------------------------------------------------
OPL_ADDR		:= 0xC0
OPL_DATA		:= 0xC1
OPL_PAN			:= 0xF6			; F6h-FEh: PAN of ch1-9 (Y8960 extension)
OPL_KEYON		:= 0x20

OPM_ADDR		:= 0x7E
OPM_DATA		:= 0x7F
OPM_KEYON		:= 0x78			; M1, C1, M2, C2

HW_COND			:= 0xFF			; conductor channel (no sound)

; -----------------------------------------------------------------------------
;	Song data
;     song_table: db count, { db hw_ch, patch, pan / dw stream } x count
;     stream    : 00h       rest (current length)
;                 01h-7Fh   note (MIDI note number, current length)
;                 80h-EEh   set length = 1-111 ticks
;                 F0h ll hh set length = hhll ticks
;                 F8h t6 t5 tempo (60Hz, 50Hz): ticks per frame x 256
;                 FFh       end
; -----------------------------------------------------------------------------
CH_HW			:= 0			; channel work offsets
CH_PTR			:= 1
CH_REMAIN		:= 3
CH_LEN			:= 5
CH_FLAGS		:= 7			; bit0: ended, bit1: key on
CH_OPL_B0		:= 8			; OPL2: last B0h value without KEYON
CH_SIZE			:= 9
CH_MAX			:= 16

FLAG_ENDED		:= 0
FLAG_KEYON		:= 1

RELEASE_FRAMES	:= 90

; -----------------------------------------------------------------------------
;	Entry Point
; -----------------------------------------------------------------------------
			org		0x100
			scope	entry_point
entry_point::
			ld		de, title_message
			call	puts

			call	sc_detect
			ld		de, not_detected_message
			jp		c, puts_and_exit

			call	find_and_enable
			ld		de, slot_error_message
			jp		c, puts_and_exit

			call	check_pal

			ld		de, playing_message
			call	puts

			di
			call	opm_init
			call	opl_init
			call	setup_channels
			call	play
			push	de
			call	all_key_off
			ld		b, RELEASE_FRAMES
release_loop:
			call	wait_vsync
			djnz	release_loop
			ei
			pop		de
			jp		puts_and_exit		; DE = result message
			endscope

; -----------------------------------------------------------------------------
; puts_and_exit (DE = message, 0 terminated)
; -----------------------------------------------------------------------------
			scope	puts_and_exit
puts_and_exit::
			call	puts
			ld		c, _TERM0
			jp		BDOS
			endscope

; -----------------------------------------------------------------------------
; sc_detect: System Controller presence + Y8960 ID check (I/O only)
; output: Cf = 1 if not detected
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
; find_and_enable
;   Searches all slots for a ROM ("AB" at 4000h) whose MMIO Enabler2 (7FFFh)
;   accepts and holds bit0 (OPL2) and bit2 (OPM). Enables them on the found
;   slot and verifies the OPL2 status port shows the idle pattern.
; output: Cf = 1 if not found
; -----------------------------------------------------------------------------
			scope	find_and_enable
find_and_enable::
			ld		b, 0			; primary slot 0..3
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
			ld		c, 0			; subslot 0..3
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

; try_slot: Cf = 0 if this slot is the Y8960 cartridge (now enabled)
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

; -----------------------------------------------------------------------------
; check_pal: pal_flag = 80h on a 50Hz machine, 00h on a 60Hz machine
; -----------------------------------------------------------------------------
			scope	check_pal
check_pal::
			ld		a, [EXPTBL]
			ld		hl, MSXVER_FREQ
			call	RDSLT
			and		a, 0x80
			ld		[pal_flag], a
			ret
			endscope

; -----------------------------------------------------------------------------
; opl_write: B = register, C = data (OPL2 needs a wait after each access)
; -----------------------------------------------------------------------------
			scope	opl_write
opl_write::
			ld		a, b
			out		[OPL_ADDR], a
			call	wait_small
			ld		a, c
			out		[OPL_DATA], a
			; fall through to wait_small
			endscope

			scope	wait_small
wait_small::
			push	bc
			ld		b, 16
ws_loop:
			djnz	ws_loop
			pop		bc
			ret
			endscope

; -----------------------------------------------------------------------------
; opm_write: B = register, C = data
;   The Y8960 queues the OPM writes and asserts /WAIT while the queue is
;   full, so no software wait is needed.
; -----------------------------------------------------------------------------
			scope	opm_write
opm_write::
			ld		a, b
			out		[OPM_ADDR], a
			ld		a, c
			out		[OPM_DATA], a
			ret
			endscope

; -----------------------------------------------------------------------------
; opm_init: all key off, silence all slots, set up the LFO
; -----------------------------------------------------------------------------
			scope	opm_init
opm_init::
			ld		bc, 0x0800		; reg 08h: key off ch0-7
koff_loop:
			call	opm_write
			inc		c
			ld		a, c
			cp		a, 8
			jr		nz, koff_loop

			ld		bc, 0x607F		; TL = 127 (60h-7Fh)
tl_loop:
			call	opm_write
			inc		b
			ld		a, b
			cp		a, 0x80
			jr		nz, tl_loop

			ld		bc, 0xE00F		; D1L = 0, RR = 15 (E0h-FFh)
rr_loop:
			call	opm_write
			inc		b
			jr		nz, rr_loop

			ld		hl, opm_init_table
init_loop:
			ld		b, [hl]
			inc		hl
			ld		c, [hl]
			inc		hl
			call	opm_write
			ld		a, b
			or		a, a
			jr		nz, init_loop
			ret
			endscope

; -----------------------------------------------------------------------------
; opl_init: waveform select on, all key off, silence all slots
; -----------------------------------------------------------------------------
			scope	opl_init
opl_init::
			ld		hl, opl_init_table
init_loop:
			ld		b, [hl]
			inc		hl
			ld		c, [hl]
			inc		hl
			call	opl_write
			ld		a, b
			or		a, a
			jr		nz, init_loop

			ld		bc, 0xB000		; B0h-B8h: key off
koff_loop:
			call	opl_write
			inc		b
			ld		a, b
			cp		a, 0xB9
			jr		nz, koff_loop

			ld		bc, 0x403F		; TL = 63 (40h-55h)
tl_loop:
			call	opl_write
			inc		b
			ld		a, b
			cp		a, 0x56
			jr		nz, tl_loop

			ld		bc, 0x800F		; SL = 0, RR = 15 (80h-95h)
rr_loop:
			call	opl_write
			inc		b
			ld		a, b
			cp		a, 0x96
			jr		nz, rr_loop
			ret
			endscope

; -----------------------------------------------------------------------------
; setup_channels: initializes the channel work and the voices from song_table
; -----------------------------------------------------------------------------
			scope	setup_channels
setup_channels::
			ld		hl, song_table
			ld		b, [hl]
			inc		hl
			ld		a, b
			ld		[num_channels], a
			ld		ix, ch_work
ch_loop:
			push	bc
			ld		a, [hl]
			ld		[ix + CH_HW], a
			inc		hl
			ld		d, [hl]			; patch
			inc		hl
			ld		e, [hl]			; pan
			inc		hl
			ld		c, [hl]
			inc		hl
			ld		b, [hl]
			inc		hl
			ld		[ix + CH_PTR + 0], c
			ld		[ix + CH_PTR + 1], b
			ld		[ix + CH_REMAIN + 0], 1
			ld		[ix + CH_REMAIN + 1], 0
			ld		[ix + CH_LEN + 0], 16
			ld		[ix + CH_LEN + 1], 0
			ld		[ix + CH_FLAGS], 0
			ld		[ix + CH_OPL_B0], 0
			push	hl
			call	set_voice
			pop		hl
			ld		bc, CH_SIZE
			add		ix, bc
			pop		bc
			djnz	ch_loop

			ld		a, 0xFF			; the first frame processes the first tick
			ld		[tempo_acc], a
			ld		a, 128
			ld		[tempo], a
			ret
			endscope

; -----------------------------------------------------------------------------
; set_voice: A = hw channel, D = patch number, E = pan
; -----------------------------------------------------------------------------
			scope	set_voice
set_voice::
			ld		[voice_ch], a
			ld		b, a
			ld		a, e
			ld		[voice_pan], a
			ld		a, b
			cp		a, HW_COND
			ret		z
			cp		a, 8
			jr		nc, opl_voice

			; OPM: HL = opm_patches + patch * 26
			ld		l, d
			ld		h, 0
			add		hl, hl			; x2
			ld		c, l
			ld		b, h
			add		hl, hl			; x4
			add		hl, hl			; x8
			push	hl
			add		hl, hl			; x16
			pop		de
			add		hl, de			; x24
			add		hl, bc			; x26
			ld		bc, opm_patches
			add		hl, bc

			ld		a, [voice_ch]	; 20h: RL | FB | CON
			add		a, 0x20
			ld		b, a
			ld		a, [voice_pan]
			or		a, [hl]
			ld		c, a
			call	opm_write
			inc		hl
			ld		a, [voice_ch]	; 38h: PMS | AMS
			add		a, 0x38
			ld		b, a
			ld		c, [hl]
			call	opm_write
			inc		hl
			ld		a, [voice_ch]	; operators M1, M2, C1, C2
			add		a, 0x40
			ld		d, a
			ld		e, 4
opm_op_loop:
			ld		b, d
			push	de
			ld		e, 6			; 40h, 60h, 80h, A0h, C0h, E0h
opm_reg_loop:
			ld		c, [hl]
			inc		hl
			call	opm_write
			ld		a, b
			add		a, 0x20
			ld		b, a
			dec		e
			jr		nz, opm_reg_loop
			pop		de
			ld		a, d
			add		a, 8
			ld		d, a
			dec		e
			jr		nz, opm_op_loop
			ret

opl_voice:
			sub		a, 8
			ld		[voice_ch], a
			add		a, OPL_PAN
			ld		b, a
			ld		c, e
			call	opl_write

			; HL = opl_patches + patch * 11
			ld		l, d
			ld		h, 0
			ld		c, l
			ld		b, h
			add		hl, hl			; x2
			add		hl, hl			; x4
			add		hl, bc			; x5
			add		hl, hl			; x10
			add		hl, bc			; x11
			ld		bc, opl_patches
			add		hl, bc

			ld		a, [voice_ch]	; C0h: FB | CON
			add		a, 0xC0
			ld		b, a
			ld		c, [hl]
			inc		hl
			call	opl_write

			push	hl
			ld		a, [voice_ch]
			ld		e, a
			ld		d, 0
			ld		hl, opl_slot_table
			add		hl, de
			ld		d, [hl]			; modulator slot
			pop		hl
			call	opl_op
			ld		a, d
			add		a, 3			; carrier slot
			ld		d, a
			; fall through to opl_op

; opl_op: D = slot, HL = 5 bytes (20h, 40h, 60h, 80h, E0h)
opl_op:
			ld		a, 0x20
			ld		e, 4
opl_reg_loop:
			push	af
			add		a, d
			ld		b, a
			ld		c, [hl]
			inc		hl
			call	opl_write
			pop		af
			add		a, 0x20
			dec		e
			jr		nz, opl_reg_loop
			ld		a, 0xE0
			add		a, d
			ld		b, a
			ld		c, [hl]
			inc		hl
			jp		opl_write
			endscope

; -----------------------------------------------------------------------------
; play: main loop (interrupts are disabled)
; output: DE = result message
; -----------------------------------------------------------------------------
			scope	play
play::
			call	wait_vsync
			call	check_esc
			jr		z, stopped
			ld		a, [tempo_acc]
			ld		b, a
			ld		a, [tempo]
			add		a, b
			ld		[tempo_acc], a
			jr		nc, play
			call	do_tick
			jr		nc, play
			ld		de, done_message
			ret
stopped:
			ld		de, stopped_message
			ret
			endscope

; -----------------------------------------------------------------------------
; wait_vsync: waits for the VSYNC flag of the VDP (reading S#0 clears it)
; -----------------------------------------------------------------------------
			scope	wait_vsync
wait_vsync::
			in		a, [VDP_STATUS]
			rlca
			jr		nc, wait_vsync
			ret
			endscope

; -----------------------------------------------------------------------------
; do_tick: advances all channels by 1 tick
; output: Cf = 1 when all channels have ended
; -----------------------------------------------------------------------------
			scope	do_tick
do_tick::
			ld		ix, ch_work
			ld		a, [num_channels]
			ld		b, a
			ld		c, 0			; number of active channels
ch_loop:
			push	bc
			bit		FLAG_ENDED, [ix + CH_FLAGS]
			jr		nz, next_ch
			ld		l, [ix + CH_REMAIN + 0]
			ld		h, [ix + CH_REMAIN + 1]
			dec		hl
			ld		[ix + CH_REMAIN + 0], l
			ld		[ix + CH_REMAIN + 1], h
			ld		a, h
			or		a, l
			jr		z, fetch
			dec		hl
			ld		a, h
			or		a, l
			jr		nz, active
			; the last tick of the note: key off (articulation)
			bit		FLAG_KEYON, [ix + CH_FLAGS]
			call	nz, key_off
			jr		active
fetch:
			call	fetch_note
			bit		FLAG_ENDED, [ix + CH_FLAGS]
			jr		nz, next_ch
active:
			pop		bc
			inc		c
			push	bc
next_ch:
			pop		bc
			ld		de, CH_SIZE
			add		ix, de
			djnz	ch_loop
			ld		a, c
			or		a, a			; Cf = 0
			ret		nz
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; fetch_note: reads the stream of the channel IX until a note or a rest
; -----------------------------------------------------------------------------
			scope	fetch_note
fetch_note::
			ld		l, [ix + CH_PTR + 0]
			ld		h, [ix + CH_PTR + 1]
read_loop:
			ld		a, [hl]
			inc		hl
			cp		a, 0x80
			jr		c, note_or_rest
			cp		a, 0xEF
			jr		c, short_len
			cp		a, 0xF0
			jr		z, long_len
			cp		a, 0xF8
			jr		z, tempo_cmd
			; FFh: end of the channel
			set		FLAG_ENDED, [ix + CH_FLAGS]
			bit		FLAG_KEYON, [ix + CH_FLAGS]
			ret		z
			jp		key_off

short_len:
			sub		a, 0x7F			; 80h -> 1
			ld		[ix + CH_LEN + 0], a
			ld		[ix + CH_LEN + 1], 0
			jr		read_loop

long_len:
			ld		a, [hl]
			inc		hl
			ld		[ix + CH_LEN + 0], a
			ld		a, [hl]
			inc		hl
			ld		[ix + CH_LEN + 1], a
			jr		read_loop

tempo_cmd:
			ld		d, [hl]			; 60Hz
			inc		hl
			ld		e, [hl]			; 50Hz
			inc		hl
			ld		a, [pal_flag]
			or		a, a
			ld		a, d
			jr		z, set_tempo
			ld		a, e
set_tempo:
			ld		[tempo], a
			jr		read_loop

note_or_rest:
			ld		[ix + CH_PTR + 0], l
			ld		[ix + CH_PTR + 1], h
			ld		e, [ix + CH_LEN + 0]
			ld		d, [ix + CH_LEN + 1]
			ld		[ix + CH_REMAIN + 0], e
			ld		[ix + CH_REMAIN + 1], d
			or		a, a
			jr		nz, key_on
			bit		FLAG_KEYON, [ix + CH_FLAGS]
			ret		z
			jp		key_off
			endscope

; -----------------------------------------------------------------------------
; key_on: A = MIDI note number, IX = channel work
;   Writes key off first, so that a repeated note is attacked again.
; -----------------------------------------------------------------------------
			scope	key_on
key_on::
			ld		e, a
			ld		d, 0
			ld		a, [ix + CH_HW]
			cp		a, HW_COND
			ret		z
			set		FLAG_KEYON, [ix + CH_FLAGS]
			cp		a, 8
			jr		nc, opl_key_on

			ld		c, a			; OPM: key off
			ld		b, 0x08
			call	opm_write
			ld		hl, opm_kc_table
			add		hl, de
			ld		a, [ix + CH_HW]	; 28h: KC
			add		a, 0x28
			ld		b, a
			ld		c, [hl]
			call	opm_write
			ld		a, [ix + CH_HW]	; 08h: key on
			or		a, OPM_KEYON
			ld		c, a
			ld		b, 0x08
			jp		opm_write

opl_key_on:
			sub		a, 8
			ld		[voice_ch], a
			add		a, 0xB0			; B0h: key off
			ld		b, a
			ld		c, [ix + CH_OPL_B0]
			call	opl_write
			ld		hl, opl_fnum_table
			add		hl, de
			add		hl, de
			ld		a, [voice_ch]	; A0h: F-Number low
			add		a, 0xA0
			ld		b, a
			ld		c, [hl]
			call	opl_write
			inc		hl
			ld		a, [hl]
			ld		[ix + CH_OPL_B0], a
			or		a, OPL_KEYON
			ld		c, a
			ld		a, [voice_ch]	; B0h: key on, block, F-Number high
			add		a, 0xB0
			ld		b, a
			jp		opl_write
			endscope

; -----------------------------------------------------------------------------
; key_off: IX = channel work
; -----------------------------------------------------------------------------
			scope	key_off
key_off::
			res		FLAG_KEYON, [ix + CH_FLAGS]
			ld		a, [ix + CH_HW]
			cp		a, HW_COND
			ret		z
			cp		a, 8
			jr		nc, opl_key_off
			ld		c, a
			ld		b, 0x08
			jp		opm_write
opl_key_off:
			add		a, 0xB0 - 8
			ld		b, a
			ld		c, [ix + CH_OPL_B0]
			jp		opl_write
			endscope

; -----------------------------------------------------------------------------
; all_key_off
; -----------------------------------------------------------------------------
			scope	all_key_off
all_key_off::
			ld		ix, ch_work
			ld		a, [num_channels]
			ld		b, a
loop:
			push	bc
			bit		FLAG_KEYON, [ix + CH_FLAGS]
			call	nz, key_off
			ld		de, CH_SIZE
			add		ix, de
			pop		bc
			djnz	loop
			ret
			endscope

; -----------------------------------------------------------------------------
; check_esc: reads the keyboard matrix directly (interrupts are disabled)
; output: Zf = 1 if ESC is pressed
; -----------------------------------------------------------------------------
			scope	check_esc
check_esc::
			in		a, [PPI_PORT_C]
			and		a, 0xF0
			or		a, KEY_ROW_ESC
			out		[PPI_PORT_C], a
			in		a, [PPI_KEY_DATA]
			and		a, KEY_BIT_ESC
			ret
			endscope

; -----------------------------------------------------------------------------
; puts (DE = 0 terminated string), putc (A = char)
; -----------------------------------------------------------------------------
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

; -----------------------------------------------------------------------------
; Chip initialize tables: { register, data } ..., terminated by register 00h
; -----------------------------------------------------------------------------
opm_init_table:
			db		0x01, 0x02		; LFO reset
			db		0x01, 0x00
			db		0x0F, 0x00		; noise off
			db		0x18, 0xC4		; LFRQ (about 5Hz)
			db		0x19, 0x8A		; PMD
			db		0x19, 0x00		; AMD
			db		0x1B, 0x02		; LFO wave: triangle
			db		0x20, 0x00		; RL = 0 (ch0-7)
			db		0x21, 0x00
			db		0x22, 0x00
			db		0x23, 0x00
			db		0x24, 0x00
			db		0x25, 0x00
			db		0x26, 0x00
			db		0x27, 0x00
			db		0x00, 0x00

opl_init_table:
			db		0x01, 0x20		; WSE = 1
			db		0x08, 0x00		; CSM = 0, NOTE SEL = 0
			db		0xBD, 0x40		; VIB depth = 14 cent, melody mode
			db		0x00, 0x00

opl_slot_table:
			db		0x00, 0x01, 0x02, 0x08, 0x09, 0x0A, 0x10, 0x11, 0x12

; -----------------------------------------------------------------------------
; OPM patches (26 bytes)
;   FB | CON, PMS | AMS,
;   M1: DT1|MUL, TL, KS|AR, AMS-EN|D1R, DT2|D2R, D1L|RR
;   M2, C1, C2: same as M1
; -----------------------------------------------------------------------------
opm_patches:
			; 0: strings (2 x 2op, detuned)
			db		(4 << 3) | 4, 0x20
			db		0x11, 0x22, 0x14, 0x06, 0x02, 0x26	; M1
			db		0x51, 0x26, 0x14, 0x06, 0x02, 0x26	; M2
			db		0x21, 0x16, 0x16, 0x02, 0x00, 0x17	; C1
			db		0x61, 0x16, 0x16, 0x02, 0x00, 0x17	; C2
			; 1: contrabass
			db		(3 << 3) | 4, 0x10
			db		0x11, 0x2C, 0x16, 0x06, 0x02, 0x26	; M1
			db		0x51, 0x2E, 0x16, 0x06, 0x02, 0x26	; M2
			db		0x21, 0x12, 0x18, 0x02, 0x00, 0x18	; C1
			db		0x61, 0x12, 0x18, 0x02, 0x00, 0x18	; C2

; -----------------------------------------------------------------------------
; OPL2 patches (11 bytes)
;   FB | CON,
;   modulator: AM|VIB|EG|KSR|MUL, KSL|TL, AR|DR, SL|RR, WS
;   carrier  : same as modulator
; -----------------------------------------------------------------------------
opl_patches:
			; 0: cello
			db		(5 << 1) | 0
			db		0x61, 0x5C, 0x72, 0x26, 0x00
			db		0x61, 0x08, 0x82, 0x17, 0x00
			; 1: harpsichord
			db		(6 << 1) | 0
			db		0x03, 0x1E, 0xF3, 0x44, 0x00
			db		0x01, 0x0E, 0xF3, 0x64, 0x00

; -----------------------------------------------------------------------------
; Messages
; -----------------------------------------------------------------------------
title_message:
			ds		"BRAND3 [Y8960 OPM + OPL2 Sample] v1.0\r\n"
			ds		"Copyright (C)2026 HRA!\r\n\r\n"
			ds		"J.S.Bach: Brandenburg Concerto No.3\r\n"
			ds		"          in G major, BWV 1048\r\n\r\n"
			db		0
not_detected_message:
			ds		"Y8960 Cartridge not found.\r\n"
			db		0
slot_error_message:
			ds		"Y8960 Cartridge slot not found (enabler failed).\r\n"
			db		0
playing_message:
			ds		"Playing (ESC: stop)...\r\n"
			db		0
done_message:
			ds		"Done.\r\n"
			db		0
stopped_message:
			ds		"Stopped.\r\n"
			db		0

; -----------------------------------------------------------------------------
; Variables
; -----------------------------------------------------------------------------
cur_slot:
			db		0
saved_en2:
			db		0
pal_flag:
			db		0
tempo:
			db		0
tempo_acc:
			db		0
voice_ch:
			db		0
voice_pan:
			db		0
num_channels:
			db		0

; -----------------------------------------------------------------------------
; Song data
; -----------------------------------------------------------------------------
			include	"brand3.inc"

; Channel work (CH_SIZE * CH_MAX bytes, outside of the COM file)
ch_work:
