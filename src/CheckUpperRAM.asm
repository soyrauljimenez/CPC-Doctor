 MODULE UPPERRAMTEST

;; Prueba de la RAM alta (bancos de 64 KB que se ven por la ventana #4000-#7FFF)
;;
;; Cambios respecto a Amstrad Diagnostics 1.4:
;; - La detección usa firmas: se escribe una marca distinta en cada banco
;;   posible y en la RAM principal, y un banco solo cuenta si conserva la
;;   suya. Antes bastaba con leer algo distinto de #FF, así que las
;;   expansiones que devuelven ruido en los puertos que no existen (DDI-5
;;   de 512 KB, issue #13) aparecían como 4 MB.
;; - El resultado se guarda en un mapa de bits (UpperBankMap) que usan la
;;   prueba y la comprobación C3, en vez de volver a adivinarlo.
;; - SetErrorFound ya no machaca BC (bucle infinito tras el primer fallo
;;   fuera de los primeros 512 KB, issue #13) y acumula los bits erróneos.
;; - ESC ya no salta a una dirección errónea: la pila se deshace bien.
;; - Se vuelve a detectar la memoria al empezar, así que la prueba
;;   continua ya no muestra 0 KB desde la segunda vuelta (issue #17).
;; - Las marcas para la comprobación C3 se escriben antes de usarla (antes
;;   siempre decía "admitida").
;;
;; IMPORTANTE (versión cargada en RAM): este código, la fuente, PrintChar y
;; los textos que se imprimen mientras hay un banco conectado deben estar
;; por debajo de #4000. Main.asm lo comprueba con ASSERT.

;; OUT	ValidBankCount - número de bancos de 64 KB encontrados
;;	UpperBankMap - mapa de bancos presentes
@CalculateTotalUpperRAM:
	jp	DetectAvailableUpperRAM

@CheckUpperRAM:
	call 	UpperRAMPrintTitle
@CheckUpperRAMWithoutTitle:
	xor	a
	ld	(FailingBits), a
	call	DetectAvailableUpperRAM
	call 	PrintAvailableUpperRAM

	ld	a, (ValidBankCount)
	or	a
	jr	z, .noUpperRAM

	call 	SetUpScreen4MB

	xor	a
	ld	(FailingBits), a
	ld	(FailingBankCount), a
	call 	RunUpperRAMTests4MB
	or	a
	jr	nz, .printAborted

	call	WriteC3Markers
	call 	CheckC3Config

	call 	PrintResult
	ret

.printAborted:
	call	PrintAborted
	ret

.noUpperRAM:
	ld	a, TESTRESULT_NOTAVAILABLE
	ld	(TestResultTableUpperRAM), a
	ld	hl, #0004
	call	LocateWrap
	ld	hl, TxtNoUpperRAM
	jp	PrintWrapped


UpperRAMPrintTitle:
	ld	hl, TxtUpperRAMTitle
	jp	PrintScreenTitle


PrintAvailableUpperRAM:
	call	SetDefaultColors
	ld 	hl, #0002
	ld 	(TxtCoords),hl
	ld 	hl,TxtTotalMemory
	call 	PrintString
	ld	a, ' '
	call	PrintChar
	ld 	a, (ValidBankCount)
	ld 	l,a
	ld 	h,0
	add 	hl,hl
	add 	hl,hl
	add 	hl,hl
	add 	hl,hl
	add 	hl,hl
	add 	hl,hl
	call 	PrintHLDec
	ld 	hl,TxtKB
	call 	PrintString
	call 	NewLine

	ret


SetUpScreen4MB:
	call 	SetDefaultColors

	ld	l, BANKLABELYSTART4MB
	ld 	de, 0
.lineLoop:
	ld	h, BANKLABELXSTART4MB
	ld 	(TxtCoords), hl
	push	hl

	ld 	hl, TxtBank
	call 	PrintString
	ld	a, BANKLABELXSTART4MB + 6
	ld	(txt_x), a

.bankLoop:
	ld 	a, e
	call 	PrintAHex
	inc	e

	ld 	hl, txt_x
	ld	a, (hl)
	add	10
	ld	(hl), a

	ld	a, e
	and	%00000011
	jr	nz, .bankLoop

	pop	hl
	inc	l

	;; Solo se dibujan las filas hasta el último banco presente
	ld	a, (HighestBankId)
	cp	e
	jr	nc, .lineLoop

	;; Message to press ESC only if it's not soak mode
	call IsSoakTestRunning
	jp z, .skipESCToCancel

	ld	h, 0
	ld	l, RESULT_Y
	ld	(TxtCoords), hl
	ld	hl, TxtPressESCToCancel
	call	PrintString

.skipESCToCancel:
	ret


ClearResultLine:
	ld	h, 0
	ld	l, RESULT_Y
	ld	(TxtCoords), hl
	ld	b, ScreenCharsWidth
.loop:
	ld	a, ' '
	call	PrintChar
	djnz	.loop
	ld	h, 0
	ld	l, RESULT_Y
	ld	(TxtCoords), hl
	ret


PrintResult:
	call	ClearResultLine

	call	SetDefaultColors
	ld 	hl,TxtC3Config
	call 	PrintString
	ld	a, ' '
	call	PrintChar
	ld 	a, (C3ConfigFailed)
	or 	a
	jr 	nz,.C3NotSupported
	ld 	hl,TxtSupported
	call 	PrintString
	call 	NewLine

.printFinalResult:
	ld 	a, (FailingBits)
	or 	a
	jr 	nz,.failingTests

	;; Remember success
	ld	a, TESTRESULT_PASSED
	ld	(TestResultTableUpperRAM), a

	call	SetSuccessColors
	ld 	hl,TxtRAMTestPassed
	call 	PrintString
	jp	SetDefaultColors

.failingTests:
	call 	SetErrorColors
	ld 	hl,TxtRAMTestFailed
	call 	PrintString
	ld	a, ' '
	call	PrintChar
	ld 	a,(FailingBits)
	ld 	d,a
	call 	PrintFailingBits
	call 	SetDefaultColors

	;; Remember failure
	ld	a, TESTRESULT_FAILED
	ld	(TestResultTableUpperRAM), a
	ret

.C3NotSupported:
	call 	SetErrorColors
	ld 	hl,TxtNot
	call 	PrintString
	ld 	a,' '
	call 	PrintChar
	ld 	hl,TxtSupported
	call 	PrintString
	call 	NewLine
	call 	SetDefaultColors
	jr 	.printFinalResult



PrintAborted:
	ld	a, TESTRESULT_ABORTED
	ld	(TestResultTableUpperRAM), a

	call	ClearResultLine
	call	SetErrorColors
	ld	hl, TxtTestAborted
	call	PrintString
	jp	SetDefaultColors


;; Estas cadenas se imprimen con un banco conectado: tienen que estar aquí,
;; por debajo de #4000, y no en los textos traducidos.
TxtInvalidBank: db '--------',0
TxtValidBank: 	db '........',0


BANKLABELXSTART4MB EQU 1
BANKLABELYSTART4MB EQU 4
RESULT_Y EQU #16


@RAMBANKSTART equ #4000

;; Firmas: id de banco + FIRMA_BASE en #4000 y su complemento en #4001.
;; La RAM principal lleva FIRMA_PRINCIPAL. Ningún valor es #00 ni #FF.
FIRMA_BASE	EQU #10
FIRMA_PRINCIPAL	EQU #08

;; Secuencia de puertos para 4 MB: #7F #7E #7D #7C #7B #7A #79 #78
;; (cada uno selecciona un tramo de 512 KB = 8 bancos de 64 KB)
;;
;; Configuraciones de cada banco (4 bloques de 16 KB):
;; C4 C5 C6 C7 / CC CD CE CF / D4 D5 D6 D7 / DC DD DE DF
;; E4 E5 E6 E7 / EC ED EE EF / F4 F5 F6 F7 / FC FD FE FF


;; IN: B = puerto (#7F..#78), D = banco (0..7)
;; OUT: A = firma del banco. Conserva BC, DE.
BankSignature:
	ld	a, #7F
	sub	b
	add	a, a
	add	a, a
	add	a, a
	add	a, d
	add	a, FIRMA_BASE
	ret


;; IN: B = puerto (#7F..#78), D = banco (0..7)
;; OUT: HL = dirección del byte del mapa, A = máscara del banco
;; Conserva BC, DE.
BankMapPosition:
	push	bc
	ld	a, #7F
	sub	b
	ld	c, a
	ld	b, 0
	ld	hl, UpperBankMap
	add	hl, bc
	ld	a, d
	or	a
	ld	a, 1
	jr	z, .done
	ld	b, d
.shift:
	add	a, a
	djnz	.shift
.done:
	pop	bc
	ret


;; IN: B = puerto, D = banco.  OUT: NZ si el banco existe. Conserva BC, DE, HL.
IsBankInMap:
	push	hl
	call	BankMapPosition
	and	(hl)
	pop	hl
	ret


;; Busca la RAM alta con firmas. Conserva el contenido de #4000-#4001
;; de la RAM principal.
;; OUT: ValidBankCount, UpperBankMap, HighestBankId
DetectAvailableUpperRAM:
	ld	bc, #7FC0
	out	(c), c
	ld	hl, (RAMBANKSTART)
	ld	(SavedMain4000), hl

	;; 1) Firmas, del tramo y banco más altos a los más bajos. Si un banco
	;;    es un reflejo de otro más bajo, la firma del bajo se escribe
	;;    después y lo delata.
	ld	b, #78
.writeSection:
	ld	d, 7
.writeBank:
	ld	e, 0
	call	GetPortForBankAndBlock
	out	(c), l
	call	BankSignature
	ld	(RAMBANKSTART), a
	cpl
	ld	(RAMBANKSTART+1), a
	dec	d
	jp	p, .writeBank
	inc	b
	ld	a, b
	cp	#80
	jr	nz, .writeSection

	;; La RAM principal, la última: cualquier banco que sea un reflejo de
	;; ella (464 y 664 sin ampliación) mostrará esta firma.
	ld	bc, #7FC0
	out	(c), c
	ld	a, FIRMA_PRINCIPAL
	ld	(RAMBANKSTART), a
	cpl
	ld	(RAMBANKSTART+1), a

	;; 2) Leer y anotar los bancos que conservan su firma
	ld	hl, UpperBankMap
	ld	b, 8
.clearMap:
	ld	(hl), 0
	inc	hl
	djnz	.clearMap
	xor	a
	ld	(ValidBankCount), a
	ld	(HighestBankId), a

	ld	b, #7F
.readSection:
	ld	d, 0
.readBank:
	ld	e, 0
	call	GetPortForBankAndBlock
	out	(c), l
	call	BankSignature
	ld	hl, RAMBANKSTART
	cp	(hl)
	jr	nz, .notPresent
	cpl
	inc	hl
	cp	(hl)
	jr	nz, .notPresent

	call	BankMapPosition
	or	(hl)
	ld	(hl), a
	ld	hl, ValidBankCount
	inc	(hl)
	call	BankSignature
	sub	FIRMA_BASE
	ld	(HighestBankId), a

.notPresent:
	inc	d
	ld	a, d
	cp	8
	jr	nz, .readBank
	dec	b
	ld	a, b
	cp	#77
	jr	nz, .readSection

	ld	bc, #7FC0
	out	(c), c
	ld	hl, (SavedMain4000)
	ld	(RAMBANKSTART), hl
	ret


;; Marcas para CheckC3Config: el primer par de bytes de cada bloque de los
;; bancos del tramo #7F lleva (configuración, #7F).
WriteC3Markers:
	ld	b, #7F
	ld	d, 0
.bank:
	call	IsBankInMap
	jr	z, .next
	ld	e, 0
.block:
	call	GetPortForBankAndBlock
	out	(c), l
	ld	a, l
	ld	(RAMBANKSTART), a
	ld	a, b
	ld	(RAMBANKSTART+1), a
	inc	e
	ld	a, e
	cp	4
	jr	nz, .block
.next:
	inc	d
	ld	a, d
	cp	8
	jr	nz, .bank
	ld	bc, #7FC0
	out	(c), c
	ret


;; OUT: A = 0 normal ending, 1 aborted
RunUpperRAMTests4MB:
	ld	h, BANKLABELXSTART4MB+8
	ld	l, BANKLABELYSTART4MB
	ld	(TxtCoords), hl

	ld 	b, #7F
.loop512K:
	ld 	d, 0

.bankLoop:
	call	IsBankInMap
	jr	z, .invalidBank

	call	PrintBank

	ld 	e, 0
.blockLoop:
	call 	GetPortForBankAndBlock
	out 	(c), l

	push	bc
	push 	de
	ld 	c, 0
	ld 	b, 2
	ld 	hl, RAMBANKSTART
.dotLoop:
	call	CheckESC
	jr	nz, .aborted

	push 	bc
	ld 	de, #2000
	call 	TestRAM
	pop 	bc
	or 	c
	ld 	c,a			; C = bad bit pattern so far

	push 	af
	call 	SetSuccessColors
	ld 	a,'~'
	call 	PrintChar
	pop 	af

	djnz 	.dotLoop

	pop 	de
	pop	bc

	or a
	jr nz,	.failedBlock

.nextBlock:
	inc 	e
	ld 	a, e
	cp 	4
	jr 	nz, .blockLoop

.nextBank:
	ld	a, (txt_x)
	add	4
	ld	(txt_x),a

	inc 	d
	ld 	a, d
	and	a, %00000011			;; Every 4 banks, move to the next line
	jr	nz, .sameLine
	ld	a, BANKLABELXSTART4MB+8
	ld	(txt_x), a
	ld	hl, txt_y
	inc	(hl)

.sameLine:
	ld	a, d
	cp 	8
	jr 	nz, .bankLoop

	dec 	b
	ld 	a, b
	cp 	#77
	jr	z, .end
	;; No seguir más allá del último banco presente
	ld	a, #7F
	sub	b
	add	a, a
	add	a, a
	add	a, a
	ld	c, a
	ld	a, (HighestBankId)
	cp	c
	jp 	nc, .loop512K
.end:
	ld 	bc, #7FC0
	out 	(c),c
	xor	a
	ret

.aborted:
	pop	de
	pop	bc
	ld 	bc, #7FC0
	out 	(c),c
	ld	a, 1
	ret

.invalidBank:
	call	SetDefaultColors
	ld 	hl, TxtInvalidBank
	call 	PrintString
	jr 	.nextBank

.failedBlock:
	call 	SetErrorFound

	ld 	hl, txt_x
	ld 	a, (hl)
	dec	a
	dec	a
	ld 	(hl), a

	call SetErrorColors
	ld a,'~'
	call PrintChar
	ld a,'~'
	call PrintChar
	call SetDefaultColors
	jr .nextBlock


PrintBank:
	push	bc
	push 	de
	call 	SetDefaultColors
	ld	hl, TxtValidBank
	call	PrintString
	ld	a, (txt_x)
	sub	8
	ld	(txt_x), a
	pop 	de
	pop	bc
	ret


;; OUT: NZ si ESC está pulsada. Conserva BC, DE, HL.
CheckESC:
	push	hl
	push 	de
	push	bc
	call 	ReadFullKeyboard
	pop	bc
	pop	de
	pop	hl
	ld 	a, (KeyboardMatrixBuffer+8)
	and	%00000100				; ESC
	ret



; IN HL = Start, DE = length
; OUT A = 0 if good, otherwise failing bits
TestRAM:
	ld 	a, 1
	ld 	b, 8     ; test 8 bits
	or 	a        ; ensure carry is cleared

.bits:
	ld 	(hl), a
	ld 	c, a     ; for compare
	ld 	a, (hl)
	cp 	c
	jr 	nz,.bad
	rla
	djnz 	.bits
	inc 	hl
	dec 	de
	ld 	a, d     ; does de=0?
	or 	e
	jp 	z, .done
	jr 	TestRAM

.done:
	ld 	a, 0
	IFDEF UpperRAMFailure
		DISPLAY "Simulating upper RAM failure."
		ld a, UpperRAMFailure
	ENDIF
	ret

.bad:
	xor 	c	; a contains failing bits
	ret


; IN D = failing bits
PrintFailingBits:
	ld b,8
.loop:
	ld a,d
	push de
	push bc
	and 1	; Check if the LSB is set
	jr z, .next

	ld a,8
	sub b
	call PrintAHex

	ld a,' '
	call PrintChar


.next:
	pop bc
	pop de
	rr d    ; Shift bits right once
	djnz .loop

	ret


;; IN: A = bits erróneos. Los acumula en FailingBits.
;; Conserva BC y DE (antes SetBorderColor machacaba BC: issue #13).
SetErrorFound:
	push	bc
	ld 	hl, FailingBits
	or	(hl)
	ld 	(hl), a
	ld	hl, FailingBankCount
	inc	(hl)
	ld 	a, #c
	call 	SetBorderColor
	pop	bc
	ret

@UpperRAMTestCodeEnd:

 ENDMODULE
