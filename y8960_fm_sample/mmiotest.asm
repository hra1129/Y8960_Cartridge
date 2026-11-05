; -----------------------------------------------------------------------------
;   MMIOTEST [Y8960 Memory Mapped I/O Test]
;
;   Checks that SSG1/SSG2, OPLL (+ rhythm), OPL2, OPM and ADPCM of the Y8960
;   Cartridge are controlled through the memory mapped I/O (7FF0h-7FFFh).
;   The I/O ports of OPL2/OPM/SSG are disabled (7FFFh = 00h) during the test,
;   so every sound is produced by the MMIO writes. Only the ADPCM memory
;   verify reads the data back through the I/O ports (C0h/C1h).
;
;   Usage:
;       MMIOTEST
;
;       ESC stops the test.
;
;   Build:
;       python mkmmiotest.py       (-> mmiotest.inc)
;       zma mmiotest.asm MMIOTEST.COM
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

OPL_ADDR		:= 0xC0			; I/O (slot detection and ADPCM verify only)
OPL_DATA		:= 0xC1
ST_BUFRDY		:= 0x08

; -----------------------------------------------------------------------------
;	Memory mapped I/O of the cartridge (page 1)
;     While testing, page 1 is switched to the cartridge slot, so everything
;     used then must be placed outside 4000h-7FFFh.
; -----------------------------------------------------------------------------
MMIO_SSG		:= 0x7FF0		; 7FF0h: register, 7FF1h: data
MMIO_OPL2		:= 0x7FF2		; 7FF2h: register, 7FF3h: data
MMIO_OPLL		:= 0x7FF4		; 7FF4h: register, 7FF5h: data
MIXER_SSG		:= 0x7FF7		; mixer volumes (write only, 128 = x1.0)
MIXER_SCC		:= 0x7FFA
MMIO_OPM		:= 0x7FFB		; 7FFBh: register, 7FFCh: data
MIXER_OPM		:= 0x7FFD
MIXER_MASTER	:= 0x7FFE
MMIO_EN2		:= 0x7FFF		; I/O Enabler2
SCC_MODE		:= 0x4FFB		; bit0: RAM Mode

ADPCM_CONTROL2	:= 0x04
ADPCM_CONTROL1	:= 0x07
ADPCM_REG_DATA	:= 0x0F
ADPCM_PAN		:= 0xFF

NOTE_FRAMES		:= 24
GAP_FRAMES		:= 6
REST_FRAMES		:= 30
RHY_FRAMES		:= 24
ADPCM_WAIT		:= 16			; djnz count after each ADPCM data write

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

			call	bios_ram_mode_off

			di
			call	map_cartridge
			ld		[saved_sp], sp
			xor		a, a
			ld		[MMIO_EN2], a		; I/O ports of OPL2/OPM/SSG/TIMER off
			call	mixer_init
			call	all_quiet

			ld		de, ssg1_message
			call	print_mapped
			xor		a, a
			call	ssg_test
			ld		de, ssg2_message
			call	print_mapped
			ld		a, 0x10
			call	ssg_test

			ld		de, opll_message
			call	print_mapped
			call	opll_test
			ld		de, rhythm_message
			call	print_mapped
			call	rhythm_test

			ld		de, opl2_message
			call	print_mapped
			call	opl2_test

			ld		de, opm_message
			call	print_mapped
			call	opm_test

			ld		de, adpcm_write_message
			call	print_mapped
			call	adpcm_write
			call	adpcm_verify
			call	print_verify

			ld		de, adpcm_play_message
			call	print_mapped
			call	adpcm_play

			ld		de, done_message
finish:
			push	de
			call	all_quiet
			ld		a, [saved_en2]
			ld		[MMIO_EN2], a		; restores the I/O enabler2
			call	unmap_cartridge
			ei
			pop		de
			jp		puts_and_exit

abort::
			ld		sp, [saved_sp]
			ld		de, stopped_message
			jr		finish
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
;   shows the idle pattern. cur_slot holds the slot of the cartridge, and
;   saved_en2 the original value of 7FFFh.
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
; map_cartridge / unmap_cartridge: switches page 1 to the cartridge slot and
;   back to the RAM. ENASLT leaves the interrupts disabled.
; -----------------------------------------------------------------------------
			scope	map_cartridge
