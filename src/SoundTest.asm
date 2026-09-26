;; Prueba de sonido
;;
;; Cada canal suena por separado (en Amstrad Diagnostics se iban sumando:
;; A, A+B, A+B+C, y no se podía saber cuál fallaba). Después suena el
;; generador de ruido y una envolvente de volumen.
;;
;; En la versión guiada se pregunta al usuario qué ha oído después de cada
;; paso: el programa no puede medir el sonido, así que el resultado se basa
;; en su respuesta y se presenta como tal.

 MODULE SOUNDTEST

SOUND_STEPS	EQU 5
STEP_FRAMES	EQU 90			; 1,8 s por paso

;; Periodos de tono (reloj del AY a 1 MHz: f = 1000000 / (16 * P))
TONE_A	EQU 142				; 440 Hz
TONE_B	EQU 119				; 525 Hz
TONE_C	EQU 95				; 658 Hz

@SoundTest:
	ld	hl, TxtSoundTitle
	call	PrintScreenTitle
	call	Silence

	ld	hl, TxtCheckingPSG
	call	PrintString
	ld	a, ' '
	call	PrintChar
	ld	a, (PSGType)
	or	a
	ld	hl, TxtAY3
	jr	z, .psg
	ld	hl, TxtYM
.psg:
	call	PrintString

 IFDEF GUIDED
	jp	GuidedSoundTest
 ELSE
	;; Versión ROM: los pasos seguidos, sin preguntas
	ld	hl, #0004
	ld	(TxtCoords), hl
	ld	b, 0
.step:
	push	bc
	ld	a, b
	call	GetStepName
	call	PrintString
	ld	a, ' '
	call	PrintChar
	pop	bc
	push	bc
	ld	a, b
	call	PlayStep
	ld	hl, TxtSoundOn
	call	PrintString
	call	NewLine
	pop	bc
	inc	b
	ld	a, b
	cp	SOUND_STEPS
	jr	nz, .step
	call	NewLine
	ld	hl, TxtSoundDone
	jp	PrintString
 ENDIF


;; IN: A = paso (0..4)  OUT: HL = nombre del paso
GetStepName:
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, StepNames
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	ret

StepNames:
	dw TxtSoundStepA, TxtSoundStepB, TxtSoundStepC, TxtSoundStepNoise, TxtSoundStepVolume


;; Hace sonar un paso durante STEP_FRAMES cuadros y luego silencio.
;; IN: A = paso (0 = canal A, 1 = B, 2 = C, 3 = ruido, 4 = envolvente)
PlayStep:
	push	af
	call	Silence
	pop	af
	or	a
	jr	nz, .notA
	ld	a, 0
	ld	hl, TONE_A
	call	AYRegWriteWord
	ld	a, 8
	ld	l, SOUND_VOLUME
	call	AYRegWriteByte
	ld	l, %10111110
	jr	.mixer
.notA:
	dec	a
	jr	nz, .notB
	ld	a, 2
	ld	hl, TONE_B
	call	AYRegWriteWord
	ld	a, 9
	ld	l, SOUND_VOLUME
	call	AYRegWriteByte
	ld	l, %10111101
	jr	.mixer
.notB:
	dec	a
	jr	nz, .notC
	ld	a, 4
	ld	hl, TONE_C
	call	AYRegWriteWord
	ld	a, 10
	ld	l, SOUND_VOLUME
	call	AYRegWriteByte
	ld	l, %10111011
	jr	.mixer
.notC:
	dec	a
	jr	nz, .envelope
	;; Ruido por el canal B (el central: se oye por los dos lados)
	ld	a, 6
	ld	l, 8
	call	AYRegWriteByte
	ld	a, 9
	ld	l, SOUND_VOLUME
	call	AYRegWriteByte
	ld	l, %10101111
	jr	.mixer
.envelope:
	;; Tono en el canal B con envolvente descendente de unos 2 segundos
	ld	a, 2
	ld	hl, TONE_A
	call	AYRegWriteWord
	;; Un ciclo de la envolvente dura 256 * EP µs (reloj de 1 MHz):
	;; con EP = 7000 el volumen baja de 15 a 0 en unos 1,8 s. (Antes era
	;; 440: 0,1 s, apenas un chasquido; se descubrió en un 464 real.)
	ld	a, 11
	ld	hl, 7000
	call	AYRegWriteWord
	ld	a, 13
	ld	l, 0				; \___
	call	AYRegWriteByte
	ld	a, 9
	ld	l, #10				; volumen controlado por la envolvente
	call	AYRegWriteByte
	ld	l, %10111101
