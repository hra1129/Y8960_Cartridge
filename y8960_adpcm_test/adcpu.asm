; -----------------------------------------------------------------------------
;   ADCPU [Y8960 ADPCM CPU Synthesis Sample]
;
;   Plays a raw Y8950-format ADPCM data file with the "ADPCM synthesis from
;   CPU" mode (R#07 = 80h). The sample memory is not used: the file is loaded
;   into main RAM, and the CPU writes each byte to R#0F, waiting for BUF_RDY.
;
;   Usage:
;       ADCPU <file> [/D:xxxx] [/V:xx] [/R]
;
;       /D:xxxx  DELTA-N (hex, default 8000 = 24.86kHz)
;       /V:xx    ADPCM volume R#12 (hex, default FF)
;       /R       repeat play until ESC is pressed
;
;   ESC stops the playback. The file must fit in the free main RAM
;   (about 50KB on MSX-DOS2, about 4 seconds at DELTA-N = 8000h).
;
;   Build:
;       zma adcpu.asm ADCPU.COM
; -----------------------------------------------------------------------------
; History
; Nov/3rd/2026  First release (v1.0)
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
;	MSX Defines
; -----------------------------------------------------------------------------
BDOS			:= 0x0005
TPA_TOP			:= 0x0006		; BDOS entry address = top of TPA
_TERM0			:= 0x00
_CONOUT			:= 0x02
_FOPEN			:= 0x0F
_FCLOSE			:= 0x10
_SETDTA			:= 0x1A
_RDBLK			:= 0x27
RDSLT			:= 0x000C
WRSLT			:= 0x0014
EXPTBL			:= 0xFCC1

PPI_KEY_DATA	:= 0xA9			; keyboard matrix column input
PPI_PORT_C		:= 0xAA			; bit3-0: keyboard row select
KEY_ROW_ESC		:= 7
KEY_BIT_ESC		:= 0x04

STACK_RESERVE	:= 0x0200

; -----------------------------------------------------------------------------
;	System Controller (I/O 40h)
; -----------------------------------------------------------------------------
SC_ENABLER		:= 0x40
SC_DEVSEL		:= 0x41
SC_ENABLE_KEY	:= 0x80
SC_ENABLED		:= 0x7F			; ~SC_ENABLE_KEY
SC_DEVICE_ID	:= 0x02			; Y8960 Cartridge
SC_DEVICE_ACK	:= 0xFD			; ~SC_DEVICE_ID

; -----------------------------------------------------------------------------
;	OPL2 + ADPCM (I/O C0h/C1h, status read from C0h)
; -----------------------------------------------------------------------------
OPL_ADDR		:= 0xC0
OPL_DATA		:= 0xC1

REG_CONTROL2	:= 0x04			; flag masks / IRQ reset
REG_CONTROL1	:= 0x07			; START/REC/MEMD/REPEAT/SPOFF/RESET
REG_MODE		:= 0x08			; 64K / ROM
REG_DATA		:= 0x0F
REG_DELTAN_L	:= 0x10
REG_DELTAN_H	:= 0x11
REG_VOLUME		:= 0x12

CTRL1_RESET		:= 0x01
CTRL1_CPU_SYNTH	:= 0x80			; START=1, REC=0, MEMORY DATA=0
CTRL2_IRQ_RESET	:= 0x80
CTRL2_MASK_EOS	:= 0x10
CTRL2_MASK_ALL	:= 0x18			; mask EOS and BUF_RDY

ST_BUFRDY		:= 0x08			; status bit3

PAD_DATA		:= 0x80			; nibbles 8 and 0: tiny steps

; -----------------------------------------------------------------------------
;	Entry Point
; -----------------------------------------------------------------------------
			org		0x100
			scope	entry_point
entry_point::
			ld		de, title_message
			call	puts

			call	parse_arguments
			jp		c, usage_and_exit

			call	sc_detect
			ld		de, not_detected_message
			jp		c, puts_and_exit

			call	find_and_enable
			ld		de, slot_error_message
			jp		c, puts_and_exit

			call	load_file
			jp		c, puts_and_exit	; DE = error message

			ld		de, playing_message
			call	puts
			call	play
			jp		puts_and_exit		; DE = result message
			endscope

; -----------------------------------------------------------------------------
; usage_and_exit / puts_and_exit (DE = message, 0 terminated)
; -----------------------------------------------------------------------------
			scope	usage_and_exit
usage_and_exit::
			ld		de, usage_message
			; fall through
			endscope

			scope	puts_and_exit
puts_and_exit::
			call	puts
			ld		c, _TERM0
			jp		BDOS
			endscope

; -----------------------------------------------------------------------------
; parse_arguments
;   Parses the command tail (0x80): first token = file name (into fcb),
;   then /D:xxxx /V:xx /R options.
; output:
;    Cf .... 0: success, 1: syntax error (no file name or bad option)
; -----------------------------------------------------------------------------
			scope	parse_arguments
parse_arguments::
			; clear fcb (37 bytes) and set defaults
			ld		hl, fcb
			ld		bc, 37
			xor		a, a
			call	memset
			; name/ext fields must be space-padded for FOPEN
			ld		hl, fcb_fname
			ld		bc, 11
			ld		a, ' '
			call	memset
			ld		hl, 0x8000
			ld		[opt_delta], hl
			ld		a, 0xFF
			ld		[opt_volume], a
			xor		a, a
			ld		[opt_repeat], a

			; terminate the command tail with 0 (tail area is 0x80..0xFF)
			ld		a, [0x80]
			ld		hl, 0x81
			ld		e, a
			ld		d, 0
			add		hl, de
			ld		[hl], 0

			ld		hl, 0x81
			call	skip_spaces
			ld		a, [hl]
			or		a, a
			scf
			ret		z			; empty tail
			; drive letter? (X:)
			ld		d, a			; save first char
			inc		hl
			ld		a, [hl]
			cp		a, ':'
			jr		nz, no_drive
			ld		a, d
			call	to_upper
			sub		a, 'A' - 1
			ld		[fcb_dr], a
			inc		hl
			jr		name_start
no_drive:
			dec		hl
name_start:
			ld		de, fcb_fname
			ld		b, 8
name_loop:
			ld		a, [hl]
			or		a, a
			jr		z, check_name
			cp		a, ' '
			jr		z, check_name
			cp		a, '.'
			jr		z, ext_start
			cp		a, '/'
			jr		z, check_name
			call	to_upper
			ld		[de], a
			inc		de
			inc		hl
			djnz	name_loop
name_skip:
			ld		a, [hl]
			or		a, a
			jr		z, check_name
			cp		a, ' '
			jr		z, check_name
			cp		a, '.'
			jr		z, ext_start
			cp		a, '/'
			jr		z, check_name
			inc		hl
			jr		name_skip
ext_start:
			inc		hl
			ld		de, fcb_fext
			ld		b, 3
ext_loop:
			ld		a, [hl]
			or		a, a
			jr		z, check_name
			cp		a, ' '
			jr		z, check_name
			cp		a, '/'
			jr		z, check_name
			call	to_upper
			ld		[de], a
			inc		de
			inc		hl
			djnz	ext_loop

check_name:
			ld		a, [fcb_fname]
			cp		a, ' '
			scf
			ret		z			; no file name
			or		a, a
			scf
			ret		z

opt_loop:
			call	skip_spaces
			ld		a, [hl]
			or		a, a
			jr		z, opt_done
			cp		a, '/'
			scf
			ret		nz			; junk after file name
			inc		hl
			ld		a, [hl]
			call	to_upper
			inc		hl
			cp		a, 'R'
			jr		z, opt_r
			cp		a, 'D'
			jr		z, opt_d
			cp		a, 'V'
			jr		z, opt_v
			scf
			ret
opt_r:
			ld		a, 1
			ld		[opt_repeat], a
			jr		opt_loop
opt_d:
			call	parse_hex16
			ret		c
			ld		hl, [hex_value]
			ld		[opt_delta], hl
			jr		opt_loop
opt_v:
			call	parse_hex16
			ret		c
			ld		a, [hex_value]	; low byte
			ld		[opt_volume], a
			jr		opt_loop
opt_done:
			or		a, a			; Cf = 0
			ret
			endscope

; -----------------------------------------------------------------------------
; parse_hex16
; in:  HL = tail pointer (optional ':' then hex digits)
; out: HL = tail pointer advanced, [hex_value] = value, Cf = 1 on no digits
; -----------------------------------------------------------------------------
			scope	parse_hex16
parse_hex16::
			ld		a, [hl]
			cp		a, ':'
			jr		nz, ph_start
			inc		hl
ph_start:
			ld		de, 0			; accumulator
			ld		b, 0			; digit count
ph_loop:
			ld		a, [hl]
			call	hex_digit		; A = 0..15 or Cf=1
			jr		c, ph_end
			inc		hl
			inc		b
			ex		de, hl
			add		hl, hl
			add		hl, hl
			add		hl, hl
			add		hl, hl
			or		a, l
			ld		l, a
			ex		de, hl
			jr		ph_loop
ph_end:
			ld		a, b
			or		a, a
			scf
			ret		z			; no digits
			ld		[hex_value], de
			or		a, a
			ret
			endscope

; -----------------------------------------------------------------------------
; hex_digit: A = char -> A = 0..15, or Cf = 1 if not a hex digit
; -----------------------------------------------------------------------------
			scope	hex_digit