map_cartridge::
			ld		a, [cur_slot]
			ld		h, 0x40
			jp		ENASLT
			endscope

			scope	unmap_cartridge
unmap_cartridge::
			ld		a, [RAMAD1]
			ld		h, 0x40
			jp		ENASLT
			endscope

; -----------------------------------------------------------------------------
; print_mapped: prints DE with page 1 = RAM and interrupts enabled, then
;   switches page 1 back to the cartridge with interrupts disabled.
; -----------------------------------------------------------------------------
			scope	print_mapped
print_mapped::
			push	de
			call	unmap_cartridge
			ei
			pop		de
			call	puts
			di
			jp		map_cartridge
			endscope

; -----------------------------------------------------------------------------
; MMIO register writes: B = register, C = data, preserves BC, DE, HL
;   SSG/OPLL/OPM: the Y8960 queues the writes (with /WAIT).
;   OPL2: a software wait after each access (same as the I/O access).
; -----------------------------------------------------------------------------
			scope	ssg_write
ssg_write::
			push	hl
			ld		hl, MMIO_SSG
			jr		pair_write
			endscope

			scope	opll_write
opll_write::
			push	hl
			ld		hl, MMIO_OPLL
			jr		pair_write
			endscope

			scope	opm_write
opm_write::
			push	hl
			ld		hl, MMIO_OPM
			; fall through to pair_write
			endscope

			scope	pair_write
pair_write::
			ld		[hl], b
			inc		hl
			ld		[hl], c
			pop		hl
			ret
			endscope

			scope	opl_write
opl_write::
			push	hl
			ld		hl, MMIO_OPL2
			ld		[hl], b
			call	wait_small
			inc		hl
			ld		[hl], c
			pop		hl
			; fall through to wait_small
			endscope

			scope	wait_small
wait_small::
			push	bc
			ld		b, 16
loop:
			djnz	loop
			pop		bc
			ret
			endscope

; io_opl_write: B = register, C = data (I/O C0h/C1h, ADPCM verify only)
			scope	io_opl_write
io_opl_write::
			ld		a, b
			out		[OPL_ADDR], a
			call	wait_small
			ld		a, c
			out		[OPL_DATA], a
			jr		wait_small
			endscope

; -----------------------------------------------------------------------------
; write tables: HL = { register, data } ..., terminated by register 00h
; -----------------------------------------------------------------------------
			scope	opll_table
opll_table::
			ld		b, [hl]
			inc		hl
			ld		c, [hl]
			inc		hl
			ld		a, b
			or		a, a
			ret		z
			call	opll_write
			jr		opll_table
			endscope

			scope	opl_table
opl_table::
			ld		b, [hl]
			inc		hl
			ld		c, [hl]
			inc		hl
			ld		a, b
			or		a, a
			ret		z
			call	opl_write
			jr		opl_table
			endscope

			scope	opm_table
opm_table::
			ld		b, [hl]
			inc		hl
			ld		c, [hl]
			inc		hl
			ld		a, b
			or		a, a
			ret		z
			call	opm_write
			jr		opm_table
			endscope

; -----------------------------------------------------------------------------
; mixer_init: sets all mixer volumes to the reset value (128 = x1.0)
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
; all_quiet: key off / silences all the tested sound chips (MMIO)
; -----------------------------------------------------------------------------
			scope	all_quiet
all_quiet::
			ld		hl, ssg_quiet_table
ssg_loop:
			ld		b, [hl]
			inc		hl
			ld		c, [hl]
			inc		hl
			ld		a, b
			cp		a, 0xFF
			jr		z, opll
			call	ssg_write
			jr		ssg_loop
opll:
			ld		bc, 0x0E00			; rhythm off
			call	opll_write
			ld		bc, 0x2000			; key off ch1-9
opll_loop:
			call	opll_write
			inc		b
			ld		a, b
			cp		a, 0x29
			jr		nz, opll_loop
			ld		hl, opl_quiet_table
			call	opl_table
			ld		bc, 0xB000			; key off ch1-9
opl_loop:
			call	opl_write
			inc		b
			ld		a, b
			cp		a, 0xB9
			jr		nz, opl_loop
			ld		bc, 0x0800			; key off ch1-8
opm_loop:
			call	opm_write
			inc		c
			ld		a, c
			cp		a, 8
			jr		nz, opm_loop
			ret
			endscope

