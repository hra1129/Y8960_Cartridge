; -----------------------------------------------------------------------------
;   Y8960UPD [Y8960 Cartridge Update Tool]
;
;   Copyright (C)2026 Takayuki Hara (HRA!)
;
;  Permission is hereby granted, free of charge, to any person obtaining a copy of this 
; software and associated documentation files (the "Software"), to deal in the Software 
; without restriction, including without limitation the rights to use, copy, modify, merge, 
; publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
; to whom the Software is furnished to do so, subject to the following conditions:
;  The above copyright notice and this permission notice shall be included in all copies or 
; substantial portions of the Software.
;  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
; INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
; PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
; FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
; ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
; SOFTWARE.
; -----------------------------------------------------------------------------
; History
; Oct/18th/2026  t.hara  First release
; Nov/2nd/2026  t.hara  ZX0 compressed image support
; -----------------------------------------------------------------------------
;	Build:
;		zma.exe y8960upd.asm Y8960UPD.COM
;
;	ConfigROM map:
;		000000h-7CFFFFh : Config data
;		7DFF00h-7DFF0Fh : Config data version string (16 bytes)
;		7DFF10h-7DFF1Fh : BIOS data version string (16 bytes)
;		7E0000h-7FFFFFh : BIOS data (128KB)
;
;	System Controller (I/O 40h-4Fh, see doc/spec/system_controller.md)
;		After writing a command to 46h, the controller does not accept any I/O
;		access until the command sequence has finished. 40h returns 7Fh only
;		when the controller is idle, so 40h is polled after every command.
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
;	MSX Defines
; -----------------------------------------------------------------------------
BDOS			:= 0x0005
_TERM0			:= 0x00
_CONOUT			:= 0x02
_FOPEN			:= 0x0F
_FCLOSE			:= 0x10
_SETDTA			:= 0x1A
_RDBLK			:= 0x27
JIFFY			:= 0xFC9E

; -----------------------------------------------------------------------------
;	System Controller
; -----------------------------------------------------------------------------
SC_ENABLER		:= 0x40
SC_DEVSEL		:= 0x41
SC_FUNCTION		:= 0x42
SC_ADDRESS_L	:= 0x43
SC_ADDRESS_M	:= 0x44
SC_ADDRESS_H	:= 0x45
SC_COMMAND		:= 0x46
SC_DATA			:= 0x47

SC_ENABLE_KEY	:= 0x80
SC_ENABLED		:= 0x7F			; ~SC_ENABLE_KEY
SC_DEVICE_ID	:= 0x02			; Y8960 Cartridge
SC_DEVICE_ACK	:= 0xFD			; ~SC_DEVICE_ID
SC_FUNC_ROM		:= 0x01			; Config ROM Reader/Writer
SC_FUNC_ACK		:= 0xFE			; ~SC_FUNC_ROM

CMD_READ		:= 0x00
CMD_WRITE		:= 0x01
CMD_ERASE		:= 0x02			; 64KB block erase
CMD_STATUS		:= 0x04			; bit0: BUSY

; -----------------------------------------------------------------------------
;	Constants
; -----------------------------------------------------------------------------
MODE_INFO		:= 0
MODE_HELP		:= 1
MODE_CONFIG		:= 2
MODE_BIOS		:= 3

HEADER_SIZE		:= 48
SIGNATURE_SIZE	:= 32
VERSION_SIZE	:= 16

FORMAT_RAW		:= 0
FORMAT_ZX0		:= 1

VERSION_ADDR_H	:= 0x7D			; 7DFF00h
VERSION_ADDR_M	:= 0xFF
CONFIG_MAX_H	:= 0x7D			; Config data must end before 7D0000h
BIOS_ADDR_H		:= 0x7E			; 7E0000h
BIOS_SIZE_H		:= 0x02			; 020000h (128KB)

BUSY_TIMEOUT	:= 600			; JIFFY count (10sec at 60Hz)

BUFFER			:= 0x8000
BUFFER_SIZE		:= 0x4000
COMP_BUFFER		:= 0x4000

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

			ld		a, [mode]
			cp		a, MODE_HELP
			jp		z, usage_and_exit
			cp		a, MODE_INFO
			jr		nz, skip_usage
			ld		de, usage_message
			call	puts
skip_usage:

			call	sc_detect
			ld		de, not_detected_message
			jp		c, puts_and_exit

			ld		a, [mode]
			cp		a, MODE_CONFIG
			jp		z, update_config
			cp		a, MODE_BIOS
			jp		z, update_bios

			; MODE_INFO
			call	show_versions
			ld		de, read_rom_error_message
			jp		c, puts_and_exit
			ld		de, empty_message
			jp		puts_and_exit
			endscope

; -----------------------------------------------------------------------------
;	Exit
; -----------------------------------------------------------------------------
			scope	exit
usage_and_exit::
			ld		de, usage_message
puts_and_exit::
			call	puts
			; Disable the System Controller.
			xor		a, a
			out		[SC_ENABLER], a

			ld		a, [file_opened]
			or		a, a
			jr		z, skip_close
			ld		de, fcb
			ld		c, _FCLOSE
			call	BDOS
skip_close:
			ld		c, _TERM0
			jp		BDOS
			endscope

; -----------------------------------------------------------------------------
; update_config
;    /C option: write the Config data to 000000h-
; -----------------------------------------------------------------------------
			scope	update_config
