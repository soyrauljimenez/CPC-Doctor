;; MachineInfo.asm — página "Detalles del equipo" (versión RAM)
;;
;; Segunda página del resumen: de dónde sale el modelo, la ROM del sistema
;; y la que pone la M4 encima, las ROMs de expansión y lo que se puede
;; deducir de la placa. También va al informe de la M4 (M4Report.asm).
;;
;; Deducciones sobre la placa (ver docs/VALIDACION.md y las fuentes en el
;; CHANGELOG de la 0.9.4): solo las que se pueden afirmar.
;; - CRTC 4: Gate Array 40226, placa abaratada Z80329 (1988 o posterior),
;;   siempre con teclas bajas.
;; - ROM del sistema española del 464 (3E84): se puso desde septiembre de
;;   1985, cuando ya no se fabricaban los de teclas altas.
;; - ROM del 664 sin disquetera ni RAM alta: el CPC 472 español la llevaba.
;; - En un 464 con placa original no se puede medir si es de teclas altas
;;   o bajas, ni si la placa es larga o corta: se dice cómo mirarlo.
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE MACHINEINFO

CRC_OS464SP	EQU #3E84
CRC_OS664	EQU #FD6F
CRC_OS6128SP	EQU #BAF7
CRC_OS6128SP2	EQU #B3A1
CRC_OS6128DK	EQU #6895

;; Al arrancar: la firma de la ROM del sistema y, si la M4 pone otra
;; encima, la de esa (SysROMCRC y M4ROMCRC, como la prueba de ROMs)
@IdentifyLowerROM:
	call	CRCLowerRom
	ld	(SysROMCRC), hl
	ld	hl, 0
	ld	(M4ROMCRC), hl
	ld	a, (M4Slot)
	inc	a
	ret	z
	call	CRCLowerRomActive
	ld	bc, RESTORE_ROM_CONFIG
	out	(c), c
	ld	de, (SysROMCRC)
	or	a
	sbc	hl, de
	ret	z
	add	hl, de
	ld	(M4ROMCRC), hl
	ret

;; Detrás del modelo, la versión según la ROM del sistema: " (1988+)" con
;; la placa abaratada (CRTC 4); si no, el idioma de la ROM, que es el del
;; teclado con que se vendió: " (Ñ)" la española, " (FR)" la francesa
;; (AZERTY), " (DK)" la danesa y " (EN)" la inglesa.
@PrintModelSuffix:
	ld	a, (CRTCType)
	cp	4
	ld	hl, TxtModel1988
	jp	z, PrintString
	ld	a, (ModelType)			; sin modelo claro, nada
	or	a
	ret	z
	ld	a, (ModelDoubt)
	or	a
	ret	nz
	ld	hl, (SysROMCRC)
	ld	de, CRC_OS6128DK
	or	a
	sbc	hl, de
	ld	hl, TxtModelDanish
	jp	z, PrintString
	ld	a, (KeyboardLanguage)
	ld	hl, TxtModelSpanish
	cp	KEYBOARD_LANGUAGE_SPANISH
	jp	z, PrintString
	ld	hl, TxtModelFrench
	cp	KEYBOARD_LANGUAGE_FRENCH
	jp	z, PrintString
	ld	hl, TxtModelEnglish
	jp	PrintString

;; Tipo de CRTC y quién lo fabrica: 0 Hitachi HD6845S o UMC UM6845, 1 UMC
;; UM6845R, 2 Motorola MC6845; 3 y 4 van dentro del ASIC 40489 (Plus) y del
;; Gate Array 40226 (abaratados). Fuente: CPCWiki (CRTC) y el Compendium
;; de Longshot.
@PrintCRTCMaker:
	ld	a, (CRTCType)
	cp	5
	ret	nc
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, CRTCMakers
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	jp	PrintString

CRTCMakers:
	dw TxtCRTC0Maker, TxtCRTC1Maker, TxtCRTC2Maker, TxtGA40489Long, TxtGA40226Long

;; El nombre de la ROM del sistema en 16 columnas como mucho, o "? XXXX"
@PrintSystemROMShort:
	ld	hl, (SysROMCRC)
	push	hl
	call	ROMTEST.GetROMAddrFromCRC
	pop	hl
	or	a
	jr	z, .unknown
	ld	ix, de
	ld	l, (ix+2)
	ld	h, (ix+3)
	ld	b, 16
.char:
	ld	a, (hl)
	or	a
	ret	z
	call	PrintChar
	inc	hl
	djnz	.char
	ret
.unknown:
	push	hl
	ld	a, '?'
	call	PrintChar
	ld	a, ' '
	call	PrintChar
	pop	hl
	push	hl
	ld	a, h
	call	PrintAHex
	pop	hl
	ld	a, l
	jp	PrintAHex

;; Pantalla completa
@ShowMachineDetails:
	ld	hl, TxtDetailsTitle
	call	PrintScreenTitle
	call	PrintMachineDetails
	ld	hl, TxtPressOKToReturn
	call	PrintHint
	jp	WaitOK

;; El contenido, desde la fila 2 (también sin pintar, para el informe)
@PrintMachineDetails:
	;; ---- Modelo y de dónde sale
	ld	hl, TxtDetailsModel
	call	PrintHeader
	call	NewLine
	ld	a, 1
	ld	(txt_x), a
	ld	a, (ModelType)
	ld	e, a
	ld	d, 0
	ld	hl, ModelNameTableOffset
	add	hl, de
	ld	e, (hl)
	ld	hl, ModelNames
	add	hl, de
	call	PrintString
	call	PrintModelSuffix
	ld	a, ' '
	call	PrintChar
	ld	hl, TxtModelByUser
	ld	a, (ModelConfirmed)
	or	a
	jr	nz, .source
	ld	hl, TxtModelUnsure
	ld	a, (ModelDoubt)
	or	a
	jr	nz, .source
	ld	hl, TxtModelByROM
.source:
	call	PrintString
	call	NewLine
	call	NewLine

	;; ---- ROMs: la del sistema (y la de la M4) y las de expansión
	ld	hl, TxtDetailsROMs
	call	PrintHeader
	call	NewLine
	ld	a, (TestResultTableLowerROM)	; esto no es la prueba de ROMs
	push	af
	call	ROMTEST.CheckLowerROM
	pop	af
	ld	(TestResultTableLowerROM), a
	call	PrintUpperROMNames
	call	NewLine
	call	NewLine

	;; ---- Placa
	call	GetBoardHint
	ld	a, h
	or	l
	ret	z
	push	hl
	ld	hl, TxtDetailsBoard
	call	PrintHeader
	ld	a, (txt_y)
	inc	a
	ld	l, a
	ld	h, 1
	call	LocateWrap
	pop	hl
	jp	PrintWrapped

;; OUT: HL = texto sobre la placa, o 0 si no hay nada que decir
GetBoardHint:
	ld	a, (CRTCType)
	cp	4
	ld	hl, TxtHintCostDown
	ret	z
	cp	3				; un Plus: ya está todo dicho
	ld	hl, 0
	ret	z
	ld	hl, (SysROMCRC)
	ld	de, CRC_OS464SP
	or	a
	sbc	hl, de
	ld	hl, TxtHintSpain
	ret	z
	ld	hl, (SysROMCRC)
	ld	de, CRC_OS664
	or	a
	sbc	hl, de
	jr	nz, .not472
	ld	a, (FDCPresent)
	ld	hl, ValidBankCount
	or	(hl)
	ld	hl, TxtHint472
	ret	z
.not472:
	ld	a, (ModelType)
	cp	MODEL_CPC464
	ld	hl, TxtHint464
	ret	z
	ld	hl, 0
	ret

;; " nn NOMBRE" de cada ROM alta (las ranuras vacías repiten la 0, BASIC)
PrintUpperROMNames:
	xor	a
	ld	de, BasicName
	call	GetROMString
	ld	b, 0
.slot:
	push	bc
	ld	a, b
	ld	de, ROMStringBuffer
	call	GetROMString
	pop	bc
	push	bc
	ld	a, b
	or	a
	jr	z, .print
	call	SameAsBasic
	jr	z, .next
.print:
	ld	a, (txt_x)			; si no cabe, a la línea siguiente
	cp	34
	jr	c, .fits
	call	NewLine
.fits:
	ld	a, (txt_x)
	or	a
	jr	nz, .sep
	inc	a				; sangría de una columna
	ld	(txt_x), a
	jr	.num
.sep:
	ld	a, ' '
	call	PrintChar
	ld	a, ' '
	call	PrintChar
.num:
	pop	bc
	push	bc
	ld	a, b
	call	PrintAHex
	ld	a, ' '
	call	PrintChar
	ld	hl, ROMStringBuffer
	call	PrintString7BitEnding
.next:
	pop	bc
	inc	b
	ld	a, b
	cp	32
	jr	nz, .slot
	ret

;; OUT: Z si ROMStringBuffer es igual que BasicName
SameAsBasic:
	ld	hl, ROMStringBuffer
	ld	de, BasicName
.cmp:
	ld	a, (de)
	cp	(hl)
	ret	nz
	inc	hl
	inc	de
	bit	7, a				; el último carácter lleva el bit 7
	jr	z, .cmp
	xor	a				; Z: iguales
	ret

 ENDMODULE
