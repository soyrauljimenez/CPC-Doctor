;; RAMChips.asm — qué chip de RAM de la placa guarda cada bit (versión RAM)
;;
;; Cuando la prueba de RAM encuentra bits erróneos, dice qué chips revisar.
;; Las posiciones salen de los esquemas de Amstrad:
;; - 464 (placas Z70200 y Z70373) y 664: 8 x 4164, CPC464 Service Manual
;;   (1985), Amendment Service Manual ("CPC464 RAM/CRTC/ULA Section") y
;;   CPC664 Service Manual. Ojo: no van en orden: D0..D3 = IC120..IC117,
;;   D4..D7 = IC121..IC124.
;; - 6128 con placa original (MC0009A, MC0020x): 16 x 4164, CPC6128 Service
;;   Manual ("CAS0 1ST BANK ONLY"): RAM base IC127..IC134, RAM alta
;;   IC119..IC126 (D0..D7), confirmado con el trazado de la placa MC0020x de
;;   pelrun/cpc-schematics.
;; - 6128 abaratado (MC0100, Gate Array 40226): 16 x 4164, Amendment Service
;;   Manual ("CPC6128 RAM Section"): IC109..IC116 (NCAS0) e IC117..IC124
;;   (NCAS1). Que NCAS0 sea la RAM base se deduce de las otras placas: se
;;   dice "probable".
;; - 464 Plus y 6128 Plus: KM41464 (4 bits cada uno), 464 Plus / 6128 Plus /
;;   GX4000 Service Manual: base IC110 (bits 0-3) e IC111 (bits 4-7), alta
;;   IC112 e IC113 (solo el 6128 Plus).
;; - 464 abaratado (MC0099, 40226): no hay esquema; puede llevar 8 x 4164 o
;;   2 x 41464. Solo se da el bit.
;;
;; El modelo sale de la ROM (o de lo que ha contestado el usuario) y de la
;; RAM alta, así que el texto dice para qué placa es el número y recuerda
;; comprobar la serigrafía antes de desoldar.
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE RAMCHIPS

BOARD_NONE	EQU 0
BOARD_464	EQU 1			; 464 y 664 con 4164
BOARD_6128	EQU 2			; 6128 con placa original
BOARD_6128CD	EQU 3			; 6128 abaratado (40226)
BOARD_PLUS	EQU 4			; 464 Plus y 6128 Plus

;; IN: A = bits erróneos, C = 0 RAM base, 1 RAM alta (los 64 KB del 6128)
;; Imprime en una línea nueva "Chips a revisar (placa): IC... IC...".
;; Si no se sabe, no imprime nada.
@PrintRAMChips:
	or	a
	ret	z
	ld	(ChipBits), a
	ld	a, c
	ld	(ChipBank), a
	call	GetBoard
	or	a
	ret	z
	ld	(ChipBoard), a
	;; La RAM alta solo es de la placa si no hay ampliaciones (un banco)
	ld	a, (ChipBank)
	or	a
	jr	z, .known
	ld	a, (ChipBoard)
	cp	BOARD_464
	ret	z
	ld	a, (ValidBankCount)
	cp	1
	ret	nz
.known:
	call	WrapNewLine
	ld	hl, TxtRAMChips
	call	PrintString
	ld	a, ' '
	call	PrintChar
	ld	a, (ChipBoard)
	dec	a
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, BoardNames
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	call	PrintString
	ld	a, ':'
	call	PrintChar

	ld	a, (ChipBoard)
	cp	BOARD_PLUS
	jr	z, .plus
	;; Un chip por bit
	ld	b, 0
.bit:
	ld	a, (ChipBits)
	ld	c, a
	ld	a, b
	or	a
	jr	z, .tested
.shift:
	srl	c
	dec	a
	jr	nz, .shift
.tested:
	bit	0, c
	jr	z, .nextBit
	push	bc
	ld	a, b
	call	ChipForBit
	call	PrintIC
	pop	bc
.nextBit:
	inc	b
	ld	a, b
	cp	8
	jr	nz, .bit
	ret

	;; Plus: un chip por cada 4 bits
.plus:
	ld	a, (ChipBits)
	and	#0F
	jr	z, .high
	call	PlusChip			; bits 0-3
	call	PrintIC
.high:
	ld	a, (ChipBits)
	and	#F0
	ret	z
	call	PlusChip			; bits 4-7: el siguiente
	inc	a
	jp	PrintIC

;; OUT: A = chip de los bits 0-3 (base 110, alta 112)
PlusChip:
	ld	a, (ChipBank)
	add	a, a
	add	a, 110
	ret

;; " IC" y el número; si no cabe en la línea, en la siguiente
;; IN: A = número
PrintIC:
	push	af
	ld	a, (txt_x)
	add	a, 6
	ld	b, a
	ld	a, (WrapRight)
	cp	b
	call	c, WrapNewLine
	ld	hl, TxtIC
	call	PrintString
	pop	af
	jp	PrintANoPad

;; IN: A = bit (0-7)  OUT: A = número de IC
ChipForBit:
	ld	c, a
	ld	a, (ChipBoard)
	cp	BOARD_464
	jr	nz, .not464
	ld	e, c
	ld	d, 0
	ld	hl, Chips464
	add	hl, de
	ld	a, (hl)
	ret
.not464:
	ld	b, 127				; 6128 original, RAM base
	cp	BOARD_6128
	jr	z, .bank
	ld	b, 109				; 6128 abaratado, NCAS0
.bank:
	ld	a, (ChipBank)
	or	a
	ld	a, b
	jr	z, .add
	sub	8				; RAM alta: 119.. y 117..
	cp	101				; 109 - 8: el abaratado es 117..
	jr	nz, .add
	add	a, 16
.add:
	add	a, c
	ret

Chips464:
	db 120, 119, 118, 117, 121, 122, 123, 124

;; OUT: A = BOARD_...
GetBoard:
	ld	a, (CRTCType)
	cp	3
	ld	a, BOARD_PLUS
	ret	z
	ld	a, (ModelDoubt)			; ROM de 6128 sin RAM alta y sin
	or	a				; confirmar el modelo: no se sabe
	ld	a, BOARD_NONE
	ret	nz
	ld	a, (CRTCType)
	cp	4
	jr	nz, .discrete
	;; 40226: el 6128 tiene RAM alta; del 464 abaratado no hay esquema
	ld	a, (ValidBankCount)
	or	a
	ld	a, BOARD_NONE
	ret	z
	ld	a, BOARD_6128CD
	ret
.discrete:
	ld	a, (ModelType)
	cp	MODEL_CPC6128
	ld	a, BOARD_6128
	ret	z
	ld	a, BOARD_464
	ret

BoardNames:
	dw TxtBoard464, TxtBoard6128, TxtBoard6128CD, TxtBoardPlus

TxtIC:	db ' IC', 0

 ENDMODULE
