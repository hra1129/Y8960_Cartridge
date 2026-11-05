; -----------------------------------------------------------------------------
;   OPLLRHY [Y8960 OPLL Rhythm Sample]
;
;   An original 8-beat tune for the OPLL of the Y8960 Cartridge:
;   the 5 rhythm sounds (BD, SD, TOM, CYM, HH) and 6 melody channels.
;   It starts with a drum demo (each drum alone for one bar).
;
;   Usage:
;       OPLLRHY
;
;       ESC stops the playback.
;
;   Build:
;       python mkopllrhy.py        (-> opllrhy.inc)
;       zma opllrhy.asm OPLLRHY.COM
; -----------------------------------------------------------------------------
; History
; Nov/5th/2026  First release (v1.0)
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
;	MSX Defines
; -----------------------------------------------------------------------------
BDOS			:= 0x0005
_TERM0			:= 0x00
_CONOUT			:= 0x02
RDSLT			:= 0x000C
WRSLT			:= 0x0014
ENASLT			:= 0x0024
RAMAD1			:= 0xF342		; MSX-DOS: RAM slot of page 1
RAMAD2			:= 0xF343		; MSX-DOS: RAM slot of page 2
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

OPL_ADDR		:= 0xC0			; OPL2 status (used to identify the slot)

; -----------------------------------------------------------------------------
;	Memory mapped I/O of the cartridge
;     While playing, page 1 and page 2 are switched to the cartridge slot,
;     so everything used then must be placed below 4000h.
; -----------------------------------------------------------------------------
MMIO_OPLL		:= 0x7FF4		; 7FF4h: register, 7FF5h: data
MIXER_SSG		:= 0x7FF7		; mixer volumes (write only, 128 = x1.0)
MIXER_SCC		:= 0x7FFA
MIXER_OPM		:= 0x7FFD
MIXER_MASTER	:= 0x7FFE
SCC_MODE		:= 0x4FFB		; bit0: RAM Mode

OPLL_FNUM		:= 0x10
OPLL_KEY		:= 0x20			; SUS, KEY, BLOCK, F-Number bit8
OPLL_INST		:= 0x30			; INST | VOL
OPLL_BANK		:= 0x40			; Y8960 extension
OPLL_PAN		:= 0x50			; Y8960 extension
OPLL_KEYON		:= 0x10
OPLL_RHYTHM		:= 0x0E			; bit5: rhythm mode, bit4-0: BD SD TOM CYM HH
OPLL_RHY_MODE	:= 0x20

; -----------------------------------------------------------------------------
;	Hardware channel numbers
; -----------------------------------------------------------------------------
HW_OPLL			:= 0x20			; 20h-25h (ch1-6, ch7-9 are the rhythm)
HW_RHY			:= 0x60			; rhythm (note = BD|SD|TOM|CYM|HH mask)
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
;     rhythm    : note = 10h BD | 08h SD | 04h TOM | 02h CYM | 01h HH
;                 (the drums are not keyed off at the end of the note)
; -----------------------------------------------------------------------------
CH_HW			:= 0			; channel work offsets
CH_PTR			:= 1
CH_REMAIN		:= 3
CH_LEN			:= 5
CH_FLAGS		:= 7			; bit0: ended, bit1: key on
CH_B0			:= 8			; block | F-Number bit8 (no KEYON)
CH_SIZE			:= 9
CH_MAX			:= 16

FLAG_ENDED		:= 0
FLAG_KEYON		:= 1

RELEASE_FRAMES	:= 120

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
			call	bios_ram_mode_off

			ld		de, playing_message
			call	puts

			di
			call	map_cartridge
			call	mixer_init
			call	opll_init
			call	setup_channels
			call	play
			push	de
			call	all_key_off
			ld		bc, (OPLL_RHYTHM << 8) | OPLL_RHY_MODE	; rhythm key off
			call	opll_write
			ld		b, RELEASE_FRAMES
