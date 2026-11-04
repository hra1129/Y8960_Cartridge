; -----------------------------------------------------------------------------
;   CANCAN [Y8960 All Sound Chips Sample]
;
;   J.Offenbach: Orphee aux enfers - Galop infernal (Can-can)
;   played with all the sound chips of the Y8960 Cartridge:
;   OPM, OPL2, ADPCM, OPLL, SCC and SSG.
;
;   Usage:
;       CANCAN
;
;       ESC stops the playback.
;
;   Build:
;       python mkcancan.py         (-> cancan.inc)
;       zma cancan.asm CANCAN.COM
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

; -----------------------------------------------------------------------------
;	OPL2 + ADPCM (I/O C0h/C1h) / OPM (I/O 7Eh/7Fh)
; -----------------------------------------------------------------------------
OPL_ADDR		:= 0xC0
OPL_DATA		:= 0xC1
OPL_PAN			:= 0xF6			; F6h-FEh: PAN of ch1-9 (Y8960 extension)
OPL_KEYON		:= 0x20

ADPCM_CONTROL2	:= 0x04			; flag masks / IRQ reset
ADPCM_CONTROL1	:= 0x07			; START/REC/MEMD/REPEAT/SPOFF/RESET
ADPCM_MODE		:= 0x08
ADPCM_START_L	:= 0x09
ADPCM_STOP_L	:= 0x0B
ADPCM_REG_DATA		:= 0x0F
ADPCM_DELTA_L	:= 0x10
ADPCM_DELTA_H	:= 0x11
ADPCM_VOLUME	:= 0x12
ADPCM_PAN		:= 0xFF			; Y8960 extension
ST_BUFRDY		:= 0x08

OPM_ADDR		:= 0x7E
OPM_DATA		:= 0x7F
OPM_KEYON		:= 0x78			; M1, C1, M2, C2

; -----------------------------------------------------------------------------
;	Memory mapped I/O of the cartridge
;     While playing, page 1 and page 2 are switched to the cartridge slot,
;     so everything used then must be placed below 4000h (see the end).
; -----------------------------------------------------------------------------
MMIO_SSG		:= 0x7FF0		; 7FF0h: register, 7FF1h: data
MMIO_OPLL		:= 0x7FF4		; 7FF4h: register, 7FF5h: data
MIXER_SSG		:= 0x7FF7		; mixer volumes (write only, 128 = x1.0)
MIXER_OPLL		:= 0x7FF8
MIXER_OPL2		:= 0x7FF9
MIXER_SCC		:= 0x7FFA
MIXER_OPM		:= 0x7FFD
MIXER_MASTER	:= 0x7FFE

SSG2_TONE		:= 0x10			; SSG2 registers (10h-1Fh)
SSG2_MIXER		:= 0x17
SSG2_VOLUME		:= 0x18
SSG2_PAN		:= 0x2C
SSG2_MIXER_ON	:= 0xB8			; tone A-C on, noise off
SSG2_MIXER_OFF	:= 0xBF

OPLL_FNUM		:= 0x10
OPLL_KEY		:= 0x20			; SUS, KEY, BLOCK, F-Number bit8
OPLL_INST		:= 0x30			; INST | VOL
OPLL_BANK		:= 0x40			; Y8960 extension
OPLL_PAN		:= 0x50			; Y8960 extension
OPLL_KEYON		:= 0x10

SCC_BANK2		:= 0x9000		; bank register of 8000h-9FFFh (RAM Mode=0)
SCC_BANK2_RM	:= 0x4FFE		; bank register of 8000h-9FFFh (RAM Mode=1)
SCC_MODE		:= 0x4FFB		; bit0: RAM Mode
SCC_BANK_SCC	:= 0x3F
SCC_BANK_INIT	:= 0x02
SCC_WAVE		:= 0x9800
SCC_FREQ		:= 0x9880
SCC_VOLUME		:= 0x988A
SCC_ENABLE		:= 0x988F
SCC_PAN			:= 0x9900		; Y8960 extension