update_config::
			ld		hl, config_signature
			call	open_image
			jp		c, puts_and_exit

			; 0 < size <= 7D0000h
			ld		a, [data_size + 0]
			ld		hl, [data_size + 1]
			or		a, l
			or		a, h
			ld		de, size_error_message
			jp		z, puts_and_exit
			ld		a, [data_size + 0]
			cp		a, CONFIG_MAX_H
			jr		c, size_ok
			jp		nz, puts_and_exit
			ld		a, h
			or		a, l
			jp		nz, puts_and_exit
size_ok:
			xor		a, a						; 000000h
			call	program_image
			jp		c, puts_and_exit

			ld		hl, 0						; Config data version: 7DFF00h
			call	update_version
			jp		c, puts_and_exit

			ld		de, config_completed_message
			jp		puts_and_exit
			endscope

; -----------------------------------------------------------------------------
; update_bios
;    /B option: write the BIOS data to 7E0000h-7FFFFFh
; -----------------------------------------------------------------------------
			scope	update_bios
update_bios::
			ld		hl, bios_signature
			call	open_image
			jp		c, puts_and_exit

			; size == 020000h
			ld		de, size_error_message
			ld		hl, [data_size + 1]
			ld		a, h
			or		a, l
			jp		nz, puts_and_exit
			ld		a, [data_size + 0]
			cp		a, BIOS_SIZE_H
			jp		nz, puts_and_exit

			ld		a, BIOS_ADDR_H				; 7E0000h
			call	program_image
			jp		c, puts_and_exit

			ld		hl, VERSION_SIZE			; BIOS data version: 7DFF10h
			call	update_version
			jp		c, puts_and_exit

			ld		de, bios_completed_message
			jp		puts_and_exit
			endscope

; -----------------------------------------------------------------------------
; open_image
; input:
;    hl .... expected signature (32 bytes)
; output:
;    Cf .... 0: success, 1: error (de = error message)
;    data_size ... size of the data body (24bit)
;    image_format ... FORMAT_RAW (raw) or FORMAT_ZX0 (ZX0 block compressed)
;    header ...... header of the image file
; break:
;    all
; -----------------------------------------------------------------------------
			scope	open_image
open_image::
			push	hl
			call	display_file_name

			ld		de, fcb
			ld		c, _FOPEN
			call	BDOS
			pop		hl
			or		a, a
			ld		de, open_error_message
			scf
			ret		nz
			ld		a, 1
			ld		[file_opened], a

			push	hl
			; record size = 1, random record = 0
			ld		hl, 1
			ld		[fcb_rsize], hl
			ld		hl, 0
			ld		[fcb_rn + 0], hl
			ld		[fcb_rn + 2], hl

			; read header
			ld		de, header
			ld		c, _SETDTA
			call	BDOS
			ld		de, fcb
			ld		hl, HEADER_SIZE
			ld		c, _RDBLK
			call	BDOS
			pop		de							; expected signature
			ld		bc, HEADER_SIZE
			or		a, a
			sbc		hl, bc
			jr		nz, format_error

			; check signature (bytes 0-30; byte 31 is the format marker)
			ld		hl, header
			ld		b, SIGNATURE_SIZE - 1
check_loop:
			ld		a, [de]
			cp		a, [hl]
			jr		nz, format_error
			inc		de
			inc		hl
			djnz	check_loop

			; format marker (header byte 31)
			ld		a, [header + SIGNATURE_SIZE - 1]
			ld		[image_format], a
			cp		a, FORMAT_ZX0 + 1
			jr		nc, format_error
			or		a, a
			jr		nz, compressed_header

			; data_size = file size - HEADER_SIZE
			ld		a, [fcb_filsiz + 3]
			or		a, a
			ld		de, size_error_message
			scf
			ret		nz
			ld		hl, [fcb_filsiz + 0]
			ld		bc, HEADER_SIZE
			or		a, a
			sbc		hl, bc
			ld		[data_size + 1], hl			; [data_size + 1] = bit15-0
			ld		a, [fcb_filsiz + 2]
			sbc		a, 0
			ld		[data_size + 0], a			; [data_size + 0] = bit23-16
			jr		c, format_error
			jr		header_done

compressed_header:
			; read the subheader (the file pointer is at offset 48)
			ld		hl, 6
			ld		de, subheader
			call	read_exact
			ret		c

			; the original size must fit in 24 bits
			ld		a, [subheader + 3]
			or		a, a
			ld		de, size_error_message
			scf
			ret		nz
			ld		hl, [subheader + 0]
			ld		[data_size + 1], hl			; [data_size + 1] = bit15-0
			ld		a, [subheader + 2]
			ld		[data_size + 0], a			; [data_size + 0] = bit23-16

			; block size must be 1..16384
			ld		hl, [subheader + 4]
			ld		[cmp_block_size], hl
			ld		a, h
			or		a, l
			jr		z, format_error
			ld		bc, BUFFER_SIZE + 1
			or		a, a
			sbc		hl, bc
			jr		nc, format_error

header_done:
			ld		de, version_message
			call	puts
			ld		hl, header + SIGNATURE_SIZE
			call	put_version
			call	puts_crlf
			or		a, a
			ret

