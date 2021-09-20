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
; Optimal clearing
; --------------------------------------------------------------
; PARAMETERS:
;	reg - Register to clear
; --------------------------------------------------------------

CLROPT macro reg
	if (strcmp("\0","b")=0)&(strcmp("\0","w")=0)&(strcmp("\0","l")=0)
		inform 3,"Clear size invalid or undefined."
	endif

	if strcmp("\0","l")<>0
		moveq	#0,\reg
	else
		clr.\0	\reg
	endif
	endm

; --------------------------------------------------------------
; Optimal left bitshifting
; --------------------------------------------------------------
; PARAMETERS:
;	bits - Number of bits to shift
;	reg  - Register to do shifting on
; --------------------------------------------------------------

SHLOPT macro bits, reg
	local max, b

b	= \bits
	if (strcmp("\0","b")=0)&(strcmp("\0","w")=0)&(strcmp("\0","l")=0)
		inform 3,"Shift size invalid or undefined."
	endif
	if narg<1
		inform 3,"Shift value not defined."
	elseif narg<2
		inform 3,"Destination register not defined."
	endif

max	= 7						; Get max amount of bits that can be shifted
	if strcmp("\0","w")<>0
max		= 15
	elseif strcmp("\0","l")<>0
max		= 31
	endif

	if b>max
		CLROPT.\0 \reg				; If we are shifting past the max amount of bits that can
							; be shifted, just clear the register
	else
		if strcmp("\0","w")<>0			; Word sized shifting
			if b>=8				; Stack store shifting (8 bits)
				move.b	\reg,-(sp)
				move.w	(sp)+,\reg
				clr.b	\reg
b				= b-8
			endif
		elseif strcmp("\0","l")<>0		; Longword sized shifting
			if b>=16
				if b>=24		; Do stack store shifting before swap (8 bits)
					move.b	\reg,-(sp)
					move.w	(sp)+,\reg
					clr.b	\reg
b					= b-8
				endif
				swap	\reg		; Swap (16 bits)
				clr.w	\reg
b				= b-16
			elseif b>=8
				lsl.l	#8,\reg		; Shift 8 bits
b				= b-8
			endif
		endif

		if (b>2)|((strcmp("\0","l")<>0)&(b>1))
			lsl.\0	#b,\reg			; Do final shifts
		else
			rept	b
				add.\0	\reg,\reg
			endr
		endif
	endif

	endm

; --------------------------------------------------------------
; Multiplication using bitshifting
; --------------------------------------------------------------
; PARAMETERS:
;	mul  - Multiplier
;	reg1 - Register to multiply on
;	reg2 - Register to use for additional calculations
; --------------------------------------------------------------

SHMUL macro mul, reg1, reg2
	local c,c2,c3,negv,setBits1,setBits2,lsb,msb,shft,lastShft

	if (strcmp("\0","b")=0)&(strcmp("\0","w")=0)&(strcmp("\0","l")=0)
		inform 3,"Multiplication size invalid or undefined."
	endif
	if narg<1
		inform 3,"Multiplier not defined."
	elseif narg<2
		inform 3,"Destination register not defined."
	endif

c	= \mul						; Multiplier
negv	= 0						; Mask out unneeded bits and check if it's a negative number
	if strcmp("\0","b")<>0
c		= c&$FF
		if (c&$80)<>0
negv			= 1
c2			= (-c)&$FF
		endif
	elseif strcmp("\0","w")<>0
c		= c&$FFFF
		if (c&$8000)<>0
negv			= 1
c2			= (-c)&$FFFF
		endif
	else
		if (c&$80000000)<>0
negv			= 1
c2			= -c
		endif
	endif

	if negv<>0					; Check if negating the multiplier would really be more optimal
setBits1	= 0
setBits2	= 0

c3		= c					; Get number of set bits in non-negated multiplier
		while c3<>0
			if (c3&1)<>0
setBits1			= setBits1+1
			endif
c3			= c3>>1
		endw

c3		= c2					; Get number of set bits in negated multiplier
		while c3<>0
			if (c3&1)<>0
setBits2			= setBits2+1
			endif
c3			= c3>>1
		endw

		if setBits1<=setBits2			; If it's more optimal to not negate, then don't negate
negv			= 0
		else					; If it's more optimal to negate, then negate
c			= c2
		endif
	endif

	if (c=0)					; If the multiplier is 0, just clear the register
		CLROPT.\0 \reg1
	elseif (c<>1)					; Perform multiplication if the value is not 1
c2		= c					; Get least significant set bit
lsb		= 0
msb		= -1
		while (c2&1)=0
lsb			= lsb+1
msb			= msb+1
c2			= c2>>1
		endw	
		while c2<>0				; Get most significant set bit
msb			= msb+1
c2			= c2>>1
		endw

		SHLOPT.\0 lsb,\reg1			; Multiply up to LSB

		if msb<>lsb				; Multiply rest of bits
msb			= msb-1
shft			= 0
lastShft		= -1
			if narg<3
				inform 3,"This multiplication requires a second register."
			endif
			move.\0	\reg1,\reg2
			while msb>(lsb-1)
shft				= shft+1
				if (c&(1<<msb))<>0
					SHLOPT.\0 shft,\reg1
shft					= 0
					add.\0	\reg2,\reg1
				endif
msb				= msb-1
			endw
		endif
	endif

	if (negv<>0)					; Apply negation
		neg.\0	\reg1
	endif
	endm

; --------------------------------------------------------------