; -----------------------------------------------------------------------------
;	Hardware channel numbers
; -----------------------------------------------------------------------------
HW_OPM			:= 0x00			; 00h-07h
HW_OPL2			:= 0x08			; 08h-10h
HW_OPLL			:= 0x20			; 20h-28h
HW_SCC			:= 0x30			; 30h-34h
HW_SSG			:= 0x40			; 40h-42h
HW_ADPCM		:= 0x50
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
;     ADPCM     : note number = drum number (1: kick, 2: snare, 3: crash)
; -----------------------------------------------------------------------------
CH_HW			:= 0			; channel work offsets
CH_PTR			:= 1
CH_REMAIN		:= 3
CH_LEN			:= 5
CH_FLAGS		:= 7			; bit0: ended, bit1: key on
CH_B0			:= 8			; OPL2/OPLL: block | F-Number high (no KEYON)
CH_V0			:= 9			; SCC/SSG software envelope
CH_VOL			:= 10
CH_ECNT			:= 11
CH_ERATE		:= 12			; frames per volume step (0: no decay)
CH_EMIN			:= 13
CH_SIZE			:= 14
CH_MAX			:= 32

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
			call	bios_ram_mode_off

			ld		de, loading_message
			call	puts
			di
			call	opl_init
			call	adpcm_load
			ei
			ld		de, adpcm_error_message
			call	c, puts

			ld		de, playing_message
			call	puts

			di
			call	map_cartridge
			call	mixer_init
			call	opm_init
			call	opll_init
			call	scc_init
			call	ssg_init
			call	setup_channels
			call	play
			push	de
			call	all_key_off
			ld		b, RELEASE_FRAMES
release_loop:
			call	wait_vsync
			djnz	release_loop
			call	shutdown
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
; find_and_enable
;   Searches all slots for a ROM ("AB" at 4000h) whose MMIO Enabler2 (7FFFh)
;   accepts and holds bit0 (OPL2) and bit2 (OPM). Enables them on the found
;   slot and verifies the OPL2 status port shows the idle pattern.
;   cur_slot holds the slot of the cartridge afterwards.
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
; bios_ram_mode_off: if the Y8960 BIOS ("MSSE8960" at 4010h) is found in
;   cur_slot, writes RAM Mode=0 (4FFBh=00h) once.
;   Temporary workaround: the current BIOS starts DOS with RAM Mode=1, where
;   9000h (BANK2 of the standard SCC) is ignored. The BIOS sets RAM Mode=1
;   by itself before it changes the banks, and the SRAM address does not
;   depend on RAM Mode, so the visible banks are not changed.
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
; opl_write: B = register, C = data (OPL2 needs a wait after each access)
;   preserves BC, DE, HL
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
; map_cartridge / unmap_cartridge: switches page 1 and page 2 to the
;   cartridge slot (for the direct MMIO/SCC access) and back to the RAM.
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
; cart_write: HL = address, E = data (page 1/2 = cartridge), preserves all
; -----------------------------------------------------------------------------
			scope	cart_write
cart_write::
			ld		[hl], e
			ret
			endscope

; -----------------------------------------------------------------------------
; ssg_write / opll_write: B = register, C = data (memory mapped I/O)
;   The OPLL writes are queued by the Y8960 (with /WAIT), so no software
;   wait is needed. preserves BC, DE, HL
; -----------------------------------------------------------------------------
			scope	ssg_write
ssg_write::
			push	hl
			ld		hl, MMIO_SSG
			jr		mmio_write
			endscope

			scope	opll_write
opll_write::
			push	hl
			ld		hl, MMIO_OPLL
			; fall through to mmio_write
			endscope

			scope	mmio_write
mmio_write::
			push	de
			ld		e, b
			call	cart_write
			inc		hl
			ld		e, c
			call	cart_write
			pop		de
			pop		hl
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
; adpcm_load: transfers the drum samples to the ADPCM memory
;   Must be called with interrupts disabled: BUF_RDY has to be unmasked to
;   poll it, and then the cartridge asserts /INT while BUF_RDY = 1.
; output: Cf = 1 on a BUF_RDY timeout (adpcm_ok = 0)
; -----------------------------------------------------------------------------
			scope	adpcm_load
adpcm_load::
			xor		a, a
			ld		[adpcm_ok], a
			ld		hl, adpcm_setup_table
