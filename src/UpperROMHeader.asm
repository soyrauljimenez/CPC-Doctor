	; ROM header
	db #01, #00, #00, #05

RSXTable:
	dw RSXNames
	jp Bootup
	jp StartDiagCommand
	jp StartDiagCommand


RSXNames:
	dc 'CPC Doctor'
	dc 'DIAG'				; el mismo nombre que Amstrad Diagnostics
	dc 'DOCTOR'
	db 0                     ;end of name table marker


Bootup:
	push 	af
	push 	bc
	push 	de
	push 	hl
	ld 	hl, TxtInitializationText
.showMessage:
	ld 	a,(hl)
	call 	#BB5A                      ; txt_output
	inc 	hl
	or 	a
	jr 	nz, .showMessage
	pop 	hl
	pop 	de
	pop 	bc
	pop 	af
	ret

StartDiagCommand:
	; C contains the upper ROM the command was executed from
	ld 	iyh,c		; Save it in iyh
	; Clear screen just to give some feedback since the initial RAM does doesn't include screen area
	ld 	d, #33
	call 	ClearScreen

	ld 	bc, RESTORE_ROM_CONFIG
	out 	(c),c

	jp 	TestStart


TxtInitializationText:
    db " CPC Doctor ",VERSION_STR," |doctor",13,10,13,10,0
