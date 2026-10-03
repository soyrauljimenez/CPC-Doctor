 MODULE SYSTEMINFO

@DetectSystemInfo:
	;; Try to detect the model and language
	call	CalculateTotalUpperRAM
	call	DetectModel

	;; ROM de 6128 sin RAM alta: puede ser un 464 o un 664 con la ROM del
	;; 6128, o un 6128 con la RAM alta averiada. No se puede saber: se marca
	;; como dudoso (y la versión guiada lo pregunta).
	xor	a
	ld	(ModelDoubt), a
	ld	a, (ModelType)
	cp	MODEL_CPC6128
	jr	nz, .noDoubt
	ld	a, (ValidBankCount)
	or	a
	jr	nz, .noDoubt
	inc	a
	ld	(ModelDoubt), a
.noDoubt:
	;; Lo que haya contestado el usuario manda sobre lo detectado
	ld	a, (ModelConfirmed)
	or	a
	jr	z, .notConfirmed
	ld	(ModelType), a
	xor	a
	ld	(ModelDoubt), a
.notConfirmed:
	call    DetectVendor
	call    DetectFrequency

	;; From the model, determine the keyboard layout
	ld	a, (ModelType)
	cp	MODEL_CPC6128
	jr	c, .set464Layout
	ld	a, KEYBOARD_LAYOUT_6128
	jr	.setLayout
.set464Layout:
	ld	a, KEYBOARD_LAYOUT_464
.setLayout:
	ld	(KeyboardLayout), a

	call	GetCRTCType
	ld	(CRTCType), a

	call	DetectPSG
	ld	(PSGType), a
 IFDEF GUIDED
	call	TestZ80CMOS
	call	TestZ80Flavor
 ENDIF

	xor	a
	ld	(FDCPresent), a
	call	IsAmstradFDCPresent
	jr	c, .noFDC

	ld	a, 1
	ld	(FDCPresent), a
 IFDEF GUIDED
	call	DetectFDCVersion
 ENDIF

.noFDC:

	ret



;; Distingue el AY-3-8912 del YM2149: el registro 1 del AY solo guarda
;; 4 bits; el YM devuelve el valor completo.
;; OUT: A = 0 AY, 1 YM
DetectPSG:
	ld	a, #01
	ld	l, #1F
	call	AYRegWriteByte
	ld	a, #01
	call	AYRegReadByte
	cp	#1F
	ld	a, 1
	ret	z
	xor	a
	ret

 ENDMODULE
