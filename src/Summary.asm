;; Summary.asm — resumen final y ayuda (versión RAM)
;;
;; El resumen cabe en una sola pantalla en Mode 1, sin efectos, con buen
;; contraste: está pensado para hacerle una foto y pedir ayuda en un foro.
;; Separa lo comprobado (con su resultado) de lo que queda pendiente, e
;; incluye un código corto con todos los resultados.
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE SUMMARY

SUM_LABEL_X	EQU 1
SUM_VALUE_X	EQU 12

@SummarySelected:
	call	ReportBegin			; con una M4, también en /DOCTOR.TXT
	ld	hl, TxtSummaryTitle
	call	PrintScreenTitle

	;; ---- Equipo
	ld	hl, TxtSummaryMachine
	call	PrintHeader
	ld	hl, #0103
	call	LocateWrap
	;; Modelo, RAM, CRTC y chip de sonido en una línea
	ld	a, (ModelType)
	ld	e, a
	ld	d, 0
	ld	hl, ModelNameTableOffset
	add	hl, de
	ld	e, (hl)
	ld	hl, ModelNames
	add	hl, de
	call	PrintString
	ld	a, (ModelType)
	or	a
	jr	z, .modelQ
	ld	a, (ModelDoubt)
	or	a
	jr	z, .modelOk
	ld	a, ' '
	call	PrintChar
.modelQ:
	ld	a, '?'
	call	PrintChar
.modelOk:
	call	PrintModelSuffix
	call	Separator
	ld 	a, (ValidBankCount)
	ld 	l,a
	ld 	h,0
	add 	hl,hl
	add 	hl,hl
	add 	hl,hl
	add 	hl,hl
	add 	hl,hl
	add 	hl,hl
	ld	de, 64
	add	hl, de
	call 	PrintHLDec
	ld 	hl, TxtKB
	call 	PrintString
	call	Separator
	ld	hl, TxtCRTC
	call	PrintString
	ld	a, ' '
	call	PrintChar
	ld	a, (CRTCType)
	add	a, '0'
	call	PrintChar
	call	PrintCRTCMaker
	call	Separator
	ld	a, (PSGType)
	or	a
	ld	hl, TxtAY3
	jr	z, .psg
	ld	hl, TxtYM
.psg:
	call	PrintString
	call	WrapNewLine
	;; Marca, frecuencia y disquetera
	ld	a, (VendorName)
	ld	e, a
	ld	d, 0
	ld	hl, VendorTableOffset
	add	hl, de
	ld	e, (hl)
	ld	hl, VendorNames
	add	hl, de
	call	PrintString
	call	Separator
	ld	a, (RefreshFrequency)
	ld	e, a
	ld	d, 0
	ld	hl, RefreshTableOffset
	add	hl, de
	ld	e, (hl)
	ld	hl, RefreshNames
	add	hl, de
	call	PrintString
	call	Separator
	ld	hl, TxtZ80
	call	PrintString
	ld	a, ' '
	call	PrintChar
	call	PrintZ80Type
	call	Separator
	ld	hl, TxtFDC
	call	PrintString
	ld	a, ' '
	call	PrintChar
	ld	a, (FDCPresent)
	or	a
	ld	hl, TxtNone
	jr	z, .fdc
	ld	hl, TxtDetected
.fdc:
	call	PrintString
	call	PrintFDCVersion
	call	WrapNewLine
	;; Pantalla usada en la prueba de imagen
	ld	hl, TxtDisplayUsed
	call	PrintString
	ld	a, ' '
	call	PrintChar
	ld	a, (TestResultTableVideo)
	cp	TESTRESULT_UNTESTED
	ld	hl, TxtSummaryNotStated
	jr	z, .noDisplay
	call	PrintDisplayType
	jr	.display
.noDisplay:
	call	PrintString
.display:

	;; ---- Resultados
	ld	hl, #0007
	ld	(TxtCoords), hl
	ld	hl, TxtTestResults
	call	PrintHeader
	ld	hl, #0008
	ld	(SumRow), hl
	ld	b, SUMMARY_ITEMS
	ld	ix, SummaryItems
.item:
	push	bc
	;; Etiqueta
	ld	hl, (SumRow)
	ld	h, SUM_LABEL_X
	ld	(TxtCoords), hl
	inc	l
	ld	(SumRow), hl
	ld	l, (ix)
	ld	h, (ix+1)
	call	PrintString
	ld	a, SUM_VALUE_X - 2
	ld	(txt_x), a
	ld	a, ':'
	call	PrintChar
	ld	a, SUM_VALUE_X
	ld	(txt_x), a
	;; Resultado
	ld	l, (ix+2)
	ld	h, (ix+3)
	ld	a, (hl)
	push	af
	call	SetColorForResultType
	pop	af
	push	af
	call	GetResultText
	call	PrintString
	call	SetDefaultColors
	pop	af
	;; Detalle, si la prueba tiene uno y no ha salido bien
	cp	TESTRESULT_FAILED
	jr	z, .detail
	cp	TESTRESULT_INCONCLUSIVE
	jr	nz, .noDetail
