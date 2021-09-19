; --------------------------------------------------------------
; Mega Drive definitions and macros
; By Ralakimus 2021
; --------------------------------------------------------------

; --------------------------------------------------------------
; Definitions
; --------------------------------------------------------------

; ROM									
ROM_START	EQU	$000000			; ROM start
ROM_END		EQU	$400000			; ROM end

; SRAM
SRAM_START	EQU	$200000			; SRAM start
SRAM_ENABLE	EQU	$A130F1			; SRAM enable port

; Z80
Z80_START	EQU	$A00000			; Z80 RAM start
Z80_END		EQU	$A02000			; Z80 RAM end
Z80_BUS		EQU	$A11100			; Z80 bus request
Z80_RESET	EQU	$A11200			; Z80 reset

; Work RAM
RAM_START	EQU	$FF0000			; Work RAM start
RAM_END		EQU	$1000000		; Work RAM end

; Sound
YM_ADDR_0	EQU	$A04000			; YM2612 address port 0
YM_DATA_0	EQU	$A04001			; YM2612 data port 0
YM_ADDR_1	EQU	$A04002			; YM2612 address port 1
YM_DATA_1	EQU	$A04003			; YM2612 data port 1
PSG_CTRL	EQU	$C00011			; PSG control port

; VDP
VDP_DATA	EQU	$C00000			; VDP data port
VDP_CTRL	EQU	$C00004			; VDP control port
VDP_HV		EQU	$C00008			; VDP H/V counter
VDP_DEBUG	EQU	$C0001C			; VDP debug register

; I/O
HW_VERSION	EQU	$A10001			; Hardware version
IO_A_DATA	EQU	$A10003			; I/O port A data port
IO_B_DATA	EQU	$A10005			; I/O port B data port
IO_C_DATA	EQU	$A10007			; I/O port C data port
IO_A_CTRL	EQU	$A10009			; I/O port A control port
IO_B_CTRL	EQU	$A1000B			; I/O port B control port
IO_C_CTRL	EQU	$A1000D			; I/O port C control port

; TMSS
TMSS_SEGA	EQU	$A14000			; TMSS "SEGA" register
TMSS_MODE	EQU	$A14100			; TMSS bus mode

; --------------------------------------------------------------
; Align
; --------------------------------------------------------------
; PARAMETERS:
;	bound - Size boundary
;	value - Value to pad with
; --------------------------------------------------------------

ALIGN macro bound, value
	if narg>1
		dcb.b	((\bound)-((*)%(\bound)))%(\bound), \value
	else
		dcb.b	((\bound)-((*)%(\bound)))%(\bound), 0
	endif
	endm

; --------------------------------------------------------------
; Align RS to even address
; --------------------------------------------------------------

RS_EVEN macros
	rs.b	__rs&1

; --------------------------------------------------------------
; Request Z80 bus access
; --------------------------------------------------------------

REQ_Z80 macros
	move.w	#$100,Z80_BUS			; Request Z80 bus access

; --------------------------------------------------------------
; Wait for Z80 bus request acknowledgement
; --------------------------------------------------------------

WAIT_Z80 macro
.Wait\@:
	btst	#0,Z80_BUS			; Was the request acknowledged?
	bne.s	.Wait\@-8			; If not, wait
	endm

; --------------------------------------------------------------
; Request Z80 bus access
; --------------------------------------------------------------

STOP_Z80 macro
	REQ_Z80					; Request Z80 bus access
	WAIT_Z80				; Wait for acknowledgement
	endm

; --------------------------------------------------------------
; Release the Z80 bus
; --------------------------------------------------------------

START_Z80 macros
	move.w	#0,Z80_BUS			; Release the bus

; --------------------------------------------------------------
; Request Z80 reset
; --------------------------------------------------------------

RESET_Z80 macros
	move.w	#0,Z80_RESET			; Request Z80 reset

; --------------------------------------------------------------
; Cancel Z80 reset
; --------------------------------------------------------------

CANCEL_Z80_RESET macros
	move.w	#$100,Z80_RESET			; Cancel Z80 reset

; --------------------------------------------------------------
; Wait for DMA to finish
; --------------------------------------------------------------
; PARAMETERS:
;	ctrl - VDP control port as an address register
;	       (If left blank, it just uses VDP_CTRL instead)
; --------------------------------------------------------------

WAIT_DMA macro ctrl
.Wait\@:
	if narg>0
		move.w	(\ctrl),ccr		; Is DMA active?
	else
		move.w	VDP_CTRL,ccr		; Is DMA active?
	endif
	bvs.s	.Wait\@				; If so, wait
	endm

; --------------------------------------------------------------
; VDP command instruction
; --------------------------------------------------------------
; PARAMETERS:
;	addr - Address in VDP memory
;	type - Type of VDP memory
;	rwd  - VDP command
; --------------------------------------------------------------

VDP_VRAM	EQU	%100001			; VRAM
VDP_CRAM	EQU	%101011			; CRAM
VDP_VSRAM	EQU	%100101			; VSRAM
VDP_READ	EQU	%001100			; VDP read
VDP_WRITE	EQU	%000111			; VDP write
VDP_DMA		EQU	%100111			; VDP DMA

; --------------------------------------------------------------

VDP_CMD macro ins, addr, type, rwd, end, end2
	if narg=5
		\ins	#((((VDP_\type&VDP_\rwd)&3)<<30)|((\addr&$3FFF)<<16)|(((VDP_\type&VDP_\rwd)&$FC)<<2)|((\addr&$C000)>>14)),\end
	elseif narg>=6
		\ins	#((((VDP_\type&VDP_\rwd)&3)<<30)|((\addr&$3FFF)<<16)|(((VDP_\type&VDP_\rwd)&$FC)<<2)|((\addr&$C000)>>14))\end,\end2
	else
		\ins	((((VDP_\type&VDP_\rwd)&3)<<30)|((\addr&$3FFF)<<16)|(((VDP_\type&VDP_\rwd)&$FC)<<2)|((\addr&$C000)>>14))
	endif
	endm

; --------------------------------------------------------------
; VDP DMA from 68000 memory to VDP memory
; --------------------------------------------------------------
; PARAMETERS:
;	src  - Source address in 68000 memory
;	dest - Destination address in VDP memory
;	len  - Length of data in bytes
;	type - Type of VDP memory
;	ctrl - VDP control port as an address register
;	       (If left blank, it just uses VDP_CTRL instead)
; --------------------------------------------------------------

DMA_68K macro src, dest, len, type, ctrl
	if narg>4
		move.l	#$94009300|((((\len)/2)&$FF00)<<8)|(((\len)/2)&$FF),(\ctrl)
		move.l	#$96009500|((((\src)/2)&$FF00)<<8)|(((\src)/2)&$FF),(\ctrl)
		move.w	#$9700|(((\src)>>17)&$7F),(\ctrl)
		VDP_CMD	move.w,\dest,\type,DMA,>>16,(\ctrl)
		VDP_CMD	move.w,\dest,\type,DMA,&$FFFF,-(sp)
		move.w	(sp)+,(\ctrl)
	else
		move.l	#$94009300|((((\len)/2)&$FF00)<<8)|(((\len)/2)&$FF),VDP_CTRL
		move.l	#$96009500|((((\src)/2)&$FF00)<<8)|(((\src)/2)&$FF),VDP_CTRL
		move.w	#$9700|(((\src)>>17)&$7F),VDP_CTRL
		VDP_CMD	move.w,\dest,\type,DMA,>>16,VDP_CTRL
		VDP_CMD	move.w,\dest,\type,DMA,&$FFFF,-(sp)
		move.w	(sp)+,VDP_CTRL
	endif
	endm

; --------------------------------------------------------------
; Fill VRAM with byte
; Auto-increment should be set to 1 beforehand
; --------------------------------------------------------------
; PARAMETERS:
;	byte - Byte to fill VRAM with
;	addr - Address in VRAM
;	len - Length of fill in bytes
;	ctrl - VDP control port as an address register
;	       (If left blank, it just uses VDP_CTRL instead)
; --------------------------------------------------------------

DMA_FILL macro byte, addr, len, ctrl
	if narg>3
		move.l	#$94009300|((((\len)-1)&$FF00)<<8)|(((\len)-1)&$FF),(\ctrl)
		move.w	#$9780,(\ctrl)
		move.l	#$40000080|(((\addr)&$3FFF)<<16)|(((\addr)&$C000)>>14),(\ctrl)
		move.w	#(\byte)<<8,-4(\ctrl)
		WAIT_DMA \ctrl
	else
		move.l	#$94009300|((((\len)-1)&$FF00)<<8)|(((\len)-1)&$FF),VDP_CTRL
		move.w	#$9780,VDP_CTRL
		move.l	#$40000080|(((\addr)&$3FFF)<<16)|(((\addr)&$C000)>>14),VDP_CTRL
		move.w	#(\byte)<<8,VDP_DATA
		WAIT_DMA
	endif
	endm

; --------------------------------------------------------------
; Copy a region of VRAM to a location in VRAM
; Auto-increment should be set to 1 beforehand
; --------------------------------------------------------------
; PARAMETERS:
;	src	- Source address in VRAM
;	dest	- Destination address in VRAM
;	len	- Length of copy in bytes
;	ctrl	- VDP control port as an address register
;		  (If left blank, this just uses the address instead)
; --------------------------------------------------------------

DMA_COPY macro src, dest, len, ctrl
	if narg>3
		move.l	#$94009300|((((\len)-1)&$FF00)<<8)|(((\len)-1)&$FF),(\ctrl)
		move.l	#$96009500|(((\src)&$FF00)<<8)|((\src)&$FF),(\ctrl)
		move.w	#$97C0,(\ctrl)
		move.l	#$000000C0|(((\dest)&$3FFF)<<16)|(((\dest)&$C000)>>14),(\ctrl)
		WAIT_DMA \ctrl
	else
		move.l	#$94009300|((((\len)-1)&$FF00)<<8)|(((\len)-1)&$FF),VDP_CTRL
		move.l	#$96009500|(((\src)&$FF00)<<8)|((\src)&$FF),VDP_CTRL
		move.w	#$97C0,VDP_CTRL
		move.l	#$000000C0|(((\dest)&$3FFF)<<16)|(((\dest)&$C000)>>14),VDP_CTRL
		WAIT_DMA
	endif
	endm

; --------------------------------------------------------------