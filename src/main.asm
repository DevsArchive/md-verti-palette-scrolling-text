; --------------------------------------------------------------
; Vertical palette text scrolling demo
; By Ralakimus 2021
; --------------------------------------------------------------

; --------------------------------------------------------------
; Constants
; --------------------------------------------------------------

SCROLL_SPEED	EQU	$2000				; Text scroll speed
COLOR_FIRST	EQU	1				; First palette entry to load palette into
COLOR_COUNT	EQU	15				; Number of colors to load

	if (COLOR_COUNT<1)|(COLOR_COUNT>20)
		inform 2,"Bad color count. Should be a value from 1 to 20."
	endif

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
	move.l	#$94009300|COLOR_COUNT,(a6)		; Set DMA length
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
	move.l	textDataOffset.w,d0			; Get text data offset
	add.l	(a4)+,d0
	clr.w	d0
	swap	d0
	SHMUL.L	COLOR_COUNT*2,d0,d1

	lea	palette.w,a0				; Copy colors
	lea	(a3,d0.l),a2
	if (COLOR_COUNT&1)<>0
		rept	COLOR_COUNT/2
			move.l	(a2)+,(a0)+
		endr
		move.w	(a2),(a0)
	else
		rept	(COLOR_COUNT/2)-1
			move.l	(a2)+,(a0)+
		endr
		move.l	(a2),(a0)
	endif
	endm

; --------------------------------------------------------------
; Text line data macro
; --------------------------------------------------------------

LN_DATA macro
	local cnt,c
cnt	= narg
	if cnt>COLOR_COUNT
cnt		= COLOR_COUNT
	endif
c = 0
	rept cnt
		dc.w	\1
		shift
c = c+1
	endr

	dcb.w	COLOR_COUNT-c, $000
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
	
	lea	TextData,a3				; Text data

	move.l	#$8134C000|(COLOR_FIRST*2),d7		; Display disable + DMA command high word
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
	cmpi.w	#(TextData_End-TextData)/(COLOR_COUNT*2),textDataOffset.w
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
ln	= 0
	rept	224
		dc.l	ln
ln		= ln+($10000/8)				; Stretch out 8x
	endr

; --------------------------------------------------------------
; Text data
; --------------------------------------------------------------

TextData:
	rept	32
		LN_DATA	$000
	endr

	include	"data/RedCat.asm"

TextData_End:
	rept	32
		LN_DATA	$000
	endr

; --------------------------------------------------------------