release_loop:
			call	wait_vsync
			djnz	release_loop
			call	opll_quiet
			call	unmap_cartridge
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
; find_and_enable (same as CANCAN)
;   Searches all slots for a ROM ("AB" at 4000h) whose MMIO Enabler2 (7FFFh)
;   accepts and holds bit0 (OPL2) and bit2 (OPM), and whose OPL2 status port
;   shows the idle pattern. cur_slot holds the slot of the cartridge.
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
; bios_ram_mode_off (same as CANCAN): if the Y8960 BIOS ("MSSE8960" at 4010h)
;   is found in cur_slot, writes RAM Mode=0 (4FFBh=00h) once.
;   The MMIO (7FF0h-7FFFh) is available only with RAM Mode=0 or a ROM bank
;   in BANK1.
; -----------------------------------------------------------------------------
			scope	bios_ram_mode_off
bios_ram_mode_off::
			ld		hl, 0x4010
			ld		de, bios_signature
			ld		b, 8
sig_loop:
			push	bc
			push	de
			ld		a, [cur_slot]
			call	RDSLT
			pop		de
			pop		bc
			ex		de, hl
			cp		a, [hl]
			ex		de, hl
			ret		nz
			inc		hl
			inc		de
			djnz	sig_loop
			ld		a, [cur_slot]
			ld		hl, SCC_MODE
			ld		e, 0x00
			call	WRSLT
			ei
			ret
			endscope

bios_signature:
			ds		"MSSE8960"

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
; map_cartridge / unmap_cartridge: switches page 1 and page 2 to the
;   cartridge slot (for the direct MMIO access) and back to the RAM.
;   ENASLT leaves the interrupts disabled.
; -----------------------------------------------------------------------------
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

; -----------------------------------------------------------------------------
; opll_write: B = register, C = data (memory mapped I/O)
;   The OPLL writes are queued by the Y8960 (with /WAIT), so no software
;   wait is needed. preserves BC, DE, HL
; -----------------------------------------------------------------------------
			scope	opll_write
opll_write::
			push	hl
			ld		hl, MMIO_OPLL
			ld		[hl], b
			inc		hl
			ld		[hl], c
			pop		hl
			ret
			endscope

; -----------------------------------------------------------------------------
; mixer_init: sets all mixer volumes to the reset value (128 = x1.0)
;   The BIOS may change them, and they cannot be read back.
; -----------------------------------------------------------------------------
			scope	mixer_init
mixer_init::
			ld		a, 128
			ld		hl, MIXER_SSG
			ld		b, MIXER_SCC - MIXER_SSG + 1
loop:
			ld		[hl], a
			inc		hl
			djnz	loop
			ld		[MIXER_OPM], a
			ld		[MIXER_MASTER], a
			ret
			endscope

; -----------------------------------------------------------------------------
; opll_init: all key off, then the rhythm setup of opll_init_table
;   (F-Number, volume, PAN of ch7-9, rhythm mode on)
; -----------------------------------------------------------------------------
			scope	opll_init
opll_init::
			call	opll_quiet
			ld		hl, opll_init_table
loop:
			ld		b, [hl]
			inc		hl
			ld		a, b
			inc		a
			jr		z, done
			ld		c, [hl]
			inc		hl
			call	opll_write
			jr		loop
done:
			ld		a, OPLL_RHY_MODE
			ld		[rhy_keys], a
			ret
			endscope

; -----------------------------------------------------------------------------
; opll_quiet: rhythm mode off, all key off
; -----------------------------------------------------------------------------
			scope	opll_quiet
opll_quiet::
			ld		bc, (OPLL_RHYTHM << 8) | 0x00
			call	opll_write
			ld		bc, (OPLL_KEY << 8) | 0x00
loop:
			call	opll_write
			inc		b
			ld		a, b
			cp		a, OPLL_KEY + 9
			jr		nz, loop
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
			ld		[ix + CH_B0], 0
			cp		a, HW_RHY
			call	c, opll_voice
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
; opll_voice: A = hw channel, D = INST | VOL, E = pan, preserves HL
; -----------------------------------------------------------------------------
			scope	opll_voice
opll_voice::
			push	hl
			sub		a, HW_OPLL
			ld		l, a			; L = channel (HL is restored at the end)
			add		a, OPLL_INST	; 30h: INST | VOL
			ld		b, a
			ld		c, d
			call	opll_write
			ld		a, l			; 40h: tone bank 0 (YM2413)
			add		a, OPLL_BANK
			ld		b, a
			ld		c, 0
			call	opll_write
			ld		a, l			; 50h: PAN
			add		a, OPLL_PAN
			ld		b, a
			ld		c, e
			call	opll_write
			ld		a, l			; 20h: key off
			add		a, OPLL_KEY
			ld		b, a
			ld		c, 0
			call	opll_write
			pop		hl
			ret
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
; key_on: A = MIDI note number (drum mask for the rhythm), IX = channel work
;   Writes key off first when still sounding, so that a repeated note is
;   attacked again.
; -----------------------------------------------------------------------------
			scope	key_on
key_on::
			ld		e, a
			ld		d, 0
			ld		a, [ix + CH_HW]
			cp		a, HW_COND
			ret		z
			cp		a, HW_RHY
			jr		z, rhythm_key_on
			ld		c, [ix + CH_FLAGS]	; previous key state
			set		FLAG_KEYON, [ix + CH_FLAGS]
			sub		a, HW_OPLL
			ld		[voice_ch], a
			bit		FLAG_KEYON, c
			jr		z, set_fnum
			add		a, OPLL_KEY
			ld		b, a
			ld		c, [ix + CH_B0]
			call	opll_write
set_fnum:
			ld		hl, opll_fnum_table
			add		hl, de
			add		hl, de
			ld		a, [voice_ch]	; 10h: F-Number low
			add		a, OPLL_FNUM
			ld		b, a
			ld		c, [hl]
			call	opll_write
			inc		hl
			ld		a, [hl]
			ld		[ix + CH_B0], a
			or		a, OPLL_KEYON
			ld		c, a
			ld		a, [voice_ch]	; 20h: key on, block, F-Number bit8
			add		a, OPLL_KEY
			ld		b, a
			jp		opll_write

			; Rhythm: keys off only the drums to be hit (the others keep
			; decaying), then keys them on. FLAG_KEYON stays 0, so the drums
			; are not keyed off at the end of the note.
rhythm_key_on:
			ld		a, e
			cpl
			ld		b, a
			ld		a, [rhy_keys]
			and		a, b
			or		a, OPLL_RHY_MODE
			ld		c, a
			ld		b, OPLL_RHYTHM
			call	opll_write
			ld		a, c
			or		a, e
			ld		[rhy_keys], a
			ld		c, a
			jp		opll_write
			endscope

; -----------------------------------------------------------------------------
; key_off: IX = channel work (melody channels only)
; -----------------------------------------------------------------------------
			scope	key_off
key_off::
			res		FLAG_KEYON, [ix + CH_FLAGS]
			ld		a, [ix + CH_HW]
			cp		a, HW_RHY
			ret		nc				; rhythm / conductor
			add		a, OPLL_KEY - HW_OPLL
			ld		b, a
			ld		c, [ix + CH_B0]
			jp		opll_write
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
; Messages
; -----------------------------------------------------------------------------
title_message:
			ds		"OPLLRHY [Y8960 OPLL Rhythm Sample] v1.0\r\n"
			ds		"Copyright (C)2026 HRA!\r\n\r\n"
			ds		"Drum demo: BD -> SD -> TOM -> CYM -> HH -> ALL\r\n"
			ds		"then an 8-beat tune (OPLL ch1-6 + rhythm)\r\n\r\n"
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
rhy_keys:
			db		0
num_channels:
			db		0
ch_work:
			space	CH_SIZE * CH_MAX

; -----------------------------------------------------------------------------
; Song data
; -----------------------------------------------------------------------------
			include	"opllrhy.inc"
end_of_program:
