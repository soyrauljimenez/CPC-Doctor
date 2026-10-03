;; VideoTest.asm — prueba guiada de imagen (versión RAM)
;;
;; El programa no puede ver la pantalla: muestra patrones y pregunta al
;; usuario qué ve. El resultado se basa en sus respuestas y así se indica.
;;
;; Pasos:
;;   0-3  franjas de rojo, verde, azul y gris (negro, nivel medio, brillante)
;;        Cada salida de color del CPC tiene tres niveles; si dos franjas se
;;        ven iguales o falta un color, algo se pierde por el camino.
;;   4    rampa de 16 brillos (solo monitor verde GT64/GT65)
;;   5    rejilla de geometría con el borde de otro color
;;   6    líneas finas en Mode 2 (nitidez)
;;   7    la rejilla desplazándose (estabilidad de la sincronía)
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE VIDEOTEST

VIDEO_STEPS	EQU 8
STEP_RAMP	EQU 4
STEP_SCROLL	EQU 7
NOT_ASKED	EQU #FF

DISPLAY_COLOUR	EQU 0
DISPLAY_GREEN	EQU 1
DISPLAY_TV_RF	EQU 2
DISPLAY_RGB	EQU 3
DISPLAY_HDMI	EQU 4

GA_MODE_BASE	EQU %10001100		; ROMs desconectadas (versión RAM)

@VideoTestSelected:
	ld	a, (AutoStep)
	or	a
	jr	nz, AutoVideoDemo
	ld	hl, TxtVideoTitle
	ld	de, TxtVideoIntro
	call	ExplainScreen
	jp	z, MainMenuRepeat

	;; ¿Qué pantalla se usa?
	ld	hl, TxtVideoTitle
	call	PrintScreenTitle
	ld	hl, TxtVideoWhichDisplay
	call	PrintString
	ld	ix, DisplayTypes
	ld	hl, #0204
	ld	a, (DisplayType)
	call	Choose
	cp	#FF
	jp	z, MainMenuRepeat
	ld	(DisplayType), a

	;; Todas las respuestas a "sin preguntar"
	ld	hl, VideoAnswers
	ld	b, VIDEO_STEPS
.clear:
	ld	(hl), NOT_ASKED
	inc	hl
	djnz	.clear

	xor	a
	ld	(VideoStep), a
.step:
	call	StepApplies
	jr	z, .next
.show:
	call	ShowPattern
	call	RestoreVideo
	call	AskAboutPattern
	cp	#FF
	jr	z, .aborted
	cp	3				; repetir
	jr	z, .show
	ld	c, a
	ld	a, (VideoStep)
	ld	e, a
	ld	d, 0
	ld	hl, VideoAnswers
	add	hl, de
	ld	(hl), c
.next:
	ld	a, (VideoStep)
	inc	a
	ld	(VideoStep), a
	cp	VIDEO_STEPS
	jr	nz, .step

	call	VideoVerdict
	call	VideoResultScreen
	jp	MainMenuRepeat

.aborted:
	call	RestoreVideo
	ld	a, TESTRESULT_ABORTED
	ld	(TestResultTableVideo), a
	jp	MainMenuRepeat


;; Modo automático: todos los patrones seguidos, cada uno con lo que hay que
;; mirar, sin preguntar. El resultado sigue "sin probar": el programa no sabe
;; qué se ha visto.
AutoVideoDemo:
	xor	a
	ld	(VideoStep), a
.step:
	call	VideoStepHeader
	ld	hl, TxtAutoWatchHint
	call	PrintHint
	ld	b, 150
	call	WaitFrames
	call	ShowPattern
	call	RestoreVideo
	ld	a, (VideoStep)
	inc	a
	ld	(VideoStep), a
	cp	VIDEO_STEPS
	jr	nz, .step
	jp	MainMenuRepeat


DisplayTypes:
	dw TxtDisplayColour, TxtDisplayGreen, TxtDisplayTV, TxtDisplayRGB, TxtDisplayHDMI, 0


;; ¿Se hace este paso con esta pantalla?  OUT: NZ si se hace
StepApplies:
	ld	a, (DisplayType)
	cp	DISPLAY_GREEN
	ld	a, (VideoStep)
	jr	z, .green
	cp	STEP_RAMP			; la rampa solo tiene sentido en el verde
	ret