format_error:
			ld		de, format_error_message
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; program_image
; input:
;    a ..... start address bit23-16 (64KB aligned)
;    data_size ... size of the data body
; output:
;    Cf .... 0: success, 1: error (de = error message)
; break:
;    all
; comment:
;    Erases the blocks, then writes and verifies the data body of the
;    opened image file.
; -----------------------------------------------------------------------------
			scope	program_image
program_image::
			ld		[start_block], a

			; number of blocks = ceil( data_size / 64KB )
			ld		c, a
			ld		a, [data_size + 0]
			ld		b, a
			ld		hl, [data_size + 1]
			ld		a, h
			or		a, l
			jr		z, no_fraction
			inc		b
no_fraction:
			call	erase_blocks
			ret		c

			; write and verify
			ld		de, write_message
			ld		[progress_label], de
			ld		a, [start_block]
			ld		[cur_address + 2], a
			xor		a, a
			ld		[cur_address + 0], a
			ld		[cur_address + 1], a
			ld		a, [data_size + 0]
			ld		[remain_size + 2], a
			ld		hl, [data_size + 1]
			ld		[remain_size + 0], hl

chunk_loop:
			; completed when no data remains
			ld		a, [remain_size + 2]
			ld		hl, [remain_size + 0]
			or		a, h
			or		a, l
			jp		z, completed

			; chunk_size = min( remain_size, BUFFER_SIZE ) for raw data,
			; min( remain_size, cmp_block_size ) for compressed data
			ld		a, [image_format]
			or		a, a
			jr		nz, cmp_chunk_size
			ld		a, [remain_size + 2]
			or		a, a
			jr		nz, full_chunk
			ld		hl, [remain_size + 0]
			ld		bc, BUFFER_SIZE
			or		a, a
			sbc		hl, bc
			add		hl, bc
			jr		c, set_chunk
full_chunk:
			ld		hl, BUFFER_SIZE
			jr		set_chunk
cmp_chunk_size:
			ld		a, [remain_size + 2]
			or		a, a
			jr		nz, cmp_full_chunk
			ld		hl, [remain_size + 0]
			ld		bc, [cmp_block_size]
			or		a, a
			sbc		hl, bc
			add		hl, bc
			jr		c, set_chunk
cmp_full_chunk:
			ld		hl, [cmp_block_size]
set_chunk:
			ld		[chunk_size], hl

			call	display_address

			; read the chunk into BUFFER (decompressing it if compressed)
			call	read_chunk
			ret		c

			; write
			ld		hl, [cur_address + 0]
			ld		[chunk_address + 0], hl
			ld		a, [cur_address + 2]
			ld		[chunk_address + 2], a
			ld		hl, BUFFER
			ld		bc, [chunk_size]
			call	write_bytes
			ld		de, write_error_message
			ret		c

			; verify
			ld		hl, [chunk_address + 0]
			ld		[cur_address + 0], hl
			ld		a, [chunk_address + 2]
			ld		[cur_address + 2], a
			ld		hl, BUFFER
			ld		bc, [chunk_size]
			call	verify_bytes
			ret		c

			; remain_size -= chunk_size
			ld		hl, [remain_size + 0]
			ld		bc, [chunk_size]
			or		a, a
			sbc		hl, bc
			ld		[remain_size + 0], hl
			ld		a, [remain_size + 2]
			sbc		a, 0
			ld		[remain_size + 2], a
			jp		chunk_loop

completed:
			call	display_address
			ld		de, ok_message
			call	puts
			or		a, a
			ret
			endscope

; -----------------------------------------------------------------------------
; read_exact
; input:
;    hl .... number of bytes to read
;    de .... destination address
; output:
;    Cf .... 0: success, 1: error (de = read error message)
; break:
;    all
; comment:
;    Reads exactly hl bytes sequentially from the opened image file.
; -----------------------------------------------------------------------------
			scope	read_exact
read_exact::
			push	hl
			ld		c, _SETDTA
			call	BDOS
			pop		hl
			push	hl
			ld		de, fcb
			ld		c, _RDBLK
			call	BDOS
			pop		bc
			or		a, a
			sbc		hl, bc
			ret		z
			ld		de, read_error_message
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; read_chunk
; input:
;    chunk_size ... number of bytes to place in BUFFER (the uncompressed size)
; output:
;    Cf .... 0: success, 1: error (de = error message)
;    BUFFER ....... chunk_size bytes of the data body
; break:
;    all
; comment:
;    Raw images are read as-is. Compressed images are read frame by frame:
;    a frame with bit15 of its length word set is a stored (uncompressed)
;    block, any other frame is one independent ZX0 stream decompressed
;    from COMP_BUFFER into BUFFER.
; -----------------------------------------------------------------------------
			scope	read_chunk
read_chunk::
			ld		a, [image_format]
			or		a, a
			jr		nz, compressed

			; raw: read chunk_size bytes as-is
			ld		hl, [chunk_size]
			ld		de, BUFFER
			jp		read_exact

