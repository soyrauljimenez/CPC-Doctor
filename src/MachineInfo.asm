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
