

;; By Rhino http://www.cpcwiki.eu/forum/programming/crtc-type-detection-code/
;; CRTC 5 (HD6345): idea de Cheshirecat (https://thecheshirec.at/2024/05/07/un-crtc6345-sur-amstrad-cpc/)
;; y adaptación de Lordheavy (fork lordheavy/amstrad-diagnostics). Aquí se
;; conserva el algoritmo original de Rhino y solo se añade la distinción
;; entre el tipo 0 y el 5, que el original confunde.
; Detect CRTC type
; Output
; a = CRTC type (0,1,2,3,4,5)
GetCRTCType:
	call	.detect
	;; Dejar el registro 12 como estaba (inicio de pantalla en #C000)
	push	af
	ld	bc, #bc0c
	out	(c), c
	ld	bc, #bd30
	out	(c), c
	pop	af
	ret

.detect:
	ld bc, #bc0c        ; select reg 12 (R/W)
	out (c), c
	ld bc, #bd00+%0110100    ; write a value
	out (c), c

;    call    wVb
	ld b, #f5            ; wait Vbl
@vbLoop1
	in a, (c)
	rra
	jr c, @vbLoop1
@vbLoop2
	in a, (c)
	rra
	jr nc, @vbLoop2

	ld b, #be            ; read from status register
	in a, (c)
	ld d, a

	inc b            ; read from #bf (read register)
	in a, (c)

	cp d            ; #be == #bf?
	jr z, @CRTC_3_4

	; CRTC 0 1 or 2
	cp c  ;%0110100        ; same value?
	jr nz, @CRTC_1_2

	; CRTC 0 o 5. El 6845 del tipo 0 solo decodifica 5 bits de número de
	; registro, así que el 44 es un alias del 12 y devuelve lo que acabamos
	; de escribir. El HD6345 tiene un registro 44 propio, que devuelve 0.
	ld bc, #bc00+44
	out (c), c
	ld b, #bf
	in a, (c)
	cp %0110100
	jr nz, @CRTC_5

	; CRTC 0
	xor a
	ret

	; CRTC 5
@CRTC_5
	ld a, 5
	ret

@CRTC_1_2
	ld a, d
	and a, %011111
	jr nz, @CRTC_2

	; CRTC 1
	ld a, 1
	ret

	; CRTC 2
@CRTC_2
	ld a, 2
	ret

	; CRTC 3 or 4
@CRTC_3_4
	ld bc, #f782
	out (c),c
	dec b
	ld a, #F
	out (c), a
	inc b
	out (c), c
	dec b
	in c, (c)
	cp c
	jr nz, @CRTC_4

	; CRTC 3
@CRTC_3
	ld a, 3
	ret

	; CRTC 4
@CRTC_4
	ld a, 4
	ret