hex_digit::
			call	to_upper
			cp		a, '0'
			jr		c, hd_ng
			cp		a, '9' + 1
			jr		c, hd_num
			cp		a, 'A'
			jr		c, hd_ng
			cp		a, 'F' + 1
			jr		nc, hd_ng
			sub		a, 'A' - 10
			or		a, a
			ret
hd_num:
			sub		a, '0'
			or		a, a
			ret
hd_ng:
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; memset: HL = addr, BC = len, A = value
; -----------------------------------------------------------------------------
			scope	memset
memset::
			ld		d, a
ms_loop:
			ld		a, d
			ld		[hl], a
			inc		hl
			dec		bc
			ld		a, b
			or		a, c
			jr		nz, ms_loop
			ret
			endscope

; -----------------------------------------------------------------------------
; skip_spaces: HL = text pointer, advance past spaces
; -----------------------------------------------------------------------------
			scope	skip_spaces
skip_spaces::
			ld		a, [hl]
			cp		a, ' '
			ret		nz
			inc		hl
			jr		skip_spaces
			endscope

; -----------------------------------------------------------------------------
; to_upper: A = char -> uppercase
; -----------------------------------------------------------------------------
			scope	to_upper
to_upper::
			cp		a, 'a'
			ret		c
			cp		a, 'z' + 1
			ret		nc
			sub		a, 'a' - 'A'
			ret
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
;   accepts and holds bit0 (OPL2+ADPCM). Enables bit0 on the found slot and
;   verifies the OPL2 status port shows the idle pattern.
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
			or		a, 0x01
			ld		e, a
			ld		a, [cur_slot]
			ld		hl, 0x7FFF
			call	WRSLT
			ld		a, [cur_slot]
			ld		hl, 0x7FFF
			call	RDSLT
			and		a, 0x01
			jr		z, restore_fail
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
; write_reg: B = register, C = data
; -----------------------------------------------------------------------------
			scope	write_reg
write_reg::
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
; load_file: loads the whole file into buffer_area.
; output: Cf = 1 with DE = error message on failure
; -----------------------------------------------------------------------------
			scope	load_file
load_file::
			; usable size = TPA top - STACK_RESERVE - buffer_area
			ld		hl, [TPA_TOP]
			ld		de, STACK_RESERVE + buffer_area
			or		a, a
			sbc		hl, de
			ld		[buffer_limit], hl

			ld		de, fcb
			ld		c, _FOPEN
			call	BDOS
			or		a, a
			ld		de, open_error_message
			scf
			ret		nz
			ld		hl, 1
			ld		[fcb_rsize], hl
			ld		hl, 0
			ld		[fcb_rn + 0], hl
			ld		[fcb_rn + 2], hl

			; The size in the FCB is not used: MSX-DOS 2.20 rounds it down to
			; a multiple of 256. Instead, buffer_limit + 1 bytes are requested
			; and the number of bytes actually read is the file size.
			ld		de, loading_message
			call	puts
			ld		de, buffer_area
			ld		c, _SETDTA
			call	BDOS
			ld		de, fcb
			ld		hl, [buffer_limit]
			inc		hl
			ld		c, _RDBLK
			call	BDOS			; HL = bytes read (A = 1 at end of file)
			; 1 <= size <= buffer_limit
			ld		a, h
			or		a, l
			jr		z, bad_size
			ld		[file_size], hl
			ex		de, hl
			ld		hl, [buffer_limit]
			or		a, a
			sbc		hl, de
			jr		c, bad_size
			ld		de, fcb
			ld		c, _FCLOSE
			call	BDOS
			or		a, a
			ret

