; --------------------------------------------------------------
; Core Mega Drive source file
; By Ralakimus 2021
; --------------------------------------------------------------

; --------------------------------------------------------------
; Includes
; --------------------------------------------------------------

	include	"../include/mddef.asm"
	include	"../debug/Debugger.asm"
	include	"ram.asm"

; --------------------------------------------------------------
; Vector table
; --------------------------------------------------------------

InitBlock:
	dc.l	stackBase			; Stack pointer
	dc.l	.Start				; Start address

	dc.l	BusError			; Bus error
	dc.l	AddressError			; Address error
	dc.l	IllegalInstr			; Illegal instruction
	dc.l	ZeroDivide			; Division by zero
	dc.l	ChkInstr			; CHK exception
	dc.l	TrapvInstr			; TRAPV exception
	dc.l	PrivilegeViol			; Privilege violation
	dc.l	Trace				; TRACE exception
	dc.l	Line1010Emu			; Line-A emulator
	dc.l	Line1111Emu			; Line-F emulator

.PSGRegs:
	dc.b	(((0)<<5)|$90)|15		; PSG1 minimum volume
	dc.b	(((1)<<5)|$90)|15		; PSG2 minimum volume
	dc.b	(((2)<<5)|$90)|15		; PSG3 minimum volume
	dc.b	(((3)<<5)|$90)|15		; PSG4 minimum volume
.PSGRegsEnd:

.VDPRegs:
	dc.b	%00000100			; H-INT off
	dc.b	%00110100			; Display off, V-INT on, DMA on
	dc.b	$C000/$400			; Plane A address
	dc.b	$D000/$400			; Window plane address
	dc.b	$E000/$2000			; Plane B address
	dc.b	$F800/$200			; Sprite table address
	dc.b	0				; Unused
	dc.b	0				; Background color line 0, color 0
	dc.b	0				; Unused
	dc.b	0				; Unused
	dc.b	256-1				; H-INT every 256 scanlines
	dc.b	0				; EXT-INT off, scroll by screen
	dc.b	%10000001			; H40 mode, S/H mode off, no interlace
	dc.b	$FC00/$400			; HScroll table address
	dc.b	0				; Unused
	dc.b	1				; Auto increment 1
	dc.b	%00000001			; 64x32 tilemap
	dc.b	0				; Window X
	dc.b	0				; Window Y
	dc.b	$FF				; DMA clear length $10000 bytes
	dc.b	$FF
	dc.b	$00				; DMA clear source $0000
	dc.b	$00
	dc.b	$80
.VDPRegsEnd:

	dcb.l	5, ErrorExcept			; Reserved

	dc.l	ErrorExcept			; Spurious exception
	dc.l	ErrorExcept			; IRQ level 1
	dc.l	externalInt			; IRQ level 2 (External interrupt)
	dc.l	ErrorExcept			; IRQ level 3
	dc.l	hblankInt			; IRQ level 4 (H-BLANK interrupt)
	dc.l	ErrorExcept			; IRQ level 5
	dc.l	vblankInt			; IRQ level 6 (V-BLANK interrupt)
	dc.l	ErrorExcept			; IRQ level 7

	dc.l	ErrorExcept			; TRAP #00 exception
	dc.l	ErrorExcept			; TRAP #01 exception
	dc.l	ErrorExcept			; TRAP #02 exception
	dc.l	ErrorExcept			; TRAP #03 exception
	dc.l	ErrorExcept			; TRAP #04 exception
	dc.l	ErrorExcept			; TRAP #05 exception
	dc.l	ErrorExcept			; TRAP #06 exception
	dc.l	ErrorExcept			; TRAP #07 exception
	dc.l	ErrorExcept			; TRAP #08 exception
	dc.l	ErrorExcept			; TRAP #09 exception
	dc.l	ErrorExcept			; TRAP #10 exception
	dc.l	ErrorExcept			; TRAP #11 exception
	dc.l	ErrorExcept			; TRAP #12 exception
	dc.l	ErrorExcept			; TRAP #13 exception
	dc.l	ErrorExcept			; TRAP #14 exception
	dc.l	ErrorExcept			; TRAP #15 exception

	dcb.l	16, ErrorExcept			; Reserved

; --------------------------------------------------------------
; ROM header
; --------------------------------------------------------------

	dc.b	"SEGA MEGA DRIVE "		; Hardware ID
	dc.b	"RALAKEK 2021.SEP"		; Release date

	dc.b	"VERTICAL PALETTE"		; Domestic name (Japan)
	dc.b	" TEXT SCROLLING "
	dc.b	"DEMO            "

	dc.b	"VERTICAL PALETTE"		; Overseas name (USA, Europe)
	dc.b	" TEXT SCROLLING "
	dc.b	"DEMO            "

	dc.b	"GM XXXXXXXX-00"		; Serial
	dc.w	0				; Checksum
	dc.b	"J               "		; I/O support

	dc.l	ROM_START, ROM_END-1		; ROM addresses
	dc.l	RAM_START, RAM_END-1		; RAM addresses
	dc.l	$20202020			; External RAM support
	dc.l	$20202020, $20202020		; External RAM addresses

	dc.b	"            "			; Modem support

	dc.b	"                "		; Notes
	dc.b	"                "
	dc.b	"        "

	dc.b	"JUE             "		; Region support

; --------------------------------------------------------------
; Program initialization
; --------------------------------------------------------------

.Start:
	move	#$2700,sr			; Reset status register

	lea	Z80_BUS,a0			; Z80 bus request port
	lea	Z80_RESET-Z80_BUS(a0),a1	; Z80 reset port
	lea	VDP_CTRL,a2			; VDP control port
	lea	VDP_DATA-VDP_CTRL(a2),a3	; VDP data port
	lea	$100.w,a4			; Location of "SEGA" string
	lea	.PSGRegs(pc),a5			; Initial register values

	moveq	#$F,d0				; Satisfy TMSS
	and.b	HW_VERSION-Z80_BUS(a0),d0
	beq.s	.SkipTMSS
	move.l	(a4),TMSS_SEGA-Z80_BUS(a0)

.SkipTMSS:
	move.w	(a2),d0				; Check if the VDP is working

	moveq	#0,d0				; Clear D0, A6, and USP
	movea.l	d0,a6
	move.l	a6,usp
	
	move.w	#(RAM_END-RAM_START)/4-1,d1	; Clear RAM

.ClearRAM:
	move.l	d0,-(a6)
	dbf	d1,.ClearRAM
	
	moveq	#.PSGRegsEnd-.PSGRegs-1,d2	; Initialize PSG registers

.InitPSG:
	move.b	(a5)+,PSG_CTRL-VDP_CTRL(a2)
	dbf	d2,.InitPSG

	move.w	#$8000,d2			; Initialize VDP registers
	moveq	#.VDPRegsEnd-.VDPRegs-1,d3

.InitVDPRegs:
	move.b	(a5)+,d2
	move.w	d2,(a2)
	add.w	a4,d2
	dbf	d3,.InitVDPRegs

	VDP_CMD	move.l,$0000,VRAM,DMA,(a2)	; Start VRAM clear
	move.w	d0,(a3)

	move.w	a4,(a0)				; Stop Z80
	move.w	a4,(a1)				; Cancel Z80 reset

.WaitZ80Stop:
	btst	d0,(a0)
	bne.s	.WaitZ80Stop

	lea	Z80_START,a5			; Write "JP $0000"
	move.b	#$C3,(a5)+
	move.b	d0,(a5)+
	move.b	d0,(a5)

	move.w	d0,(a1)				; Reset Z80
	moveq	#$7F,d2				; Wait until Z80 is fully reset
	dbf	d2,*
	move.w	d0,(a0)				; Start Z80
	move.w	a4,(a1)				; Cancel Z80 reset

	WAIT_DMA a2				; Wait until VDP DMA is finished
	move.w	#$8F02,(a2)			; Set VDP auto increment to 2

	moveq	#$80/4-1,d2			; Clear CRAM
	VDP_CMD	move.l,$0000,CRAM,WRITE,(a2)

.ClearCRAM:
	move.l	d0,(a3)
	dbf	d2,.ClearCRAM

	moveq	#$50/4-1,d2			; Clear VSRAM
	VDP_CMD	move.l,$0000,VSRAM,WRITE,(a2)

.ClearVSRAM:
	move.l	d0,(a3)
	dbf	d2,.ClearVSRAM
	
	tst.w	(a2)				; Test VDP

	lea	externalInt.w,a0		; Set up interrupts
	move.w	#$4E73,d0
	move.w	d0,(a0)
	move.w	d0,hblankInt-externalInt(a0)
	move.w	d0,vblankInt-externalInt(a0)

	movem.l	(a6),d0-a6			; Clear registers
	
	jmp	Main				; Go to main program

; --------------------------------------------------------------
; Main program
; --------------------------------------------------------------

	include	"main.asm"

; --------------------------------------------------------------
; Vladikcomper's error handler
; --------------------------------------------------------------

	include	"../debug/ErrorHandler.asm"

; --------------------------------------------------------------