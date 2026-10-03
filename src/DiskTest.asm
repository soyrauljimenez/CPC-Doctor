;; DiskTest.asm — velocidad de giro de la disquetera (versión guiada)
;;
;; Portado del fork de Ismael Salvador (issalig/amstrad-diagnostics, 2025),
;; basado a su vez en el programa RPM de Brice Rive, Philippe Depré y
;; Simon Owen.
;;
;; Método: se pide al FDC (µPD765) que lea un sector que no existe (R = 0;
;; los discos del CPC empiezan en #41 o #C1). El FDC lo busca durante dos
;; vueltas completas, de agujero índice a agujero índice, y entonces
;; responde. Lo primero sincroniza con el índice; lo segundo mide el tiempo
;; de esas dos vueltas contando iteraciones de un bucle de 20 µs.
;;   2 vueltas a 300 rpm = 0,4 s = 20000 iteraciones
;;   rpm x 10 = 60000000 / iteraciones
;;
;; Cambio respecto al original: el bucle de espera se ha reordenado para
;; comprobar un límite de tiempo (65536 iteraciones, 1,3 s) sin cambiar su
;; duración de 20 µs; sin disco o sin motor, el original esperaba para
;; siempre.
;;
;; No se ha podido comprobar en una disquetera real con CPC Doctor: el
;; emulador de pruebas no reproduce la rotación del disco. Ver
;; docs/VALIDACION.md.
;;
;; Parte de CPC Doctor. Licencia MIT.

 MODULE DISKTEST

FDC_STATUS	EQU #FB7E
MOTOR_PORT	EQU #FA7E
RPM_OK		EQU 45			; ±4,5 rpm (1,5 %) en décimas
RPM_WARN	EQU 90			; ±9 rpm (3 %)

AUTO_DISK_MEASURES EQU 15		; unos 6 segundos

@DiskTestSelected:
	ld	a, (FDCPresent)
	or	a
	jr	nz, .hasFDC
	;; Sin controladora no hay nada que medir
	ld	a, TESTRESULT_NOTAVAILABLE
	ld	(TestResultTableDisk), a
	ld	hl, TxtDiskTitle
	ld	de, TxtDiskNoFDC
	call	ExplainScreen
	jp	MainMenuRepeat
.hasFDC:
	ld	hl, TxtDiskTitle
	ld	de, TxtDiskIntro
	call	ExplainScreen
	jp	z, MainMenuRepeat

	ld	hl, TxtDiskTitle
	call	PrintScreenTitle
	ld	hl, TxtDiskMeasuring
	call	PrintString
	ld	hl, TxtDiskStop
	call	PrintHint
	call	MotorOn
	;; Un segundo para que el motor coja velocidad
	ld	b, 50
	call	WaitFrames
	xor	a
	ld	(DiskMeasured), a
	ld	(DiskGoodCount), a
	ld	(DiskFailCount), a
	ld	a, AUTO_DISK_MEASURES
	ld	(AutoDiskLeft), a

.measure:
	call	MeasureRPM
	call	ShowRPM
	;; Si el FDC no ha respondido sigue ocupado: no se puede seguir midiendo
	ld	hl, (DiskCount)
	ld	a, h
	or	l
	jr	z, .finish
	ld	a, (AutoStep)			; modo automático: termina sola
	or	a
	jr	z, .askUser
	ld	hl, AutoDiskLeft
	dec	(hl)
	jr	z, .finish
.askUser:
	call	ReadInput
	and	(1 << UI.INPUT_OK) | (1 << UI.INPUT_BACK)
	jr	z, .measure
.finish:
	call	MotorOff
	call	WaitNoKeys
	call	DiskVerdict
	;; En el modo automático nadie ha metido un disco: si no llega el
	;; agujero índice, no se sabe si es una avería
	ld	a, (AutoStep)
	or	a
	jr	z, .verdictDone
	ld	a, (DiskMeasured)
	or	a
	jr	nz, .verdictDone
	ld	a, TESTRESULT_INCONCLUSIVE
	ld	(TestResultTableDisk), a
.verdictDone:
	call	DiskResultScreen
	jp	MainMenuRepeat


MotorOn:
	ld	bc, MOTOR_PORT
	ld	a, 1
	out	(c), a
	ret
MotorOff:
	ld	bc, MOTOR_PORT
	xor	a
	out	(c), a
	ret


;; OUT: DiskCount = iteraciones de dos vueltas (0 si no ha respondido)
MeasureRPM:
	call	ReadMissingSector		; sincroniza con el agujero índice
	ld	a, d
	or	e
	jr	z, .store			; no responde: no mandar más comandos
	call	ReadMissingSector		; mide
.store:
	ld	(DiskCount), de
	ret

;; Lanza READ DATA de un sector inexistente y espera la respuesta.
;; OUT: DE = iteraciones de 20 µs (0 si se agota el tiempo)
ReadMissingSector:
	ld	hl, ReadCommand
	ld	b, 9
.send:
	ld	a, (hl)
	inc	hl
	call	FdcSend
	djnz	.send
	ld	bc, FDC_STATUS
	ld	de, 0
	;; Bucle de 20 µs (unidades de 1 µs del CPC):
	;; in 4 + jp m 3 + inc 2 + ld 1 + or 1 + jr 2 + 4 nop + jp 3 = 20
.wait:
	in	a, (c)
	jp	m, .ready			; RQM: el FDC tiene el resultado
	inc	de
	ld	a, d
	or	e
	jr	z, .timeout
	nop
	nop
	nop
	nop
	jp	.wait
.timeout:
	;; El FDC sigue esperando el índice: sin disco o sin motor. Se reinicia
	;; el FDC apagando el motor para no dejarlo a medias.
	ld	de, 0
	ret
.ready:
	push	de
	call	FdcResult
	pop	de
	ret

ReadCommand:
	;; READ DATA (MFM), unidad 0, C=0 H=0 R=0 N=0, EOT=0, GPL=#2A, DTL=#FF
	db #46, #00, #00, #00, #00, #00, #00, #2A, #FF

;; Envía A al FDC. Conserva BC y HL.
FdcSend:
	push	bc
	push	af
	ld	bc, FDC_STATUS
.wait:
	in	a, (c)
	add	a, a				; RQM
	jr	nc, .wait
	add	a, a				; DIO: debe ser escritura
	jr	c, .skip
	pop	af
	inc	c
	out	(c), a
	ld	a, 5
.delay:
	dec	a
	jr	nz, .delay
	pop	bc
	ret
.skip:
	pop	af
	pop	bc
	ret

;; Lee los bytes de resultado del FDC y los descarta
FdcResult:
	ld	bc, FDC_STATUS
.next:
	in	a, (c)
	cp	#C0
	jr	c, .next
	inc	c
	in	a, (c)
	dec	c
	ld	a, 5
.delay:
	dec	a
	jr	nz, .delay
	in	a, (c)
	and	#10				; ¿quedan bytes?
	jr	nz, .next
	ret


;; Muestra las rpm de la última medida
ShowRPM:
	ld	l, 4
	ld	b, 6
	call	ClearTextRows
	ld	hl, #0004
	call	LocateWrap
	call	ComputeRPM
	jr	nc, .valid
	ld	hl, TxtDiskNoIndex
	call	PrintWrapped
	ld	hl, DiskFailCount
	inc	(hl)
	xor	a
	ld	(DiskGoodCount), a
	ret
.valid:
	ld	a, 1
	ld	(DiskMeasured), a
	ld	hl, TxtDiskSpeed
	call	PrintString
	ld	a, ' '
	call	PrintChar
	call	RPMColour
	call	PrintRPM
	call	SetDefaultColors
	call	IsRPMGood
	ld	hl, DiskGoodCount
	jr	nz, .bad
	inc	(hl)
	ret
.bad:
	ld	(hl), 0
	ret

;; rpm x 10 = 60000000 / DiskCount
;; OUT: DiskRPM10, carry si la medida no es válida
ComputeRPM:
	ld	hl, (DiskCount)
	ld	a, h
	cp	#10				; menos de 4096 iteraciones: > 1465 rpm
	ret	c				; (o el FDC no ha esperado al índice)
	ld	ix, (DiskCount)
	ld	iy, 60000000 / 65536
	ld	bc, 60000000 % 65536
	call	Div32by16
	ld	(DiskRPM10), bc
	or	a
	ret

;; OUT: A = |rpm x 10 - 3000| (saturado a 255)
RPMDeviation:
	ld	hl, (DiskRPM10)
	ld	de, 3000
	or	a
	sbc	hl, de
	bit	7, h
	jr	z, .pos
	xor	a
	sub	l
	ld	l, a
	sbc	a, a
	sub	h
	ld	h, a
.pos:
	ld	a, h
	or	a
	ld	a, l
	ret	z
	ld	a, 255
	ret

;; OUT: Z si la última medida está dentro de ±1,5 %
IsRPMGood:
	call	RPMDeviation
	cp	RPM_OK + 1
	jr	nc, .no
	xor	a
	ret
.no:
	or	1
	ret

RPMColour:
	call	RPMDeviation
	cp	RPM_OK + 1
	jp	c, SetSuccessColors
	cp	RPM_WARN + 1
	jp	c, SetWarningColors
	jp	SetErrorColors

;; "300,4 rpm"
PrintRPM:
	ld	hl, (DiskRPM10)
	ld	de, 10
	call	Div16by8
	push	af				; décimas
	call	PrintHLDec
	ld	a, ','
	call	PrintChar
	pop	af
	add	a, '0'
	call	PrintChar
	ld	hl, TxtDiskRPM
	jp	PrintString

;; HL = HL / E, A = resto
Div16by8:
	xor	a
	ld	b, 16
.loop:
	add	hl, hl
	rla
	cp	e
	jr	c, .next
	sub	e
	inc	l
.next:
	djnz	.loop
	ret


;; Superado si hay 3 medidas buenas seguidas; error si nunca responde o se
;; sale de ±3 %; inconcluso en otro caso.
DiskVerdict:
	ld	a, (DiskMeasured)
	or	a
	ld	a, TESTRESULT_FAILED
	jr	z, .set
	ld	a, (DiskGoodCount)
	cp	3
	ld	a, TESTRESULT_PASSED
	jr	nc, .set
	call	RPMDeviation
	cp	RPM_WARN + 1
	ld	a, TESTRESULT_FAILED
	jr	nc, .set
	ld	a, TESTRESULT_INCONCLUSIVE
.set:
	ld	(TestResultTableDisk), a
	ret


DiskResultScreen:
	ld	hl, TxtDiskTitle
	call	PrintScreenTitle
	ld	hl, TxtMeasured
	call	PrintHeader
	ld	hl, #0003
	call	LocateWrap
	ld	a, (DiskMeasured)
	or	a
	jr	z, .noMeasure
	ld	hl, TxtDiskSpeed
	call	PrintString
	ld	a, ' '
	call	PrintChar
	call	RPMColour
	call	PrintRPM
	call	SetDefaultColors
	call	WrapNewLine
.noMeasure:
	call	WrapNewLine
	ld	a, (TestResultTableDisk)
	call	PrintResultLine
	call	WrapNewLine
	call	WrapNewLine
	ld	a, (DiskMeasured)
	or	a
	ld	hl, TxtDiskAdvNoIndex
	jr	z, .advice
	ld	a, (TestResultTableDisk)
	cp	TESTRESULT_PASSED
	ld	hl, TxtDiskAdvOk
	jr	z, .advice
	ld	hl, TxtDiskAdvSpeed
.advice:
	call	PrintWrapped
	ld	hl, TxtPressOKToReturn
	call	PrintHint
	jp	WaitOK


;; División de 32 entre 16 bits, del fork de issalig (código de dominio
;; público muy extendido).
;; IN: IY:BC = dividendo, IX = divisor  OUT: IY:BC = cociente, HL = resto
Div32by16:
	ld	hl, 0
	ld	a, ixl
	or	ixh
	ret	z
	ld	de, 0
	ld	a, 32
.loop:
	ld	(DivCounter), a
	rl	c
	rl	b
	ld	a, iyl
	rla
	ld	iyl, a
	ld	a, iyh
	rla
	ld	iyh, a
	rl	l
	rl	h
	rl	e
	rl	d
	ld	a, l
	sub	ixl
	ld	l, a
	ld	a, h
	sbc	a, ixh
	ld	h, a
	ld	a, e
	sbc	a, 0
	ld	e, a
	ld	a, d
	sbc	a, 0
	ld	d, a
	jr	nc, .fits
	ld	a, l
	add	a, ixl
	ld	l, a
	ld	a, h
	adc	a, ixh
	ld	h, a
	ld	a, e
	adc	a, 0
	ld	e, a
	ld	a, d
	adc	a, 0
	ld	d, a
	scf
.fits:
	ccf
	ld	a, (DivCounter)
	dec	a
	jr	nz, .loop
	rl	c
	rl	b
	ld	a, iyl
	rla
	ld	iyl, a
	ld	a, iyh
	rla
	ld	iyh, a
	ret

 ENDMODULE
