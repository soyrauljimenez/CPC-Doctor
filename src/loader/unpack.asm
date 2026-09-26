;; Descompresor del cargador de CPC Doctor (ver tools/pack.py).
;; Se ensambla con PACKED, UNPACK_TO, UNPACK_END y STUB_AT definidos desde fuera.
;;
;;   0LLLLLLL           L+1 bytes literales
;;   10LLLLLL d         copia de L+2 bytes desde DE - (d+1)
;;   11LLLLLL lo hi     copia de L+3 bytes desde DE - (hi*256+lo)
;;
;; Parte de CPC Doctor. Licencia MIT.

	OUTPUT OutFile
	ORG STUB_AT

	di
	ld	hl, PACKED
	ld	de, UNPACK_TO
.loop:
	ld	a, (hl)
	inc	hl
	bit	7, a
	jr	nz, .match
	ld	c, a			; literales
	ld	b, 0
	inc	bc
	ldir
	jr	.check
.match:
	ld	b, 0
	bit	6, a
	jr	nz, .long
	and	#3F			; copia corta
	add	a, 2
	ld	c, a
	ld	a, (hl)
	inc	hl
	push	hl
	cpl				; HL = DE - (d+1) = DE + (#FF00 | not d)
	ld	l, a
	ld	h, #FF
	add	hl, de
	ldir
	pop	hl
	jr	.check
.long:
	and	#3F
	add	a, 3
	ld	c, a
	ld	a, (hl)			; distancia, byte bajo
	inc	hl
	push	hl
	ld	h, (hl)			; byte alto
	ld	l, a
	ld	a, e
	sub	l
	ld	l, a
	ld	a, d
	sbc	a, h
	ld	h, a
	ldir
	pop	hl
	inc	hl
.check:
	ld	a, e
	cp	low UNPACK_END
	jr	nz, .loop
	ld	a, d
	cp	high UNPACK_END
	jr	nz, .loop
	jp	UNPACK_TO
