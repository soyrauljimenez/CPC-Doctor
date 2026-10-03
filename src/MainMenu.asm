;; Menú principal de CPC Doctor
;;
;; Izquierda: ficha del equipo y resultados. Derecha: pruebas, que se
;; eligen por número, con los cursores o con el joystick.

MainMenu:
	;; La RAM baja se acaba de comprobar (y borrar): hay que volver a
	;; detectar el equipo antes de nada, también en la prueba continua
	;; (issue #17).
	call	DetectSystemInfo

	call 	IsSoakTestRunning
	jp 	z, SoakTestSelected
	ld	a, (ValidBankCount)
	or	a
	jr	nz, .upperRAMPresent
	ld	a, TESTRESULT_NOTAVAILABLE
	ld	(TestResultTableUpperRAM), a
.upperRAMPresent:
 IFDEF GUIDED
	call	ConfirmModel			; puede cambiar el resultado de la RAM alta
 ENDIF

MainMenuRepeat:
 IFDEF GUIDED
	ld	a, (AutoStep)
	or	a
	jp	nz, AutoNext
 ENDIF
	call 	SetUpScreen
	ld	ix, MenuTexts
	ld	h, MENU_X
	ld	l, MENU_Y
	ld	a, (SelectedMenuItem)
	call	Choose
 IFDEF GUIDED
	cp	#FE
	jp	z, AutoNext			; 30 s sin tocar nada
 ENDIF
	cp	#FF
 IFDEF GUIDED
	jp	z, ExitToBASIC			; ESC: salir al BASIC
 ELSE
	jr	z, MainMenuRepeat
 ENDIF
	ld	(SelectedMenuItem), a
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, MenuFunctions
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	jp	(hl)


;; ---------------------------------------------------------------------------
;; Opciones del menú. Las pruebas guiadas solo están en la versión cargada
;; desde cinta o disco: no caben en una ROM de 16 KB.
;; ---------------------------------------------------------------------------
MenuTexts:
	dw TxtMenuKeyboard
 IFDEF GUIDED
	dw TxtMenuVideo
 ENDIF
	dw TxtMenuSound
 IFDEF GUIDED
	dw TxtMenuTape
	dw TxtMenuDisk
 ENDIF
	dw TxtMenuLowerRAM
	dw TxtMenuUpperRAM
 IFDEF ROM_CHECK
	dw TxtMenuROM
 ENDIF
	dw TxtMenuSoak
 IFDEF GUIDED
	dw TxtMenuSummary
	dw TxtMenuHelp
 ENDIF
	dw 0

MenuFunctions:
	dw KeyboardTestSelected
 IFDEF GUIDED
	dw VideoTestSelected
 ENDIF
	dw SoundTestSelected
 IFDEF GUIDED
	dw TapeTestSelected
	dw DiskTestSelected
 ENDIF
	dw LowerRAMTestSelected
	dw UpperRAMTestSelected
 IFDEF ROM_CHECK
	dw ROMTestSelected
 ENDIF
	dw SoakTestSelected
 IFDEF GUIDED
	dw SummarySelected
	dw HelpSelected
 ENDIF


LowerRAMTestSelected:
 IFDEF GUIDED
	call	GuidedLowerRAMTest
	jp	MainMenuRepeat
 ENDIF
 IFDEF UpperROMBuild
	ld	d, 0
 	call 	ClearScreen
 	ld	a, (UpperROMConfig)
	ld 	iyh, a			;; Save the ROM we came from in I
 ENDIF
	jp TestStart

UpperRAMTestSelected:
	call CheckUpperRAM
	jp TestComplete

ROMTestSelected:
 IFDEF ROM_CHECK
	call CheckROMs
	jp TestComplete
 ELSE
	jp MainMenuRepeat
 ENDIF

KeyboardTestSelected:
	call TestKeyboard
	jp MainMenuRepeat

SoundTestSelected:
	call SoundTest
 IFDEF GUIDED
	jp MainMenuRepeat
 ELSE
	jp TestComplete
 ENDIF

 IFDEF GUIDED
;; ---------------------------------------------------------------------------
;; Modo automático: si al arrancar no se toca nada en 30 s (puede que el
;; teclado no funcione), se hacen una tras otra las pruebas que no necesitan
;; respuestas y se termina en el resumen. Cada prueba vuelve a
;; MainMenuRepeat, que salta aquí mientras AutoStep no sea 0.
;; ---------------------------------------------------------------------------
AutoNext:
	ld	a, (AutoStep)
	cp	1
	jr	nz, .step
	;; Primer paso: explicar qué va a pasar
	inc	a
	ld	(AutoStep), a
	ld	hl, TxtAutoTitle
	ld	de, TxtAutoIntro
	call	ExplainScreen
	jr	nz, AutoNext
	xor	a				; ESC: al menú
	ld	(AutoStep), a
	jp	MainMenuRepeat
.step:
	sub	2
	ld	e, a
	ld	d, 0
	ld	hl, AutoSequence
	add	hl, de
	ld	a, (hl)
	inc	a
	jr	nz, .run
	;; Fin: el resumen, ya esperando a una pulsación de verdad
	xor	a
	ld	(AutoStep), a
	ld	a, AUTO_SUMMARY
	ld	(SelectedMenuItem), a
	jp	SummarySelected
.run:
	dec	a
	ld	(SelectedMenuItem), a
	ld	hl, AutoStep
	inc	(hl)
	add	a, a
	ld	e, a
	ld	hl, MenuFunctions
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	jp	(hl)

;; Opciones del menú (empezando en 0) que no necesitan respuestas
AUTO_SUMMARY	EQU 9
AutoSequence:
	db 0				; teclado y joystick (termina a los 10 s)
	db 4				; disquetera
	db 5				; RAM baja
	db 6				; RAM alta
	db 7				; ROMs
	db #FF
 ENDIF

;; Espera una tecla y vuelve al menú
TestComplete:
	ld	h, 0
	ld	l, 24
	ld	(TxtCoords), hl
	call	SetDefaultColors
	ld	hl, TxtPressAnyKey
 IFDEF GUIDED
	ld	a, (AutoStep)
	or	a
	jr	z, .manual
	ld	hl, TxtAutoNextHint
	call	PrintString
	ld	b, AUTO_WAIT_FRAMES
	call	WaitFrames
	jp	MainMenuRepeat
.manual:
 ENDIF
	call	PrintString
	call	WaitNoKeys
.loop:
	call WaitForVsync
	call ReadFullKeyboard
	call UpdateKeyBuffers
	call IsAnyKeyPressed
	jr z,.loop
	jp MainMenuRepeat


;; ---------------------------------------------------------------------------
;; Pantalla principal
;; ---------------------------------------------------------------------------
INFO_X		EQU 1			; etiquetas
INFO_COLON_X	EQU INFO_X + 10
INFO_VALUE_X	EQU INFO_COLON_X + 2
INFO_Y		EQU 2			; cabecera "SISTEMA"
MENU_HEADER_X	EQU 30
MENU_X		EQU MENU_HEADER_X
MENU_Y		EQU INFO_Y + 1
HINT_Y		EQU 23

SetUpScreen:
	call	BuildMenuTitle
	call	PrintScreenTitle

	;; Cabeceras
	ld	h, 0
	ld	l, INFO_Y
	ld	(TxtCoords), hl
	ld	hl, TxtSystemInfo
	call	PrintHeader
	ld	h, MENU_HEADER_X
	ld	l, INFO_Y
	ld	(TxtCoords), hl
	ld	hl, TxtSelectTest
	call	PrintHeader

	;; Ficha del equipo
	ld	l, INFO_Y + 1
	ld	(InfoRow), hl

	ld	hl, TxtModel
	call	PrintInfoLabel
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
	jr	z, .modelUnknown
	ld	a, (ModelDoubt)
	or	a
	jr	z, .modelKnown
	ld	a, ' '
	call	PrintChar
.modelUnknown:
	ld	hl, TxtUnknownModel
	call	PrintString
.modelKnown:

	ld	hl, TxtVendor
	call	PrintInfoLabel
	ld	a, (VendorName)
	ld	e, a
	ld	d, 0
	ld	hl, VendorTableOffset
	add	hl, de
	ld	e, (hl)
	ld	hl, VendorNames
	add	hl, de
	call	PrintString

	ld	hl, TxtRefresh
	call	PrintInfoLabel
	ld	a, (RefreshFrequency)
	ld	e, a
	ld	d, 0
	ld	hl, RefreshTableOffset
	add	hl, de
	ld	e, (hl)
	ld	hl, RefreshNames
	add	hl, de
	call	PrintString

	ld	hl, TxtRAM
	call	PrintInfoLabel
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

	ld	hl, TxtCRTC
	call	PrintInfoLabel
	ld	a, (CRTCType)
	add	a, '0'
	call	PrintChar

	ld	hl, TxtFDC
	call	PrintInfoLabel
	ld	a, (FDCPresent)
	or	a
	ld	hl, TxtNone
	jr	z, .FDCskip
	ld	hl, TxtDetected
.FDCskip:
	call	PrintString

	ld	hl, TxtPSG
	call	PrintInfoLabel
	ld	a, (PSGType)
	or	a
	ld	hl, TxtAY3
	jr	z, .psg
	ld	hl, TxtYM
.psg:
	call	PrintString
 IFDEF GUIDED
	ld	hl, TxtZ80
	call	PrintInfoLabel
	call	PrintZ80Type
 ENDIF

	;; Resultados
	ld	hl, (InfoRow)
	inc	l
	ld	h, 0
	ld	(TxtCoords), hl
	inc	l
	ld	(InfoRow), hl
	ld	hl, TxtTestResults
	call	PrintHeader

	ld	b, ResultLabelTableCount
	ld	ix, ResultLabelTable
	ld	iy, TestResultTable
	ld	c, 0
.resultLoop:
	push	bc
	ld	l, (ix)
	ld	h, (ix+1)
	call	PrintInfoLabel
	ld	a, (iy)
	call	SetColorForResultType
	ld	a, (iy)
	call	GetResultText
	call	PrintString
	call	SetDefaultColors
	pop	bc

	ld	a, c
	cp	KEYBOARD_TEST_INDEX
	jr	nz, .notKeyboard
	ld	a, (iy)
	cp	TESTRESULT_FAILED
	jr	nz, .nextResult
	call	CountPressedKeys
	ld	d, KEYBOARD_KEY_COUNT
	call	PrintPressedKeys
	jr	.nextResult
.notKeyboard:
	cp	JOYSTICK_TEST_INDEX
	jr	nz, .nextResult
	ld	a, (iy)
	cp	TESTRESULT_FAILED
	jr	nz, .nextResult
	call	CountPressedJoystickButtons
	ld	d, JOYSTICK_KEY_COUNT
	call	PrintPressedKeys

.nextResult:
	inc	iy
	inc	ix
	inc	ix
	inc	c
	djnz	.resultLoop

	;; Ayuda de manejo
	ld	h, 0
	ld	l, HINT_Y
	ld	(TxtCoords), hl
	ld	hl, TxtMenuHint
	call	PrintString
 IFDEF GUIDED
	ld	hl, TxtMenuHintExit
	call	PrintString
 ENDIF
 IFDEF UpperROMBuild
	ld	a, ' '
	call	PrintChar
	call	PrintChar
	ld	hl, TxtROM
	call	PrintString
	ld	a, (UpperROMConfig)
	call	PrintAHex
 ENDIF
 IFDEF GUIDED
	ld	hl, #0000 + HINT_Y + 1
	call	LocateWrap
	ld	hl, TxtMenuHint2
	call	PrintString
 ENDIF
	ret


;; Barra de título del menú: "CPC Doctor V0.9A - CPC 464 - Taller AUA"
;; (el "Taller AUA" lo añade PrintScreenTitle)
;; OUT: HL = texto (en TitleBuffer)
BuildMenuTitle:
	ld	de, TitleBuffer
	ld	a, (ModelType)
	ld	c, a
	ld	b, 0
	ld	hl, ModelNameTableOffset
	add	hl, bc
	ld	c, (hl)
	ld	hl, ModelNames
	add	hl, bc
	call	.copy
	ld	a, (ModelType)
	or	a
	jr	z, .question			; modelo desconocido: "CPC ?"
	ld	a, (ModelDoubt)
	or	a
	jr	z, .end
	ld	a, ' '
	ld	(de), a
	inc	de
.question:
	ld	a, '?'
	ld	(de), a
	inc	de
.end:
	xor	a
	ld	(de), a
	ld	hl, TitleBuffer
	ret
.copy:
	ld	a, (hl)
	or	a
	ret	z
	ld	(de), a
	inc	hl
	inc	de
	jr	.copy


;; Imprime "Etiqueta  : " en la siguiente fila de InfoRow
;; IN: HL = etiqueta
PrintInfoLabel:
	push	hl
	ld	hl, (InfoRow)
	ld	h, INFO_X
	ld	(TxtCoords), hl
	inc	l
	ld	(InfoRow), hl
	pop	hl
	call	SetDefaultColors
	call	PrintString
	ld	a, INFO_COLON_X
	ld	(txt_x), a
	ld	a, ':'
	call	PrintChar
	ld	a, INFO_VALUE_X
	ld	(txt_x), a
	ret


;; IN:	A - count
;;	D - total
PrintPressedKeys:
	push	bc
	push	de
	push	af
	ld	hl, txt_x
	inc	(hl)
	ld	a, '('
	call	PrintChar
	pop	af
	call	PrintANoPad
	ld	a, '/'
	call	PrintChar
	pop	de
	ld	a, d
	call	PrintANoPad
	ld	a, ')'
	call	PrintChar
	pop	bc
	ret


;; IN: A = resultado  OUT: HL = texto
@GetResultText:
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, ResultTextTable
	add	hl, de
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	ex	de, hl
	ret


;; IN:	A - result type
;; OUT: Color set
@SetColorForResultType:
	cp	TESTRESULT_PASSED
	jp	z, SetSuccessColors
	cp	TESTRESULT_FAILED
	jp	z, SetErrorColors
	cp	TESTRESULT_INCONCLUSIVE
	jp	z, SetWarningColors
	jp	SetDefaultColors


ResultLabelTable:
	dw TxtResultLowerRAM
	dw TxtResultUpperRAM
	dw TxtResultLowerROM
	dw TxtResultUpperROM
	dw TxtResultKeyboard
	dw TxtResultJoystick
 IFDEF GUIDED
	dw TxtResultVideo
	dw TxtResultSound
	dw TxtResultTape
	dw TxtResultDisk
 ENDIF
ResultLabelTableCount EQU ($-ResultLabelTable)/2

KEYBOARD_TEST_INDEX EQU 4
JOYSTICK_TEST_INDEX EQU 5

ResultTextTable:
	dw TxtUntested
	dw TxtPassed
	dw TxtFailed
	dw TxtAborted
	dw TxtNotAvailable
	dw TxtInconclusive


TxtTitle: db 'CPC Doctor V', VERSION_STR, BUILD_STR, 0
TxtTitleLen EQU $-TxtTitle-1
TxtROM: db 'ROM ',0
TxtAY3: db 'AY-3-8912',0
TxtYM: db 'YM2149',0