; -----------------------------------------------------------------------------
; wait_frames: B = frames (VSYNC), aborts the test when ESC is pressed
;   preserves C, DE, HL
; -----------------------------------------------------------------------------
			scope	wait_frames
wait_frames::
			in		a, [VDP_STATUS]
			rlca
			jr		nc, wait_frames
			in		a, [PPI_PORT_C]
			and		a, 0xF0
			or		a, KEY_ROW_ESC
			out		[PPI_PORT_C], a
			in		a, [PPI_KEY_DATA]
			and		a, KEY_BIT_ESC
			jp		z, abort
			djnz	wait_frames
			ret
			endscope

; -----------------------------------------------------------------------------
; play_arp: plays C4-E4-G4-C5 with PAN L, R, C, C
;   HL = { dw note_on, dw note_off, dw pitch_table }
;   note_on: A = PAN (1: left, 128: center, 255: right), DE = pitch
; -----------------------------------------------------------------------------
			scope	play_arp
play_arp::
			ld		de, arp_on
			ld		bc, 6
			ldir
			ld		hl, arp_pans
			ld		[arp_pan], hl
			ld		a, 4
			ld		[arp_count], a
loop:
			ld		hl, [arp_pitch]
			ld		e, [hl]
			inc		hl
			ld		d, [hl]
			inc		hl
			ld		[arp_pitch], hl
			ld		hl, [arp_pan]
			ld		a, [hl]
			inc		hl
			ld		[arp_pan], hl
			ld		hl, [arp_on]
			call	call_hl
			ld		b, NOTE_FRAMES
			call	wait_frames
			ld		hl, [arp_off]
			call	call_hl
			ld		b, GAP_FRAMES
			call	wait_frames
			ld		hl, arp_count
			dec		[hl]
			jr		nz, loop
			ld		b, REST_FRAMES
			jp		wait_frames
call_hl:
			jp		hl
			endscope

; -----------------------------------------------------------------------------
; SSG test: A = register base (00h: SSG1, 10h: SSG2), uses ch.A
; -----------------------------------------------------------------------------
			scope	ssg_test
ssg_test::
			ld		[ssg_base], a
			add		a, 7				; tone A only
			ld		b, a
			ld		c, 0xBE
			call	ssg_write
			ld		a, [ssg_base]		; channel volume (20h / 24h)
			rrca
			rrca
			add		a, 0x20
			ld		b, a
			ld		c, 128
			call	ssg_write
			ld		hl, ssg_desc
			call	play_arp
			ld		a, [ssg_base]
			add		a, 7
			ld		b, a
			ld		c, 0xBF
			jp		ssg_write

ssg_on:
			ld		c, a				; PAN (28h / 2Ch)
			ld		a, [ssg_base]
			rrca
			rrca
			add		a, 0x28
			ld		b, a
			call	ssg_write
			ld		a, [ssg_base]		; tone period
			ld		b, a
			ld		c, e
			call	ssg_write
			inc		b
			ld		c, d
			call	ssg_write
			ld		a, [ssg_base]		; volume
			add		a, 8
			ld		b, a
			ld		c, 13
			jp		ssg_write

ssg_off:
			ld		a, [ssg_base]
			add		a, 8
			ld		b, a
			ld		c, 0
			jp		ssg_write

ssg_desc:
			dw		ssg_on, ssg_off, ssg_pitch
			endscope

; -----------------------------------------------------------------------------
; OPLL test: ch1 piano
; -----------------------------------------------------------------------------
			scope	opll_test
opll_test::
			ld		bc, 0x3030			; INST 3 (piano), VOL 0
			call	opll_write
			ld		bc, 0x4000			; tone bank 0
			call	opll_write
			ld		hl, opll_desc
			jp		play_arp

opll_on:
			ld		c, a
			ld		b, 0x50				; PAN
			call	opll_write
			ld		b, 0x10
			ld		c, e
			call	opll_write
			ld		a, d
			ld		[key_b0], a
			or		a, 0x10				; KEY
			ld		c, a
			ld		b, 0x20
			jp		opll_write

opll_off:
			ld		a, [key_b0]
			ld		c, a
			ld		b, 0x20
			jp		opll_write

opll_desc:
			dw		opll_on, opll_off, opll_pitch
			endscope

; -----------------------------------------------------------------------------
; OPLL rhythm test: BD, SD, TOM, CYM, HH, then all
; -----------------------------------------------------------------------------
			scope	rhythm_test
rhythm_test::
			ld		hl, rhythm_init_table
			call	opll_table
			ld		hl, rhythm_hits
loop:
			ld		a, [hl]
			or		a, a
			jr		z, done
			inc		hl
			or		a, 0x20
			ld		c, a
			ld		b, 0x0E
			push	bc
			ld		c, 0x20				; key off the drums, rhythm mode on
			call	opll_write
			pop		bc
			call	opll_write			; key on
			ld		b, RHY_FRAMES
			call	wait_frames
			jr		loop
done:
			ld		bc, 0x0E20
			call	opll_write
			ld		b, REST_FRAMES
			call	wait_frames
			ld		bc, 0x0E00
			jp		opll_write

rhythm_hits:
			db		0x10, 0x08, 0x04, 0x02, 0x01, 0x1F, 0x00
			endscope

; -----------------------------------------------------------------------------
; OPL2 test: ch1 lead
; -----------------------------------------------------------------------------
			scope	opl2_test
opl2_test::
			ld		hl, opl_patch_table
			call	opl_table
			ld		hl, opl_desc
			jp		play_arp

opl_on:
			ld		c, a
			ld		b, 0xF6				; PAN of ch1
			call	opl_write
			ld		b, 0xA0
			ld		c, e
			call	opl_write
			ld		a, d
			ld		[key_b0], a
			or		a, 0x20				; KEY-ON
			ld		c, a
			ld		b, 0xB0
			jp		opl_write

opl_off:
			ld		a, [key_b0]
			ld		c, a
			ld		b, 0xB0
			jp		opl_write

opl_desc:
			dw		opl_on, opl_off, opl_pitch
			endscope

; -----------------------------------------------------------------------------
; OPM test: ch1 brass (PAN: L = 40h, R = 80h, C = C0h of register 20h)
; -----------------------------------------------------------------------------
			scope	opm_test
opm_test::
			ld		hl, opm_patch_table
			call	opm_table
			ld		hl, opm_desc
			jp		play_arp

opm_on:
			ld		c, 0x40
			cp		a, 64
			jr		c, set_pan
			ld		c, 0x80
			cp		a, 193
			jr		nc, set_pan
			ld		c, 0xC0
set_pan:
			ld		a, c
			or		a, (6 << 3) | 4		; FB | CON
			ld		c, a
			ld		b, 0x20
			call	opm_write
			ld		b, 0x28				; KC
			ld		c, e
			call	opm_write
			ld		bc, 0x3000			; KF
			call	opm_write
			ld		bc, 0x0878			; key on M1, C1, M2, C2
			jp		opm_write

opm_off:
			ld		bc, 0x0800
			jp		opm_write

opm_desc:
			dw		opm_on, opm_off, opm_pitch
			endscope

; -----------------------------------------------------------------------------
; adpcm_write: writes the sample to the ADPCM memory (address 0-) via MMIO.
;   BUF_RDY cannot be read through the MMIO, so a software wait is used.
; -----------------------------------------------------------------------------
			scope	adpcm_write
adpcm_write::
			ld		hl, adpcm_write_table
			call	opl_table
			ld		a, ADPCM_REG_DATA
			ld		[MMIO_OPL2], a
			call	wait_small
			ld		hl, adpcm_data
			ld		de, ADPCM_SIZE
loop:
			ld		a, [hl]
			ld		[MMIO_OPL2 + 1], a
			inc		hl
			ld		b, ADPCM_WAIT
wait:
			djnz	wait
			dec		de
			ld		a, d
			or		a, e
			jr		nz, loop
			ld		bc, (ADPCM_CONTROL1 << 8) | 0x01
			call	opl_write
			ld		bc, (ADPCM_CONTROL2 << 8) | 0x80
			jp		opl_write
			endscope

; -----------------------------------------------------------------------------
; adpcm_verify: reads the ADPCM memory back through the I/O ports (C0h/C1h)
;   and compares it with adpcm_data.
;   err_count: number of mismatches (FFFFh: BUF_RDY timeout)
;   first_addr / first_wrote / first_read: the first mismatch
; -----------------------------------------------------------------------------
			scope	adpcm_verify
adpcm_verify::
			ld		hl, 0
			ld		[err_count], hl
			ld		a, EN2_OPL2
			ld		[MMIO_EN2], a		; OPL2 I/O on (read back only)
			ld		hl, adpcm_read_table
