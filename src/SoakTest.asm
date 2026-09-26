
SoakTestByte1 EQU 'S'
SoakTestByte2 EQU 'O'
SoakTestByte3 EQU 'A'
SoakTestByte4 EQU 'K'


 MODULE SOAKTEST

@IsSoakTestRunning:
	ld ix, SoakTestIndicator		
	ld b,4

	ld a,(ix)
	cp SoakTestByte1
	ret nz
	ld a,(ix+1)
	cp SoakTestByte2
	ret nz
	ld a,(ix+2)
	cp SoakTestByte3
	ret nz
	ld a,(ix+3)
	cp SoakTestByte4
	ret nz

	ret	

@SoakTestSelected:
	call MarkSoakTestActive
	ld a,(SoakTestCount)
	inc a
	ld (SoakTestCount),a

 IFDEF ROM_CHECK
	call SoakTestPrintTitle
	call CheckROMsWithoutTitle
 ENDIF

 IFDEF GUIDED
	;; En la versión cargada la RAM baja se prueba aquí
	call SoakTestPrintTitle
	call RunLowerRAMTest
	ld a, (TestResultTableLowerRAM)
	cp TESTRESULT_FAILED
	jr z, SoakStopped
 ENDIF
	;; Sin RAM alta no hay nada que probar (antes FailingBits quedaba sin
	;; poner a cero y la prueba se quedaba colgada en un 464)
	ld a, (ValidBankCount)
	or a
	jr z, .pause
	call SoakTestPrintTitle
	call CheckUpperRAMWithoutTitle
	ld a, (FailingBits)
	or a
	jr nz, SoakStopped

	;; Pausa de unos 2 segundos entre vueltas; manteniendo ESC se sale
.pause:
	call SetDefaultColors
	ld hl, #0018
	ld (TxtCoords), hl
	ld hl, TxtSoakHint
	call PrintString
	ld b, 100
.wait:
	push bc
	call WaitForVsync
	call ReadFullKeyboard
	pop bc
	ld a, (KeyboardMatrixBuffer+8)
	and %00000100				; ESC
	jr nz, SoakExit
	djnz .wait
	jp TestStart


;; Un error detiene la prueba: se dice en qué vuelta y se vuelve al menú
SoakStopped:
	ld hl, #0018
	ld (TxtCoords), hl
	call SetErrorColors
	ld hl, TxtSoakStopped
	call PrintString
	ld a, ' '
	call PrintChar
	ld a, (SoakTestCount)
	call PrintANoPad
	call SetDefaultColors
	call WaitOK
SoakExit:
	ld ix, SoakTestIndicator
	xor a
	ld (ix), a
	ld (ix+1), a
	ld (ix+2), a
	ld (ix+3), a
	call WaitNoKeys
	jp MainMenu


@MarkSoakTestActive:
	ld ix, SoakTestIndicator
	ld (ix), SoakTestByte1			; Set those byte to indicate soak test
	ld (ix+1), SoakTestByte2
	ld (ix+2), SoakTestByte3
	ld (ix+3), SoakTestByte4
	ret


SoakTestPrintTitle:
	;; "Continua, vuelta N" en la barra de título
	ld	hl, TxtSoakTitle
	ld	de, TitleBuffer
.copy:
	ld	a, (hl)
	ld	(de), a
	or	a
	jr	z, .copied
	inc	hl
	inc	de
	jr	.copy
.copied:
	ld	a, ' '
	ld	(de), a
	inc	de
	ld	a, (SoakTestCount)
	ld	c, 0				; ¿ya se ha escrito una cifra?
	ld	b, 100
	call	.digit
	ld	b, 10
	call	.digit
	add	a, '0'
	ld	(de), a
	inc	de
	xor	a
	ld	(de), a
	ld	hl, TitleBuffer
	jp	PrintScreenTitle

;; Escribe en DE la cifra de A en base B (sin ceros a la izquierda) y deja
;; el resto en A. C indica si ya se ha escrito alguna cifra.
.digit:
	ld	h, 0
.sub:
	cp	b
	jr	c, .got
	sub	b
	inc	h
	jr	.sub
.got:
	push	af
	ld	a, h
	or	c
	jr	z, .skip
	ld	a, h
	add	a, '0'
	ld	(de), a
	inc	de
	ld	c, 1
.skip:
	pop	af
	ret

 ENDMODULE
