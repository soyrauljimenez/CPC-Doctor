;; KeyboardGuide.asm — prueba guiada de teclado y joystick (versión RAM)
;;
;; Añade a la prueba de teclado de Amstrad Diagnostics:
;; - una explicación previa (qué hacer, cómo salir, las teclas fantasma);
;; - teclas pulsadas al empezar: atascadas o en cortocircuito;
;; - rebotes: una tecla que se suelta y vuelve a activarse en uno o dos
;;   cuadros (40 ms) no puede ser una persona; es un contacto que falla;
;; - un análisis por líneas y columnas de la matriz al terminar.
;;
;; Las conclusiones se presentan separando lo observado, la posible causa
;; y cómo confirmarla. Que no responda una línea entera hace sospechar de
;; una pista común o del 74LS145, pero no demuestra cuál de ellas falla.
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE KBGUIDE

KB_ROWS		EQU 10
MAX_LISTED	EQU 16			; más teclas sin respuesta no se listan
MIN_FOR_ANALYSIS EQU 50			; teclas probadas para analizar la matriz
JOY_ROW		EQU 9
JOY_MASK	EQU %01111111		; bits de joystick en la fila 9 (el 7 es DEL)

;; Pantalla previa. OUT: Z si el usuario pulsa ESC.
@KbGuideIntro:
	ld	hl, TxtKeyboardTitle
	ld	de, TxtKbIntro
	call	ExplainScreen
	ret	z
	;; Lo que siga pulsado tras esperar a que se suelte todo, está atascado
	call	WaitNoKeys
	ld	hl, KeyboardMatrixBuffer
	ld	de, StuckMatrixBuffer
	ld	bc, KB_ROWS
	ldir
	ld	hl, FlakyMatrixBuffer
	call	ClearKeyboardBuffer
	ld	hl, PrevOff1Buffer
	call	ClearKeyboardBuffer
	ld	hl, PrevOff2Buffer
	call	ClearKeyboardBuffer
	ld	a, 1
	or	a
	ret


;; Llamar una vez por cuadro, después de UpdateKeyBuffers.
;; Un flanco de pulsación justo después de un flanco de suelta (1 o 2
;; cuadros) es un rebote.
@KbTrackFlaky:
	ld	hl, EdgeOnKeyboardMatrixBuffer
	ld	de, PrevOff1Buffer
	ld	ix, PrevOff2Buffer
	ld	iy, FlakyMatrixBuffer
	ld	b, KB_ROWS
.loop:
	ld	a, (de)
	or	(ix)
	and	(hl)
	or	(iy)
	ld	(iy), a
	;; desplazar la historia: Prev2 = Prev1, Prev1 = suelta de este cuadro
	ld	a, (de)
	ld	(ix), a
	push	hl
	push	bc
	ld	bc, EdgeOffKeyboardMatrixBuffer - EdgeOnKeyboardMatrixBuffer
	add	hl, bc
	ld	a, (hl)
	pop	bc
	pop	hl
	ld	(de), a
	inc	hl
	inc	de
	inc	ix
	inc	iy
	djnz	.loop
	ret


;; Máscara de las teclas atascadas para la salida (ESC / TAB / FUEGO)
;; IN: A = fila del búfer, E = índice de fila  OUT: A sin las atascadas
@KbMaskStuck:
	push	hl
	push	de
	ld	d, 0
	ld	hl, StuckMatrixBuffer
	add	hl, de
	ld	e, a
	ld	a, (hl)
	cpl
	and	e
	pop	de
	pop	hl
	ret


;; ---------------------------------------------------------------------------
;; Resultado
;; ---------------------------------------------------------------------------
@KbGuideResult:
	;; Pulsadas de verdad = pulsadas y no atascadas desde el principio
	call	CountKeysInBuffer.pressed	; A = teclas pulsadas
	ld	(KbPressedCount), a
	call	CountStuckAndFlaky

	;; Resultado del teclado
	ld	a, (KbPressedCount)
	cp	KEYBOARD_KEY_COUNT
	jr	z, .allPressed
	;; Con pocas teclas probadas no sabemos si fallan o si no se pulsaron
	ld	b, TESTRESULT_INCONCLUSIVE
	cp	MIN_FOR_ANALYSIS
	jr	c, .kbSet
	ld	b, TESTRESULT_FAILED
	jr	.kbSet
.allPressed:
	ld	b, TESTRESULT_FAILED
	ld	a, (KbStuckCount)
	or	a
	jr	nz, .kbSet
	ld	b, TESTRESULT_INCONCLUSIVE
	ld	a, (KbFlakyCount)
	or	a
	jr	nz, .kbSet
	ld	b, TESTRESULT_PASSED
.kbSet:
	ld	a, b
	ld	(TestResultTableKeyboard), a

	;; Joystick: si no se ha tocado, queda sin probar (puede que no haya)
	call	CountPressedJoystickButtons
	ld	b, TESTRESULT_UNTESTED
	or	a
	jr	z, .joySet
	ld	b, TESTRESULT_PASSED
	cp	JOYSTICK_KEY_COUNT
	jr	z, .joyCheckStuck
	ld	b, TESTRESULT_FAILED
	jr	.joySet
.joyCheckStuck:
	ld	a, (StuckMatrixBuffer + JOY_ROW)
	and	JOY_MASK
	jr	z, .joySet
	ld	b, TESTRESULT_FAILED
.joySet:
	ld	a, b
	ld	(TestResultTableJoystick), a

	call	KbResultScreen
	jp	WaitOK


KbResultScreen:
	ld	hl, TxtKeyboardTitle
	call	PrintScreenTitle
	ld	hl, TxtObserved
	call	PrintHeader
	ld	hl, #0003
	call	LocateWrap

	;; Teclado: n de 73
	ld	hl, TxtKbPressed
	call	PrintString
	ld	a, ' '
	call	PrintChar
	ld	a, (KbPressedCount)
	call	PrintANoPad
	ld	a, '/'
	call	PrintChar
	ld	a, KEYBOARD_KEY_COUNT
	call	PrintANoPad
	call	WrapNewLine

	;; Teclas sin respuesta (la lista solo si son pocas: si no, no cabe)
	ld	a, (KbPressedCount)
	cp	KEYBOARD_KEY_COUNT
	jr	z, .noMissing
	cp	KEYBOARD_KEY_COUNT - MAX_LISTED
	jr	c, .noMissing
	ld	hl, TxtKbMissing
	ld	de, PresseddMatrixBuffer
	ld	c, 1				; lista las que NO están en el búfer
	call	PrintKeyList
.noMissing:
	ld	a, (KbStuckCount)
	or	a
	jr	z, .noStuck
	ld	hl, TxtKbStuck
	ld	de, StuckMatrixBuffer
	ld	c, 0
	call	PrintKeyList
.noStuck:
	ld	a, (KbFlakyCount)
	or	a
	jr	z, .noFlaky
	ld	hl, TxtKbFlaky
	ld	de, FlakyMatrixBuffer
	ld	c, 0
	call	PrintKeyList
.noFlaky:
	;; Joystick
	ld	hl, TxtResultJoystick
	call	PrintString
	ld	a, ':'
	call	PrintChar
	ld	a, ' '
	call	PrintChar
	ld	a, (TestResultTableJoystick)
	call	SetColorForResultType
	ld	a, (TestResultTableJoystick)
	call	GetResultText
	call	PrintString
	call	SetDefaultColors
	;; Entradas del joystick que no se han pulsado (si se ha probado)
	ld	a, (TestResultTableJoystick)
	cp	TESTRESULT_UNTESTED
	jr	z, .joyDone
	ld	a, (PresseddMatrixBuffer + JOY_ROW)
	cpl
	and	%01111111
	jr	z, .joyDone
	ld	c, a
	ld	a, ' '
	call	PrintChar
	ld	hl, TxtJoyNotPressed
	call	PrintString
	ld	a, ' '
	call	PrintChar
	ld	b, 0
.joyBit:
	bit	0, c
	jr	z, .joyNext
	push	bc
	ld	a, b
	add	a, JOY_ROW * 8
	call	GetKeyName
	call	KbPrintWord
	pop	bc
.joyNext:
	srl	c
	inc	b
	ld	a, b
	cp	7
	jr	nz, .joyBit
.joyDone:
	call	WrapNewLine

	;; Resultado del teclado y posibles causas
	call	WrapNewLine
	ld	a, (TestResultTableKeyboard)
	call	PrintResultLine
	call	WrapNewLine
	call	WrapNewLine
	call	KbAnalysis
	ld	hl, TxtPressOKToReturn
	jp	PrintHint


;; Lista de teclas de un búfer de matriz.
;; IN: HL = título, DE = búfer, C = 1 para listar los bits a 0, 0 para los bits a 1
;; Solo filas 0-8 y DEL (no el joystick).
PrintKeyList:
	push	de
	push	bc
	call	PrintString
	pop	bc
	pop	de
	ld	a, ' '
	call	PrintChar
	ld	b, 0				; índice de tecla 0..79
.key:
	ld	a, b
	srl	a
	srl	a
	srl	a				; fila
	ld	l, a
	ld	h, 0
	add	hl, de
	ld	a, (hl)
	bit	0, c
	jr	z, .noInvert
	cpl
.noInvert:
	push	af
	ld	a, b
	and	7
	ld	l, a
	pop	af
	;; comprobar el bit L
	inc	l
.shift:
	dec	l
	jr	z, .test
	rrca
	jr	.shift
.test:
	bit	0, a
	jr	z, .next
	;; ignorar el joystick
	ld	a, b
	cp	JOY_ROW * 8 + 7
	jr	z, .print
	cp	JOY_ROW * 8
	jr	nc, .next
.print:
	push	bc
	push	de
	ld	a, b
	call	GetKeyName
	call	KbPrintWord
	pop	de
	pop	bc
.next:
	inc	b
	ld	a, b
	cp	80
	jr	nz, .key
	jp	WrapNewLine


;; Imprime una palabra con un espacio detrás, saltando de línea si no cabe
KbPrintWord:
	push	hl
	call	StrLenSep
	ld	c, a
	ld	a, (txt_x)
	add	a, c
	inc	a
	ld	b, a
	ld	a, (WrapRight)
	cp	b
	call	c, WrapNewLine
	pop	hl
.loop:
	ld	a, (hl)
	or	a
	jr	z, .end
	cp	CharLF
	jr	z, .end
	call	PrintChar
	inc	hl
	jr	.loop
.end:
	ld	a, ' '
	jp	PrintChar

;; Longitud hasta 0 o salto de línea
StrLenSep:
	ld	b, 0
.loop:
	ld	a, (hl)
	or	a
	jr	z, .end
	cp	CharLF
	jr	z, .end
	inc	b
	inc	hl
	jr	.loop
.end:
	ld	a, b
	ret


;; IN: A = índice de tecla (fila*8+bit)  OUT: HL = nombre (termina en | o 0)
@GetKeyName:
	ld	hl, TxtKeyNames
	or	a
	ret	z
	ld	b, a
.skip:
	ld	a, (hl)
	inc	hl
	cp	CharLF
	jr	nz, .skip
	djnz	.skip
	ret


;; Cuenta las teclas atascadas y las que rebotan (sin joystick)
CountStuckAndFlaky:
	ld	hl, StuckMatrixBuffer
	call	CountKeysInBuffer
	ld	(KbStuckCount), a
	ld	hl, FlakyMatrixBuffer
	call	CountKeysInBuffer
	ld	(KbFlakyCount), a
	ret

;; IN: HL = búfer  OUT: A = bits a 1 en filas 0-8 y DEL
CountKeysInBuffer:
	ld	d, 0
	ld	c, KB_ROWS
.row:
	ld	a, (hl)
	ld	e, a
	ld	a, c
	cp	1				; última fila: solo DEL
	ld	a, e
	jr	nz, .count
	and	%10000000
.count:
	ld	b, 8
.bit:
	rrca
	jr	nc, .nextBit
	inc	d
.nextBit:
	djnz	.bit
	inc	hl
	dec	c
	jr	nz, .row
	ld	a, d
	ret
;; Pulsadas que no estaban atascadas
.pressed:
	ld	hl, PresseddMatrixBuffer
	ld	de, StuckMatrixBuffer
	ld	ix, KbTempBuffer
	ld	b, KB_ROWS
.p:
	ld	a, (de)
	cpl
	and	(hl)
	ld	(ix), a
	inc	hl
	inc	de
	inc	ix
	djnz	.p
	ld	hl, KbTempBuffer
	jr	CountKeysInBuffer


;; ---------------------------------------------------------------------------
;; Análisis de la matriz: líneas (salidas del 74LS145) y columnas (bits del
;; puerto A del AY) en las que no ha respondido ninguna tecla.
;; Solo tiene sentido si otras teclas sí han respondido.
;; ---------------------------------------------------------------------------
KbAnalysis:
	ld	a, (KbPressedCount)
	or	a
	jr	nz, .some
	ld	hl, TxtKbNone
	jp	PrintWrapped
.some:
	cp	KEYBOARD_KEY_COUNT
	jr	nz, .missing
	ld	a, (KbStuckCount)
	or	a
	jr	nz, .stuck
	ld	a, (KbFlakyCount)
	or	a
	jr	nz, .flaky
	ld	hl, TxtKbAllOk
	jp	PrintWrapped
.stuck:
	ld	hl, TxtKbStuckAdvice
	jp	PrintWrapped
.flaky:
	ld	hl, TxtKbFlakyAdvice
	jp	PrintWrapped

.missing:
	;; Con pocas teclas probadas no se puede sacar ninguna conclusión
	ld	a, (KbPressedCount)
	cp	MIN_FOR_ANALYSIS
	jr	nc, .enough
	ld	hl, TxtKbTooFew
	jp	PrintWrapped
.enough:
	xor	a
	ld	(KbPatternFound), a
	;; Líneas 0-8 completas sin respuesta
	ld	hl, PresseddMatrixBuffer
	ld	b, 0
.line:
	ld	a, (hl)
	or	a
	jr	nz, .nextLine
	push	hl
	push	bc
	ld	hl, TxtKbLineDead
	call	PrintWrapped
	ld	a, ' '
	call	PrintChar
	pop	bc
	push	bc
	ld	a, b
	add	a, '0'
	call	PrintChar
	call	WrapNewLine
	ld	a, 1
	ld	(KbPatternFound), a
	pop	bc
	pop	hl
.nextLine:
	inc	hl
	inc	b
	ld	a, b
	cp	JOY_ROW
	jr	nz, .line

	;; Columnas: OR de las filas 0-8; un bit a 0 es una columna muerta
	ld	hl, PresseddMatrixBuffer
	ld	b, JOY_ROW
	xor	a
.or:
	or	(hl)
	inc	hl
	djnz	.or
	ld	c, a
	ld	b, 0
.col:
	bit	0, c
	jr	nz, .nextCol
	push	bc
	ld	hl, TxtKbColumnDead
	call	PrintWrapped
	ld	a, ' '
	call	PrintChar
	pop	bc
	push	bc
	ld	a, b
	add	a, '0'
	call	PrintChar
	call	WrapNewLine
	ld	a, 1
	ld	(KbPatternFound), a
	pop	bc
.nextCol:
	rr	c
	inc	b
	ld	a, b
	cp	8
	jr	nz, .col

	ld	a, (KbPatternFound)
	or	a
	ld	hl, TxtKbPatternAdvice
	jr	nz, .advice
	ld	hl, TxtKbScatteredAdvice
.advice:
	jp	PrintWrapped

 ENDMODULE