setup_loop:
			ld		b, [hl]
			inc		hl
			ld		c, [hl]
			inc		hl
			call	opl_write
			ld		a, b
			cp		a, ADPCM_CONTROL2
			jr		nz, setup_loop
			ld		a, c
			or		a, a
			jr		nz, setup_loop		; ends with R#04 = 00h (unmask)

			ld		a, ADPCM_REG_DATA		; the register selection persists
			out		[OPL_ADDR], a
			call	wait_small
			ld		hl, adpcm_data
			ld		bc, ADPCM_SIZE
send_loop:
			ld		de, 0				; BUF_RDY timeout per byte
send_wait:
			in		a, [OPL_ADDR]
			and		a, ST_BUFRDY
			jr		nz, send_byte
			dec		de
			ld		a, d
			or		a, e
			jr		nz, send_wait
			call	adpcm_finish
			scf
			ret
send_byte:
			ld		a, [hl]
			out		[OPL_DATA], a
			inc		hl
			dec		bc
			ld		a, b
			or		a, c
			jr		nz, send_loop
			call	adpcm_finish
			ld		a, 1
			ld		[adpcm_ok], a
			or		a, a
			ret

; adpcm_finish: leaves the memory write mode, masks the flags
adpcm_finish:
			ld		bc, (ADPCM_CONTROL1 << 8) | 0x01
			call	opl_write
			ld		bc, (ADPCM_CONTROL2 << 8) | 0x80
			call	opl_write
			ld		bc, (ADPCM_CONTROL2 << 8) | 0x18
			jp		opl_write
			endscope

; -----------------------------------------------------------------------------
; opll_init: rhythm off, all key off
; -----------------------------------------------------------------------------
			scope	opll_init
opll_init::
			ld		bc, 0x0E00		; rhythm mode off
			call	opll_write
			ld		bc, (OPLL_KEY << 8) | 0x00
koff_loop:
			call	opll_write
			inc		b
			ld		a, b
			cp		a, OPLL_KEY + 9
			jr		nz, koff_loop
			ret
			endscope

; -----------------------------------------------------------------------------
; scc_init: maps the SCC registers to 9800h-, silences all channels
;   The Y8960 BIOS leaves RAM Mode=1 (4FFBh), where 9000h is ignored and
;   BANK2 is 4FFEh. Both are written, each one is ignored in the other mode.
; -----------------------------------------------------------------------------
			scope	scc_init
scc_init::
			ld		e, SCC_BANK_SCC
			call	set_scc_bank2
			ld		hl, SCC_VOLUME
			ld		e, 0
			ld		b, 5
vol_loop:
			call	cart_write
			inc		hl
			djnz	vol_loop
			ld		hl, SCC_ENABLE
			ld		e, 0x1F
			jp		cart_write
			endscope

; -----------------------------------------------------------------------------
; mixer_init: sets all mixer volumes to the reset value (128 = x1.0)
;   The BIOS may change them, and they cannot be read back.
; -----------------------------------------------------------------------------
			scope	mixer_init
mixer_init::
			ld		e, 128
			ld		hl, MIXER_SSG
			ld		b, MIXER_SCC - MIXER_SSG + 1
loop:
			call	cart_write
			inc		hl
			djnz	loop
			ld		hl, MIXER_OPM
			call	cart_write
			ld		hl, MIXER_MASTER
			jp		cart_write
			endscope

; -----------------------------------------------------------------------------
; set_scc_bank2: E = bank number of 8000h-9FFFh (RAM Mode=0 and RAM Mode=1)
; -----------------------------------------------------------------------------
			scope	set_scc_bank2
set_scc_bank2::
			ld		hl, SCC_BANK2_RM
			call	cart_write
			ld		hl, SCC_BANK2
			jp		cart_write
			endscope

; -----------------------------------------------------------------------------
; ssg_init: SSG2 tone on, all volumes 0
; -----------------------------------------------------------------------------
			scope	ssg_init
ssg_init::
			ld		bc, (SSG2_VOLUME << 8) | 0
			call	ssg_write
			inc		b
			call	ssg_write
			inc		b
			call	ssg_write
			ld		bc, (SSG2_MIXER << 8) | SSG2_MIXER_ON
			jp		ssg_write
			endscope

