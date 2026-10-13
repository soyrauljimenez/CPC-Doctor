;; M4Report.asm — informe en la tarjeta de la M4 Board (versión RAM)
;;
;; Si el CPC tiene una M4 Board, al mostrar el resumen se escribe también
;; /DOCTOR.TXT en su tarjeta SD: el mismo texto del resumen y de la página
;; de detalles del equipo, y /DOCTOR.ROM con la ROM del sistema. Se puede leer desde otro ordenador por la red (la web de la
;; M4) sin hacer fotos de la pantalla.
;;
;; El texto se captura de PrintChar mientras se pinta: cada carácter va a
;; un búfer con su posición, y los saltos de fila y de columna se
;; convierten en saltos de línea y espacios. Las letras propias de la
;; fuente (á, ñ, ¿...) se escriben en UTF-8.
;;
;; La M4 recibe las órdenes por el puerto #FE00 (tamaño y bytes) y las
;; ejecuta al escribir en #FC00; la respuesta queda en su ROM, en la
;; dirección que indica #FF02. Órdenes (fuente oficial de la ROM de la M4,
;; github.com/M4Duke/m4rom): C_OPEN #4301, C_WRITE #4303, C_CLOSE #4304.
;; Todo funciona sin el firmware del CPC.
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE M4REPORT

M4_DATA		EQU #FE00
M4_KICK		EQU #FC00
C_OPEN_LO	EQU #01
C_WRITE_LO	EQU #03
C_CLOSE_LO	EQU #04
C_HI		EQU #43
FA_WRITE_NEW	EQU #8A			; escribir, crear siempre, nombre largo
CHUNK		EQU 240			; bytes de texto por paquete

;; Busca la ROM de la M4 ("M4 BOARD") entre las ranuras 0-31.
;; OUT: M4Slot = ranura, o #FF si no hay M4
@FindM4:
	ld	a, #FF
	ld	(M4Slot), a
	ld	b, 0
.slot:
	push	bc
	ld	a, b
	ld	de, ROMStringBuffer
	call	GetROMString
	ld	hl, ROMStringBuffer
	ld	de, TxtM4Board
	ld	b, 8
.cmp:
	ld	a, (de)
	cp	(hl)
	jr	nz, .next
	inc	hl
	inc	de
	djnz	.cmp
	pop	bc
	ld	a, b
	ld	(M4Slot), a
	ret
.next:
	pop	bc
	inc	b
	ld	a, b
	cp	32
	jr	nz, .slot
	ret

TxtM4Board:	db 'M4 BOAR', 'D' + #80

;; ---------------------------------------------------------------------------
;; ReportBegin: abre /DOCTOR.TXT y empieza a capturar lo que se imprime.
;; Si no hay M4 o no se puede abrir, no hace nada.
;; ---------------------------------------------------------------------------
@ReportBegin:
	xor	a
	ld	(ReportOn), a
	ld	a, (M4Slot)
	inc	a
	ret	z
	;; C_OPEN: tamaño, orden, modo, nombre terminado en 0
	ld	hl, OpenPacket
	call	M4Send
	ld	a, (M4Resp + 4)			; 0 = abierto
	or	a
	ret	nz
	ld	a, (M4Resp + 3)
	ld	(ReportFd), a
	xor	a
	ld	(ReportLen), a
	ld	(ReportCol), a
	ld	(ReportRow), a
	ld	(ReportOnly), a
	inc	a
	ld	(ReportOn), a
	ret

OpenPacket:
	db OpenEnd - OpenPacket - 1, C_OPEN_LO, C_HI, FA_WRITE_NEW
	db '/DOCTOR.TXT', 0
OpenEnd:

;; ---------------------------------------------------------------------------
;; ReportEnd: añade los detalles del equipo, vacía el búfer y cierra el
;; fichero; después copia la ROM del sistema.
;; ---------------------------------------------------------------------------
@ReportEnd:
	ld	a, (ReportOn)
	or	a
	ret	z
	call	ReportDetails
	call	ReportNewLine
	call	Flush
	ld	hl, ClosePacket
	ld	a, (ReportFd)
	ld	(ClosePacket + 3), a
	call	M4Send
	xor	a
	ld	(ReportOn), a
	jp	DumpLowerROM

ClosePacket:
	db 3, C_CLOSE_LO, C_HI, 0

;; Copia la ROM baja (la del sistema) en /DOCTOR.ROM, para identificarla
;; desde otro ordenador cuando no está en la tabla de CRC.
DumpLowerROM:
	ld	hl, OpenRomPacket
	call	M4Send
	ld	a, (M4Resp + 4)
	or	a
	ret	nz
	ld	a, (M4Resp + 3)
	ld	(ReportFd), a
	ld	(ClosePacket + 3), a
	ld	hl, #0000
	ld	b, #4000 / ROM_CHUNK
.chunk:
	push	bc
	ld	de, ReportPacket + 4
	ld	bc, ROM_CHUNK
	call	CopyFromLowerROM		; en el bloque de RAM alta: la ROM tapa #0000-#3FFF
	push	hl
	ld	a, ROM_CHUNK
	ld	(ReportLen), a
	call	Flush
	pop	hl
	pop	bc
	djnz	.chunk
	ld	hl, ClosePacket
	jp	M4Send

ROM_CHUNK	EQU 128

OpenRomPacket:
	db OpenRomEnd - OpenRomPacket - 1, C_OPEN_LO, C_HI, FA_WRITE_NEW
	db '/DOCTOR.ROM', 0
OpenRomEnd:

;; La página de detalles del equipo, sin pintarla (va detrás del resumen)
ReportDetails:
	ld	a, 1
	ld	(ReportOnly), a
	ld	hl, #0040			; fila 64: fuera de la pantalla
	ld	(TxtCoords), hl
	call	ReportNewLine
	call	PrintMachineDetails
	xor	a
	ld	(ReportOnly), a
	ret

;; ---------------------------------------------------------------------------
;; ReportChar: lo llama PrintChar con el carácter en A. Conserva todo.
;; ---------------------------------------------------------------------------
@ReportChar:
	push	af
	push	bc
	push	de
	push	hl
	ld	c, a
	;; ¿Otra fila? Saltos de línea (como mucho dos seguidos)
	ld	a, (ReportRow)
	ld	b, a
	ld	a, (txt_y)
	cp	b
	jr	z, .sameRow
	ld	(ReportRow), a
	jr	c, .oneLine			; ha vuelto hacia arriba
	sub	b
	cp	3
	jr	c, .lines
	ld	a, 2
.lines:
	ld	b, a
.nl:
	call	ReportNewLine
	djnz	.nl
	jr	.col
.oneLine:
	call	ReportNewLine
	jr	.col
.sameRow:
	;; Si vuelve a una columna anterior (se reescribe la fila), otra línea
	ld	a, (ReportCol)
	ld	b, a
	ld	a, (txt_x)
	cp	b
	call	c, ReportNewLine
.col:
	;; Los espacios no se escriben: se convierten en huecos al escribir el
	;; siguiente carácter. Así no quedan espacios al final ni filas borradas
	ld	a, c
	cp	' '
	jr	z, .done
	ld	a, (ReportCol)
	ld	b, a
	ld	a, (txt_x)
	sub	b
	jr	z, .put
	jr	c, .put
	ld	b, a
.space:
	ld	a, ' '
	call	Emit
	djnz	.space
.put:
	ld	a, c
	call	EmitChar
	ld	a, (txt_x)
	inc	a
	ld	(ReportCol), a
.done:
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

ReportNewLine:
	ld	a, 13
	call	Emit
	ld	a, 10
	call	Emit
	xor	a
	ld	(ReportCol), a
	ret

;; IN: A = carácter de la fuente. Las letras propias, en UTF-8
EmitChar:
	cp	#80
	jr	c, Emit
	cp	#90
	jr	nc, .other
	sub	#80
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, Utf8Table
	add	hl, de
	ld	a, (hl)
	call	Emit
	inc	hl
	ld	a, (hl)
	jr	Emit
.other:
	ld	a, '#'				; flechas y teclas dibujadas

;; IN: A = byte. Lo añade al búfer y lo envía cuando se llena
Emit:
	push	hl
	push	de
	ld	d, a				; el byte
	ld	a, (ReportLen)
	ld	e, a
	ld	a, d
	ld	d, 0
	ld	hl, ReportPacket + 4
	add	hl, de
	ld	(hl), a
	pop	de
	pop	hl
	ld	a, (ReportLen)
	inc	a
	ld	(ReportLen), a
	cp	CHUNK
	ret	c
	;; sigue en Flush

;; Envía lo que haya en el búfer
Flush:
	ld	a, (ReportLen)
	or	a
	ret	z
	push	bc
	push	de
	push	hl
	add	a, 3
	ld	(ReportPacket), a
	ld	a, C_WRITE_LO
	ld	(ReportPacket + 1), a
	ld	a, C_HI
	ld	(ReportPacket + 2), a
	ld	a, (ReportFd)
	ld	(ReportPacket + 3), a
	ld	hl, ReportPacket
	call	M4Send
	xor	a
	ld	(ReportLen), a
	pop	hl
	pop	de
	pop	bc
	ret

;; á é í ó ú ñ Ñ ü ¿ ¡ ù º Ü ç è à (códigos #80-#8F de la fuente)
Utf8Table:
	db #C3,#A1, #C3,#A9, #C3,#AD, #C3,#B3, #C3,#BA, #C3,#B1, #C3,#91, #C3,#BC
	db #C2,#BF, #C2,#A1, #C3,#B9, #C2,#BA, #C3,#9C, #C3,#A7, #C3,#A8, #C3,#A0

;; ---------------------------------------------------------------------------
;; M4Send: envía el paquete HL (tamaño y bytes) y copia el principio de la
;; respuesta en M4Resp.
;; ---------------------------------------------------------------------------
M4Send:
	ld	a, (hl)
	inc	a
	ld	e, a
	ld	bc, M4_DATA
.out:
	ld	a, (hl)
	out	(c), a
	inc	hl
	dec	e
	jr	nz, .out
	ld	bc, M4_KICK
	out	(c), c
	;; La respuesta, en la ROM de la M4
	ld	bc, #7F85			; ROM alta conectada, modo 1
	out	(c), c
	ld	a, (M4Slot)
	ld	bc, #DF00
	out	(c), a
	ld	hl, (#FF02)
	ld	de, M4Resp
	ld	bc, 8
	ldir
	jp	RestoreROMState

 ENDMODULE