bad_size:
			ld		de, fcb
			ld		c, _FCLOSE
			call	BDOS
			ld		de, size_error_message
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; play: ADPCM synthesis from CPU (R#07 = 80h)
;   Interrupts are disabled while playing. Reason: BUF_RDY must be unmasked
;   to poll it via the status register, and then the cartridge asserts /INT
;   while BUF_RDY = 1 (the BIOS handler never clears this source).
; output: DE = result message
; -----------------------------------------------------------------------------
			scope	play
play::
			di
			ld		b, REG_CONTROL1		; stop ADPCM
			ld		c, CTRL1_RESET
			call	write_reg
			ld		b, REG_MODE			; no sample memory options
			ld		c, 0x00
			call	write_reg
			ld		hl, [opt_delta]
			ld		b, REG_DELTAN_L
			ld		c, l
			call	write_reg
			ld		b, REG_DELTAN_H
			ld		c, h
			call	write_reg
			ld		a, [opt_volume]
			ld		c, a
			ld		b, REG_VOLUME
			call	write_reg
			; clear flags, then unmask BUF_RDY only (EOS is never raised here)
			ld		b, REG_CONTROL2
			ld		c, CTRL2_IRQ_RESET
			call	write_reg
			ld		b, REG_CONTROL2
			ld		c, CTRL2_MASK_EOS
			call	write_reg

			; The first byte is written before START, so that the first
			; nibble is valid even if it is decoded before the CPU can
			; write it again.
			ld		hl, buffer_area
			ld		b, REG_DATA
			ld		c, [hl]
			call	write_reg
			ld		b, REG_CONTROL1		; start synthesis from CPU
			ld		c, CTRL1_CPU_SYNTH
			call	write_reg
			; select R#0F once (the selection persists)
			ld		a, REG_DATA
			out		[OPL_ADDR], a
			call	wait_small
			; Writing the same first byte again clears BUF_RDY. From now on,
			; BUF_RDY = 1 means "the byte has been taken, send the next one".
			ld		a, [hl]
			out		[OPL_DATA], a
			inc		hl
			ld		bc, [file_size]
			dec		bc

send_loop:
			ld		a, b
			or		a, c
			jr		z, end_of_data
send_wait:
			in		a, [OPL_ADDR]
			and		a, ST_BUFRDY
			jr		nz, send_byte
			call	check_esc
			jr		nz, send_wait
			jr		stopped
send_byte:
			ld		a, [hl]
			out		[OPL_DATA], a
			inc		hl
			dec		bc
			jr		send_loop

end_of_data:
			ld		a, [opt_repeat]
			or		a, a
			jr		z, finish
			ld		hl, buffer_area		; repeat: continue with the first byte
			ld		bc, [file_size]
			jr		send_loop

finish:
			; The last byte has been written. One padding byte is sent, and
			; when it is taken, the lower nibble of the last byte has been
			; decoded as well.
			call	wait_buf_rdy
			jr		z, stopped
			ld		a, PAD_DATA
			out		[OPL_DATA], a
			call	wait_buf_rdy
			jr		z, stopped
			call	stop_adpcm
			ld		de, done_message
			ret

stopped:
			call	stop_adpcm
			ld		de, stopped_message
			ret

; wait_buf_rdy: Zf = 1 if ESC is pressed
wait_buf_rdy:
			in		a, [OPL_ADDR]
			and		a, ST_BUFRDY
			ret		nz
			call	check_esc
			jr		nz, wait_buf_rdy
			ret

; stop_adpcm: stop, clear and mask the flags, then enable interrupts
stop_adpcm:
			ld		b, REG_CONTROL1
			ld		c, CTRL1_RESET
			call	write_reg
			ld		b, REG_CONTROL2
			ld		c, CTRL2_IRQ_RESET
			call	write_reg
			ld		b, REG_CONTROL2
			ld		c, CTRL2_MASK_ALL
			call	write_reg
			ei
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
			ds		"ADCPU [Y8960 ADPCM CPU Synthesis Sample] v1.0\r\n"
			ds		"Copyright (C)2026 HRA!\r\n\r\n"
			db		0
usage_message:
			ds		"Usage: ADCPU <file> [/D:xxxx] [/V:xx] [/R]\r\n"
			ds		"  /D:xxxx DELTA-N (hex, default 8000)\r\n"
			ds		"  /V:xx   volume R#12 (hex, default FF)\r\n"
			ds		"  /R      repeat play\r\n"
			ds		"  ESC     stop\r\n"
			db		0
not_detected_message:
			ds		"Y8960 Cartridge not found.\r\n"
			db		0
slot_error_message:
			ds		"Y8960 Cartridge slot not found (enabler failed).\r\n"
			db		0
open_error_message:
			ds		"File open error.\r\n"
			db		0
size_error_message:
			ds		"Bad file size (empty or too large for the free RAM).\r\n"
			db		0
loading_message:
			ds		"Loading...\r\n"
			db		0
playing_message:
			ds		"Playing from CPU (ESC: stop)...\r\n"
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
opt_delta:
			dw		0
opt_volume:
			db		0
opt_repeat:
			db		0
hex_value:
			dw		0
file_size:
			dw		0
buffer_limit:
			dw		0

fcb:
fcb_dr:
			db		0
fcb_fname:
			ds		"        "
fcb_fext:
			ds		"   "
fcb_extent:
			dw		0
fcb_rsize:
			dw		0
fcb_filsiz:
			dw		0, 0
fcb_date:
			dw		0
fcb_time:
			dw		0
fcb_devid:
			db		0
fcb_dirloc:
			db		0
fcb_strcls:
			dw		0
fcb_clrcls:
			dw		0
fcb_clsoff:
			dw		0
fcb_cr:
			db		0
fcb_rn:
			dw		0, 0

; ADPCM data is loaded here (up to the top of TPA - STACK_RESERVE)
buffer_area:
