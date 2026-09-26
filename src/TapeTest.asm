;; TapeTest.asm — prueba del lector de cassette (versión RAM)
;;
;; Al final de la cinta de CPC Doctor (y en el WAV) hay un tono de
;; calibración de 2000 Hz. La prueba enciende el motor y cuenta los
;; flancos de la señal de cinta (PPI puerto B, bit 7) durante 50 cuadros.
;; El reloj es el propio VSYNC: con la configuración del CRTC de este
;; programa hay 312 líneas de 64 µs, 50,08 cuadros por segundo, así que 50
;; cuadros son 0,9984 s. Esto es una medición, no una observación del
;; usuario:
;;
;; - Velocidad: frecuencia medida frente a 2000 Hz. Un motor lento o una
;;   correa gastada dan una frecuencia más baja.
;; - Estabilidad: flancos en el peor cuadro frente al mejor. Si la señal
;;   llega débil (azimut del cabezal desajustado, cabezal sucio) se
;;   pierden flancos en algunos cuadros.
;;
;; La medida se repite cada segundo para poder ajustar el azimut o el
;; potenciómetro del motor mirando la pantalla.
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE TAPETEST

FRAMES		EQU 50
EXPECTED	EQU 3994		; flancos de 2000 Hz en 50 cuadros
MIN_EDGES	EQU 400			; por debajo, no hay tono
SPEED_OK	EQU 30			; ±3,0 %
SPEED_WARN	EQU 60			; ±6,0 %
QUALITY_OK	EQU 90			; %
NOT_TONE	EQU 150			; ±15,0 %: más allá no es el tono

@TapeTestSelected:
	ld	hl, TxtTapeTitle
	ld	de, TxtTapeIntro
	call	ExplainScreen
	jp	z, MainMenuRepeat

	xor	a
	ld	(TapeGoodCount), a
	ld	(TapeMeasured), a
.restart:
	call	MeasureScreen
	call	MotorOn
	xor	a
	ld	(TapeStop), a
.measure:
	call	MeasureSecond
	call	ShowMeasure
	ld	a, (TapeStop)
	or	a
	jr	z, .measure
	call	WaitNoKeys
	ld	a, (TapeStop)
	cp	TAPE_STOP_INFO
	jr	nz, .finished
	;; I: instrucciones con el motor parado (para no gastar el tono)
	call	MotorOff
	call	SpeedInstructions
	jr	.restart
.finished:

	call	MotorOff
	call	TapeVerdict
	call	TapeResultScreen
	jp	MainMenuRepeat


MeasureScreen:
	ld	hl, TxtTapeTitle
	call	PrintScreenTitle
	ld	hl, TxtTapeMeasuring
	call	PrintString
	ld	hl, TxtTapeStop
	jp	PrintHint

;; Cómo ajustar la velocidad del motor, en dos pantallas
SpeedInstructions:
	ld	hl, TxtTapeSpeedHowTitle
	ld	de, TxtTapeSpeedHow1
	call	ExplainScreen
	ret	z
	ld	hl, TxtTapeSpeedHowTitle
	ld	de, TxtTapeSpeedHow2
	call	ExplainScreen
	ret	z
	ld	hl, TxtTapeSpeedHowTitle
	ld	de, TxtTapeSpeedHow3
	jp	ExplainScreen

TAPE_STOP_END	EQU 1
TAPE_STOP_INFO	EQU 2

MotorOn:
	ld	bc, #F610
	out	(c), c
	ret
MotorOff:
	ld	bc, #F600
	out	(c), c
	ret


;; Cuenta flancos de la cinta durante FRAMES cuadros.
;; OUT: TapeEdges (16 bits), TapeMinFrame, TapeMaxFrame
MeasureSecond:
	di
	ld	a, #FF
	ld	(TapeMinFrame), a
	xor	a
	ld	(TapeMaxFrame), a
	call	WaitForVsync
	ld	b, #F5
	in	c, (c)			; C = valor anterior del puerto B
	ld	hl, 0			; flancos totales
	ld	ix, 0			; IXl = flancos de este cuadro
	ld	e, FRAMES
.loop:
	in	a, (c)
	ld	d, a
	xor	c			; bits que han cambiado
	ld	c, d
	bit	7, a
	jr	z, .noTape
	inc	hl
	inc	ixl
.noTape:
	and	1			; ¿ha cambiado el VSYNC?
	jr	z, .loop
	bit	0, d			; ¿empieza un cuadro?
	jr	z, .loop
	;; Fin de cuadro: guardar el mínimo y el máximo
	ld	a, ixl
	push	hl
	ld	hl, TapeMinFrame
	cp	(hl)
	jr	nc, .notMin
	ld	(hl), a
.notMin:
	ld	hl, TapeMaxFrame
	cp	(hl)
	jr	c, .notMax
	ld	(hl), a
.notMax:
	pop	hl
	ld	ixl, 0
	call	CheckStopKeys		; unos 80 µs: menos que un semiperiodo
	ld	b, #F5
	dec	e
	jr	nz, .loop
	ld	(TapeEdges), hl
	ret


;; Lee una de las filas de las teclas de parada (ENTER, RETURN, ESC, FUEGO
;; e I), una distinta en cada cuadro. Leer las cinco a la vez tardaba más
;; que medio periodo del tono y se perdían flancos (la velocidad salía
;; más baja). Una pulsación de más de 100 ms se detecta igual.
;; Si la tecla está pulsada, pone su motivo en TapeStop. Conserva BC, DE, HL.
CheckStopKeys:
	push	bc
	push	de
	push	hl
	ld	a, (TapeKeyRow)
	inc	a
	cp	5
	jr	c, .rowOk
	xor	a
.rowOk:
	ld	(TapeKeyRow), a
	ld	e, a
	add	a, a
	add	a, e				; x3
	ld	e, a
	ld	d, 0
	ld	hl, StopRows
	add	hl, de
	ld	bc, #F40E			; registro 14 del AY
	out	(c), c
	ld	b, #F6
	in	a, (c)
	and	#30				; conservar motor y escritura de cinta
	ld	e, a
	or	#C0
	out	(c), a
	out	(c), e
	ld	bc, #F792			; puerto A del PPI en entrada
	out	(c), c
	ld	a, (hl)
	inc	hl
	or	e
	or	#40				; leer del AY
	ld	b, #F6
	out	(c), a
	ld	b, #F4
	in	a, (c)
	cpl
	and	(hl)
	inc	hl
	jr	z, .done
	ld	a, (hl)
	ld	(TapeStop), a
.done:
	ld	bc, #F782
	out	(c), c
	ld	b, #F6
	out	(c), e
	pop	hl
	pop	de
	pop	bc
	ret

StopRows:
	db 0, %01000000, TAPE_STOP_END	; ENTER
	db 2, %00000100, TAPE_STOP_END	; RETURN
	db 8, %00000100, TAPE_STOP_END	; ESC
	db 9, %00110000, TAPE_STOP_END	; FUEGO 1 y 2
	db 4, %00001000, TAPE_STOP_INFO	; I

;; Calcula la velocidad en décimas de % y la calidad en %, y las muestra
ShowMeasure:
	ld	hl, (TapeEdges)
	ld	de, MIN_EDGES
	or	a
	sbc	hl, de
	jr	nc, .signal
	;; Sin tono
	ld	hl, #0004
	call	LocateWrap
	call	ClearLines
	ld	hl, #0004
	call	LocateWrap
	ld	hl, TxtTapeNoSignal
	call	PrintWrapped
	xor	a
	ld	(TapeHasSignal), a
	ret
.signal:
	;; Velocidad = (flancos - EXPECTED) / 4 (en décimas de %)
	ld	hl, (TapeEdges)
	ld	de, EXPECTED
	or	a
	sbc	hl, de
	sra	h
	rr	l
	sra	h
	rr	l
	ld	(TapeSpeed), hl
	;; Más de un 15 % de diferencia no es un motor lento: la señal no es el
	;; tono de calibración (por ejemplo, la cinta de un juego)
	call	AbsSpeed
	cp	NOT_TONE + 1
	jr	c, .isTone
	ld	hl, #0004
	call	LocateWrap
	call	ClearLines
	ld	hl, #0004
	call	LocateWrap
	ld	hl, TxtTapeNotTone
	call	PrintWrapped
	xor	a
	ld	(TapeHasSignal), a
	ld	(TapeGoodCount), a
	ret
.isTone:
	ld	a, 1
	ld	(TapeHasSignal), a
	ld	(TapeMeasured), a
	;; Calidad = mínimo * 100 / máximo
	ld	a, (TapeMaxFrame)
	or	a
	jr	z, .q0
	ld	c, a
	ld	a, (TapeMinFrame)
	ld	l, a
	ld	h, 0
	ld	d, h
	ld	e, l
	;; HL = min * 100
	add	hl, hl			; 2
	add	hl, hl			; 4
	add	hl, de			; 5
	add	hl, hl			; 10
	add	hl, hl			; 20
	ld	d, h
	ld	e, l
	add	hl, hl			; 40
	add	hl, hl			; 80
	add	hl, de			; 100
	;; / max
	ld	b, 0
	ld	a, 0
.div:
	or	a
	sbc	hl, bc
	jr	c, .divEnd
	inc	a
	jr	.div
.divEnd:
	jr	.q
.q0:
	xor	a
.q:
	ld	(TapeQuality), a

	;; Contar lecturas buenas seguidas (para el resultado)
	call	IsMeasureGood
	ld	hl, TapeGoodCount
	jr	nz, .bad
	inc	(hl)
	jr	.show
.bad:
	ld	(hl), 0
.show:
	ld	hl, #0004
	call	LocateWrap
	call	ClearLines
	ld	hl, #0004
	call	LocateWrap
	;; Frecuencia (flancos / 2, corregida a 1 s aprox.)
	ld	hl, TxtTapeFrequency
	call	PrintString
	ld	a, ' '
	call	PrintChar
	;; 2000 Hz + 2 Hz por cada décima de %
	ld	hl, (TapeSpeed)
	add	hl, hl
	ld	de, 2000
	add	hl, de
	call	PrintHLDec
	ld	hl, TxtTapeHz
	call	PrintString
	call	WrapNewLine
	;; Velocidad
	ld	hl, TxtTapeSpeed
	call	PrintString
	ld	a, ' '
	call	PrintChar
	call	SpeedColour
	call	PrintSpeed
	call	SetDefaultColors
	call	WrapNewLine
	;; Estabilidad
	ld	hl, TxtTapeQuality
	call	PrintString
	ld	a, ' '
	call	PrintChar
	ld	a, (TapeQuality)
	cp	QUALITY_OK
	call	c, SetErrorColors
	call	nc, SetSuccessColors
	ld	a, (TapeQuality)
	call	PrintANoPad
	ld	a, '%'
	call	PrintChar
	call	SetDefaultColors
	;; Barra de estabilidad: una casilla por cada 4 %
	call	WrapNewLine
	call	WrapNewLine
	ld	a, (TapeQuality)
	srl	a
	srl	a
	or	a
	ret	z
	ld	b, a
	call	SetSuccessColors
.bar:
	ld	a, #7F
	call	PrintChar
	djnz	.bar
	jp	SetDefaultColors


;; Borra las líneas 4 a 12
ClearLines:
	ld	l, 4
	ld	b, 9
	jp	ClearTextRows


;; OUT: Z si la última medida está dentro de tolerancia
IsMeasureGood:
	call	AbsSpeed
	cp	SPEED_OK + 1
	jr	nc, .no
	ld	a, (TapeQuality)
	cp	QUALITY_OK
	jr	c, .no
	xor	a
	ret
.no:
	or	1
	ret

;; OUT: A = |velocidad| en décimas de % (saturado a 255)
AbsSpeed:
	ld	hl, (TapeSpeed)
	bit	7, h
	jr	z, .pos
	xor	a
	sub	l
	ld	l, a
	sbc	a, a
	sub	h
	ld	h, a
.pos:
	ld	a, h
	or	a
	ld	a, l
	ret	z
	ld	a, 255
	ret

SpeedColour:
	call	AbsSpeed
	cp	SPEED_OK + 1
	jp	c, SetSuccessColors
	cp	SPEED_WARN + 1
	jp	c, SetWarningColors
	jp	SetErrorColors

;; "+1,2 %" a partir de TapeSpeed (décimas)
PrintSpeed:
	ld	hl, (TapeSpeed)
	ld	a, '+'
	bit	7, h
	jr	z, .sign
	ld	a, '-'
.sign:
	call	PrintChar
	call	AbsSpeed
	ld	l, a
	ld	h, 0
	;; parte entera = A / 10
	ld	c, 0
.div:
	sub	10
	jr	c, .divEnd
	inc	c
	jr	.div
.divEnd:
	add	a, 10
	push	af
	ld	a, c
	call	PrintANoPad
	ld	a, ','
	call	PrintChar
	pop	af
	add	a, '0'
	call	PrintChar
	ld	a, ' '
	call	PrintChar
	ld	a, '%'
	jp	PrintChar


;; Resultado: superado si la última medida era buena y lo fue al menos 3
;; segundos seguidos; error si la velocidad se sale de ±6 %; inconcluso
;; si no se llegó a oír el tono o si la medida no se estabilizó.
TapeVerdict:
	ld	a, (TapeMeasured)
	or	a
	ld	a, TESTRESULT_INCONCLUSIVE
	jr	z, .set
	ld	a, (TapeGoodCount)
	cp	3
	ld	a, TESTRESULT_PASSED
	jr	nc, .set
	call	AbsSpeed
	cp	SPEED_WARN + 1
	ld	a, TESTRESULT_FAILED
	jr	nc, .set
	ld	a, (TapeQuality)
	cp	QUALITY_OK
	ld	a, TESTRESULT_FAILED
	jr	c, .set
	ld	a, TESTRESULT_INCONCLUSIVE
.set:
	ld	(TestResultTableTape), a
	ret


TapeResultScreen:
	ld	hl, TxtTapeTitle
	call	PrintScreenTitle
	ld	hl, TxtMeasured
	call	PrintHeader
	ld	hl, #0003
	call	LocateWrap
	ld	a, (TapeMeasured)
	or	a
	jr	z, .noMeasure
	ld	hl, TxtTapeSpeed
	call	PrintString
	ld	a, ' '
	call	PrintChar
	call	SpeedColour
	call	PrintSpeed
	call	SetDefaultColors
	call	WrapNewLine
	ld	hl, TxtTapeQuality
	call	PrintString
	ld	a, ' '
	call	PrintChar
	ld	a, (TapeQuality)
	call	PrintANoPad
	ld	a, '%'
	call	PrintChar
	call	WrapNewLine
.noMeasure:
	call	WrapNewLine
	ld	a, (TestResultTableTape)
	call	PrintResultLine
	call	WrapNewLine
	call	WrapNewLine
	;; Consejo
	ld	a, (TapeMeasured)
	or	a
	ld	hl, TxtTapeAdvNoSignal
	jr	z, .advice
	ld	a, (TestResultTableTape)
	cp	TESTRESULT_PASSED
	ld	hl, TxtTapeAdvOk
	jr	z, .advice
	call	AbsSpeed
	cp	SPEED_OK + 1
	jr	c, .quality
	;; Velocidad fuera de margen: se pueden ver las instrucciones con I
	ld	hl, TxtTapeAdvSpeed
	call	PrintWrapped
	ld	hl, TxtTapeResultHint
	call	PrintHint
	call	WaitNoKeys
.waitKey:
	call	ReadInput
	and	(1 << UI.INPUT_OK) | (1 << UI.INPUT_BACK)
	ret	nz
	ld	a, (EdgeOnKeyboardMatrixBuffer + 4)
	and	%00001000			; I
	jr	z, .waitKey
	call	SpeedInstructions
	jp	TapeResultScreen
.quality:
	ld	hl, TxtTapeAdvQuality
.advice:
	call	PrintWrapped
	ld	hl, TxtPressOKToReturn
	call	PrintHint
	jp	WaitOK

 ENDMODULE