; -----------------------------------------------------------------------------
; shutdown: silences the SCC/SSG/ADPCM and restores the SCC bank register
; -----------------------------------------------------------------------------
			scope	shutdown
shutdown::
			ld		hl, SCC_ENABLE
			ld		e, 0
			call	cart_write
			ld		e, SCC_BANK_INIT
			call	set_scc_bank2
			ld		bc, (SSG2_MIXER << 8) | SSG2_MIXER_OFF
			call	ssg_write
			ld		bc, (ADPCM_CONTROL1 << 8) | 0x01
			call	opl_write
			ld		bc, (ADPCM_CONTROL2 << 8) | 0x80
			call	opl_write
			ld		bc, (ADPCM_CONTROL2 << 8) | 0x18
			jp		opl_write
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
			ld		[ix + CH_V0], 0
			ld		[ix + CH_VOL], 0
			ld		[ix + CH_ECNT], 0
			ld		[ix + CH_ERATE], 0
			ld		[ix + CH_EMIN], 0
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
; set_voice: A = hw channel, D = patch number, E = pan, IX = channel work
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
			cp		a, HW_ADPCM
			jr		z, adpcm_voice
			cp		a, HW_SSG
			jp		nc, ssg_voice
			cp		a, HW_SCC
			jp		nc, scc_voice
			cp		a, HW_OPLL
			jp		nc, opll_voice
			cp		a, HW_OPL2
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

adpcm_voice:
			ld		b, ADPCM_PAN
			ld		c, e
			jp		opl_write

opl_voice:
			sub		a, HW_OPL2
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

opll_voice:
			sub		a, HW_OPLL
			ld		[voice_ch], a
			add		a, OPLL_INST	; 30h: INST | VOL
			ld		b, a
			ld		c, d
			call	opll_write
			ld		a, [voice_ch]	; 40h: tone bank 0 (YM2413)
			add		a, OPLL_BANK
			ld		b, a
			ld		c, 0
			call	opll_write
			ld		a, [voice_ch]	; 50h: PAN
			add		a, OPLL_PAN
			ld		b, a
			ld		a, [voice_pan]
			ld		c, a
			call	opll_write
			ld		a, [voice_ch]	; 20h: key off
			add		a, OPLL_KEY
			ld		b, a
			ld		c, 0
			jp		opll_write

scc_voice:
			sub		a, HW_SCC
			ld		[voice_ch], a
			; HL = scc_patches + patch * 4 (wave, v0, vmin, rate)
			ld		l, d
			ld		h, 0
			add		hl, hl
			add		hl, hl
			ld		bc, scc_patches
			add		hl, bc
			ld		a, [hl]			; wave
			inc		hl
			call	set_env_params
			; DE = scc_waves + wave * 32
			ld		l, a
			ld		h, 0
			add		hl, hl
			add		hl, hl
			add		hl, hl
			add		hl, hl
			add		hl, hl
			ld		de, scc_waves
			add		hl, de
			ex		de, hl
			; HL = 9800h + ch * 32 (Ch.D and Ch.E share the waveform)
			ld		a, [voice_ch]
			cp		a, 4
			jr		c, scc_wave_ch
			ld		a, 3
scc_wave_ch:
			add		a, a
			add		a, a
			add		a, a
			add		a, a
			add		a, a
			ld		l, a
			ld		h, SCC_WAVE >> 8
			ld		b, 32
scc_wave_loop:
			ld		a, [de]
			inc		de
			push	de
			ld		e, a
			call	cart_write
			pop		de
			inc		hl
			djnz	scc_wave_loop
			ld		a, [voice_ch]	; PAN
			ld		l, a
			ld		h, SCC_PAN >> 8
			ld		a, [voice_pan]
			ld		e, a
			jp		cart_write

ssg_voice:
			sub		a, HW_SSG
			ld		[voice_ch], a
			; HL = psg_patches + patch * 3 (v0, vmin, rate)
			ld		l, d
			ld		h, 0
			ld		c, l
			ld		b, h
			add		hl, hl
			add		hl, bc
			ld		bc, psg_patches
			add		hl, bc
			call	set_env_params
			ld		a, [voice_ch]	; PAN
			add		a, SSG2_PAN
			ld		b, a
			ld		a, [voice_pan]
			ld		c, a
			jp		ssg_write