.green:
	cp	STEP_RAMP			; en el verde no hay colores que comprobar
	jr	c, .no
	or	1
	ret
.no:
	xor	a
	ret


;; ---------------------------------------------------------------------------
;; Patrones
;; ---------------------------------------------------------------------------
ShowPattern:
	call	WaitNoKeys
	ld	a, (VideoStep)
	cp	STEP_RAMP
	jp	c, PatternBars
	jp	z, PatternRamp
	cp	5
	jp	z, PatternGrid
	cp	6
	jp	z, PatternSharp
	jp	PatternScroll


;; Tres franjas del mismo color: apagado, medio y brillante, y su nombre
PatternBars:
	ld	a, 1
	call	SetVideoMode
	;; Tintas: 0 negro, 1 nivel medio, 2 brillante, 3 blanco para el texto
	ld	a, (VideoStep)
	ld	e, a
	add	a, a
	add	a, e				; x3
	ld	e, a
	ld	d, 0
	ld	hl, BarInks
	add	hl, de
	ld	a, ColorBlack
	ld	c, 0
	call	SetInk
	ld	a, (hl)
	ld	c, 1
	call	SetInk
	inc	hl
	ld	a, (hl)
	ld	c, 2
	call	SetInk
	inc	hl
	ld	a, (hl)
	ld	c, 16				; borde del mismo color que el nivel alto
	call	SetInk
	ld	a, ColorWhite
	ld	c, 3
	call	SetInk

	xor	a
	call	FillScreen
	;; Franja central y derecha (la izquierda es el negro del fondo)
	ld	hl, #1A10			; x = 26 bytes, y = 16
	ld	bc, #1A98			; 26 bytes x 152 líneas			; 26 bytes x 152 líneas
	ld	a, PATTERN_YELLOW		; tinta 1
	call	FillRect
	ld	hl, #3410
	ld	bc, #1A98
	ld	a, PATTERN_BLUE			; tinta 2
	call	FillRect
	;; Marco blanco alrededor de las tres franjas (si no, la negra no se ve)
	ld	hl, #000F
	ld	bc, #4F01
	ld	a, #FF
	call	FillRect
	ld	hl, #00A8
	ld	bc, #4F01
	ld	a, #FF
	call	FillRect
	ld	h, 0
.frame:
	push	hl
	ld	l, #10
	ld	bc, #0198
	ld	a, %10001000
	call	FillRect
	pop	hl
	ld	a, h
	add	a, 26
	ld	h, a
	cp	78
	jr	c, .frame
	ld	hl, #4E10
	ld	bc, #0198
	ld	a, %10001000
	call	FillRect
	;; Nombre del color debajo
	ld	h, pen0
	ld	l, pen3
	call	SetTxtColors
	ld	hl, #0016
	ld	(TxtCoords), hl
	ld	a, (VideoStep)
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, BarNames
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	call	PrintString
	jp	WaitOK

BarInks:
	db ColorRed, ColorBrightRed, ColorBrightRed
	db ColorGreen, ColorBrightGreen, ColorBrightGreen
	db ColorBlue, ColorBrightBlue, ColorBrightBlue
	db ColorGrey, ColorWhite, ColorGrey
BarNames:
	dw TxtVideoRed, TxtVideoGreen, TxtVideoBlue, TxtVideoGrey


;; 16 franjas de brillo creciente en Mode 0
PatternRamp:
	xor	a
	call	SetVideoMode
	ld	hl, RampInks
	ld	c, 0
.ink:
	ld	a, (hl)
	call	SetInk
	inc	hl
	inc	c
	ld	a, c
	cp	16
	jr	nz, .ink
	ld	a, ColorBlack
	ld	c, 16
	call	SetInk
	;; Franja n: 5 bytes de ancho con la tinta n
	ld	c, 0
	ld	h, 0
.bar:
	push	bc
	push	hl
	ld	a, c
	call	Mode0InkByte
	ld	l, 0
	ld	bc, #05C8			; 5 bytes x 200 líneas
	call	FillRect
	pop	hl
	pop	bc
	ld	a, h
	add	a, 5
	ld	h, a
	inc	c
	ld	a, c
	cp	16
	jr	nz, .bar
	jp	WaitOK

;; Colores del firmware 0,2,3,5,6,8,9,11,13,15,17,18,20,22,24,26:
;; brillo creciente
RampInks:
	db ColorBlack, ColorBrightBlue, ColorRed, ColorMauve
	db ColorBrightRed, ColorBrightMagenta, ColorGreen, ColorSkyBlue
	db ColorGrey, ColorOrange, ColorPastelMagenta, ColorBrightGreen
	db ColorBrightCyan, ColorPastelGreen, ColorBrightYellow, ColorWhite

;; IN: A = tinta 0..15  OUT: A = byte de Mode 0 con los dos píxeles de esa tinta
;; Bits de un píxel en Mode 0: b0 -> 7, b2 -> 5, b1 -> 3, b3 -> 1 (y el
;; segundo píxel en el bit siguiente a la derecha).
Mode0InkByte:
	ld	e, a
	xor	a
	bit	0, e
	jr	z, $+4
	or	%11000000
	bit	2, e
	jr	z, $+4
	or	%00110000
	bit	1, e
	jr	z, $+4
	or	%00001100
	bit	3, e
	jr	z, $+4
	or	%00000011
	ret


;; Rejilla blanca sobre negro, borde rojo
PatternGrid:
	call	DrawGrid
	jp	WaitOK

DrawGrid:
	ld	a, 1
	call	SetVideoMode
	ld	a, ColorBlack
	ld	c, 0
	call	SetInk
	ld	a, ColorWhite
	ld	c, 3
	call	SetInk
	ld	a, ColorBrightRed
	ld	c, 16
	call	SetInk
	xor	a
	call	FillScreen
	;; Líneas verticales de un píxel cada 8 bytes y la del borde derecho
	ld	h, 0
.vline:
	push	hl
	ld	l, 0
	ld	bc, #01C8
	ld	a, %10001000			; píxel izquierdo en tinta 3
	call	FillRect
	pop	hl
	ld	a, h
	add	a, 8
	ld	h, a
	cp	80
	jr	c, .vline
	ld	hl, #4F00
	ld	bc, #01C8
	ld	a, %00010001			; píxel derecho del último byte
	call	FillRect
	;; Líneas horizontales cada 20 líneas y la última
	ld	l, 0
.hline:
	push	hl
	ld	h, 0
	ld	bc, #5001			; 80 bytes x 1 línea
	ld	a, #FF
	call	FillRect
	pop	hl
	ld	a, l
	add	a, 20
	ld	l, a
	cp	200
	jr	c, .hline
	ld	hl, #00C7
	ld	bc, #5001
	ld	a, #FF
	call	FillRect
	ret


;; Mode 2: mitad de arriba líneas verticales de un píxel, mitad de abajo
;; tablero de ajedrez
PatternSharp:
	ld	a, 2
	call	SetVideoMode
	ld	a, ColorBlack
	ld	c, 0
	call	SetInk
	ld	a, ColorWhite
	ld	c, 1
	call	SetInk
	ld	a, ColorBlack
	ld	c, 16
	call	SetInk
	ld	hl, #0000
	ld	bc, #5064
	ld	a, #AA
	call	FillRect
	ld	l, 100
.checker:
	push	hl
	ld	h, 0
	ld	bc, #5001
	ld	a, l
	and	1
	ld	a, #AA
	jr	z, .even
	ld	a, #55
.even:
	call	FillRect
	pop	hl
	inc	l
	ld	a, l
	cp	200
	jr	c, .checker
	jp	WaitOK


;; La rejilla desplazándose (se cambia el inicio de pantalla cada cuadro)
PatternScroll:
	call	DrawGrid
	call	WaitNoKeys
	ld	hl, AUTO_WAIT_FRAMES
	ld	(WaitOKFrames), hl
	ld	hl, #3000			; R12/R13 al empezar (#C000)
.frame:
	push	hl
	call	ReadInput
	ld	a, (AutoStep)			; modo automático: 5 s
	or	a
	jr	z, .manual
	ld	hl, (WaitOKFrames)
	dec	hl
	ld	(WaitOKFrames), hl
	ld	a, h
	or	l
	jr	nz, .manual
	pop	hl
	ret
.manual:
	ld	a, (InputFlags)
	pop	hl
	and	(1 << UI.INPUT_OK) | (1 << UI.INPUT_BACK)
	ret	nz
	inc	hl
	ld	a, h
	and	%00000011
	or	#30
	ld	h, a
	ld	bc, #BC0C
	out	(c), c
	inc	b
	out	(c), h
	dec	b
	inc	c
	out	(c), c
	inc	b
	out	(c), l
	jr	.frame


;; ---------------------------------------------------------------------------
;; Utilidades de vídeo
;; ---------------------------------------------------------------------------

;; IN: A = modo (0, 1, 2)
SetVideoMode:
	or	GA_MODE_BASE
	ld	b, #7F
	out	(c), a
	ret

;; IN: C = tinta (0..15, 16 = borde), A = color hardware (#40..#5F)
SetInk:
	push	bc
	ld	b, #7F
	out	(c), c
	out	(c), a
	pop	bc
	ret

;; Deja la pantalla como la usa el resto del programa
RestoreVideo:
	call	InitializeCRTC
	ld	a, 1
	call	SetVideoMode
	ld	hl, DefaultInks
	ld	c, 0
.ink:
	ld	a, (hl)
	call	SetInk
	inc	hl
	inc	c
	ld	a, c
	cp	4
	jr	nz, .ink
	ld	a, ColorBlue
	ld	c, 16
	call	SetInk
	jp	SetDefaultColors

;; Tintas del firmware en Mode 1: azul, amarillo, cian y rojo
@DefaultInks:
	db ColorBlue, ColorBrightYellow, ColorBrightCyan, ColorBrightRed

;; IN: A = byte con el que se llena
FillScreen:
	ld	hl, #C000
	ld	(hl), a
	ld	de, #C001
	ld	bc, #3FFF
	ldir
	ret

;; IN: H = x (bytes), L = y (líneas), B = ancho (bytes), C = alto (líneas),
;;     A = byte con el que se llena
FillRect:
	ld	(FillByte), a
.line:
	push	bc
	push	hl
	;; Dirección = scr_table[y] + x
	ld	a, h
	ld	h, 0
	add	hl, hl
	ld	de, scr_table
	add	hl, de
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	ld	l, a
	ld	h, 0
	add	hl, de
	ld	a, (FillByte)
.byte:
	ld	(hl), a
	inc	hl
	djnz	.byte
	pop	hl
	inc	l
	pop	bc
	dec	c
	jr	nz, .line
	ret


;; ---------------------------------------------------------------------------
;; Preguntas y resultado
;; ---------------------------------------------------------------------------

;; OUT: A = respuesta (0 sí, 1 no, 2 no lo sé, 3 repetir) o #FF
AskAboutPattern:
	call	VideoStepHeader
	ld	ix, AnswersWithRepeat
	ld	hl, #0214
	xor	a
	jp	Choose

;; Título, nombre del paso y lo que hay que mirar
VideoStepHeader:
	ld	hl, TxtVideoTitle
	call	PrintScreenTitle
	ld	a, (VideoStep)
	call	GetVideoStepText
	push	hl
	ld	a, (VideoStep)
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, StepNames
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	call	PrintHeader
	ld	hl, #0004
	call	LocateWrap
	pop	hl
	jp	PrintWrapped

;; IN: A = paso  OUT: HL = pregunta del paso
GetVideoStepText:
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, StepQuestions
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	ret

StepNames:
	dw TxtVideoRed, TxtVideoGreen, TxtVideoBlue, TxtVideoGrey
	dw TxtVideoRampName, TxtVideoGridName, TxtVideoSharpName, TxtVideoScrollName
StepQuestions:
	dw TxtVideoQBars, TxtVideoQBars, TxtVideoQBars, TxtVideoQGrey
	dw TxtVideoQRamp, TxtVideoQGrid, TxtVideoQSharp, TxtVideoQScroll
StepAdvice:
	dw TxtVideoAdvColour, TxtVideoAdvColour, TxtVideoAdvColour, TxtVideoAdvGrey
	dw TxtVideoAdvRamp, TxtVideoAdvGrid, TxtVideoAdvSharp, TxtVideoAdvScroll


VideoVerdict:
	ld	hl, VideoAnswers
	ld	b, VIDEO_STEPS
	ld	c, 0
.loop:
	ld	a, (hl)
	cp	ANSWER_NO
	jr	nz, $+4
	set	0, c
	cp	ANSWER_UNSURE
	jr	nz, $+4
	set	1, c
	inc	hl
	djnz	.loop
	ld	a, TESTRESULT_FAILED
	bit	0, c
	jr	nz, .set
	ld	a, TESTRESULT_INCONCLUSIVE
	bit	1, c
	jr	nz, .set
	ld	a, TESTRESULT_PASSED
.set:
	ld	(TestResultTableVideo), a
	ret


VideoResultScreen:
	ld	hl, TxtVideoTitle
	call	PrintScreenTitle
	ld	hl, TxtDisplayUsed
	call	PrintString
	ld	a, ' '
	call	PrintChar
	call	PrintDisplayType
	call	NewLine
	call	NewLine
	ld	hl, TxtObserved
	call	PrintHeader
	call	NewLine
	ld	b, 0
.line:
	ld	e, b
	ld	d, 0
	ld	hl, VideoAnswers
	add	hl, de
	ld	a, (hl)
	cp	NOT_ASKED
	jr	z, .skip
	push	bc
	ld	a, 2
	ld	(txt_x), a
	ld	a, b
	add	a, a
	ld	e, a
	ld	hl, StepNames
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	call	PrintString
	ld	a, 30
	ld	(txt_x), a
	pop	bc
	push	bc
	ld	e, b
	ld	d, 0
	ld	hl, VideoAnswers
	add	hl, de
	ld	a, (hl)
	call	PrintAnswer
	call	NewLine
	pop	bc
.skip:
	inc	b
	ld	a, b
	cp	VIDEO_STEPS
	jr	nz, .line

	call	NewLine
	ld	a, (TestResultTableVideo)
	call	PrintResultLine
	ld	a, (TestResultTableVideo)
	cp	TESTRESULT_PASSED
	jr	nz, .advice
	call	NewLine
	call	NewLine
	ld	hl, TxtVideoAllOk
	call	PrintWrapped
	ld	hl, TxtPressOKToReturn
	call	PrintHint
	jp	WaitOK

	;; Un consejo por cada paso que ha fallado o ha quedado en duda, en
	;; pantallas sucesivas
.advice:
	ld	hl, TxtPressOKToContinue
	call	PrintHint
	call	WaitOK
	ret	z
	ld	b, 0
.adv:
	ld	e, b
	ld	d, 0
	ld	hl, VideoAnswers
	add	hl, de
	ld	a, (hl)
	cp	ANSWER_NO
	jr	z, .give
	cp	ANSWER_UNSURE
	jr	nz, .nextAdv
.give:
	push	bc
	ld	hl, TxtVideoTitle
	call	PrintScreenTitle
	pop	bc
	push	bc
	ld	a, b
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, StepNames
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	call	PrintHeader
	ld	hl, #0004
	call	LocateWrap
	pop	bc
	push	bc
	ld	a, b
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, StepAdvice
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	call	PrintWrapped
	;; Recordatorio según la pantalla usada
	call	WrapNewLine
	call	WrapNewLine
	call	GetDisplayAdvice
	call	PrintWrapped
	ld	hl, TxtPressOKToContinue
	call	PrintHint
	call	WaitOK
	pop	bc
	ret	z
.nextAdv:
	inc	b
	ld	a, b
	cp	VIDEO_STEPS
	jr	nz, .adv
	ret

;; OUT: HL = consejo según el tipo de pantalla
GetDisplayAdvice:
	ld	a, (DisplayType)
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, DisplayAdvice
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	ret

DisplayAdvice:
	dw TxtDisplayAdvColour, TxtDisplayAdvGreen, TxtDisplayAdvTV, TxtDisplayAdvRGB, TxtDisplayAdvHDMI

@PrintDisplayType:
	ld	a, (DisplayType)
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, DisplayTypes
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	jp	PrintString

 ENDMODULE