compressed:
			; read the frame word
			ld		hl, 2
			ld		de, frame_word
			call	read_exact
			ret		c

			ld		hl, [frame_word]
			bit		7, h
			jr		nz, stored_frame

			; ZX0 frame: its length must be 1..16384
			ld		a, h
			or		a, l
			jr		z, frame_error
			push	hl
			ld		bc, BUFFER_SIZE + 1
			or		a, a
			sbc		hl, bc
			pop		hl
			jr		nc, frame_error
			ld		de, COMP_BUFFER
			call	read_exact
			ret		c

			ld		hl, COMP_BUFFER
			ld		de, BUFFER
			call	dzx0_standard

			; DE must point at BUFFER + chunk_size
			ld		hl, BUFFER
			ld		bc, [chunk_size]
			add		hl, bc
			or		a, a
			sbc		hl, de
			ret		z
			ld		de, decompress_error_message
			scf
			ret

stored_frame:
			; the stored length (frame word & 0x7FFF) must equal chunk_size
			ld		a, h
			and		a, 0x7F
			ld		h, a
			ld		bc, [chunk_size]
			or		a, a
			sbc		hl, bc
			jr		nz, frame_error
			ld		hl, [chunk_size]
			ld		de, BUFFER
			jp		read_exact

frame_error:
			ld		de, format_error_message
			scf
			ret
			endscope

; ZX0D_BEGIN
; -----------------------------------------------------------------------------
; dzx0_standard
;    ZX0 decompressor ("Standard" version, 68 bytes)
;    by Einar Saukas & Urusergi. Ported to ZMA syntax.
;    ZX0 is BSD 3-Clause licensed, (C) Einar Saukas.
; input:
;    hl .... source address (compressed data)
;    de .... destination address (decompressed data)
; output:
;    de .... end address of the decompressed data
; -----------------------------------------------------------------------------
			scope	dzx0
dzx0_standard::
			ld		bc, 0xFFFF			; preserve default offset 1
			push	bc
			inc		bc
			ld		a, 0x80
dzx0s_literals:
			call	dzx0s_elias			; obtain length
			ldir						; copy literals
			add		a, a					; copy from last offset or new offset?
			jr		c, dzx0s_new_offset
			call	dzx0s_elias			; obtain length
dzx0s_copy:
			ex		[sp], hl				; preserve source, restore offset
			push	hl						; preserve offset
			add		hl, de				; calculate destination - offset
			ldir						; copy from offset
			pop		hl						; restore offset
			ex		[sp], hl				; preserve offset, restore source
			add		a, a					; copy from literals or new offset?
			jr		nc, dzx0s_literals
dzx0s_new_offset:
			pop		bc						; discard last offset
			ld		c, 0xFE				; prepare negative offset
			call	dzx0s_elias_loop	; obtain offset MSB
			inc		c
			ret		z						; check end marker
			ld		b, c
			ld		c, [hl]				; obtain offset LSB
			inc		hl
			rr		b						; last offset bit becomes first length bit
			rr		c
			push	bc						; preserve new offset
			ld		bc, 1					; obtain length
			call	nc, dzx0s_elias_backtrack
			inc		bc
			jr		dzx0s_copy
dzx0s_elias:
			inc		c						; interlaced Elias gamma coding
dzx0s_elias_loop:
			add		a, a
			jr		nz, dzx0s_elias_skip
			ld		a, [hl]				; load another group of 8 bits
			inc		hl
			rla
dzx0s_elias_skip:
			ret		c
dzx0s_elias_backtrack:
			add		a, a
			rl		c
			rl		b
			jr		dzx0s_elias_loop
			endscope
; ZX0D_END

; -----------------------------------------------------------------------------
; erase_blocks
; input:
;    c ..... first block (address bit23-16)
;    b ..... number of blocks (1 or more)
; output:
;    Cf .... 0: success, 1: error (de = error message)
; break:
;    all
; -----------------------------------------------------------------------------
			scope	erase_blocks
erase_blocks::
			ld		de, erase_message
			ld		[progress_label], de
loop:
			xor		a, a
			ld		[cur_address + 0], a
			ld		[cur_address + 1], a
			ld		a, c
			ld		[cur_address + 2], a
			push	bc
			call	display_address
			call	out_cur_address
			ld		a, CMD_ERASE
			call	sc_exec
			call	nc, rom_wait_ready
			ld		de, erase_error_message
			jr		c, failed
			; A 64KB erase takes milliseconds, so BUSY must be observed.
			; If not, the ConfigROM ignored the command (e.g. write protected).
			ld		a, [busy_seen]
			or		a, a
			jr		z, not_accepted
			call	blank_check
			jr		c, failed
			pop		bc
			inc		c
			djnz	loop

			ld		de, ok_message
			call	puts
			or		a, a
			ret

not_accepted:
			ld		de, erase_ignored_message
			call	puts
			ld		a, [last_status]
			call	puthex8
			ld		de, erase_ignored_end_message
failed:
			pop		bc
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; blank_check
; input:
;    cur_address ... start address of the erased block
; output:
;    Cf .... 0: the first 256 bytes are FFh, 1: error (de = error message)
; break:
;    all
; -----------------------------------------------------------------------------
			scope	blank_check
blank_check::
			ld		b, 0
loop:
			push	bc
			call	out_cur_address
			call	rom_read_byte
			pop		bc
			ld		de, read_rom_error_message
			ret		c
			cp		a, 0xFF
			jr		nz, not_blank
			call	inc_cur_address
			djnz	loop
			or		a, a
			ret

not_blank:
			ld		[verify_actual], a
			ld		de, blank_error_message
			call	puts
			call	put_address
			ld		de, blank_actual_message
			call	puts
			ld		a, [verify_actual]
			call	puthex8
			ld		de, verify_status_message
			call	puts
			ld		a, [last_status]
			call	puthex8
			ld		de, verify_end_message
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; write_bytes
; input:
;    hl .... source address
;    bc .... number of bytes (1 or more)
;    cur_address ... destination ConfigROM address
; output:
;    Cf .... 0: success, 1: error
;    cur_address ... next address
; break:
;    all
; comment:
;    FFh is skipped because the erased ConfigROM is already FFh.
; -----------------------------------------------------------------------------
			scope	write_bytes
write_bytes::
			ld		a, [hl]
			cp		a, 0xFF
			jr		z, skip
			push	hl
			push	bc
			call	out_cur_address
			pop		bc
			pop		hl
			ld		a, [hl]
			out		[SC_DATA], a
			ld		a, CMD_WRITE
			push	hl
			push	bc
			call	sc_exec
			call	nc, rom_wait_ready
			pop		bc
			pop		hl
			ret		c
skip:
			call	inc_cur_address
			inc		hl
			dec		bc
			ld		a, b
			or		a, c
			jr		nz, write_bytes
			ret									; Cf = 0 (or a, c)
			endscope

; -----------------------------------------------------------------------------
; verify_bytes
; input:
;    hl .... expected data
;    bc .... number of bytes (1 or more)
;    cur_address ... ConfigROM address
; output:
;    Cf .... 0: success, 1: error (de = error message)
;    cur_address ... next address
; break:
;    all
; -----------------------------------------------------------------------------
			scope	verify_bytes
verify_bytes::
			call	out_cur_address
			call	rom_read_byte
			ld		de, read_rom_error_message
			ret		c
			cp		a, [hl]
			jr		nz, mismatch
			call	inc_cur_address
			inc		hl
			dec		bc
			ld		a, b
			or		a, c
			jr		nz, verify_bytes
			ret									; Cf = 0 (or a, c)

mismatch:
			ld		[verify_actual], a
			ld		a, [hl]
			ld		[verify_expected], a
			ld		de, verify_error_message
			call	puts
			call	put_address
			ld		de, verify_expected_message
			call	puts
			ld		a, [verify_expected]
			call	puthex8
			ld		de, verify_actual_message
			call	puts
			ld		a, [verify_actual]
			call	puthex8
			ld		de, verify_status_message
			call	puts
			ld		a, [last_status]
			call	puthex8
			ld		de, verify_end_message
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; update_version
; input:
;    hl .... 0: Config data version, 16: BIOS data version
;    header ... header of the image file (version string at +32)
; output:
;    Cf .... 0: success, 1: error (de = error message)
; break:
;    all
; comment:
;    The version strings share the 64KB block 7D0000h-7DFFFFh.
;    Both strings are saved, the block is erased and both are written back.
; -----------------------------------------------------------------------------
			scope	update_version
update_version::
			push	hl
			ld		de, version_write_message
			call	puts
			call	read_versions
			pop		hl
			ld		de, read_rom_error_message
			ret		c

			ld		de, version_buffer
			add		hl, de
			ex		de, hl
			ld		hl, header + SIGNATURE_SIZE
			ld		bc, VERSION_SIZE
			ldir

			ld		c, VERSION_ADDR_H
			ld		b, 1
			call	erase_blocks
			ret		c

			call	set_version_address
			ld		hl, version_buffer
			ld		bc, VERSION_SIZE * 2
			call	write_bytes
			ld		de, write_error_message
			ret		c

			call	set_version_address
			ld		hl, version_buffer
			ld		bc, VERSION_SIZE * 2
			call	verify_bytes
			ret		c

			ld		de, ok_message
			call	puts
			or		a, a
			ret
			endscope

; -----------------------------------------------------------------------------
; read_versions
; output:
;    Cf .... 0: success, 1: error
;    version_buffer ... 7DFF00h-7DFF1Fh
; break:
;    all
; -----------------------------------------------------------------------------
			scope	read_versions
read_versions::
			call	set_version_address
			ld		hl, version_buffer
			ld		b, VERSION_SIZE * 2
loop:
			push	bc
			call	out_cur_address
			call	rom_read_byte
			pop		bc
			ret		c
			ld		[hl], a
			inc		hl
			call	inc_cur_address
			djnz	loop
			or		a, a
			ret
			endscope

; -----------------------------------------------------------------------------
; set_version_address
;    cur_address = 7DFF00h
; -----------------------------------------------------------------------------
			scope	set_version_address
set_version_address::
			xor		a, a
			ld		[cur_address + 0], a
			ld		a, VERSION_ADDR_M
			ld		[cur_address + 1], a
			ld		a, VERSION_ADDR_H
			ld		[cur_address + 2], a
			ret
			endscope

; -----------------------------------------------------------------------------
; show_versions
; output:
;    Cf .... 0: success, 1: error
; break:
;    all
; -----------------------------------------------------------------------------
			scope	show_versions
show_versions::
			call	read_versions
			ret		c
			ld		de, config_version_message
			call	puts
			ld		hl, version_buffer
			call	put_version
			call	puts_crlf
			ld		de, bios_version_message
			call	puts
			ld		hl, version_buffer + VERSION_SIZE
			call	put_version
			call	puts_crlf
			or		a, a
			ret
			endscope

; -----------------------------------------------------------------------------
; put_version
; input:
;    hl .... version string (16 bytes, 00h terminated if shorter)
; break:
;    all
; -----------------------------------------------------------------------------
			scope	put_version
put_version::
			ld		a, [hl]
			cp		a, 0xFF
			jr		z, not_written
			or		a, a
			jr		z, not_written
			ld		b, VERSION_SIZE
loop:
			ld		a, [hl]
			or		a, a
			ret		z
			cp		a, ' '
			jr		c, replace
			cp		a, 0x7F
			jr		c, put_one
replace:
			ld		a, '?'
put_one:
			push	hl
			push	bc
			call	putc
			pop		bc
			pop		hl
			inc		hl
			djnz	loop
			ret
not_written:
			ld		de, none_message
			jp		puts
			endscope

; -----------------------------------------------------------------------------
; sc_detect
; output:
;    Cf .... 0: Y8960 Cartridge detected, 1: not detected
; break:
;    a
; comment:
;    Enables the System Controller and selects the Config ROM Reader/Writer.
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
			ld		a, SC_FUNC_ROM
			out		[SC_FUNCTION], a
			in		a, [SC_FUNCTION]
			cp		a, SC_FUNC_ACK
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
; sc_exec
; input:
;    a ..... command
; output:
;    Cf .... 0: success, 1: timeout
; break:
;    a, f
; comment:
;    Issues the command and waits until the System Controller becomes idle.
; -----------------------------------------------------------------------------
			scope	sc_exec
sc_exec::
			out		[SC_COMMAND], a
			push	bc
			ld		bc, 0
loop:
			in		a, [SC_ENABLER]
			cp		a, SC_ENABLED
			jr		z, idle
			dec		bc
			ld		a, b
			or		a, c
			jr		nz, loop
			pop		bc
			scf
			ret
idle:
			pop		bc
			or		a, a
			ret
			endscope

; -----------------------------------------------------------------------------
; rom_read_byte
; input:
;    ConfigROM address registers (43h-45h)
; output:
;    a ..... read data
;    Cf .... 0: success, 1: timeout
; break:
;    a, f
; -----------------------------------------------------------------------------
			scope	rom_read_byte
rom_read_byte::
			ld		a, CMD_READ
			call	sc_exec
			ret		c
			in		a, [SC_DATA]
			ret
			endscope

; -----------------------------------------------------------------------------
; rom_wait_ready
; output:
;    Cf .... 0: ready, 1: timeout
; break:
;    a, f, de
; comment:
;    Polls the BUSY bit of the ConfigROM status register.
; -----------------------------------------------------------------------------
			scope	rom_wait_ready
rom_wait_ready::
			push	hl
			xor		a, a
			ld		[busy_seen], a
			ld		hl, [JIFFY]
			ld		[wait_start], hl
loop:
			ld		a, CMD_STATUS
			call	sc_exec
			jr		c, exit
			in		a, [SC_DATA]
			ld		[last_status], a
			rrca
			jr		nc, exit					; BUSY = 0
			ld		a, 1
			ld		[busy_seen], a
			ld		hl, [JIFFY]
			ld		de, [wait_start]
			or		a, a
			sbc		hl, de
			ld		de, BUSY_TIMEOUT
			or		a, a
			sbc		hl, de
			jr		c, loop
			scf
exit:
			pop		hl
			ret
			endscope

; -----------------------------------------------------------------------------
; out_cur_address
;    Writes cur_address to the address registers (43h-45h).
; break:
;    a
; -----------------------------------------------------------------------------
			scope	out_cur_address
out_cur_address::
			ld		a, [cur_address + 0]
			out		[SC_ADDRESS_L], a
			ld		a, [cur_address + 1]
			out		[SC_ADDRESS_M], a
			ld		a, [cur_address + 2]
			out		[SC_ADDRESS_H], a
			ret
			endscope

; -----------------------------------------------------------------------------
; inc_cur_address
;    cur_address = cur_address + 1
; break:
;    none
; -----------------------------------------------------------------------------
			scope	inc_cur_address
inc_cur_address::
			push	hl
			ld		hl, cur_address
			inc		[hl]
			jr		nz, exit
			inc		hl
			inc		[hl]
			jr		nz, exit
			inc		hl
			inc		[hl]
exit:
			pop		hl
			ret
			endscope

; -----------------------------------------------------------------------------
; display_address
;    Displays "\r" + progress_label + cur_address (6 digits) + "h"
; break:
;    all
; -----------------------------------------------------------------------------
			scope	display_address
display_address::
			ld		a, 13
			call	putc
			ld		de, [progress_label]
			call	puts
put_address::
			ld		a, [cur_address + 2]
			call	puthex8
			ld		a, [cur_address + 1]
			call	puthex8
			ld		a, [cur_address + 0]
			call	puthex8
			ld		a, 'h'
			jp		putc
			endscope

; -----------------------------------------------------------------------------
; display_file_name
;    Displays "File: " + file name in the FCB
; break:
;    all
; -----------------------------------------------------------------------------
			scope	display_file_name
display_file_name::
			ld		de, file_message
			call	puts
			ld		a, [fcb_dr]
			or		a, a
			jr		z, skip_drive
			add		a, 'A' - 1
			call	putc
			ld		a, ':'
			call	putc