; set_env_params: HL = { v0, vmin, rate } -> IX channel work (preserves A)
set_env_params:
			push	af
			ld		a, [hl]
			ld		[ix + CH_V0], a
			inc		hl
			ld		a, [hl]
			ld		[ix + CH_EMIN], a
			inc		hl
			ld		a, [hl]
			ld		[ix + CH_ERATE], a
			pop		af
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
			call	update_envelopes
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
; update_envelopes: software decay of the SCC/SSG channels (once a frame)
; -----------------------------------------------------------------------------
			scope	update_envelopes
update_envelopes::
			ld		ix, ch_work
			ld		a, [num_channels]
			ld		b, a
ch_loop:
			ld		a, [ix + CH_ERATE]
			or		a, a
			jr		z, next_ch
			bit		FLAG_KEYON, [ix + CH_FLAGS]
			jr		z, next_ch
			dec		[ix + CH_ECNT]
			jr		nz, next_ch
			ld		[ix + CH_ECNT], a
			ld		a, [ix + CH_VOL]
			cp		a, [ix + CH_EMIN]
			jr		z, next_ch
			jr		c, next_ch
			dec		a
			ld		[ix + CH_VOL], a
			push	bc
			call	write_volume
			pop		bc
next_ch:
			ld		de, CH_SIZE
			add		ix, de
			djnz	ch_loop
			ret
			endscope

; -----------------------------------------------------------------------------
; write_volume: A = volume (0-15), IX = SCC or SSG channel work
; -----------------------------------------------------------------------------
			scope	write_volume
write_volume::
			ld		e, a
			ld		a, [ix + CH_HW]
			cp		a, HW_SSG
			jr		nc, ssg_volume
			add		a, (SCC_VOLUME & 0xFF) - HW_SCC
			ld		l, a
			ld		h, SCC_VOLUME >> 8
			jp		cart_write
ssg_volume:
			add		a, SSG2_VOLUME - HW_SSG
			ld		b, a
			ld		c, e
			jp		ssg_write
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
; key_on: A = MIDI note number (drum number for ADPCM), IX = channel work
;   Writes key off first, so that a repeated note is attacked again.
; -----------------------------------------------------------------------------
			scope	key_on
key_on::
			ld		e, a
			ld		d, 0
			ld		a, [ix + CH_HW]
			cp		a, HW_COND
			ret		z
			cp		a, HW_ADPCM
			jp		z, adpcm_key_on
			ld		c, [ix + CH_FLAGS]	; previous key state (OPLL)
			set		FLAG_KEYON, [ix + CH_FLAGS]
			cp		a, HW_SSG
			jp		nc, ssg_key_on
			cp		a, HW_SCC
			jp		nc, scc_key_on
			cp		a, HW_OPLL
			jp		nc, opll_key_on
			cp		a, HW_OPL2
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
			sub		a, HW_OPL2
			ld		[voice_ch], a
			add		a, 0xB0			; B0h: key off
			ld		b, a
			ld		c, [ix + CH_B0]
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
			ld		[ix + CH_B0], a
			or		a, OPL_KEYON
			ld		c, a
			ld		a, [voice_ch]	; B0h: key on, block, F-Number high
			add		a, 0xB0
			ld		b, a
			jp		opl_write

opll_key_on:
			sub		a, HW_OPLL
			ld		[voice_ch], a
			bit		FLAG_KEYON, c	; key off only when still sounding
			jr		z, opll_set_fnum
			add		a, OPLL_KEY
			ld		b, a
			ld		c, [ix + CH_B0]
			call	opll_write
opll_set_fnum:
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

scc_key_on:
			sub		a, HW_SCC
			add		a, a
			add		a, SCC_FREQ & 0xFF
			ld		hl, scc_freq_table
			add		hl, de
			add		hl, de
			ld		e, [hl]
			inc		hl
			ld		d, [hl]
			ld		l, a
			ld		h, SCC_FREQ >> 8
			call	cart_write		; frequency low
			inc		hl
			ld		e, d
			call	cart_write		; frequency high
			jr		start_envelope

ssg_key_on:
			sub		a, HW_SSG
			add		a, a
			add		a, SSG2_TONE
			ld		b, a
			ld		hl, ssg_tone_table
			add		hl, de
			add		hl, de
			ld		c, [hl]
			call	ssg_write		; tone period low
			inc		b
			inc		hl
			ld		c, [hl]
			call	ssg_write		; tone period high
			; fall through to start_envelope

start_envelope:
			ld		a, [ix + CH_ERATE]
			ld		[ix + CH_ECNT], a
			ld		a, [ix + CH_V0]
			ld		[ix + CH_VOL], a
			jp		write_volume

adpcm_key_on:
			ld		a, [adpcm_ok]
			or		a, a
			ret		z
			ld		hl, adpcm_table - 4	; drum 1 = first entry
			ld		a, e
			add		a, a
			add		a, a
			ld		e, a
			add		hl, de
			ld		bc, (ADPCM_CONTROL1 << 8) | 0x01	; stop (RESET)
			call	opl_write
			ld		b, ADPCM_START_L
			ld		e, 4			; start L/H, stop L/H
adpcm_addr_loop:
			ld		c, [hl]
			inc		hl
			call	opl_write
			inc		b
			dec		e
			jr		nz, adpcm_addr_loop
			ld		bc, (ADPCM_CONTROL1 << 8) | 0xA0	; START + MEMD
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
			cp		a, HW_ADPCM
			ret		z
			cp		a, HW_SCC
			jr		c, fm_key_off
			xor		a, a			; SCC/SSG: volume 0
			jp		write_volume
fm_key_off:
			cp		a, HW_OPLL
			jr		nc, opll_key_off
			cp		a, HW_OPL2
			jr		nc, opl_key_off
			ld		c, a
			ld		b, 0x08
			jp		opm_write
opll_key_off:
			add		a, OPLL_KEY - HW_OPLL
			ld		b, a
			ld		c, [ix + CH_B0]
			jp		opll_write
opl_key_off:
			add		a, 0xB0 - HW_OPL2
			ld		b, a
			ld		c, [ix + CH_B0]
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
; Chip initialize tables: { register, data } ...
; -----------------------------------------------------------------------------
opm_init_table:					; terminated by register 00h
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

opl_init_table:					; terminated by register 00h
			db		0x01, 0x20		; WSE = 1
			db		0x08, 0x00		; CSM = 0, NOTE SEL = 0
			db		0xBD, 0x40		; VIB depth = 14 cent, melody mode
			db		0x00, 0x00

adpcm_setup_table:				; terminated by R#04 = 00h
			db		ADPCM_CONTROL1, 0x01		; stop (RESET)
			db		ADPCM_MODE, 0x00			; 256KB RAM
			db		ADPCM_START_L + 0, 0x00
			db		ADPCM_START_L + 1, 0x00
			db		ADPCM_STOP_L + 0, ADPCM_STOP & 0xFF
			db		ADPCM_STOP_L + 1, ADPCM_STOP >> 8
			db		ADPCM_DELTA_L, ADPCM_DELTA_N & 0xFF
			db		ADPCM_DELTA_H, ADPCM_DELTA_N >> 8
			db		ADPCM_VOLUME, 0xFF
			db		ADPCM_CONTROL1, 0x60		; memory write (REC + MEMD)
			db		ADPCM_CONTROL2, 0x80		; reset the flags
			db		ADPCM_CONTROL2, 0x00		; unmask (BUF_RDY polling)

opl_slot_table:
			db		0x00, 0x01, 0x02, 0x08, 0x09, 0x0A, 0x10, 0x11, 0x12

; -----------------------------------------------------------------------------
; OPM patches (26 bytes)
;   FB | CON, PMS | AMS,
;   M1: DT1|MUL, TL, KS|AR, AMS-EN|D1R, DT2|D2R, D1L|RR
;   M2, C1, C2: same as M1
; -----------------------------------------------------------------------------
opm_patches:
			; 0: brass (2 x 2op, detuned)
			db		(6 << 3) | 4, 0x20
			db		0x01, 0x1C, 0x12, 0x08, 0x00, 0x27	; M1
			db		0x31, 0x1E, 0x12, 0x08, 0x00, 0x27	; M2
			db		0x01, 0x14, 0x16, 0x05, 0x02, 0x18	; C1
			db		0x71, 0x14, 0x16, 0x05, 0x02, 0x18	; C2
			; 1: electric piano
			db		(0 << 3) | 4, 0x00
			db		0x0E, 0x30, 0x1F, 0x0C, 0x00, 0xF6	; M1
			db		0x01, 0x26, 0x1F, 0x0A, 0x00, 0xF6	; M2
			db		0x01, 0x18, 0x1F, 0x06, 0x03, 0x36	; C1
			db		0x31, 0x18, 0x1F, 0x06, 0x03, 0x36	; C2
			; 2: bass
			db		(5 << 3) | 4, 0x00
			db		0x01, 0x1E, 0x1F, 0x08, 0x04, 0x27	; M1
			db		0x01, 0x28, 0x1F, 0x08, 0x04, 0x27	; M2
			db		0x01, 0x12, 0x1F, 0x05, 0x04, 0x28	; C1
			db		0x01, 0x16, 0x1F, 0x05, 0x04, 0x28	; C2

; -----------------------------------------------------------------------------
; OPL2 patches (11 bytes)
;   FB | CON,
;   modulator: AM|VIB|EG|KSR|MUL, KSL|TL, AR|DR, SL|RR, WS
;   carrier  : same as modulator
; -----------------------------------------------------------------------------
opl_patches:
			; 0: lead
			db		(6 << 1) | 0
			db		0x21, 0x1A, 0xF2, 0x15, 0x02
			db		0x61, 0x04, 0xF1, 0x16, 0x00
			; 1: harpsichord
			db		(6 << 1) | 0
			db		0x03, 0x1E, 0xF3, 0x44, 0x00
			db		0x01, 0x0E, 0xF3, 0x64, 0x00
			; 2: bass
			db		(5 << 1) | 0
			db		0x01, 0x18, 0xF4, 0x45, 0x00
			db		0x01, 0x02, 0xF3, 0x26, 0x00

; -----------------------------------------------------------------------------
; SCC patches (4 bytes): waveform (scc_waves), v0, vmin, frames per step
;   Ch.D and Ch.E share the waveform: patches 3 and 4 use the same one.
; -----------------------------------------------------------------------------
scc_patches:
			db		0, 14, 10, 4	; 0: melody (saw)
			db		1, 11, 7, 4		; 1: harmony (square)
			db		2, 12, 5, 2		; 2: chord (triangle)
			db		0, 10, 4, 2		; 3: chord (saw)
			db		0, 13, 6, 3		; 4: bass (saw)

; -----------------------------------------------------------------------------
; SSG patches (3 bytes): v0, vmin, frames per step
; -----------------------------------------------------------------------------
psg_patches:
			db		13, 9, 4		; 0: melody
			db		11, 7, 4		; 1: harmony
			db		13, 5, 2		; 2: bass

; -----------------------------------------------------------------------------
; Messages
; -----------------------------------------------------------------------------
title_message:
			ds		"CANCAN [Y8960 All Sound Chips Sample] v1.0\r\n"
			ds		"Copyright (C)2026 HRA!\r\n\r\n"
			ds		"J.Offenbach: Orphee aux enfers\r\n"
			ds		"             - Galop infernal (Can-can)\r\n\r\n"
			ds		"SSG -> SCC -> OPLL -> OPL2 -> OPM -> ALL\r\n"
			ds		"(drums: ADPCM)\r\n\r\n"
			db		0
not_detected_message:
			ds		"Y8960 Cartridge not found.\r\n"
			db		0
slot_error_message:
			ds		"Y8960 Cartridge slot not found (enabler failed).\r\n"
			db		0
loading_message:
			ds		"Loading ADPCM drums...\r\n"
			db		0
adpcm_error_message:
			ds		"ADPCM transfer failed (BUF_RDY timeout).\r\n"
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
adpcm_ok:
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
ch_work:
			space	CH_SIZE * CH_MAX

; -----------------------------------------------------------------------------
; Song data (adpcm_data is placed at the end: it is used only before the
; page switching, so it may exceed 4000h)
; -----------------------------------------------------------------------------
			include	"cancan.inc"
end_of_program:
