;; UI.asm — utilidades de interfaz de CPC Doctor
;;
;; - PrintWrapped: texto con ajuste de línea entre dos márgenes
;; - PrintScreenTitle: barra de título "CPC DOCTOR vX - subtítulo"
;; - Choose: lista de opciones numeradas, con cursor, teclado o joystick
;; - ReadInput / WaitNoKeys / WaitFrames
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE UI

;; ---------------------------------------------------------------------------
;; Teclas de la matriz usadas por la interfaz (fila, máscara)
;; ---------------------------------------------------------------------------
KROW_CURSOR	EQU 0		; bit 0 arriba, bit 2 abajo, bit 6 ENTER pequeño
KROW_RETURN	EQU 2		; bit 2 RETURN
KROW_SPACE	EQU 5		; bit 7 espacio
KROW_ESC	EQU 8		; bit 2 ESC
KROW_JOY	EQU 9		; bit 0 arriba, 1 abajo, 2 izq, 3 der, 4 fuego 1, 5 fuego 2

;; Bits de InputFlags
INPUT_UP	EQU 0
INPUT_DOWN	EQU 1
INPUT_LEFT	EQU 2
INPUT_RIGHT	EQU 3
INPUT_OK	EQU 4
INPUT_BACK	EQU 5

;; ---------------------------------------------------------------------------
;; ReadInput: lee teclado y joystick una vez por cuadro.
;; OUT: A = InputFlags con las pulsaciones NUEVAS (flancos)
;;      NumberPressed = 1..10 si se acaba de pulsar un número (0 = 10), si no 0
;; ---------------------------------------------------------------------------
@ReadInput:
	call	WaitForVsync
	call	ReadFullKeyboard
	call	UpdateKeyBuffers

	ld	c, 0
	ld	a, (EdgeOnKeyboardMatrixBuffer + KROW_CURSOR)
	bit	0, a
	jr	z, $+4
	set	INPUT_UP, c
	bit	2, a
	jr	z, $+4
	set	INPUT_DOWN, c
	bit	1, a
	jr	z, $+4
	set	INPUT_RIGHT, c
	bit	6, a
	jr	z, $+4
	set	INPUT_OK, c
	ld	a, (EdgeOnKeyboardMatrixBuffer + 1)
	bit	0, a				; cursor izquierda
	jr	z, $+4
	set	INPUT_LEFT, c
	ld	a, (EdgeOnKeyboardMatrixBuffer + KROW_RETURN)
	bit	2, a
	jr	z, $+4
	set	INPUT_OK, c
	ld	a, (EdgeOnKeyboardMatrixBuffer + KROW_SPACE)
	bit	7, a
	jr	z, $+4
	set	INPUT_OK, c
	ld	a, (EdgeOnKeyboardMatrixBuffer + KROW_ESC)
	bit	2, a
	jr	z, $+4
	set	INPUT_BACK, c
	ld	a, (EdgeOnKeyboardMatrixBuffer + KROW_JOY)
	bit	0, a
	jr	z, $+4
	set	INPUT_UP, c
	bit	1, a
	jr	z, $+4
	set	INPUT_DOWN, c
	bit	2, a
	jr	z, $+4
	set	INPUT_LEFT, c
	bit	3, a
	jr	z, $+4
	set	INPUT_RIGHT, c
	bit	4, a
	jr	z, $+4
	set	INPUT_OK, c
	bit	5, a
	jr	z, $+4
	set	INPUT_BACK, c

	;; Números 1..9 (fila superior y teclado numérico)
	ld	hl, NumberKeyTable
	ld	b, 20
.numLoop:
	ld	e, (hl)				; fila
	inc	hl
	ld	d, 0
	push	hl
	ld	hl, EdgeOnKeyboardMatrixBuffer
	add	hl, de
	ld	a, (hl)
	pop	hl
	and	(hl)				; máscara
	inc	hl
	jr	nz, .numFound
	djnz	.numLoop
	xor	a
	jr	.numDone
.numFound:
	;; b = 20..1 -> número = ((20 - b) mod 10) + 1  (el 0 es la opción 10)
	ld	a, 20
	sub	b
	cp	10
	jr	c, $+4
	sub	10
	inc	a
.numDone:
	ld	(NumberPressed), a
	ld	a, c
	ld	(InputFlags), a
	ret

NumberKeyTable:
	;; fila, máscara para 1..9 (fila superior)
	db 8, %00000001,  8, %00000010,  7, %00000010,  7, %00000001
	db 6, %00000010,  6, %00000001,  5, %00000010,  5, %00000001
	db 4, %00000010,  4, %00000001
	;; f1..f9 y f0 (teclado numérico)
	db 1, %00100000,  1, %01000000,  0, %00100000,  2, %00010000
	db 1, %00010000,  0, %00010000,  1, %00000100,  1, %00001000
	db 0, %00001000,  1, %10000000


;; ---------------------------------------------------------------------------
;; ClearTextRows: borra filas de texto enteras escribiendo directamente en
;; la memoria de vídeo (mucho más rápido que imprimir espacios).
;; IN: L = primera fila (0..24), B = número de filas
;; ---------------------------------------------------------------------------
@ClearTextRows:
.row:
	push	bc
	push	hl
	ld	a, l
	add	a, a
	add	a, a
	add	a, a				; primera línea de píxeles
	ld	l, a
	ld	h, 0
	add	hl, hl
	ld	de, scr_table
	add	hl, de
	ld	b, 8
.line:
	push	bc
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	inc	hl
	push	hl
	ld	h, d
	ld	l, e
	ld	(hl), 0
	inc	de
	ld	bc, 79
	ldir
	pop	hl
	pop	bc
	djnz	.line
	pop	hl
	inc	l
	pop	bc
	djnz	.row
	ret


;; ---------------------------------------------------------------------------
;; PrintANoPad: número de 0 a 255 sin ceros a la izquierda
;; ---------------------------------------------------------------------------
@PrintANoPad:
	ld	c, 0			; ¿ya se ha impreso una cifra?
	ld	b, 100
	call	.digit
	ld	b, 10
	call	.digit
	add	a, '0'
	jp	PrintChar
.digit:
	ld	d, 0
.sub:
	cp	b
	jr	c, .got
	sub	b
	inc	d
	jr	.sub
.got:
	push	af
	ld	a, d
	or	c
	jr	z, .skip
	ld	a, d
	add	a, '0'
	call	PrintChar
	ld	c, 1
.skip:
	pop	af
	ret


;; ---------------------------------------------------------------------------
;; WaitNoKeys: espera a que no haya ninguna tecla ni botón pulsado.
;; Evita que una pulsación pase de una pantalla a la siguiente.
;; Si una tecla está bloqueada (avería), sale a los 2 segundos.
;; ---------------------------------------------------------------------------
@WaitNoKeys:
	ld	b, 100
.loop:
	push	bc
	call	WaitForVsync
	call	ReadFullKeyboard
	call	UpdateKeyBuffers
	pop	bc
	ld	hl, KeyboardMatrixBuffer
	ld	c, KeyboardBufferSize
	xor	a
.or:
	or	(hl)
	inc	hl
	dec	c
	jr	nz, .or
	or	a
	ret	z
	djnz	.loop
	ret


;; ---------------------------------------------------------------------------
;; WaitFrames: espera B cuadros (1/50 s cada uno)
;; ---------------------------------------------------------------------------
@WaitFrames:
	push	bc
	call	WaitForVsync
	pop	bc
	djnz	@WaitFrames
	ret


;; ---------------------------------------------------------------------------
;; WaitOK: espera a que se pulse ENTER, espacio, FUEGO o ESC.
;; OUT: Z si fue ESC / FUEGO 2
;; En el modo automático sigue sola a los 5 segundos.
;; ---------------------------------------------------------------------------
@WaitOK:
	call	WaitNoKeys
 IFDEF GUIDED
	ld	hl, AUTO_WAIT_FRAMES
	ld	(WaitOKFrames), hl
 ENDIF
.loop:
	call	ReadInput
 IFDEF GUIDED
	ld	a, (AutoStep)
	or	a
	jr	z, .manual
	ld	hl, (WaitOKFrames)
	dec	hl
	ld	(WaitOKFrames), hl
	ld	a, h
	or	l
	jr	z, .ok
.manual:
	ld	a, (InputFlags)
 ENDIF
	bit	INPUT_BACK, a
	jr	nz, .back
	and	1 << INPUT_OK
	jr	z, .loop
.ok:
	ld	a, 1
	or	a
	ret
.back:
	xor	a
	ret


;; ---------------------------------------------------------------------------
;; PrintWrapped: imprime un texto ajustando las palabras entre
;; WrapLeft (columna) y WrapRight (primera columna que no se puede usar).
;; '|' en los textos (código 10) fuerza un salto de línea.
;; IN: HL = texto. Empieza en TxtCoords.
;; OUT: HL = después del 0 final
;; ---------------------------------------------------------------------------
@PrintWrapped:
.next:
	ld	a, (hl)
	or	a
	jr	nz, .notEnd
	inc	hl
	ret
.notEnd:
	cp	CharLF
	jr	nz, .notNL
	inc	hl
	call	WrapNewLine
	jr	.next
.notNL:
	cp	' '
	jr	nz, .word
	inc	hl
	;; Un espacio al principio de línea no se imprime
	ld	a, (WrapLeft)
	ld	b, a
	ld	a, (txt_x)
	cp	b
	jr	z, .next
	;; Ni al final
	ld	b, a
	ld	a, (WrapRight)
	cp	b
	jr	z, .spaceNL
	jr	c, .spaceNL
	ld	a, ' '
	call	PrintChar
	jr	.next
.spaceNL:
	call	WrapNewLine
	jr	.next
.word:
	;; Medir la palabra
	push	hl
	ld	c, 0
.measure:
	ld	a, (hl)
	or	a
	jr	z, .measured
	cp	' '
	jr	z, .measured
	cp	CharLF
	jr	z, .measured
	inc	c
	inc	hl
	jr	.measure
.measured:
	pop	hl
	;; ¿Cabe? txt_x + c <= WrapRight
	ld	a, (txt_x)
	add	a, c
	ld	b, a
	ld	a, (WrapRight)
	cp	b
	jr	nc, .print
	;; No cabe: salto de línea salvo que ya estemos al principio
	ld	a, (WrapLeft)
	ld	b, a
	ld	a, (txt_x)
	cp	b
	call	nz, WrapNewLine
.print:
	ld	a, (hl)
	call	PrintChar
	inc	hl
	dec	c
	jr	nz, .print
	jr	.next

@WrapNewLine:
	ld	a, (WrapLeft)
	ld	(txt_x), a
	ld	a, (txt_y)
	inc	a
	ld	(txt_y), a
	ret

;; Márgenes a pantalla completa
@SetFullWrap:
	xor	a
	ld	(WrapLeft), a
	ld	a, ScreenCharsWidth
	ld	(WrapRight), a
	ret

;; IN: H = columna, L = fila. Coloca el cursor y fija el margen izquierdo.
@LocateWrap:
	ld	(TxtCoords), hl
	ld	a, h
	ld	(WrapLeft), a
	ret


;; ---------------------------------------------------------------------------
;; PrintScreenTitle: borra la pantalla y dibuja la barra de título
;; "CPC DOCTOR vX.Y - subtítulo" centrada.
;; IN: HL = subtítulo (0 = sin subtítulo)
;; ---------------------------------------------------------------------------
@PrintScreenTitle:
	push	hl
	ld	d, 0
	call	ClearScreen
	ld	a, 4
	call	SetBorderColor
	call	SetTitleColors
	ld	hl, 0
	ld	(TxtCoords), hl
	ld	b, ScreenCharsWidth
.bar:
	ld	a, ' '
	call	PrintChar
	djnz	.bar
	pop	hl
	;; Longitud total = título + (" - " + subtítulo) + " - Taller AUA"
	push	hl
	ld	c, TxtTitleLen + TxtWorkshopLen
	ld	a, h
	or	l
	jr	z, .measured
	call	StrLen
	add	a, 3
	add	a, c
	ld	c, a
.measured:
	ld	a, ScreenCharsWidth
	sub	c
	srl	a
	ld	(txt_x), a
	xor	a
	ld	(txt_y), a
	ld	hl, TxtTitle
	call	PrintString
	pop	hl
	ld	a, h
	or	l
	jr	z, .done
	push	hl
	ld	hl, TxtTitleSeparator
	call	PrintString
	pop	hl
	call	PrintString
.done:
	ld	hl, TxtWorkshop
	call	PrintString
	call	SetDefaultColors
	call	SetFullWrap
	ld	hl, #0002
	ld	(TxtCoords), hl
	ret

TxtTitleSeparator: db ' - ', 0
@TxtWorkshop: db ' - Taller AUA', 0
@TxtWorkshopLen EQU $ - TxtWorkshop - 1

;; IN: HL = texto  OUT: A = longitud (máx. 255). Conserva HL.
@StrLen:
	push	hl
	ld	b, 0
.loop:
	ld	a, (hl)
	or	a
	jr	z, .end
	inc	b
	inc	hl
	jr	.loop
.end:
	ld	a, b
	pop	hl
	ret


;; ---------------------------------------------------------------------------
;; PrintHeader: texto en vídeo inverso (cabecera de sección)
;; IN: HL = texto
;; ---------------------------------------------------------------------------
@PrintHeader:
	call	SetInverseColors
	call	PrintString
	jp	SetDefaultColors


;; ---------------------------------------------------------------------------
;; Choose: lista de opciones numeradas.
;; IN:  IX = tabla de punteros a textos terminada en dw 0
;;      H = columna, L = fila de la primera opción
;;      A = opción seleccionada al empezar (0..)
;; OUT: A = opción elegida (0..) o #FF si se pulsa ESC / FUEGO 2
;;      (versión guiada) #FE si se agota la cuenta atrás del modo automático
;;      Las opciones se eligen con el número, o con cursor/joystick y
;;      ENTER / espacio / FUEGO.
;; ---------------------------------------------------------------------------
@Choose:
	ld	(ChooseTable), ix
	ld	(ChoosePos), hl
	ld	(ChooseSelected), a
	;; Contar opciones
	ld	b, 0
.count:
	ld	a, (ix)
	or	(ix+1)
	jr	z, .counted
	inc	b
	inc	ix
	inc	ix
	jr	.count
.counted:
	ld	a, b
	ld	(ChooseCount), a
	call	ChooseDrawAll
	call	WaitNoKeys
.loop:
	call	ReadInput
 IFDEF GUIDED
	call	AutoCountdownTick
	ld	a, #FE				; se acabó el tiempo sin tocar nada
	ret	z
 ENDIF
	ld	a, (NumberPressed)
	or	a
	jr	z, .noNumber
	dec	a
	ld	b, a
	ld	a, (ChooseCount)
	dec	a
	cp	b
	jr	c, .noNumber			; número fuera de la lista
	ld	a, b
	ld	(ChooseSelected), a
	call	ChooseDrawAll
	ld	a, (ChooseSelected)
	ret
.noNumber:
	ld	a, (InputFlags)
	bit	INPUT_BACK, a
	jr	nz, .back
	bit	INPUT_OK, a
	jr	nz, .ok
	bit	INPUT_UP, a
	jr	nz, .up
	bit	INPUT_DOWN, a
	jr	nz, .down
	jr	.loop
.ok:
	ld	a, (ChooseSelected)
	ret
.back:
	ld	a, #FF
	ret
.up:
	ld	a, (ChooseSelected)
	or	a
	jr	nz, .upOk
	ld	a, (ChooseCount)
.upOk:
	dec	a
	jr	.moved
.down:
	ld	a, (ChooseCount)
	ld	b, a
	ld	a, (ChooseSelected)
	inc	a
	cp	b
	jr	c, .moved
	xor	a
.moved:
	ld	(ChooseSelected), a
	call	ChooseDrawAll
	jr	.loop

 IFDEF GUIDED
@AUTO_START_FRAMES	EQU 30 * 50
@AUTO_WAIT_FRAMES	EQU 5 * 50

;; Llamar una vez por cuadro tras ReadInput. Descuenta la cuenta atrás del
;; modo automático; cualquier pulsación nueva la anula. Las teclas atascadas
;; no la anulan: no producen pulsaciones nuevas.
;; OUT: Z si se acaba de agotar (y entonces AutoStep = 1)
@AutoCountdownTick:
	ld	hl, (AutoCountdown)
	ld	a, h
	or	l
	jr	z, .off
	call	AnyNewKey
	jr	nz, .cancel
	ld	hl, (AutoCountdown)
	dec	hl
	ld	(AutoCountdown), hl
	ld	a, h
	or	l
	ret	nz
	inc	a
	ld	(AutoStep), a
	xor	a				; Z
	ret
.cancel:
	ld	hl, 0
	ld	(AutoCountdown), hl
.off:
	or	1				; NZ
	ret

;; OUT: NZ si hay alguna tecla o botón recién pulsado
@AnyNewKey:
	ld	hl, EdgeOnKeyboardMatrixBuffer
	ld	b, KeyboardBufferSize
	xor	a
.or:
	or	(hl)
	inc	hl
	djnz	.or
	or	a
	ret
 ENDIF

ChooseDrawAll:
	ld	ix, (ChooseTable)
	ld	hl, (ChoosePos)
	ld	c, 0
.item:
	ld	a, (ix)
	or	(ix+1)
	ret	z
	ld	(TxtCoords), hl
	push	hl
	ld	a, (ChooseSelected)
	cp	c
	call	z, SetInverseColors
	call	nz, SetDefaultColors
	ld	a, c
	add	a, '1'
	cp	'9' + 1			; la opción 10 se elige con el 0
	jr	c, .digit
	ld	a, '0'
	jr	z, .digit
	ld	a, ' '			; de la 11 en adelante, sin número
.digit:
	call	PrintChar
	ld	a, '.'
	call	PrintChar
	ld	a, ' '
	call	PrintChar
	ld	l, (ix)
	ld	h, (ix+1)
	call	PrintString
	ld	a, ' '
	call	PrintChar
	call	SetDefaultColors
	pop	hl
	inc	l
	inc	ix
	inc	ix
	inc	c
	jr	.item

 ENDMODULE