skip_drive:
			ld		hl, fcb_fname
			ld		b, 8
			call	put_fcb_name
			ld		a, [fcb_fext]
			cp		a, ' '
			jr		z, skip_ext
			ld		a, '.'
			call	putc
			ld		hl, fcb_fext
			ld		b, 3
			call	put_fcb_name
skip_ext:
			jp		puts_crlf

put_fcb_name:
			ld		a, [hl]
			cp		a, ' '
			ret		z
			push	hl
			push	bc
			call	putc
			pop		bc
			pop		hl
			inc		hl
			djnz	put_fcb_name
			ret
			endscope

; -----------------------------------------------------------------------------
; parse_arguments
; output:
;    Cf .... 0: success, 1: syntax error
;    mode .. MODE_INFO, MODE_HELP, MODE_CONFIG, MODE_BIOS
;    fcb ... target file name (MODE_CONFIG, MODE_BIOS)
; break:
;    all
; -----------------------------------------------------------------------------
			scope	parse_arguments
parse_arguments::
			ld		hl, 0x0080
			ld		b, [hl]
			inc		hl
			ld		a, MODE_INFO
			ld		[mode], a

			call	skip_spaces
			ret		z							; no argument (Cf = 0)
			call	get_char
			cp		a, '/'
			jr		nz, syntax_error
			call	get_char
			jr		z, syntax_error
			ld		c, MODE_HELP
			cp		a, 'H'
			jr		z, set_mode
			cp		a, '?'
			jr		z, set_mode
			ld		c, MODE_CONFIG
			cp		a, 'C'
			jr		z, set_file_mode
			ld		c, MODE_BIOS
			cp		a, 'B'
			jr		nz, syntax_error
set_file_mode:
			ld		a, c
			ld		[mode], a
			; a delimiter is needed between the option and the file name
			call	get_char
			jr		z, syntax_error
			call	is_space
			jr		nz, syntax_error
			call	skip_spaces
			jr		z, syntax_error
			call	parse_file_name
			ret		c
			call	skip_spaces
			jr		nz, syntax_error
			or		a, a
			ret
set_mode:
			ld		a, c
			ld		[mode], a
			or		a, a
			ret
syntax_error:
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; parse_file_name
; input:
;    hl .... pointer of the command line
;    b ..... remaining length
; output:
;    Cf .... 0: success, 1: syntax error
;    fcb ... drive, file name and extension
; -----------------------------------------------------------------------------
			scope	parse_file_name
parse_file_name::
			; drive
			ld		a, b
			cp		a, 2
			jr		c, no_drive
			inc		hl
			ld		a, [hl]
			dec		hl
			cp		a, ':'
			jr		nz, no_drive
			call	get_char
			sub		a, 'A' - 1
			jr		c, syntax_error
			jr		z, syntax_error
			cp		a, 9
			jr		nc, syntax_error
			ld		[fcb_dr], a
			call	get_char					; ':'
no_drive:
			; file name
			ld		de, fcb_fname
			ld		c, 8
name_loop:
			call	get_char
			jr		z, done
			call	is_space
			jr		z, unget_done
			cp		a, '.'
			jr		z, extension
			ld		[de], a
			inc		de
			dec		c
			jr		nz, name_loop
			call	get_char
			jr		z, done
			call	is_space
			jr		z, unget_done
			cp		a, '.'
			jr		nz, syntax_error
extension:
			ld		de, fcb_fext
			ld		c, 3
ext_loop:
			call	get_char
			jr		z, done
			call	is_space
			jr		z, unget_done
			cp		a, '.'
			jr		z, syntax_error
			ld		[de], a
			inc		de
			dec		c
			jr		nz, ext_loop
			call	get_char
			jr		z, done
			call	is_space
			jr		nz, syntax_error
unget_done:
			dec		hl
			inc		b
done:
			ld		a, [fcb_fname]
			cp		a, ' '
			jr		z, syntax_error
			or		a, a
			ret
syntax_error:
			scf
			ret
			endscope

; -----------------------------------------------------------------------------
; get_char
; input:
;    hl .... pointer of the command line
;    b ..... remaining length
; output:
;    a ..... character (upper case)
;    Zf .... 1: end of the command line
; -----------------------------------------------------------------------------
			scope	get_char
get_char::
			ld		a, b
			or		a, a
			ret		z
			dec		b
			ld		a, [hl]
			inc		hl
			cp		a, 'a'
			jr		c, not_lower
			cp		a, 'z' + 1
			jr		nc, not_lower
			sub		a, 0x20
not_lower:
			or		a, a						; Zf = 0 (a character is not 00h)
			ret
			endscope

; -----------------------------------------------------------------------------
; skip_spaces
; output:
;    a ..... next character (not consumed)
;    Zf .... 1: end of the command line
; -----------------------------------------------------------------------------
			scope	skip_spaces
skip_spaces::
			call	get_char
			ret		z
			call	is_space
			jr		z, skip_spaces
			dec		hl
			inc		b
			or		a, a						; Zf = 0
			ret
			endscope

; -----------------------------------------------------------------------------
; is_space
; output:
;    Zf .... 1: a is a space or a tab
; -----------------------------------------------------------------------------
			scope	is_space
is_space::
			cp		a, ' '
			ret		z
			cp		a, 9
			ret
			endscope

; -----------------------------------------------------------------------------
; puts_crlf / puts
; input:
;    de .... string (00h terminated)
; break:
;    all
; -----------------------------------------------------------------------------
			scope	puts
puts_crlf::
			ld		de, crlf_message
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

; -----------------------------------------------------------------------------
; putc
; input:
;    a ..... character
; break:
;    all
; -----------------------------------------------------------------------------
			scope	putc
putc::
			ld		e, a
			ld		c, _CONOUT
			jp		BDOS
			endscope

; -----------------------------------------------------------------------------
; puthex8
; input:
;    a ..... number
; break:
;    all
; -----------------------------------------------------------------------------
			scope	puthex8
puthex8::
			push	af
			rrca
			rrca
			rrca
			rrca
			call	put_digit
			pop		af
put_digit:
			and		a, 0x0F
			add		a, '0'
			cp		a, '9' + 1
			jr		c, putc
			add		a, 'A' - '9' - 1
			jr		putc
			endscope

; -----------------------------------------------------------------------------
;	Messages
; -----------------------------------------------------------------------------
title_message:
			ds		"Y8960UPD [Y8960 Cartridge Update Tool] v1.1\r\n"
			ds		"Copyright (C)2026 HRA!\r\n\r\n"
			db		0
usage_message:
			ds		"Usage: Y8960UPD [/C file | /B file | /H]\r\n"
			ds		"  (none)   Show the version information.\r\n"
			ds		"  /C file  Write the Config data.\r\n"
			ds		"  /B file  Write the BIOS data.\r\n"
			ds		"  /H, /?   Show this help.\r\n\r\n"
			db		0
not_detected_message:
			ds		"Y8960 Cartridge is not detected.\r\n"
			db		0
config_version_message:
			ds		"Cfg. Ver: "
			db		0
bios_version_message:
			ds		"BIOS Ver: "
			db		0
none_message:
			ds		"(none)"
			db		0
file_message:
			ds		"File    : "
			db		0
version_message:
			ds		"Version : "
			db		0
erase_message:
			ds		"Erase   : "
			db		0
write_message:
			ds		"Write   : "
			db		0
version_write_message:
			ds		"Version update\r\n"
			db		0
ok_message:
			ds		" OK\r\n"
			db		0
config_completed_message:
			ds		"\r\nConfig data has been updated.\r\n"
			db		0
bios_completed_message:
			ds		"\r\nBIOS data has been updated.\r\n"
			ds		"Reset the MSX to load the new BIOS.\r\n"
			db		0
open_error_message:
			ds		"Cannot open the file.\r\n"
			db		0
format_error_message:
			ds		"This file is not a valid image for this option.\r\n"
			db		0
size_error_message:
			ds		"Invalid data size.\r\n"
			db		0
read_error_message:
			ds		"\r\nFile read error.\r\n"
			db		0
decompress_error_message:
			ds		"\r\nDecompress error.\r\n"
			db		0
erase_error_message:
			ds		"\r\nErase error.\r\n"
			db		0
write_error_message:
			ds		"\r\nWrite error.\r\n"
			db		0
verify_error_message:
			ds		"\r\nVerify error at "
			db		0
verify_expected_message:
			ds		": expected "
			db		0
verify_actual_message:
			ds		"h, read "
			db		0
verify_status_message:
			ds		"h (last SR1="
			db		0
verify_end_message:
			ds		"h).\r\n"
			db		0
read_rom_error_message:
			ds		"\r\nConfigROM read error.\r\n"
			db		0
erase_ignored_message:
			ds		"\r\nErase was not accepted (BUSY never set, SR1="
			db		0
erase_ignored_end_message:
			ds		"h).\r\nThe ConfigROM may be write protected.\r\n"
			db		0
blank_error_message:
			ds		"\r\nErase check failed at "
			db		0
blank_actual_message:
			ds		": read "
			db		0
empty_message:
crlf_message:
			ds		"\r\n"
			db		0

; -----------------------------------------------------------------------------
;	Signatures (32 bytes, padded with 00h)
; -----------------------------------------------------------------------------
config_signature:
			ds		"Y8960_TP25K_CARTRIDGE"			; 21 bytes
			db		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
bios_signature:
			ds		"Y8960_BIOS_IMAGE"				; 16 bytes
			db		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; -----------------------------------------------------------------------------
;	Work area
; -----------------------------------------------------------------------------
mode:
			db		0
file_opened:
			db		0
start_block:
			db		0
data_size:
			db		0					; bit23-16
			dw		0					; bit15-0
image_format:
			db		0					; FORMAT_RAW or FORMAT_ZX0
cmp_block_size:
			dw		0
frame_word:
			dw		0
subheader:
			db		0, 0, 0, 0, 0, 0
remain_size:
			dw		0					; bit15-0
			db		0					; bit23-16
chunk_size:
			dw		0
cur_address:
			db		0, 0, 0				; bit7-0, bit15-8, bit23-16
chunk_address:
			db		0, 0, 0
wait_start:
			dw		0
last_status:
			db		0
busy_seen:
			db		0
progress_label:
			dw		0
verify_expected:
			db		0
verify_actual:
			db		0
version_buffer:
			ds		"                "
			ds		"                "
header:
			ds		"                "
			ds		"                "
			ds		"                "

fcb:
fcb_dr:
			db		0					; 0: default drive, 1: A, ... 8: H
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
