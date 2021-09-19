; --------------------------------------------------------------
; Vertical palette text scrolling demo
; By Ralakimus 2021
; --------------------------------------------------------------

; --------------------------------------------------------------
; Constants
; --------------------------------------------------------------

SCROLL_SPEED	EQU	$2000				; Text scroll speed

; --------------------------------------------------------------
; Variables
; --------------------------------------------------------------

	rsset localVars

dmaCmdLow	rs.w	1				; DMA command low word
textDataOffset	rs.l	1				; Text data offset

	if __rs>localVarsEnd
		inform 2,"Local RAM definitions are too large by 0x%h bytes", __rs-localVarsEnd
	endif

; --------------------------------------------------------------
; Prepare DMA
; --------------------------------------------------------------

PREPARE_DMA macro
	move.w	#$8174,(a6)				; Enable display
	move.l	#$94009308,(a6)				; Set DMA length
	move.w	#$9700|((palette>>17)&$7F),(a6)		; Set DMA source
	move.l	#$95009600|(((palette>>1)&$FF)<<16)|((palette>>9)&$FF),(a6)
	endm

; --------------------------------------------------------------
; DMA scanline palette
; --------------------------------------------------------------

DMA_LINE macro
	move.l	d7,(a6)					; Disable display and send Send command high word
	move.w	dmaCmdLow.w,(a6)			; Send DMA command low word
	PREPARE_DMA					; Prepare next DMA
	endm

; --------------------------------------------------------------
; Get palette data
; --------------------------------------------------------------

GET_LINE_PAL macro
	lea	TextData,a1				; Get text data line
	move.l	textDataOffset.w,d0
	add.l	(a4)+,d0
	clr.w	d0
	swap	d0
	lsl.l	#4,d0
	add.l	d0,a1

	lea	palette.w,a0				; Copy colors
	move.l	(a1)+,(a0)+
	move.l	(a1)+,(a0)+
	move.l	(a1)+,(a0)+
	move.l	(a1),(a0)
	endm

; --------------------------------------------------------------
; Program
; --------------------------------------------------------------

Main:
	lea	VDP_HV+1,a5				; H/V counter
	lea	VDP_CTRL,a6				; VDP control port

							; Lazily load art
	DMA_68K	Art_Base,$20,Art_Base_End-Art_Base,VRAM,a6

	lea	Map_Base,a0				; Lazily load map
	move.l	#$40000003,d2
	moveq	#$28-1,d0
	moveq	#$1C-1,d1

.Row:
	move.l	d2,(a6)
	move.w	d0,d3

.Tile:
	move.w	(a0)+,d4
	addq.w	#1,d4
	move.w	d4,-4(a6)
	dbf	d3,.Tile
	addi.l	#$800000,d2
	dbf	d1,.Row

	move.l	#$8134C002,d7				; Display disable + DMA command high word
	move.w	#$80,dmaCmdLow.w			; DMA command low word
	PREPARE_DMA					; Prepare first DMA

.WaitVBlankStart:
	move.w	(a6),ccr				; Is V-BLANK active?
	bpl.s	.WaitVBlankStart			; If not, wait

; --------------------------------------------------------------

.MainLoop:
	lea	TextLineIDs,a4				; Text pattern
	move.w	#$E0-1,d6				; Number of scanlines

	GET_LINE_PAL					; Get palette data for first scanline
	DMA_LINE					; DMA palette data

.WaitVBlankEnd:
	move.w	(a6),ccr				; Is V-BLANK still active?
	bmi.s	.WaitVBlankEnd				; If so, wait
	
.WaitHBlankEnd:
	move.w	(a6),ccr				; Is H-BLANK still active?
	bne.s	.WaitHBlankEnd				; If so, wait

.ScanlineLoop:
	GET_LINE_PAL					; Get palette data for this scanline
	moveq	#$FFFFFF9A,d0				; Wait until we are almost offscreen

.WaitHBLANK:
	cmp.b	(a5),d0
	bhi.s	.WaitHBLANK

	DMA_LINE					; DMA palette data
	dbf	d6,.ScanlineLoop			; Loop until all scanlines are processed

	addi.l	#SCROLL_SPEED,textDataOffset.w		; Scroll text
	cmpi.w	#(TextData_End-TextData)/16,textDataOffset.w
	bcc.s	.End					; If we have reached the end, branch

; --------------------------------------------------------------

	move.w	#$8134,(a6)				; Disable display
	
	; V-BLANK CODE

	bra.w	.MainLoop				; Loop

; --------------------------------------------------------------

.End:
	bra.w	*					; Loop here forever

; --------------------------------------------------------------
; Base graphics data
; --------------------------------------------------------------

Art_Base:
	incbin	"data/Art.bin"
Art_Base_End:
	even

Map_Base:
	incbin	"data/Map.bin"
	even

; --------------------------------------------------------------
; Line IDs
; --------------------------------------------------------------
; Each value is a 16.16 fixed point value that represents a
; line ID. This can be used to stretch or squish the text,
; apply perspective, etc.
; --------------------------------------------------------------

TextLineIDs:
ln = 0
	rept	224
		dc.l	ln
ln = ln+($10000/16)					; Stretch out 16x
	endr

; --------------------------------------------------------------
; Text data
; --------------------------------------------------------------

TextData:
	rept	224/16
		dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	endr

	; Toof
	dc.w	$000, $00E, $000, $000, $000, $000, $000, $00E
	dc.w	$000, $00E, $00E, $000, $000, $000, $00E, $00E
	dc.w	$000, $00E, $00E, $00E, $00E, $00E, $00E, $00E
	dc.w	$000, $00E, $EEE, $EEE, $00E, $EEE, $EEE, $00E
	dc.w	$000, $00E, $EEE, $000, $00E, $EEE, $000, $00E
	dc.w	$EEE, $EEE, $000, $EEE, $EEE, $000, $EEE, $000
	dc.w	$000, $EEE, $EEE, $000, $000, $EEE, $000, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000

	; Space
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	
	; Z
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$000, $000, $000, $000, $000, $EEE, $EEE, $EEE
	dc.w	$000, $000, $000, $000, $EEE, $EEE, $EEE, $000
	dc.w	$000, $000, $EEE, $EEE, $EEE, $EEE, $000, $000
	dc.w	$000, $EEE, $EEE, $EEE, $EEE, $000, $000, $000
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000

	; O
	dc.w	$000, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$000, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000

	; M
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $000, $000, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $EEE, $EEE, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000

	; G
	dc.w	$000, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $000, $000
	dc.w	$EEE, $EEE, $000, $000, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$000, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000

	; Space
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000

	; R
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000

	; E
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $000, $000
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000, $000
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000, $000
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $000, $000
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000

	; D
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000

	; Space
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	
	; C
	dc.w	$000, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $000, $000
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $000, $000
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$000, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	
	; A
	dc.w	$000, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $000
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $000, $000, $000, $EEE, $EEE
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	
	; T
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE, $EEE
	dc.w	$000, $000, $000, $EEE, $EEE, $000, $000, $000
	dc.w	$000, $000, $000, $EEE, $EEE, $000, $000, $000
	dc.w	$000, $000, $000, $EEE, $EEE, $000, $000, $000
	dc.w	$000, $000, $000, $EEE, $EEE, $000, $000, $000
	dc.w	$000, $000, $000, $EEE, $EEE, $000, $000, $000
	dc.w	$000, $000, $000, $EEE, $EEE, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	
	; !!!
	dc.w	$EEE, $EEE, $000, $EEE, $EEE, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $EEE, $EEE, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $EEE, $EEE, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $EEE, $EEE, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $EEE, $EEE, $000, $EEE, $EEE
	dc.w	$EEE, $EEE, $000, $EEE, $EEE, $000, $EEE, $EEE
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$EEE, $EEE, $000, $EEE, $EEE, $000, $EEE, $EEE
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	dc.w	$000, $000, $000, $000, $000, $000, $000, $000

TextData_End:
	rept	224/16
		dc.w	$000, $000, $000, $000, $000, $000, $000, $000
	endr

; --------------------------------------------------------------