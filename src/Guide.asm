;; Guide.asm — piezas comunes de las pruebas guiadas (solo versión RAM)
;;
;; Cada prueba guiada sigue el mismo esquema:
;;   1. Qué vamos a comprobar y qué tiene que hacer o mirar el usuario.
;;   2. La prueba.
;;   3. Lo observado (medido o contestado por el usuario, y se dice cuál).
;;   4. El resultado: superado, error, inconcluso o sin probar.
;;   5. Qué comprobar después. Las posibles causas se presentan como
;;      posibilidades a confirmar, nunca como diagnóstico seguro.
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE GUIDE

HINT_ROW EQU 24

;; Respuestas a las preguntas al usuario (índices de Choose)
@ANSWER_YES	EQU 0
@ANSWER_NO	EQU 1
@ANSWER_UNSURE	EQU 2

@Answers:
	dw TxtAnswerYes, TxtAnswerNo, TxtAnswerUnsure, 0
@AnswersWithRepeat:
	dw TxtAnswerYes, TxtAnswerNo, TxtAnswerUnsure, TxtAnswerRepeat, 0


;; Texto de ayuda en la última línea de la pantalla
;; IN: HL = texto
@PrintHint:
	push	hl
	ld	h, 0
	ld	l, HINT_ROW
	ld	(TxtCoords), hl
	ld	b, ScreenCharsWidth - 1
.clear:
	ld	a, ' '
	call	PrintChar
	djnz	.clear
	ld	h, 0
	ld	l, HINT_ROW
	ld	(TxtCoords), hl
	pop	hl
	call	SetDefaultColors
	jp	PrintString


;; IN: A = respuesta (0 sí, 1 no, 2 no lo sé, #FF sin responder)
@PrintAnswer:
	cp	ANSWER_NO
	jr	z, .no
	cp	ANSWER_UNSURE
	jr	z, .unsure
	cp	ANSWER_YES
	jr	z, .yes
	ld	hl, TxtNotAnswered
	jp	PrintString
.yes:
	ld	hl, TxtAnswerYes
	jp	PrintString
.no:
	call	SetErrorColors
	ld	hl, TxtAnswerNo
	call	PrintString
	jp	SetDefaultColors
.unsure:
	call	SetWarningColors
	ld	hl, TxtAnswerUnsure
	call	PrintString
	jp	SetDefaultColors


;; "Resultado: Superado" con el color del resultado
;; IN: A = resultado (TESTRESULT_...)
@PrintResultLine:
	push	af
	ld	hl, TxtResult
	call	PrintString
	ld	a, ' '
	call	PrintChar
	pop	af
	push	af
	call	SetColorForResultType
	pop	af
	call	GetResultText
	call	PrintString
	jp	SetDefaultColors


;; Pregunta al usuario con las respuestas Sí / No / No lo sé
;; IN: HL = pregunta, E = fila
;; OUT: A = respuesta (ANSWER_...) o #FF si ESC
@AskYesNo:
	push	de
	ld	d, 0
	ld	(TxtCoords), de
	call	SetDefaultColors
	call	PrintString
	pop	de
	inc	e
	ld	l, e
	ld	h, 2
	ld	ix, Answers
	xor	a
	jp	Choose


;; Muestra una pantalla de explicación y espera ENTER / FUEGO
;; IN: HL = título, DE = texto
;; OUT: Z si el usuario pulsó ESC
@ExplainScreen:
	push	de
	call	PrintScreenTitle
	ld	hl, #0002
	call	LocateWrap
	pop	hl
	call	PrintWrapped
	ld	hl, TxtPressOKToStart
	call	PrintHint
	jp	WaitOK

 ENDMODULE

;; ---------------------------------------------------------------------------
;; ConfirmModel: si la ROM es de 6128 pero no hay RAM alta, pregunta qué
;; modelo es. Si el usuario dice 6128, falta la RAM alta: es una avería.
;; ---------------------------------------------------------------------------
@ConfirmModel:
	ld	a, (ModelDoubt)
	or	a
	ret	z
	ld	a, (ModelConfirmed)
	or	a
	ret	nz
	ld	hl, TxtModelTitle
	call	PrintScreenTitle
	ld	hl, #0002
	call	LocateWrap
	ld	hl, TxtModelDoubt
	call	PrintWrapped
	ld	ix, ModelChoices
	ld	hl, #0213
	xor	a
	call	Choose
	cp	3
	ret	nc				; no lo sé / ESC: sigue dudoso
	ld	e, a
	ld	d, 0
	ld	hl, ModelCodes
	add	hl, de
	ld	a, (hl)
	ld	(ModelConfirmed), a
	cp	MODEL_CPC6128
	jr	nz, .redetect
	;; Un 6128 sin sus 64 KB de RAM alta
	ld	a, TESTRESULT_FAILED
	ld	(TestResultTableUpperRAM), a
	ld	hl, TxtModelTitle
	ld	de, TxtModel6128NoUpper
	call	ExplainScreen
.redetect:
	jp	DetectSystemInfo		; aplica el modelo y la distribución del teclado

ModelChoices:
	dw TxtModel464, TxtModel664, TxtModel6128, TxtAnswerUnsure, 0
ModelCodes:
	db MODEL_CPC464, MODEL_CPC664, MODEL_CPC6128

;; ---------------------------------------------------------------------------
;; ExitToBASIC: pide confirmación y reinicia el ordenador. Con la ROM baja
;; y la ROM alta 0 conectadas, saltar a #0000 es un arranque en frío: el
;; firmware lo inicializa todo, igual que al encenderlo.
;; ---------------------------------------------------------------------------
@ExitToBASIC:
	ld	hl, TxtExitTitle
	call	PrintScreenTitle
	ld	hl, #0002
	call	LocateWrap
	ld	hl, TxtExitQuestion
	call	PrintWrapped
	ld	ix, ExitChoices
	ld	hl, #020A
	ld	a, 1				; por defecto, "No"
	call	Choose
	or	a
	jp	nz, MainMenuRepeat		; No o ESC
	call	Silence
	jp	ColdBootToBASIC			; está en el bloque de #A000 (ROMAccess.asm)

ExitChoices:
	dw TxtAnswerYes, TxtAnswerNo, 0