.mixer:
	ld	a, 7
	call	AYRegWriteByte
	ld	b, STEP_FRAMES
	call	WaitFrames
	jp	Silence

SOUND_VOLUME EQU 15


;; Todo en silencio. El bit 6 del mezclador queda a 0: el puerto A del AY
;; tiene que seguir en entrada para poder leer el teclado.
@Silence:
	ld	a, 7
	ld	l, %10111111
	call	AYRegWriteByte
	ld	a, 8
	ld	l, 0
	call	AYRegWriteByte
	ld	a, 9
	ld	l, 0
	call	AYRegWriteByte
	ld	a, 10
	ld	l, 0
	jp	AYRegWriteByte


;; IN: A = registro, HL = valor (L en A, H en A+1)
@AYRegWriteWord:
	push	af
	call	AYRegWriteByte
	pop	af
	inc	a
	ld	l, h
	;; sigue en AYRegWriteByte

;; IN: A = registro, L = valor. Conserva A.
@AYRegWriteByte:
	push	bc
	ld	b, #F4
	ld	c, a
	out	(c), c
	ld	bc, #F6C0			; seleccionar registro
	out	(c), c
	ld	bc, #F600
	out	(c), c
	ld	b, #F4
	ld	c, l
	out	(c), c
	ld	bc, #F680			; escribir dato
	out	(c), c
	ld	bc, #F600
	out	(c), c
	pop	bc
	ret


;; IN: A = registro  OUT: A = valor
@AYRegReadByte:
	ld	b, #F4
	ld	c, a
	out	(c), c
	ld	bc, #F6C0
	out	(c), c
	ld	bc, #F600
	out	(c), c
	ld	bc, #F792			; puerto A del PPI en entrada
	out	(c), c
	ld	bc, #F640			; leer dato
	out	(c), c
	ld	b, #F4
	in	a, (c)
	ld	bc, #F782			; puerto A del PPI en salida
	out	(c), c
	ld	bc, #F600
	out	(c), c
	ret


 IFDEF GUIDED
;; ---------------------------------------------------------------------------
;; Versión guiada
;; ---------------------------------------------------------------------------
GuidedSoundTest:
	ld	hl, #0003
	call	LocateWrap
	ld	hl, TxtSoundIntro
	call	PrintWrapped
	ld	hl, TxtPressOKToStart
	call	PrintHint
	call	WaitOK
	ret	z				; ESC: volver sin resultado

	xor	a
	ld	(SoundStep), a
.step:
	call	SoundStepScreen
	ld	a, (SoundStep)
	call	PlayStep
.ask:
	ld	ix, AnswersWithRepeat
	ld	hl, #0000 + ANSWER_Y
	ld	h, 2
	xor	a
	call	Choose
	cp	#FF
	jr	z, .aborted
	cp	3				; repetir
	jr	nz, .answered
	ld	a, (SoundStep)
	call	PlayStep
	jr	.ask
.answered:
	;; Guardar la respuesta (0 sí, 1 no, 2 no lo sé)
	ld	c, a
	ld	a, (SoundStep)
	ld	e, a
	ld	d, 0
	ld	hl, SoundAnswers
	add	hl, de
	ld	(hl), c
	ld	a, (SoundStep)
	inc	a
	ld	(SoundStep), a
	cp	SOUND_STEPS
	jr	nz, .step

	call	SoundVerdict
	jp	SoundResultScreen

.aborted:
	call	Silence
	ld	a, TESTRESULT_ABORTED
	ld	(TestResultTableSound), a
	ret


ANSWER_Y EQU 14

SoundStepScreen:
	ld	hl, TxtSoundTitle
	call	PrintScreenTitle
	ld	hl, #0002
	ld	(TxtCoords), hl
	ld	a, (SoundStep)
	call	GetStepName
	call	PrintHeader
	ld	hl, #0004
	call	LocateWrap
	ld	a, (SoundStep)
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, StepHelp
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	call	PrintWrapped
	ld	hl, #0000 + ANSWER_Y - 2
	ld	(TxtCoords), hl
	ld	hl, TxtSoundQuestion
	jp	PrintString

;; Busca un patrón concreto en las respuestas. El ruido y la envolvente
;; salen por el canal B, así que comparando se puede afinar:
;; - tono B no, ruido sí: la salida B funciona; falla el generador de tono B
;;   (dentro del AY). Visto en un 464 real y confirmado con SOUND en BASIC.
;; - tono B no, ruido no: falla todo el canal B (salida del AY o su mezcla).
;; - tono B sí, envolvente no: falla la envolvente del AY.
;; OUT: HL = consejo
SoundPattern:
	ld	a, (SoundAnswers + 1)		; canal B
	cp	ANSWER_NO
	jr	nz, .bOk
	ld	a, (SoundAnswers + 3)		; ruido (por el canal B)
	cp	ANSWER_YES
	ld	hl, TxtSoundToneBDead
	ret	z
	cp	ANSWER_NO
	ld	hl, TxtSoundChannelBDead
	ret	z
	jr	.generic
.bOk:
	cp	ANSWER_YES
	jr	nz, .generic
	ld	a, (SoundAnswers + 4)		; envolvente
	cp	ANSWER_NO
	ld	hl, TxtSoundEnvelopeDead
	ret	z
.generic:
	ld	hl, TxtSoundSomeMissing
	ret

StepHelp:
	dw TxtSoundHelpA, TxtSoundHelpB, TxtSoundHelpC, TxtSoundHelpNoise, TxtSoundHelpVolume


;; Calcula el resultado a partir de las respuestas.
;; Un "no" es un fallo observado; un "no lo sé" sin ningún "no" deja la
;; prueba inconclusa.
SoundVerdict:
	ld	hl, SoundAnswers
	ld	b, SOUND_STEPS
	ld	c, 0				; bit 0: algún no, bit 1: algún no lo sé
	ld	d, 0				; número de "no"
.loop:
	ld	a, (hl)
	cp	1
	jr	nz, .notNo
	set	0, c
	inc	d
.notNo:
	cp	2
	jr	nz, .next
	set	1, c
.next:
	inc	hl
	djnz	.loop
	ld	a, d
	ld	(SoundNoCount), a
	ld	a, TESTRESULT_FAILED
	bit	0, c
	jr	nz, .set
	ld	a, TESTRESULT_INCONCLUSIVE
	bit	1, c
	jr	nz, .set
	ld	a, TESTRESULT_PASSED
.set:
	ld	(TestResultTableSound), a
	ret


SoundResultScreen:
	ld	hl, TxtSoundTitle
	call	PrintScreenTitle
	;; Lo que ha contestado el usuario
	ld	hl, TxtObserved
	call	PrintHeader
	call	NewLine
	ld	b, 0
.line:
	push	bc
	ld	a, 2
	ld	(txt_x), a
	ld	a, b
	call	GetStepName
	call	PrintString
	ld	a, 34
	ld	(txt_x), a
	pop	bc
	push	bc
	ld	e, b
	ld	d, 0
	ld	hl, SoundAnswers
	add	hl, de
	ld	a, (hl)
	call	PrintAnswer
	call	NewLine
	pop	bc
	inc	b
	ld	a, b
	cp	SOUND_STEPS
	jr	nz, .line

	;; Resultado y qué hacer después
	call	NewLine
	ld	a, (TestResultTableSound)
	call	PrintResultLine
	call	NewLine
	ld	a, (txt_y)
	inc	a
	ld	l, a
	ld	h, 0
	call	LocateWrap
	ld	hl, TxtSoundAllOk
	ld	a, (TestResultTableSound)
	cp	TESTRESULT_PASSED
	jr	z, .advice
	ld	hl, TxtSoundUnsure
	cp	TESTRESULT_INCONCLUSIVE
	jr	z, .advice
	ld	hl, TxtSoundNothing
	ld	a, (SoundNoCount)
	cp	SOUND_STEPS
	jr	z, .advice
	call	SoundPattern
.advice:
	call	PrintWrapped
	ld	hl, TxtPressOKToReturn
	call	PrintHint
	jp	WaitOK

 ENDIF

 ENDMODULE
