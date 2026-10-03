;; LowerRAMGuide.asm — prueba de la RAM baja en la versión cargada (RAM)
;;
;; Un programa cargado desde cinta o disco no puede comprobar la memoria
;; que ocupa él mismo. Amstrad Diagnostics solo comprobaba aquí los 16 KB
;; de pantalla y daba "PASSED" para toda la RAM baja. Esta prueba comprueba
;; todos los bloques de 1 KB libres, muestra un mapa de lo comprobado y
;; lo que no, y dice cuántos KB ha cubierto.
;;
;; Pasadas:
;;   1. En toda la zona libre, cada byte recibe un valor que depende de su
;;      dirección; después se relee todo. Detecta líneas de dirección
;;      cruzadas o abiertas (un bloque que es reflejo de otro).
;;   2. En cada bloque: #00, #FF, #55 y #AA (cada bit a 0 y a 1, y bits
;;      vecinos con valores distintos).
;;
;; Para comprobar el 100 % de la RAM hace falta la versión en ROM baja.
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE LOWERRAMGUIDE

BLOCKS		EQU 64
BLOCK_UNTESTED	EQU 0
BLOCK_OK	EQU 1
BLOCK_FAILED	EQU 2
BLOCK_BUSY	EQU 3			; ocupado por CPC Doctor

MAP_Y		EQU 4

@GuidedLowerRAMTest:
	ld	hl, TxtResultLowerRAM
	ld	de, TxtLowerRAMIntro
	call	ExplainScreen
	ret	z
	call	RunLowerRAMTest
	jp	LowerRAMResultText

;; La prueba y el mapa, sin explicación ni espera (también para la prueba
;; continua). OUT: TestResultTableLowerRAM
@RunLowerRAMTest:
	call	MarkBusyBlocks
	xor	a
	ld	(LowRAMFailBits), a

	;; La pantalla primero: la prueba la llena de basura
	ld	b, 48
.screenBlocks:
	push	bc
	ld	a, b
	call	TestBlock
	pop	bc
	inc	b
	ld	a, b
	cp	BLOCKS
	jr	nz, .screenBlocks

	call	DrawMapScreen

	;; Pasada de direcciones en los bloques libres fuera de la pantalla
	call	AddressPass

	;; Pasada de patrones bloque a bloque, pintando el mapa
	ld	b, 0
.blocks:
	push	bc
	ld	a, b
	call	IsBlockFree
	jr	z, .next
	ld	a, b
	call	TestBlock
.next:
	pop	bc
	push	bc
	ld	a, b
	call	DrawBlock
	pop	bc
	inc	b
	ld	a, b
	cp	48
	jr	nz, .blocks
	ld	b, 48
.drawScreenBlocks:
	push	bc
	ld	a, b
	call	DrawBlock
	pop	bc
	inc	b
	ld	a, b
	cp	BLOCKS
	jr	nz, .drawScreenBlocks

	;; Resultado
	ld	a, (LowRAMFailBits)
	or	a
	ld	a, TESTRESULT_PASSED
	jr	z, .set
	ld	a, TESTRESULT_FAILED
.set:
	ld	(TestResultTableLowerRAM), a
	ret

LowerRAMResultText:
	ld	hl, #000B
	call	LocateWrap
	ld	hl, TxtLowerRAMTested
	call	PrintString
	ld	a, ' '
	call	PrintChar
	call	CountTested
	call	PrintANoPad
	ld	hl, TxtLowerRAMOf64
	call	PrintString
	call	WrapNewLine
	ld	a, (TestResultTableLowerRAM)
	call	PrintResultLine
	ld	a, (LowRAMFailBits)
	or	a
	jr	z, .ok
	ld	a, ' '
	call	PrintChar
	ld	hl, TxtSummaryBits
	call	PrintString
	ld	a, (LowRAMFailBits)
	ld	d, a
	call	UPPERRAMTEST.PrintFailingBits
	ld	a, (LowRAMFailBits)
	ld	c, 0
	call	PrintRAMChips
	call	WrapNewLine
	call	WrapNewLine
	ld	hl, TxtLowerRAMFailAdvice
	jr	.advice
.ok:
	call	WrapNewLine
	call	WrapNewLine
	ld	hl, TxtLowerRAMOkAdvice
.advice:
	call	PrintWrapped
	ld	hl, TxtPressOKToReturn
	call	PrintHint
	jp	WaitOK


;; Marca los bloques que ocupa el programa (código, variables y pila)
MarkBusyBlocks:
	ld	hl, BlockStatus
	ld	b, BLOCKS
	xor	a
.clear:
	ld	(hl), a
	inc	hl
	djnz	.clear
	ld	de, #0400
	ld	hl, ProgramEnd
	call	MarkBusyRange
	ld	de, RAMProgramAddr
	ld	hl, RAMEnd
	call	MarkBusyRange
	ld	de, #BC00			; pila
	ld	hl, #C000
	;; sigue

;; IN: DE = inicio, HL = fin (sin incluir)
MarkBusyRange:
	dec	hl
	ld	a, h
	srl	a
	srl	a
	ld	c, a				; último bloque
	ld	a, d
	srl	a
	srl	a				; primer bloque
.loop:
	push	af
	ld	e, a
	ld	d, 0
	ld	hl, BlockStatus
	add	hl, de
	ld	(hl), BLOCK_BUSY
	pop	af
	cp	c
	ret	z
	inc	a
	jr	.loop

;; IN: A = bloque  OUT: NZ si está libre (sin marcar como ocupado)
IsBlockFree:
	ld	e, a
	ld	d, 0
	ld	hl, BlockStatus
	add	hl, de
	ld	a, (hl)
	cp	BLOCK_BUSY
	ret


;; Prueba un bloque de 1 KB con cuatro patrones. Si ya había fallado en la
;; pasada de direcciones, sigue marcado como fallido.
;; IN: A = bloque
TestBlock:
	ld	c, a
	add	a, a
	add	a, a
	ld	h, a
	ld	l, 0				; HL = inicio del bloque
	ld	b, 0				; bits erróneos del bloque
	ld	a, #00
	call	PatternBlock
	ld	a, #FF
	call	PatternBlock
	ld	a, #55
	call	PatternBlock
	ld	a, #AA
	call	PatternBlock
	ld	e, c
	ld	d, 0
	ld	ix, BlockStatus
	add	ix, de
	ld	a, b
	or	a
	jr	nz, .failed
	ld	a, (ix)
	cp	BLOCK_FAILED
	ret	z
	ld	(ix), BLOCK_OK
	ret
.failed:
	ld	(ix), BLOCK_FAILED
	ld	hl, LowRAMFailBits
	or	(hl)
	ld	(hl), a
	ret

;; Llena 1 KB desde HL con A y lo relee. Acumula en B los bits erróneos.
;; Conserva HL y C.
PatternBlock:
	push	hl
	push	bc
	ld	e, a
	ld	bc, #0400
.fill:
	ld	(hl), e
	inc	hl
	dec	bc
	ld	a, b
	or	c
	jr	nz, .fill
	pop	bc
	pop	hl
	push	hl
	push	bc
	ld	bc, #0400
	ld	d, 0
.check:
	ld	a, (hl)
	xor	e
	or	d
	ld	d, a
	inc	hl
	dec	bc
	ld	a, b
	or	c
	jr	nz, .check
	pop	bc
	pop	hl
	ld	a, d
	or	b
	ld	b, a
	ret


;; Pasada de direcciones en los bloques libres 0..47
AddressPass:
	ld	c, 0
.write:
	ld	a, c
	call	IsBlockFree
	jr	z, .nextWrite
	ld	a, c
	add	a, a
	add	a, a
	ld	h, a
	ld	l, 0
	ld	de, #0400
.w:
	ld	a, h
	xor	l
	add	a, c				; el bloque también cuenta
	ld	(hl), a
	inc	hl
	dec	de
	ld	a, d
	or	e
	jr	nz, .w
.nextWrite:
	inc	c
	ld	a, c
	cp	48
	jr	nz, .write

	ld	c, 0
.read:
	ld	a, c
	call	IsBlockFree
	jr	z, .nextRead
	ld	a, c
	add	a, a
	add	a, a
	ld	h, a
	ld	l, 0
	ld	de, #0400
	ld	b, 0
.r:
	ld	a, h
	xor	l
	add	a, c
	xor	(hl)
	or	b
	ld	b, a
	inc	hl
	dec	de
	ld	a, d
	or	e
	jr	nz, .r
	ld	a, b
	or	a
	jr	z, .nextRead
	push	hl
	ld	hl, LowRAMFailBits
	or	(hl)
	ld	(hl), a
	ld	e, c
	ld	d, 0
	ld	hl, BlockStatus
	add	hl, de
	ld	(hl), BLOCK_FAILED
	pop	hl
.nextRead:
	inc	c
	ld	a, c
	cp	48
	jr	nz, .read
	ret


;; OUT: A = KB comprobados
CountTested:
	ld	hl, BlockStatus
	ld	b, BLOCKS
	ld	c, 0
.loop:
	ld	a, (hl)
	cp	BLOCK_OK
	jr	z, .count
	cp	BLOCK_FAILED
	jr	nz, .next
.count:
	inc	c
.next:
	inc	hl
	djnz	.loop
	ld	a, c
	ret


;; Pantalla con el mapa vacío y la leyenda
DrawMapScreen:
	;; En la prueba continua la barra sigue diciendo en qué vuelta va
	call	IsSoakTestRunning
	ld	hl, TitleBuffer
	jr	z, .title
	ld	hl, TxtResultLowerRAM
.title:
	call	PrintScreenTitle
	ld	hl, TxtLowerRAMMap
	call	PrintString
	ld	b, 0
.rows:
	push	bc
	ld	a, b
	add	a, MAP_Y
	ld	l, a
	ld	h, 1
	ld	(TxtCoords), hl
	ld	a, '#'
	call	PrintChar
	ld	a, b
	add	a, a
	add	a, a
	add	a, a
	add	a, a
	add	a, a
	add	a, a				; x #40
	call	PrintAHex
	ld	a, '0'
	call	PrintChar
	ld	a, '0'
	call	PrintChar
	pop	bc
	inc	b
	ld	a, b
	cp	4
	jr	nz, .rows
	ld	hl, #0009
	ld	(TxtCoords), hl
	call	SetSuccessColors
	ld	a, '+'
	call	PrintChar
	call	SetDefaultColors
	ld	hl, TxtLowerRAMLegendOk
	call	PrintString
	call	SetErrorColors
	ld	a, 'X'
	call	PrintChar
	call	SetDefaultColors
	ld	hl, TxtLowerRAMLegendBad
	call	PrintString
	ld	a, '-'
	call	PrintChar
	ld	hl, TxtLowerRAMLegendBusy
	jp	PrintString

;; IN: A = bloque. Lo pinta en el mapa según su estado.
DrawBlock:
	ld	c, a
	and	15
	add	a, a				; dos columnas por bloque
	add	a, 8
	ld	h, a
	ld	a, c
	srl	a
	srl	a
	srl	a
	srl	a
	add	a, MAP_Y
	ld	l, a
	ld	(TxtCoords), hl
	ld	e, c
	ld	d, 0
	ld	hl, BlockStatus
	add	hl, de
	ld	a, (hl)
	cp	BLOCK_OK
	jr	nz, .notOk
	call	SetSuccessColors
	ld	a, '+'
	jr	.print
.notOk:
	cp	BLOCK_FAILED
	jr	nz, .notFailed
	call	SetErrorColors
	ld	a, 'X'
	jr	.print
.notFailed:
	call	SetDefaultColors
	ld	a, '-'
.print:
	call	PrintChar
	jp	SetDefaultColors

 ENDMODULE
