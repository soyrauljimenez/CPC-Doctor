 MODULE FDC


AMSTRAD_FDC_PORT EQU #FB7E		;; I/O address for main status register of NEC765 in Amstrad controller
VORTEX_FDC_PORT EQU #FBF6

@IsAmstradFDCPresent:
	ld	bc, AMSTRAD_FDC_PORT
	ld	d, 0			;; orden no válida: debe responder #80
	call	FDCOneByteCommand
	ret	c
	cp	#80
	ret	z
	scf
	ret

 IFDEF GUIDED
;; Versión de la controladora. La orden VERSION (#10) no existe en el
;; µPD765A ni en sus clones (Zilog Z0765A, UMC UM8272A...), que responden
;; "orden no válida" (#80), como los del DDI-1, el 664 y el 6128. El
;; µPD765B y los posteriores responden #90.
;; OUT: FDCVersion = byte de respuesta (0 si no ha respondido)
@DetectFDCVersion:
	ld	bc, AMSTRAD_FDC_PORT
	ld	d, #10
	call	FDCOneByteCommand
	jr	nc, .store
	xor	a
.store:
	ld	(FDCVersion), a
	ret
 ENDIF


;; http://www.cpcwiki.eu/index.php?title=Programming:Detecting_an_Amstrad_or_Vortex_disc_controler

;;-----------------------------------------------------------------
;; Entry conditions:
;; BC = I/O address for FDC main status register
;; D = orden de un solo byte (0, no válida, para detectar la controladora)
;;
;; Exit conditions:
;; carry flag set -> no ha respondido
;; carry flag clear -> A = primer byte de la fase de resultado
;;
;; assumes:
;; - I/O port for read data = I/O port for write data
;; - I/O port for read data = I/O port for write data = I/O port for main status register + 1
;; - FDC is not executing a command at this time
;;
;; Attempts to execute a invalid command.

FDCOneByteCommand:
	;; initialise timeout
	ld 	e, 0

.df1:
	;; read main status register
	in 	a, (c)
	;; isolate flags we are interested in
	and 	%11110000
	;; test for the following flags:
	;; - Data register of FDC is ready for data transfer
	;; - Data transfer direction is from CPU->FDC
	;; - Not in Execution Mode
	;; - FDC not busy
	cp 	%10000000
	jr 	z, .df2

	;; decrease timeout
	dec 	e
	jr 	nz, .df1
	;; failed
	scf
	ret

.df2:
	;; ok... FDC is ready to accept a command
	;; write the "invalid" command
	inc 	c
	;; BC = I/O address of FDC data register

	ld	a, d
	;; write to FDC data register
	out 	(c), a
	dec 	c
	;; BC = I/O address of FDC main status register

	;; wait for fdc to become busy
	ld 	e,0
.df3:
	;; read main status register
	in 	a, (c)
	and 	%00010000
	jr 	nz, .df4

	dec 	e
	jr 	nz, .df3
	;; failed
	scf
	ret

.df4:
	;; saw fdc become busy

	;; wait for execution phase
	ld 	e, 0
.df5:
	in 	a, (c)
	and 	%11110000
	;; test for the following flags:
	;; - Data register of FDC is ready for data transfer
	;; - Data transfer direction is from CPU->FDC
	;; - Not in Execution Mode
	;; - FDC busy
	cp 	%11010000
	jr 	z, .df6
	dec 	e
	jr 	nz, .df5

	;; failed
	scf
	ret

.df6:
	;; ok saw start of result phase
	inc 	c
	;; BC = I/O address of FDC data register

	;; read result phase data
	in 	a, (c)
	dec 	c
	or	a			;; carry a 0: ha respondido
	ret

 ENDMODULE
