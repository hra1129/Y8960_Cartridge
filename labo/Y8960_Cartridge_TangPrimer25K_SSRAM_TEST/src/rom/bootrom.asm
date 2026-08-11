;
; bootrom.asm
;   BOOT ROM
;   Revision 1.00
;
; Copyright (c) 2026 Takayuki Hara.
; All rights reserved.
;
; Redistribution and use of this source code or any derivative works, are
; permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice,
;    this list of conditions and the following disclaimer.
; 2. Redistributions in binary form must reproduce the above copyright
;    notice, this list of conditions and the following disclaimer in the
;    documentation and/or other materials provided with the distribution.
; 3. Redistributions may not be sold, nor may they be used in a commercial
;    product or activity without specific prior written permission.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
; TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
; PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
; PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
; OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
; ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
; ----------------------------------------------------------------------------
; 8KB の BOOT ROM (RAM) で動作するコードです。

; I/O ポートの定義
UART								:= 0x10
BUTTON								:= 0x11

SSRAM_ADDRESS						:= 0x8000

				org		0x0000
; ----------------------------------------------------------------------------
;	Initialization
; ----------------------------------------------------------------------------
				di
				ld		sp, 0x5000 - 2

; ----------------------------------------------------------------------------
;	SRAM write and read test
; ----------------------------------------------------------------------------
start:
				call	wait_dipsw_change

				ld		hl, message_start
				call	puts

				ld		hl, SSRAM_ADDRESS

test_loop:
				ld		a, l
				ld		[hl], a
				ld		a, [hl]
				cp		l
				jr		nz, test_failed

				inc		hl
				ld		a, h
				or		l
				jr		z, test_finish

				ld		a, l
				or		a
				jr		nz, test_loop

				ld		a, '*'
				call	putc
				jr		test_loop

test_failed:
				ld		d, h
				ld		e, l
				ld		hl, message_failed
				call	puts
				ld		h, d
				ld		l, e
				call	put_hex16
				ld		a, 'h'
				call	putc
				call	put_crlf
				jp		halt

test_finish:
				call	put_crlf
				ld		hl, message_finish
				call	puts

halt:
				jp		halt

; ----------------------------------------------------------------------------
; wait_dipsw_change
;   Wait until BUTTON port value changes.
; ----------------------------------------------------------------------------
wait_dipsw_change:
				in		a, [BUTTON]
				ld		b, a
wait_loop:
				in		a, [BUTTON]
				cp		b
				jr		z, wait_loop
				ret

; ----------------------------------------------------------------------------
; putc
;   A = output character
; ----------------------------------------------------------------------------
putc:
				out		[UART], a
				ret

; ----------------------------------------------------------------------------
; put_crlf
; ----------------------------------------------------------------------------
put_crlf:
				ld		a, 0x0D
				call	putc
				ld		a, 0x0A
				call	putc
				ret

; ----------------------------------------------------------------------------
; puts
;   HL = zero terminated string
; ----------------------------------------------------------------------------
puts:
				ld		a, [hl]
				or		a
				ret		z
				call	putc
				inc		hl
				jr		puts

; ----------------------------------------------------------------------------
; put_hex16
;   HL = 16bit value
; ----------------------------------------------------------------------------
put_hex16:
				ld		a, h
				call	put_hex8
				ld		a, l
				call	put_hex8
				ret

; ----------------------------------------------------------------------------
; put_hex8
;   A = 8bit value
; ----------------------------------------------------------------------------
put_hex8:
				push	af
				rrca
				rrca
				rrca
				rrca
				call	put_hex4
				pop		af
				call	put_hex4
				ret

; ----------------------------------------------------------------------------
; put_hex4
;   A = low nibble
; ----------------------------------------------------------------------------
put_hex4:
				and		0x0F
				add		a, '0'
				cp		0x3A
				jr		c, digit
				add		a, 7
digit:
				call	putc
				ret

message_start:
				db		"SRAM Test Start", 0x0D, 0x0A, 0

message_finish:
				db		"SRAM Test Finish", 0x0D, 0x0A, 0

message_failed:
				db		"Failed ", 0
