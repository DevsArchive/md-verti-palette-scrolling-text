; --------------------------------------------------------------
; Core Mega Drive RAM definitions
; By Ralakimus 2021
; --------------------------------------------------------------

	rsset	RAM_START+$FF000000

; Main buffer
buffer		rs.b	$8000			; Main buffer

; Global variables
globalVars	rs.b	0			; Global variables start
		; Include global variables here
globalVarsEnd	rs.b	0			; Global variables end

; Local variables
localVars	rs.b	0			; Local variables start
		rs.b	-$192-__rs
localVarsEnd	rs.b	0			; Local variables end

; Core variables
palette		rs.b	$80			; Palette buffer

externalInt	rs.b	6			; External interrupt
hblankInt	rs.b	6			; H-BLANK interrupt
vblankInt	rs.b	6			; V-BLANK interrupt

stack		rs.b	$100			; Stack space
stackBase	rs.b	0			; Stack base

; Check RAM definition misalignment
	if (__rs<>0)
		inform 2,"RAM definitions are misaligned by %d bytes", __rs
	endif

; --------------------------------------------------------------