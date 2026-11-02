; -----------------------------------------------------------------------------
;   ADPLAY [Y8960 ADPCM Test Player]
;
;   Loads a raw Y8950-format ADPCM data file into the Y8960 Cartridge sample
;   memory (SerialSRAM) and plays it once. Intended for ADPCM debugging:
;   pair it with the SILENT / SINE1K / SWEEP test samples.
;
;   Usage:
;       ADPLAY <file> [/A:xxxx] [/D:xxxx] [/V:xx] [/R]
;
;       /A:xxxx  load address in sample memory (hex, byte unit, default 0000)
;       /D:xxxx  DELTA-N (hex, default 8000 = 24.86kHz)
;       /V:xx    ADPCM volume R#12 (hex, default FF)
;       /R       repeat play (returns to DOS immediately, keeps playing)
;
;   The file size must be a multiple of 4 bytes, and load address + size
;   must fit in the 256KB sample memory.
;
;   Build:
;       zma adplay.asm ADPLAY.COM
; -----------------------------------------------------------------------------
; History
; Nov/2nd/2026  First release (v1.0)
; Nov/2nd/2026  v1.1: re-select R#0F after the R#04 unmask writes in the
;               transfer loop (the register selection had been replaced,
;               so sample data went to R#04 and the transfer stalled);
;               added a BUF_RDY timeout with an error message.
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
;	MSX Defines
; -----------------------------------------------------------------------------
BDOS			:= 0x0005
_TERM0			:= 0x00
_CONIN			:= 0x01
_CONOUT			:= 0x02
_CONST			:= 0x0B
_FOPEN			:= 0x0F
_FCLOSE			:= 0x10
_FMAKE			:= 0x16
_WRBLK			:= 0x26
_SETDTA			:= 0x1A
_RDBLK			:= 0x27
RDSLT			:= 0x000C
WRSLT			:= 0x0014
EXPTBL			:= 0xFCC1

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
REG_START_L		:= 0x09
REG_START_H		:= 0x0A
REG_STOP_L		:= 0x0B
REG_STOP_H		:= 0x0C
REG_DATA		:= 0x0F
REG_DELTAN_L	:= 0x10
REG_DELTAN_H	:= 0x11
REG_VOLUME		:= 0x12

ST_EOS			:= 0x10			; status bit4
ST_BUFRDY		:= 0x08			; status bit3

BUFFER			:= 0x8000
BUFFER_SIZE		:= 0x4000

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

			call	play_file
			jp		c, puts_and_exit	; DE = error message

			ld		de, empty_message
			jp		puts_and_exit
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
;   then /A:xxxx /D:xxxx /V:xx /R options.
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
			ld		hl, 0
			ld		[opt_addr], hl
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
			cp		a, 'A'
			jr		z, opt_a
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
opt_a:
			call	parse_hex16
			ret		c
			ld		hl, [hex_value]
			ld		[opt_addr], hl
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
; play_file: open, transfer to sample memory, play.
; output: Cf = 1 with DE = error message on failure
; -----------------------------------------------------------------------------
			scope	play_file
play_file::
			; ---- open (interrupts ON: the disk driver needs them)
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

			; ---- validate: addr % 4 == 0
			ld		hl, [opt_addr]
			ld		a, l
			and		a, 0x03
			jp		nz, bad_size
			; The exact file size is NOT taken from the FCB: MSX-DOS 2.20
			; rounds the FCB file-size field down to a 256-byte multiple.
			; The write loop streams the file and counts the bytes actually
			; read. For hw_setup, file_size is set to the whole remaining
			; region (0x40000 - addr) so no write is dropped as ptr_over.
			ld		hl, [opt_addr]
			ex		de, hl
			ld		hl, 0
			or		a, a
			sbc		hl, de
			ld		[file_size], hl
			ld		a, 4
			sbc		a, 0
			ld		[file_size + 2], a
			ld		hl, 0
			ld		[total_lo], hl
			xor		a, a
			ld		[total_hi], a
			ld		de, loading_message
			call	puts
			; ---- transfer: file reads run with interrupts ON, the ADPCM
			;      register/data handling with interrupts OFF. Reason: with
			;      BUF_RDY unmasked (required to poll it via the status
			;      register) the cartridge asserts /INT while BUF_RDY = 1,
			;      and the BIOS handler never clears this source; with
			;      interrupts OFF the disk driver stalls instead.
			xor		a, a
			ld		[setup_done], a
transfer_loop:
			ld		hl, BUFFER_SIZE
			ld		[chunk_size], hl
			ld		de, BUFFER
			ld		c, _SETDTA
			call	BDOS
			ld		hl, BUFFER_SIZE
			ld		de, fcb
			ld		c, _RDBLK
			call	BDOS
			; HL = bytes actually read; A = 0 (full block) or 1 (EOF)
			cp		a, 2
			jp		nc, read_error
			ld		[chunk_size], hl
			ld		a, h
			or		a, l
			jp		z, transfer_done		; EOF: nothing read
			; ---- hardware window (interrupts OFF)
			di
			ld		a, [setup_done]
			or		a, a
			call	z, hw_setup		; first chunk only
			; unmask flags so BUF_RDY can be polled
			ld		b, REG_CONTROL2
			ld		c, 0x80
			call	write_reg
			ld		b, REG_CONTROL2
			ld		c, 0x00
			call	write_reg
			; Re-select the data register: the R#04 accesses above have
			; replaced the register selection made in hw_setup, and OPL_DATA
			; writes go to whichever register is currently selected.
			ld		a, REG_DATA
			out		[OPL_ADDR], a
			call	wait_small
			; send chunk to the data register
			ld		hl, BUFFER
			ld		bc, [chunk_size]
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
			; timeout: mask both flags, then bail out with an error
			ld		b, REG_CONTROL2
			ld		c, 0x18
			call	write_reg
			ei
			ld		de, transfer_error_message
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
			; mask both flags again before re-enabling interrupts
			ld		b, REG_CONTROL2
			ld		c, 0x18
			call	write_reg
			ei
			; total += chunk_size; a short block was the last one
			ld		hl, [total_lo]
			ld		de, [chunk_size]
			add		hl, de
			ld		[total_lo], hl
			ld		a, [total_hi]
			adc		a, 0
			ld		[total_hi], a
			ld		hl, [chunk_size]
			ld		a, h
			cp		a, 0x40
			jp		nz, transfer_done
			ld		a, l
			or		a, a
			jp		nz, transfer_done
			jp		transfer_loop
transfer_done:
			; file_size := the number of bytes actually written
			ld		hl, [total_lo]
			ld		[file_size], hl
			ld		a, [total_hi]
			ld		[file_size + 2], a
			or		a, a
			jr		nz, td_hi_ok
			ld		a, h
			or		a, l
			jp		z, bad_size			; empty file
td_hi_ok:
			ld		a, l
			and		a, 0x03
			jp		nz, bad_size			; total % 4 != 0
			ld		hl, [opt_addr]
			ld		de, [total_lo]
			add		hl, de
			ld		a, [total_hi]
			adc		a, 0
			cp		a, 5
			jp		nc, bad_size
			cp		a, 4
			jr		nz, td_ok
			ld		a, h
			or		a, l
			jp		nz, bad_size			; end address > 0x40000
td_ok:
			; ---- verify: close, reopen, read the SRAM back and compare.
			; (Flags are masked here; the last chunk window ended masked.)
			ld		de, fcb
			ld		c, _FCLOSE
			call	BDOS
			ld		de, verifying_message
			call	puts
			; reset verify state
			ld		hl, 0
			ld		[err_count], hl
			ld		[cur_off_lo], hl
			ld		[cur_off_lo + 2], hl
			xor		a, a
			ld		[rd_setup_done], a
			; create READBACK.BIN (the read-back bytes are saved there)
			ld		de, rdump_fcb
			ld		c, _FMAKE
			call	BDOS
			ld		hl, 1
			ld		[rdump_fcb + 14], hl
			xor		a, a
			ld		[rdump_fcb + 33], a
			ld		[rdump_fcb + 34], a
			ld		[rdump_fcb + 35], a
			ld		[rdump_fcb + 36], a
			; reopen
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
			ld		hl, [file_size]
			ld		[remain_lo], hl
			ld		a, [file_size + 2]
			ld		[remain_hi], a
verify_loop:
			ld		a, [remain_hi]
			or		a, a
			jr		nz, v_full_chunk
			ld		hl, [remain_lo]
			ld		a, h
			or		a, l
			jp		z, verify_done
			ld		a, h
			cp		a, 0x40
			jr		c, v_read_chunk
v_full_chunk:
			ld		hl, BUFFER_SIZE
v_read_chunk:
			ld		[chunk_size], hl
			; read one chunk (interrupts ON)
			push	hl
			ld		de, BUFFER
			ld		c, _SETDTA
			call	BDOS
			ld		de, fcb
			pop		hl
			push	hl
			ld		c, _RDBLK
			call	BDOS
			pop		de
			or		a, a
			jp		nz, read_error
			ld		a, h
			cp		a, d
			jp		nz, read_error
			ld		a, l
			cp		a, e
			jp		nz, read_error
			; compare the chunk against SRAM (interrupts OFF)
			di
			ld		a, [rd_setup_done]
			or		a, a
			call	z, rd_setup
			ld		b, REG_CONTROL2		; clear flags
			ld		c, 0x80
			call	write_reg
			ld		b, REG_CONTROL2		; unmask flags
			ld		c, 0x00
			call	write_reg
			; re-select R#0F (the R#04 writes replaced the selection)
			ld		a, REG_DATA
			out		[OPL_ADDR], a
			call	wait_small
			ld		hl, BUFFER
			ld		bc, [chunk_size]
			ld		ix, rbuf
vbyte_loop:
			ld		de, 0				; BUF_RDY timeout per byte
vpoll:
			in		a, [OPL_ADDR]
			and		a, ST_BUFRDY
			jr		nz, vread_byte
			dec		de
			ld		a, d
			or		a, e
			jr		nz, vpoll
			ld		b, REG_CONTROL2
			ld		c, 0x18
			call	write_reg
			ei
			ld		de, verify_timeout_message
			scf
			ret
vread_byte:
			in		a, [OPL_DATA]		; A = byte read from SRAM
			ld		[ix + 0], a
			inc		ix
			ld		e, a
			ld		a, [hl]			; A = expected byte
			cp		a, e
			jr		z, vbyte_next
			; mismatch: record the first one and count them all
			push	hl
			push	bc
			ld		d, a				; D = expected
			ld		hl, [err_count]
			ld		a, h
			or		a, l
			jr		nz, verr_counted
			ld		a, [cur_off_lo]
			ld		[first_off], a
			ld		a, [cur_off_lo + 1]
			ld		[first_off + 1], a
			ld		a, [cur_off_lo + 2]
			ld		[first_off + 2], a
			ld		a, d
			ld		[first_wrote], a
			ld		a, e
			ld		[first_read], a
verr_counted:
			ld		hl, [err_count]
			inc		hl
			ld		[err_count], hl
			pop		bc
			pop		hl
vbyte_next:
			inc		hl
			; cur_off++
			ld		a, [cur_off_lo]
			inc		a
			ld		[cur_off_lo], a
			jr		nz, voff_done
			ld		a, [cur_off_lo + 1]
			inc		a
			ld		[cur_off_lo + 1], a
			jr		nz, voff_done
			ld		a, [cur_off_lo + 2]
			inc		a
			ld		[cur_off_lo + 2], a
voff_done:
			dec		bc
			ld		a, b
			or		a, c
			jr		nz, vbyte_loop
			; mask both flags again before re-enabling interrupts
			ld		b, REG_CONTROL2
			ld		c, 0x18
			call	write_reg
			ei
			; remain -= chunk_size
			ld		hl, [remain_lo]
			ld		de, [chunk_size]
			or		a, a
			sbc		hl, de
			ld		[remain_lo], hl
			ld		a, [remain_hi]
			sbc		a, 0
			ld		[remain_hi], a
			; append the captured bytes to READBACK.BIN
			ld		de, rbuf
			ld		c, _SETDTA
			call	BDOS
			ld		hl, [chunk_size]
			ld		de, rdump_fcb
			ld		c, _WRBLK
			call	BDOS
			jp		verify_loop
verify_done:
			ld		de, fcb
			ld		c, _FCLOSE
			call	BDOS
			ld		de, rdump_fcb
			ld		c, _FCLOSE
			call	BDOS
			ld		de, saved_message
			call	puts
			ld		hl, [err_count]
			ld		a, h
			or		a, l
			jr		nz, report_fail
			ld		de, verify_ok_message
			call	puts
			ld		de, done_message
			call	puts
			or		a, a
			ret
report_fail:
			call	print_dec16
			ld		de, mismatches_message
			call	puts
			ld		de, firstat_message
			call	puts
			ld		a, [first_off + 2]
			call	print_hex8
			ld		hl, [first_off]
			call	print_hex16
			ld		de, wrote_message
			call	puts
			ld		a, [first_wrote]
			call	print_hex8
			ld		de, read_message
			call	puts
			ld		a, [first_read]
			call	print_hex8
			ld		de, dot_message
			call	puts
			or		a, a
			ret

; rd_setup: register setup + enter memory-read mode + select R#0F +
; discard the two dummy data reads that follow a mode change.
; Called with interrupts OFF. Sets [rd_setup_done] = 1.
rd_setup:
			ld		b, REG_CONTROL1		; stop ADPCM (RESET bit)
			ld		c, 0x01
			call	write_reg
			ld		b, REG_MODE			; 256KB RAM mode
			ld		c, 0x00
			call	write_reg
			ld		hl, [opt_addr]
			srl		h
			rr		l
			srl		h
			rr		l
			ld		b, REG_START_L
			ld		c, l
			call	write_reg
			ld		b, REG_START_H
			ld		c, h
			call	write_reg
			ld		hl, [total_lo]
			ld		a, [total_hi]
			srl		a
			rr		h
			rr		l
			srl		a
			rr		h
			rr		l
			or		a, a
			jr		nz, rd_stop_max
			dec		hl
			jr		rd_stop_ready
rd_stop_max:
			ld		hl, 0xFFFF
rd_stop_ready:
			ld		b, REG_STOP_L
			ld		c, l
			call	write_reg
			ld		b, REG_STOP_H
			ld		c, h
			call	write_reg
			; enter memory mode (REC + MEMD): direction comes from the
			; data-port access (read = memory read)
			ld		b, REG_CONTROL1
			ld		c, 0x20
			call	write_reg
			; select the data register and discard the 2 dummy reads
			ld		a, REG_DATA
			out		[OPL_ADDR], a
			call	wait_small
			in		a, [OPL_DATA]
			in		a, [OPL_DATA]
			ld		a, 1
			ld		[rd_setup_done], a
			ret

; hw_setup: register setup + enter memory-write mode + select R#0F.
; Called with interrupts OFF. Sets [setup_done] = 1.
hw_setup:
			ld		b, REG_CONTROL1		; stop ADPCM (RESET bit)
			ld		c, 0x01
			call	write_reg
			ld		b, REG_MODE			; 256KB RAM mode
			ld		c, 0x00
			call	write_reg
			; start address (4-byte units)
			ld		hl, [opt_addr]
			srl		h
			rr		l
			srl		h
			rr		l
			ld		b, REG_START_L
			ld		c, l
			call	write_reg
			ld		b, REG_START_H
			ld		c, h
			call	write_reg
			; stop address = total / 4 - 1 (total is A:HL, <= 0x40000)
			ld		hl, [total_lo]
			ld		a, [total_hi]
			srl		a
			rr		h
			rr		l
			srl		a
			rr		h
			rr		l
			or		a, a
			jr		nz, stop_max		; total == 0x40000 -> stop = 0xFFFF
			dec		hl
			jr		stop_ready
stop_max:
			ld		hl, 0xFFFF
stop_ready:
			ld		b, REG_STOP_L
			ld		c, l
			call	write_reg
			ld		b, REG_STOP_H
			ld		c, h
			call	write_reg
			; DELTA-N
			ld		hl, [opt_delta]
			ld		b, REG_DELTAN_L
			ld		c, l
			call	write_reg
			ld		b, REG_DELTAN_H
			ld		c, h
			call	write_reg
			; volume
			ld		a, [opt_volume]
			ld		c, a
			ld		b, REG_VOLUME
			call	write_reg
			; memory-write mode (REC + MEMD)
			ld		b, REG_CONTROL1
			ld		c, 0x60
			call	write_reg
			; select data register once (selection persists)
			ld		a, REG_DATA
			out		[OPL_ADDR], a
			call	wait_small
			ld		a, 1
			ld		[setup_done], a
			ret

bad_size:
			ld		de, size_error_message
			scf
			ret
read_error:
			ld		de, read_error_message
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; puts (DE = 0 terminated string), putc (A = char)
; -----------------------------------------------------------------------------
			scope	print_hex8
print_hex8::
			push	af
			srl		a
			srl		a
			srl		a
			srl		a
			call	print_hex4
			pop		af
			and		a, 0x0F
			; fall through
			endscope

		scope	print_hex4
print_hex4::
			add		a, 0x30
			cp		a, 0x3A
			jr		c, ph4_out
			add		a, 7
ph4_out:
			jp		putc
			endscope

		scope	print_hex16
print_hex16::
			ld		a, h
			call	print_hex8
			ld		a, l
			jp		print_hex8
			endscope

		scope	print_dec16
print_dec16::
			; Build the decimal string first (BDOS output may clobber
			; registers, so no live state is kept across putc calls),
			; then print it with puts. HL holds the value to convert;
			; preserve it while dec_ptr is initialised.
			push	hl
			ld		hl, dec_buffer
			ld		[dec_ptr], hl
			pop		hl
			xor		a, a
			ld		[dec_started], a
			ld		de, 10000
			call	pd_digit
			ld		de, 1000
			call	pd_digit
			ld		de, 100
			call	pd_digit
			ld		de, 10
			call	pd_digit
			ld		a, l
			add		a, 0x30
			ld		b, a
			call	pd_store
			ld		hl, [dec_ptr]
			ld		[hl], 0
			ld		de, dec_buffer
			jp		puts
pd_digit:
			ld		b, 0x2F
pd_loop:
			inc		b
			or		a, a
			sbc		hl, de
			jr		nc, pd_loop
			add		hl, de
			ld		a, b
			cp		a, 0x30
			jr		nz, pd_store
			ld		a, [dec_started]
			or		a, a
			ret		z
pd_store:
			ld		a, 1
			ld		[dec_started], a
			ld		a, b
			push	hl
			ld		hl, [dec_ptr]
			ld		[hl], a
			inc		hl
			ld		[dec_ptr], hl
			pop		hl
			ret
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

; -----------------------------------------------------------------------------
; Messages
; -----------------------------------------------------------------------------
title_message:
			ds		"ADTEST [Y8960 ADPCM Write/Verify Test] v1.2\r\n"
			ds		"Copyright (C)2026 HRA!\r\n\r\n"
			db		0
usage_message:
			ds		"Usage: ADTEST <file> [/A:xxxx]\r\n"
			ds		"  /A:xxxx load address (hex, default 0000)\r\n"
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
			ds		"Bad file size or address (multiple of 4, within 256KB).\r\n"
			db		0
read_error_message:
			ds		"File read error.\r\n"
			db		0
transfer_error_message:
			ds		"ADPCM transfer timeout.\r\n"
			db		0
loading_message:
			ds		"Writing...\r\n"
			db		0
verifying_message:
			ds		"Verifying...\r\n"
			db		0
done_message:
			ds		"Done.\r\n"
			db		0
saved_message:
			ds		"Readback saved to READBACK.BIN.\r\n"
			db		0
verify_ok_message:
			ds		"Verify OK.\r\n"
			db		0
verify_timeout_message:
			ds		"ADPCM verify timeout.\r\n"
			db		0
mismatches_message:
			ds		" mismatches.\r\n"
			db		0
firstat_message:
			ds		"First mismatch at "
			db		0
wrote_message:
			ds		": wrote "
			db		0
read_message:
			ds		" read "
			db		0
dot_message:
			ds		".\r\n"
			db		0
empty_message:
			db		0

; -----------------------------------------------------------------------------
; Variables
; -----------------------------------------------------------------------------
cur_slot:
			db		0
saved_en2:
			db		0
opt_addr:
			dw		0
opt_delta:
			dw		0
opt_volume:
			db		0
opt_repeat:
			db		0
err_count:
			dw		0
cur_off_lo:
			db		0, 0, 0, 0
first_off:
			db		0, 0, 0
first_wrote:
			db		0
first_read:
			db		0
rd_setup_done:
			db		0
dec_started:
			db		0
dec_ptr:
			dw		0
dec_buffer:
			db		0, 0, 0, 0, 0, 0
rdump_fcb:
			db		0
			ds		"READBACKBIN"
			db		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
			db		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
hex_value:
			dw		0
file_size:
			dw		0
			db		0
total_lo:
			dw		0
total_hi:
			db		0
remain_lo:
			dw		0
remain_hi:
			db		0
chunk_size:
			dw		0
setup_done:
			db		0

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

; ----------------------------------------------------------------------
; Read-back capture buffer (16 KB). Kept LAST in the file: zma's ds
; reservation must not be followed by other data definitions.
; ----------------------------------------------------------------------
rbuf:
			ds		16384