io_loop:
			ld		b, [hl]
			inc		hl
			ld		c, [hl]
			inc		hl
			ld		a, b
			or		a, a
			jr		z, io_done
			call	io_opl_write
			jr		io_loop
io_done:
			ld		a, ADPCM_REG_DATA	; 2 dummy reads after the mode change
			out		[OPL_ADDR], a
			call	wait_small
			in		a, [OPL_DATA]
			in		a, [OPL_DATA]
			ld		bc, (ADPCM_CONTROL2 << 8) | 0x80	; reset the flags
			call	io_opl_write
			ld		bc, (ADPCM_CONTROL2 << 8) | 0x00	; unmask (BUF_RDY polling)
			call	io_opl_write
			ld		a, ADPCM_REG_DATA
			out		[OPL_ADDR], a
			call	wait_small

			ld		hl, adpcm_data
			ld		bc, ADPCM_SIZE
byte_loop:
			ld		de, 0				; BUF_RDY timeout
poll:
			in		a, [OPL_ADDR]
			and		a, ST_BUFRDY
			jr		nz, read_byte
			dec		de
			ld		a, d
			or		a, e
			jr		nz, poll
			ld		hl, 0xFFFF
			ld		[err_count], hl
			jr		finish
read_byte:
			in		a, [OPL_DATA]
			cp		a, [hl]
			jr		z, next
			ld		e, a
			push	hl
			ld		hl, [err_count]
			ld		a, h
			or		a, l
			inc		hl
			ld		[err_count], hl
			pop		hl
			jr		nz, next
			ld		a, e
			ld		[first_read], a
			ld		a, [hl]
			ld		[first_wrote], a
			push	hl
			ld		de, adpcm_data
			or		a, a
			sbc		hl, de
			ld		[first_addr], hl
			pop		hl
next:
			inc		hl
			dec		bc
			ld		a, b
			or		a, c
			jr		nz, byte_loop
finish:
			ld		bc, (ADPCM_CONTROL2 << 8) | 0x18	; mask the flags
			call	io_opl_write
			ld		bc, (ADPCM_CONTROL1 << 8) | 0x01
			call	io_opl_write
			ld		bc, (ADPCM_CONTROL2 << 8) | 0x80
			call	io_opl_write
			xor		a, a
			ld		[MMIO_EN2], a		; OPL2 I/O off
			ret
			endscope

; -----------------------------------------------------------------------------
; print_verify: prints the result of adpcm_verify
; -----------------------------------------------------------------------------
			scope	print_verify
print_verify::
			call	unmap_cartridge
			ei
			ld		hl, [err_count]
			ld		a, h
			and		a, l
			inc		a
			jr		z, timeout
			ld		a, h
			or		a, l
			jr		nz, mismatch
			ld		de, verify_ok_message
			call	puts
			jr		done
timeout:
			ld		de, verify_timeout_message
			call	puts
			jr		done
mismatch:
			ld		de, verify_ng_message
			call	puts
			ld		hl, [err_count]
			call	print_hex16
			ld		de, verify_first_message
			call	puts
			ld		hl, [first_addr]
			call	print_hex16
			ld		de, verify_wrote_message
			call	puts
			ld		a, [first_wrote]
			call	print_hex8
			ld		de, verify_read_message
			call	puts
			ld		a, [first_read]
			call	print_hex8
			ld		de, verify_end_message
			call	puts
done:
			di
			jp		map_cartridge
			endscope

; -----------------------------------------------------------------------------
; adpcm_play: plays the sample 3 times with PAN L, R, C (MMIO)
; -----------------------------------------------------------------------------
			scope	adpcm_play
adpcm_play::
			ld		hl, adpcm_play_table
			call	opl_table
			ld		hl, arp_pans
			ld		[arp_pan], hl
			ld		a, 3
			ld		[arp_count], a
loop:
			ld		hl, [arp_pan]
			ld		c, [hl]
			inc		hl
			ld		[arp_pan], hl
			ld		b, ADPCM_PAN
			call	opl_write
			ld		bc, (ADPCM_CONTROL1 << 8) | 0x01	; stop (RESET)
			call	opl_write
			ld		bc, (ADPCM_CONTROL1 << 8) | 0xA0	; START + MEMD
			call	opl_write
			ld		b, ADPCM_FRAMES + GAP_FRAMES
			call	wait_frames
			ld		hl, arp_count
			dec		[hl]
			jr		nz, loop
			ld		bc, (ADPCM_CONTROL1 << 8) | 0x01
			call	opl_write
			ld		bc, (ADPCM_PAN << 8) | 128
			jp		opl_write
			endscope

; -----------------------------------------------------------------------------
; puts (DE = 0 terminated string), putc (A = char), print_hex8 (A),
; print_hex16 (HL)
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

			scope	print_hex16
print_hex16::
			push	hl
			ld		a, h
			call	print_hex8
			pop		hl
			ld		a, l
			; fall through to print_hex8
			endscope

			scope	print_hex8
print_hex8::
			push	af
			rrca
			rrca
			rrca
			rrca
			call	print_hex4
			pop		af
print_hex4:
			and		a, 0x0F
			add		a, '0'
			cp		a, '9' + 1
			jr		c, putc
			add		a, 7
			jr		putc
			endscope

; -----------------------------------------------------------------------------
; Register tables: { register, data } ..., terminated by register 00h
;   (ssg_quiet_table is terminated by FFh)
; -----------------------------------------------------------------------------
ssg_quiet_table:
			db		0x07, 0xBF, 0x08, 0x00, 0x09, 0x00, 0x0A, 0x00
			db		0x17, 0xBF, 0x18, 0x00, 0x19, 0x00, 0x1A, 0x00
			db		0xFF, 0xFF

opl_quiet_table:
			db		0x01, 0x20		; WSE = 1
			db		0x08, 0x00		; CSM = 0, NOTE SEL = 0
			db		0xBD, 0x00		; melody mode
			db		ADPCM_CONTROL1, 0x01
			db		ADPCM_CONTROL2, 0x18
			db		ADPCM_CONTROL2, 0x80
			db		0x00, 0x00

rhythm_init_table:
			db		0x16, 0x20, 0x26, 0x05	; F-Number (same as MSX-MUSIC)
			db		0x17, 0x50, 0x27, 0x05
			db		0x18, 0xC0, 0x28, 0x01
			db		0x36, 0x00, 0x37, 0x00, 0x38, 0x00	; volume max
			db		0x46, 0x00, 0x47, 0x00, 0x48, 0x00	; tone bank 0
			db		0x56, 0x80, 0x57, 0x80, 0x58, 0x80	; PAN center
			db		0x0E, 0x20				; rhythm mode
			db		0x00, 0x00

opl_patch_table:				; ch1 (slot 0 / 3): lead
			db		0xC0, (6 << 1) | 0
			db		0x20, 0x21, 0x40, 0x1A, 0x60, 0xF2, 0x80, 0x15, 0xE0, 0x02
			db		0x23, 0x61, 0x43, 0x04, 0x63, 0xF1, 0x83, 0x16, 0xE3, 0x00
			db		0x00, 0x00

opm_patch_table:				; ch1: brass
			db		0x01, 0x02, 0x01, 0x00	; LFO reset
			db		0x0F, 0x00				; noise off
			db		0x38, 0x00				; PMS | AMS
			db		0x40, 0x01, 0x60, 0x1C, 0x80, 0x12, 0xA0, 0x08, 0xC0, 0x00, 0xE0, 0x27	; M1
			db		0x48, 0x31, 0x68, 0x1E, 0x88, 0x12, 0xA8, 0x08, 0xC8, 0x00, 0xE8, 0x27	; M2
			db		0x50, 0x01, 0x70, 0x14, 0x90, 0x16, 0xB0, 0x05, 0xD0, 0x02, 0xF0, 0x18	; C1
			db		0x58, 0x71, 0x78, 0x14, 0x98, 0x16, 0xB8, 0x05, 0xD8, 0x02, 0xF8, 0x18	; C2
			db		0x00, 0x00

adpcm_write_table:
			db		ADPCM_CONTROL1, 0x01		; stop (RESET)
			db		ADPCM_CONTROL2, 0x18		; mask the flags (no IRQ)
			db		ADPCM_CONTROL2, 0x80		; reset the flags
			db		0x08, 0x00					; 256KB RAM
			db		0x09, 0x00, 0x0A, 0x00		; start
			db		0x0B, ADPCM_STOP & 0xFF, 0x0C, ADPCM_STOP >> 8
			db		ADPCM_CONTROL1, 0x60		; memory write (REC + MEMD)
			db		0x00, 0x00

adpcm_read_table:				; (I/O)
			db		ADPCM_CONTROL1, 0x01		; stop (RESET)
			db		ADPCM_CONTROL2, 0x18
			db		0x08, 0x00
			db		0x09, 0x00, 0x0A, 0x00
			db		0x0B, ADPCM_STOP & 0xFF, 0x0C, ADPCM_STOP >> 8
			db		ADPCM_CONTROL1, 0x20		; memory read (MEMD)
			db		0x00, 0x00

adpcm_play_table:
			db		ADPCM_CONTROL1, 0x01
			db		0x08, 0x00
			db		0x09, 0x00, 0x0A, 0x00
			db		0x0B, ADPCM_STOP & 0xFF, 0x0C, ADPCM_STOP >> 8
			db		0x10, ADPCM_DELTA_N & 0xFF, 0x11, ADPCM_DELTA_N >> 8
			db		0x12, 0xFF					; volume
			db		0x00, 0x00

arp_pans:
			db		1, 255, 128, 128

; -----------------------------------------------------------------------------
; Messages
; -----------------------------------------------------------------------------
title_message:
			ds		"MMIOTEST [Y8960 Memory Mapped I/O Test] v1.0\r\n"
			ds		"Copyright (C)2026 HRA!\r\n\r\n"
			ds		"I/O ports of OPL2/OPM/SSG are disabled (7FFFh=00h),\r\n"
			ds		"all sounds are written via 7FF0h-7FFFh.\r\n"
			ds		"Each test plays C-E-G-C with PAN L,R,C,C.\r\n"
			ds		"ESC: stop\r\n\r\n"
			db		0
not_detected_message:
			ds		"Y8960 Cartridge not found.\r\n"
			db		0
slot_error_message:
			ds		"Y8960 Cartridge slot not found (enabler failed).\r\n"
			db		0
ssg1_message:
			ds		"1. SSG1 ch.A  (7FF0h/7FF1h R#00h-, PAN R#28h)\r\n"
			db		0
ssg2_message:
			ds		"2. SSG2 ch.A  (7FF0h/7FF1h R#10h-, PAN R#2Ch)\r\n"
			db		0
opll_message:
			ds		"3. OPLL ch1   (7FF4h/7FF5h, piano, PAN R#50h)\r\n"
			db		0
rhythm_message:
			ds		"4. OPLL rhythm (BD, SD, TOM, CYM, HH, ALL)\r\n"
			db		0
opl2_message:
			ds		"5. OPL2 ch1   (7FF2h/7FF3h, PAN R#F6h)\r\n"
			db		0
opm_message:
			ds		"6. OPM ch1    (7FFBh/7FFCh, PAN = RL of R#20h)\r\n"
			db		0
adpcm_write_message:
			ds		"7. ADPCM memory write (7FF2h/7FF3h)\r\n"
			ds		"   verify (I/O C0h/C1h): "
			db		0
verify_ok_message:
			ds		"OK\r\n"
			db		0
verify_timeout_message:
			ds		"NG (BUF_RDY timeout)\r\n"
			db		0
verify_ng_message:
			ds		"NG, errors="
			db		0
verify_first_message:
			ds		"h (first at "
			db		0
verify_wrote_message:
			ds		"h: wrote "
			db		0
verify_read_message:
			ds		"h, read "
			db		0
verify_end_message:
			ds		"h)\r\n"
			db		0
adpcm_play_message:
			ds		"8. ADPCM play (PAN L,R,C)\r\n"
			db		0
done_message:
			ds		"Done.\r\n"
			db		0
stopped_message:
			ds		"\r\nStopped.\r\n"
			db		0

; -----------------------------------------------------------------------------
; Variables
; -----------------------------------------------------------------------------
saved_sp:
			dw		0
cur_slot:
			db		0
saved_en2:
			db		0
ssg_base:
			db		0
key_b0:
			db		0
arp_on:
			dw		0
arp_off:
			dw		0
arp_pitch:
			dw		0
arp_pan:
			dw		0
arp_count:
			db		0
err_count:
			dw		0
first_addr:
			dw		0
first_wrote:
			db		0
first_read:
			db		0

; -----------------------------------------------------------------------------
; Pitch tables and the ADPCM sample
; -----------------------------------------------------------------------------
			include	"mmiotest.inc"
end_of_program:
