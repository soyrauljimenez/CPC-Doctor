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
PAIR_SLOTS	EQU 12			; parejas de líneas o columnas unidas
PAIR_SIZE	EQU 5			; tipo, a, b, veces, ejemplo
PAIR_LINES	EQU 1			; misma columna, dos líneas: líneas unidas
PAIR_COLUMNS	EQU 2			; misma línea, dos columnas: columnas unidas
PAIR_MIN	EQU 2			; veces para darlo por confirmado
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
	ld	hl, KbPairs
	ld	b, PAIR_SLOTS * PAIR_SIZE
.clearPairs:
	ld	(hl), 0
	inc	hl
	djnz	.clearPairs
	ld	hl, PrevOff1Buffer
	call	ClearKeyboardBuffer
	ld	hl, PrevOff2Buffer
	call	ClearKeyboardBuffer
	ld	hl, 0
	ld	(KbIdleFrames), hl
	xor	a
	ld	(KbTimedOut), a
	inc	a				; NZ
	ret


KB_IDLE_FRAMES	EQU 10 * 50

;; Llamar una vez por cuadro, después de KbTrackFlaky. Cuenta el tiempo sin
;; pulsaciones nuevas. Las de teclas con rebotes no cuentan: una tecla que
;; falla sola no debe impedir que la prueba termine.
;; OUT: Z si se han cumplido 10 s (y KbTimedOut = 1)
@KbIdleTick:
	ld	hl, EdgeOnKeyboardMatrixBuffer
	ld	de, FlakyMatrixBuffer
	ld	b, KB_ROWS
	ld	c, 0
.row:
	ld	a, (de)
	cpl
	and	(hl)
	or	c
	ld	c, a
	inc	hl
	inc	de
	djnz	.row
	ld	a, c
	or	a
	ld	hl, 0
	jr	nz, .store			; alguien ha pulsado algo
	ld	hl, (KbIdleFrames)
	inc	hl
	ld	a, h
	cp	high KB_IDLE_FRAMES
	jr	nz, .store
	ld	a, l
	cp	low KB_IDLE_FRAMES
	jr	nz, .store
	ld	a, 1
	ld	(KbTimedOut), a
	xor	a				; Z
	ret
.store:
	ld	(KbIdleFrames), hl
	or	1				; NZ
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


;; Llamar una vez por cuadro. Si en el mismo cuadro se encienden exactamente
;; dos teclas que comparten columna (o línea), se anota la pareja. Una
;; persona casi nunca pulsa dos teclas en los mismos 20 ms; con dos líneas
;; de la matriz unidas (pistas de la membrana que se tocan), una sola
;; tecla enciende siempre las dos. Visto en un 464 real: líneas 0 y 1.
@KbTrackPairs:
	xor	a
	ld	(KbEdgeCount), a
	ld	hl, EdgeOnKeyboardMatrixBuffer
	ld	c, 0				; línea
.row:
	ld	e, (hl)
	ld	a, c
	cp	JOY_ROW
	jr	nz, .notJoy
	ld	a, e
	and	%10000000			; de la fila 9 solo DEL
	ld	e, a
.notJoy:
	ld	a, e
	or	a
	jr	z, .nextRow
	ld	b, 0				; columna
.bit:
	srl	e
	jr	nc, .nextBit
	push	hl
	ld	hl, KbEdgeCount
	ld	a, (hl)
	inc	(hl)
	cp	2
	jr	nc, .skip
	add	a, a
	ld	hl, KbEdges
	add	a, l
	ld	l, a
	jr	nc, $+3
	inc	h
	ld	(hl), c
	inc	hl
	ld	(hl), b
.skip:
	pop	hl
.nextBit:
	inc	b
	ld	a, e
	or	a
	jr	nz, .bit
.nextRow:
	inc	hl
	inc	c
	ld	a, c
	cp	KB_ROWS
	jr	nz, .row

	ld	a, (KbEdgeCount)
	cp	2
	ret	nz
	ld	a, (KbEdges)			; línea 1
	ld	d, a
	ld	a, (KbEdges + 2)		; línea 2
	ld	e, a
	ld	a, (KbEdges + 1)		; columna 1
	ld	b, a
	ld	a, (KbEdges + 3)		; columna 2
	cp	b
	jr	nz, .diffColumn
	;; Misma columna: líneas D y E unidas; ejemplo = la columna
	ld	l, b
	ld	a, PAIR_LINES
	jr	.record
.diffColumn:
	ld	c, a				; C = columna 2
	ld	a, d
	cp	e
	ret	nz				; ni línea ni columna en común
	;; Misma línea: columnas B y C unidas; ejemplo = la línea
	ld	l, d
	ld	d, b
	ld	e, c
	ld	a, PAIR_COLUMNS
.record:
	;; A = tipo, D/E = las dos líneas o columnas, L = ejemplo
	ld	c, a
	ld	ix, KbPairs
	ld	b, PAIR_SLOTS
.find:
	ld	a, (ix)
	or	a
	jr	z, .new
	cp	c
	jr	nz, .next
	ld	a, (ix+1)
	cp	d
	jr	nz, .next
	ld	a, (ix+2)
	cp	e
	jr	nz, .next
	inc	(ix+3)
	ret
.next:
	push	de
	ld	de, PAIR_SIZE
	add	ix, de
	pop	de
	djnz	.find
	ret					; tabla llena
.new:
	ld	(ix), c
	ld	(ix+1), d
	ld	(ix+2), e
	ld	(ix+3), 1
	ld	(ix+4), l
	ret

;; OUT: A = parejas confirmadas, C = tipo de la primera
KbCountJoined:
	ld	ix, KbPairs
	ld	b, PAIR_SLOTS
	ld	d, 0
	ld	c, 0
.loop:
	ld	a, (ix+3)
	cp	PAIR_MIN
	jr	c, .next
	ld	a, d
	or	a
	jr	nz, .counted
	ld	c, (ix)
.counted:
	inc	d
.next:
	push	de
	ld	de, PAIR_SIZE
	add	ix, de
	pop	de
	djnz	.loop
	ld	a, d
	ret

;; Lista las parejas confirmadas, en una línea por tipo:
;;   Líneas unidas: 0-1 5-6
;;   Columnas unidas: 2-3
KbPrintJoined:
	call	KbCountJoined
	or	a
	ret	z
	ld	hl, TxtKbJoinedLines
	ld	c, PAIR_LINES
	call	.list
	ld	hl, TxtKbJoinedColumns
	ld	c, PAIR_COLUMNS
	;; sigue
;; IN: HL = título, C = tipo. Solo imprime si hay alguna pareja de ese tipo.
.list:
	push	hl
	ld	ix, KbPairs
	ld	b, PAIR_SLOTS
	ld	e, 0				; ¿ya se ha escrito el título?
.loop:
	ld	a, (ix+3)
	cp	PAIR_MIN
	jr	c, .next
	ld	a, (ix)
	cp	c
	jr	nz, .next
	ld	a, e
	or	a
	jr	nz, .item
	pop	hl
	push	hl
	push	bc
	call	PrintString
	pop	bc
	ld	e, 1
.item:
	push	bc
	push	de
	;; Si no cabe " 0-1" en la línea, se sigue en la siguiente
	ld	a, (txt_x)
	add	a, 4
	ld	b, a
	ld	a, (WrapRight)
	cp	b
	call	c, WrapNewLine
	ld	a, ' '
	call	PrintChar
	ld	a, (ix+1)
	add	a, '0'
	call	PrintChar
	ld	a, '-'
	call	PrintChar
	ld	a, (ix+2)
	add	a, '0'
	call	PrintChar
	pop	de
	pop	bc
.next:
	push	de
	ld	de, PAIR_SIZE
	add	ix, de
	pop	de
	djnz	.loop
	pop	hl
	ld	a, e
	or	a
	ret	z
	jp	WrapNewLine


;; ---------------------------------------------------------------------------
;; Lectura lenta del puerto del AY
;;
;; Si cada tecla aparece también en la línea SIGUIENTE (0-1, 1-2, 2-3...), lo
;; más probable no es un cruce de pistas sino que el puerto A del AY tarda en
;; volver a reposo al cambiar de línea (resistencias pull-up internas débiles
;; o inexistentes). Visto en un 464 real con un AY-3-8912A de recambio: con el
;; AY original el teclado iba bien.
;;
;; Para confirmarlo se lee el teclado de las dos formas mientras el usuario
;; mantiene una tecla pulsada: la lectura normal (la que usan el firmware y
;; los juegos) y otra con una espera de unos 100 µs antes de cada línea.
;; ---------------------------------------------------------------------------

;; OUT: A = parejas de líneas consecutivas confirmadas, si TODAS las parejas
;;      confirmadas son de líneas consecutivas; si no, 0
KbConsecutiveLines:
	ld	ix, KbPairs
	ld	b, PAIR_SLOTS
	ld	c, 0				; consecutivas
.loop:
	ld	a, (ix+3)
	cp	PAIR_MIN
	jr	c, .next
	ld	a, (ix)
	cp	PAIR_LINES
	jr	nz, .other
	ld	a, (ix+1)
	inc	a
	cp	(ix+2)
	jr	nz, .other
	inc	c
.next:
	ld	de, PAIR_SIZE
	add	ix, de
	djnz	.loop
	ld	a, c
	ret
.other:
	xor	a
	ret

;; Como ReadFullKeyboard, pero esperando unos 100 µs entre elegir cada línea
;; y leerla. Deja el resultado en SlowMatrixBuffer.
ReadKeyboardSlow:
	ld	hl, SlowMatrixBuffer
	ld	bc, #F40E
	out	(c), c
	ld	b, #F6
	in	a, (c)
	and	#30
	ld	c, a
	or	#C0
	out	(c), a
	out	(c), c
	inc	b
	ld	a, #92
	out	(c), a
	push	bc
	set	6, c
.line:
	ld	b, #F6
	out	(c), c
	push	bc
	ld	b, 25
	djnz	$
	pop	bc
	ld	b, #F4
	in	a, (c)
	cpl
	ld	(hl), a
	inc	hl
	inc	c
	ld	a, c
	and	#0F
	cp	#0A
	jr	nz, .line
	pop	bc
	ld	a, #82
	out	(c), a
	dec	b
	out	(c), c
	ret

SLOW_FRAMES	EQU 150			; 3 segundos
SLOW_ENOUGH	EQU 25			; medio segundo de evidencia

;; Pide mantener una tecla y compara las dos lecturas.
;; OUT: KbSlowResult = 0 no se pudo saber, 1 lectura lenta confirmada,
;;      2 las dos lecturas coinciden (no es cuestión de tiempo)
KbSlowScanCheck:
	ld	hl, TxtKeyboardTitle
	call	PrintScreenTitle
	ld	hl, #0002
	call	LocateWrap
	ld	hl, TxtKbHoldKey
	call	PrintWrapped
	call	WaitNoKeys
	xor	a
	ld	(KbSlowYes), a
	ld	(KbSlowNo), a
	ld	b, SLOW_FRAMES
.frame:
	push	bc
	call	WaitForVsync
	call	ReadFullKeyboard
	ld	hl, KeyboardMatrixBuffer
	call	CountKeysInBuffer
	push	af
	call	ReadKeyboardSlow
	ld	hl, SlowMatrixBuffer
	call	CountKeysInBuffer
	ld	c, a				; teclas con la lectura lenta
	pop	af				; teclas con la lectura normal
	ld	b, a
	ld	a, c
	or	a
	jr	z, .skip			; nada pulsado
	ld	a, (SlowMatrixBuffer+9)
	or	a				; la línea 9 no tiene siguiente
	jr	nz, .skip
	ld	a, b
	cp	c
	ld	hl, KbSlowNo			; las dos lecturas coinciden
	jr	z, .count
	ld	a, c
	dec	a
	jr	nz, .skip
	ld	hl, KbSlowYes			; lenta ve una, normal ve más
.count:
	inc	(hl)
.skip:
	;; Barra de progreso
	pop	bc
	push	bc
	ld	a, SLOW_FRAMES
	sub	b
	srl	a
	srl	a				; 0..37
	add	a, 2
	ld	(txt_x), a
	ld	a, 20
	ld	(txt_y), a
	ld	a, '#'
	call	PrintChar
	pop	bc
	djnz	.frame

	ld	a, (KbSlowYes)
	cp	SLOW_ENOUGH
	ld	b, 1
	jr	nc, .set
	ld	a, (KbSlowNo)
	cp	SLOW_ENOUGH
	ld	b, 2
	jr	nc, .set
	ld	b, 0
.set:
	ld	a, b
	ld	(KbSlowResult), a
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
	;; Una tecla atascada es una avería aunque se hayan probado pocas
	ld	a, (KbStuckCount)
	or	a
	jr	z, .noStuckSet
	ld	b, TESTRESULT_FAILED
.noStuckSet:
	;; Teclas que se encienden a la vez: avería, aunque todas respondan
	push	bc
	call	KbCountJoined
	pop	bc
	or	a
	jr	z, .noJoined
	ld	b, TESTRESULT_FAILED
.noJoined:
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

	;; Si el patrón es el de la lectura lenta, se comprueba antes del resultado
	xor	a
	ld	(KbSlowResult), a
	ld	a, (AutoStep)			; en el modo automático no hay nadie
	or	a
	jr	nz, .noSlowCheck
	call	KbConsecutiveLines
	cp	2
	call	nc, KbSlowScanCheck
.noSlowCheck:
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
	call	KbPrintJoined
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
	call	KbCountJoined
	or	a
	jr	z, .notJoined
	ld	a, (KbSlowResult)
	cp	1
	ld	hl, TxtKbSlowPortAdvice
	jp	z, PrintWrapped
	cp	2				; las dos lecturas coinciden: no es el AY
	jr	z, .joinedAdvice
	call	KbConsecutiveLines
	cp	2
	ld	hl, TxtKbSlowPortLikely
	jp	nc, PrintWrapped
.joinedAdvice:
	call	KbCountJoined
	ld	hl, TxtKbJoinedLinesAdvice
	ld	a, c
	cp	PAIR_LINES
	jp	z, PrintWrapped
	ld	hl, TxtKbJoinedColumnsAdvice
	jp	PrintWrapped
.notJoined:
	ld	a, (KbPressedCount)
	or	a
	jr	nz, .some
	ld	a, (KbTimedOut)
	or	a
	ld	hl, TxtKbIdleNone		; nadie ha pulsado nada en 10 s
	jp	nz, PrintWrapped
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
