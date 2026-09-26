;; Z80Detect.asm — tipo de Z80 (versión guiada)
;;
;; Portado del fork de Ismael Salvador (issalig/amstrad-diagnostics, 2025),
;; que se basa en:
;; - NMOS o CMOS: https://www.malinov.com/sergeys-blog/z80-type-detection.html
;;   (OUT (C),0 escribe 0 en un NMOS y #FF en un CMOS).
;; - Fabricante: https://github.com/redcode/Z80_XCF_Flavor (comportamiento
;;   de los flags YF y XF tras SCF y CCF).
;;
;; Cambio respecto al original: no se hace EI al terminar, porque CPC Doctor
;; funciona siempre con las interrupciones desactivadas.
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE Z80DETECT

;; OUT: Z80Type = 0 NMOS, 1 CMOS
@TestZ80CMOS:
	ld	b, #F4			; puerto A del PPI: se puede escribir y leer
	db	#ED, #71		; OUT (C),0 (no documentada)
	nop
	in	a, (c)			; #00 NMOS, #FF CMOS
	and	1
	ld	(Z80Type), a
	ret


	MACRO Q0_F0_A0
		xor	a
	ENDM
	MACRO Q0_F1_A0
		xor	a
		dec	a
		ld	a, 0
	ENDM
	MACRO Q1_F1_A0
		xor	a
		ld	e, a
		dec	e
	ENDM
	MACRO Q0_F0_A1
		xor	a
		ld	a, #FF
	ENDM
	MACRO Q0_F1_A1
		xor	a
		dec	a
		nop
	ENDM
	MACRO Q1_F1_A1
		xor	a
		dec	a
	ENDM

;; OUT: Z80Flavor = 0 desconocido, 1 Zilog, 2 NEC NMOS, 3 ST CMOS
@TestZ80Flavor:
	ld	bc, Z80XcfResults
	Q0_F0_A0 : ccf : call StoreYXF
	Q0_F1_A0 : ccf : call StoreYXF
	Q1_F1_A0 : ccf : call StoreYXF
	Q0_F0_A1 : ccf : call StoreYXF
	Q0_F1_A1 : ccf : call StoreYXF
	Q1_F1_A1 : ccf : call StoreYXF
	Q0_F0_A0 : scf : call StoreYXF
	Q0_F1_A0 : scf : call StoreYXF
	Q1_F1_A0 : scf : call StoreYXF
	Q0_F0_A1 : scf : call StoreYXF
	Q0_F1_A1 : scf : call StoreYXF
	Q1_F1_A1 : scf : call StoreYXF

	;; CCF y SCF deben dar lo mismo; si no, el comportamiento es inestable
	ld	b, 0
	ld	de, Z80XcfResults
	ld	hl, Z80XcfResults + 6
	call	CompareResults
	jr	nz, .done
	ld	b, 1
	ld	de, Z80XcfResults
	ld	hl, ResultsZilog
	call	CompareResults
	jr	z, .done
	ld	b, 2
	ld	de, Z80XcfResults
	ld	hl, ResultsNecNMOS
	call	CompareResults
	jr	z, .done
	ld	b, 3
	ld	de, Z80XcfResults
	ld	hl, ResultsSTCMOS
	call	CompareResults
	jr	z, .done
	ld	b, 0
.done:
	ld	a, b
	ld	(Z80Flavor), a
	ret

;; Guarda YF y XF en (BC) y avanza BC
StoreYXF:
	push	af
	pop	de
	ld	a, e
	and	%00101000
	ld	(bc), a
	inc	bc
	ret

;; IN: DE, HL = dos tablas de 6 bytes  OUT: Z si son iguales
CompareResults:
	ld	c, 6
.loop:
	ld	a, (de)
	sub	(hl)
	ret	nz
	inc	de
	inc	hl
	dec	c
	jr	nz, .loop
	ret

ResultsZilog:
	db %00000000, %00101000, %00000000, %00101000, %00101000, %00101000
ResultsNecNMOS:
	db %00000000, %00000000, %00000000, %00101000, %00101000, %00101000
ResultsSTCMOS:
	db %00000000, %00100000, %00000000, %00001000, %00101000, %00101000


;; "NMOS, Zilog", "CMOS, ST" o solo "NMOS" si no se reconoce el fabricante
@PrintZ80Type:
	ld	a, (Z80Type)
	or	a
	ld	hl, TxtNMOS
	jr	z, .type
	ld	hl, TxtCMOS
.type:
	call	PrintString
	ld	a, (Z80Flavor)
	or	a
	ret	z
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, FlavorNames - 2
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	push	hl
	ld	a, ','
	call	PrintChar
	ld	a, ' '
	call	PrintChar
	pop	hl
	jp	PrintString

FlavorNames:
	dw TxtZilog, TxtNEC, TxtST
TxtNMOS:	db "NMOS", 0
TxtCMOS:	db "CMOS", 0
TxtZilog:	db "Zilog", 0
TxtNEC:		db "NEC", 0
TxtST:		db "ST", 0

 ENDMODULE