.detail:
	ld	l, (ix+4)
	ld	h, (ix+5)
	ld	a, h
	or	l
	jr	z, .noDetail
	ld	a, ' '
	call	PrintChar
	ld	de, .noDetail
	push	de
	jp	(hl)
.noDetail:
	ld	de, 6
	add	ix, de
	pop	bc
	djnz	.item

	;; ---- Pendiente
	ld	hl, (SumRow)
	inc	l
	ld	h, 0
	call	LocateWrap
	ld	hl, TxtSummaryPending
	call	PrintHeader
	ld	a, ' '
	call	PrintChar
	ld	c, 0				; hay algo pendiente
	ld	b, SUMMARY_ITEMS
	ld	ix, SummaryItems
.pending:
	ld	l, (ix+2)
	ld	h, (ix+3)
	ld	a, (hl)
	cp	TESTRESULT_UNTESTED
	jr	z, .isPending
	cp	TESTRESULT_ABORTED
	jr	nz, .notPending
.isPending:
	push	bc
	ld	a, c
	or	a
	jr	z, .first
	ld	a, ','
	call	PrintChar
	ld	a, ' '
	call	PrintChar
.first:
	ld	l, (ix)
	ld	h, (ix+1)
	call	PrintWrapped
	pop	bc
	ld	c, 1
.notPending:
	ld	de, 6
	add	ix, de
	djnz	.pending
	ld	a, c
	or	a
	jr	nz, .code
	ld	hl, TxtSummaryNothingPending
	call	PrintString

	;; ---- Aviso del puerto del AY (medido al arrancar)
.code:
	ld	a, (AYPortReads)
	or	a
	jr	z, .noPortWarning
	ld	hl, #0015
	ld	(TxtCoords), hl
	call	SetErrorColors
	ld	hl, TxtSummaryPortSlow
	call	PrintString
	call	SetDefaultColors
.noPortWarning:
	;; ---- Código de resultados
	ld	hl, #0016
	ld	(TxtCoords), hl
	ld	hl, TxtSummaryCode
	call	PrintString
	ld	a, ' '
	call	PrintChar
	call	PrintResultCode

	ld	hl, #0017
	call	LocateWrap
	ld	hl, TxtSummaryPhoto
	call	PrintWrapped
	;; Con M4, escribir el informe tarda unos segundos (y el teclado no se
	;; atiende): se avisa en la línea de ayuda, sin que vaya al informe
	ld	a, (ReportOn)
	or	a
	jr	z, .noReport
	xor	a
	ld	(ReportOn), a
	ld	hl, TxtSummaryBusy
	call	PrintHint
	ld	a, 1
	ld	(ReportOn), a
	call	ReportEnd
.noReport:
	ld	hl, TxtSummaryHint		; en la línea de ayuda, aparte
	call	PrintHint
	call	WaitOK
	call	nz, ShowMachineDetails		; ENTER: la segunda página
	jp	MainMenuRepeat


;; " · " entre datos de la misma línea
Separator:
	ld	hl, TxtSeparator
	jp	PrintString
TxtSeparator: db ', ', 0


;; Código: versión, modelo, bancos de RAM alta y un dígito por prueba
;; en el orden de SummaryItems (0 sin probar, 1 superado, 2 error,
;; 3 cancelado, 4 no disponible, 5 inconcluso).
;; Ejemplo: 10A-3-01-11101150
PrintResultCode:
	ld	a, VERSION_CODE_1
	call	PrintChar
	ld	a, VERSION_CODE_2
	call	PrintChar
	ld	a, BUILD_STR
	call	PrintChar
	ld	a, '-'
	call	PrintChar
	ld	a, (ModelType)
	add	a, '0'
	call	PrintChar
	ld	a, '-'
	call	PrintChar
	ld	a, (ValidBankCount)
	call	PrintAHex
	ld	a, '-'
	call	PrintChar
	ld	b, SUMMARY_ITEMS
	ld	ix, SummaryItems
.loop:
	ld	l, (ix+2)
	ld	h, (ix+3)
	ld	a, (hl)
	add	a, '0'
	call	PrintChar
	ld	de, 6
	add	ix, de
	djnz	.loop
	ret


;; Etiqueta, resultado, rutina que imprime el detalle (0 = ninguna)
SummaryItems:
	dw TxtResultKeyboard, TestResultTableKeyboard, DetailKeyboard
	dw TxtResultJoystick, TestResultTableJoystick, 0
	dw TxtResultVideo, TestResultTableVideo, DetailVideo
	dw TxtResultSound, TestResultTableSound, DetailSound
	dw TxtResultTape, TestResultTableTape, DetailTape
	dw TxtResultDisk, TestResultTableDisk, DetailDisk
	dw TxtResultLowerRAM, TestResultTableLowerRAM, 0
	dw TxtResultUpperRAM, TestResultTableUpperRAM, DetailUpperRAM
	dw TxtResultLowerROM, TestResultTableLowerROM, 0
	dw TxtResultUpperROM, TestResultTableUpperROM, 0
SUMMARY_ITEMS EQU ($ - SummaryItems) / 6


;; (n/73 teclas)
DetailKeyboard:
	ld	a, '('
	call	PrintChar
	ld	a, (KbPressedCount)
	call	PrintANoPad
	ld	a, '/'
	call	PrintChar
	ld	a, KEYBOARD_KEY_COUNT
	call	PrintANoPad
	ld	hl, TxtSummaryKeys
	call	PrintString
	;; Líneas y columnas que no responden, y líneas o columnas unidas. El
	;; bucle del resumen usa IX y BC: se conservan
	push	ix
	push	bc
	call	DetailKbMatrix
	pop	bc
	pop	ix
	ld	a, ')'
	jp	PrintChar

DetailKbMatrix:
	ld	hl, (KbDeadLines)
	ld	de, TxtSummaryKbLine
	ld	bc, TxtSummaryKbLines
	ld	a, 9
	call	DetailKbList
	ld	a, (KbDeadCols)
	ld	l, a
	ld	h, 0
	ld	de, TxtSummaryKbCol
	ld	bc, TxtSummaryKbCols
	ld	a, 8
	call	DetailKbList
	call	KBGUIDE.KbCountJoined		; A = parejas, C = tipo de la primera
	or	a
	jr	z, .close
	ld	a, ','
	call	PrintChar
	ld	hl, TxtSummaryKbJoinedLines
	ld	a, c
	cp	1				; PAIR_LINES
	jr	z, .joined
	ld	hl, TxtSummaryKbJoinedCols
.joined:
	jp	PrintString
.close:
	ret

;; ", línea 3" o ", líneas 3 5" con los bits a 1 de HL
;; IN: HL = bits, A = cuántos, DE = singular, BC = plural
DetailKbList:
	push	af
	ld	a, h
	or	l
	jr	nz, .some
	pop	af
	ret
.some:
	push	bc
	push	de
	;; ¿Uno solo? (HL & (HL-1) = 0)
	ld	d, h
	ld	e, l
	dec	de
	ld	a, d
	and	h
	ld	d, a
	ld	a, e
	and	l
	or	d
	pop	de
	pop	bc
	push	hl
	ld	h, d
	ld	l, e
	jr	z, .one
	ld	h, b
	ld	l, c
.one:
	ld	a, ','
	call	PrintChar
	call	PrintString
	pop	hl
	pop	af
	ld	b, a
	ld	c, '0'
.bit:
	srl	h
	rr	l
	jr	nc, .next
	ld	a, ' '
	call	PrintChar
	ld	a, c
	call	PrintChar
.next:
	inc	c
	djnz	.bit
	ret

;; Primer paso de la prueba de imagen que no se vio bien
DetailVideo:
	ld	hl, VideoAnswers
	ld	b, 8
	ld	de, VIDEOTEST.StepNames
	jr	DetailFirstBad

;; Primer sonido que no se oyó bien
DetailSound:
	ld	hl, SoundAnswers
	ld	b, 5
	ld	de, SOUNDTEST.StepNames
	;; sigue

;; IN: HL = respuestas, B = número, DE = tabla de nombres
DetailFirstBad:
	ld	a, (hl)
	cp	ANSWER_NO
	jr	z, .found
	cp	ANSWER_UNSURE
	jr	z, .found
	inc	hl
	inc	de
	inc	de
	djnz	DetailFirstBad
	ret
.found:
	ld	a, '('
	call	PrintChar
	ex	de, hl
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	call	PrintString
	ld	a, ')'
	jp	PrintChar

;; Velocidad medida del cassette
DetailTape:
	ld	a, (TapeMeasured)
	or	a
	ret	z
	ld	a, '('
	call	PrintChar
	call	TAPETEST.PrintSpeed
	ld	a, ')'
	jp	PrintChar

;; Velocidad medida de la disquetera
DetailDisk:
	ld	a, (DiskMeasured)
	or	a
	ret	z
	ld	a, '('
	call	PrintChar
	call	DISKTEST.PrintRPM
	ld	a, ')'
	jp	PrintChar

;; Bits erróneos de la RAM alta
DetailUpperRAM:
	ld	hl, TxtSummaryBits
	call	PrintString
	ld	a, (FailingBits)
	ld	d, a
	jp	UPPERRAMTEST.PrintFailingBits


;; ---------------------------------------------------------------------------
;; Ayuda
;; ---------------------------------------------------------------------------
@HelpSelected:
	ld	hl, TxtMenuHelp
	ld	de, TxtHelp1
	call	ExplainScreen
	jp	z, MainMenuRepeat
	ld	hl, TxtMenuHelp
	ld	de, TxtHelp2
	call	ExplainScreen
	jp	MainMenuRepeat

 ENDMODULE
