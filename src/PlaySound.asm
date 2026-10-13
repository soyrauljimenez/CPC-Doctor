	;; Activate B channel (y A en la versión cargada)
	ld bc,#F407 ;;<< register
	out (c),c
	ld bc,#F6c0 ;;<<<<<< select register
	out (c),c
	ld bc,#F600
	out (c),c ;; << back to inactive

 IFDEF GUIDED
	;; Versión cargada: canales A y B a la vez, para oírlo siempre aunque
	;; falle uno de los dos (visto: generador de tono B que falla a ratos)
	ld bc,#F400 + %10111100 ;; << data: tono A y B
 ELSE
	ld bc,#F400 + %10111000 + SOUND_CHANNEL ;; << data
 ENDIF
	out (c),c
	ld bc,#F680 ;; << write data to register
	out (c),c
	ld bc,#F600
	out (c),c

	;; Select note for B channel
	ld bc,#F402 ;;<< register
	out (c),c
	ld bc,#F6c0 ;;<<<<<< select register
	out (c),c
	ld bc,#F600
	out (c),c ;; << back to inactive

	ld bc,#F400 + SOUND_TONE_L ;; << data
	out (c),c
	ld bc,#F680 ;; << write data to register
	out (c),c
	ld bc,#F600
	out (c),c

	ld bc,#F403 ;;<< register
	out (c),c
	ld bc,#F6c0 ;;<<<<<< select register
	out (c),c
	ld bc,#F600
	out (c),c ;; << back to inactive

	ld bc,#F400 + SOUND_TONE_H ;; << data
	out (c),c
	ld bc,#F680 ;; << write data to register
	out (c),c
	ld bc,#F600
	out (c),c

	;; Select volume for B channel
	ld bc,#F409 ;;<< register
	out (c),c
	ld bc,#F6c0 ;;<<<<<< select register
	out (c),c
	ld bc,#F600
	out (c),c ;; << back to inactive

	ld bc,#F400 + %00000111 ;; << data
	out (c),c
	ld bc,#F6A0 ;; << write data to register
	out (c),c
	ld bc,#F600
	out (c),c

 IFDEF GUIDED
	;; Mismo tono y volumen en el canal A
	ld bc,#F400 ;;<< register 0
	out (c),c
	ld bc,#F6c0
	out (c),c
	ld bc,#F600
	out (c),c
	ld bc,#F400 + SOUND_TONE_L
	out (c),c
	ld bc,#F680
	out (c),c
	ld bc,#F600
	out (c),c

	ld bc,#F401 ;;<< register 1
	out (c),c
	ld bc,#F6c0
	out (c),c
	ld bc,#F600
	out (c),c
	ld bc,#F400 + SOUND_TONE_H
	out (c),c
	ld bc,#F680
	out (c),c
	ld bc,#F600
	out (c),c

	ld bc,#F408 ;;<< register 8: volumen A
	out (c),c
	ld bc,#F6c0
	out (c),c
	ld bc,#F600
	out (c),c
	ld bc,#F400 + %00000111
	out (c),c
	ld bc,#F680
	out (c),c
	ld bc,#F600
	out (c),c
 ENDIF

	ld bc,SOUND_DURATION
1
	dec bc
	ld a,b
	or c
	jr nz,1B

	;; Deactivate B channel
	ld bc,#F407 ;;<< register
	out (c),c
	ld bc,#F6c0 ;;<<<<<< select register
	out (c),c
	ld bc,#F600
	out (c),c ;; << back to inactive

	ld bc,#F400 + %10111111 ;; << data
	out (c),c
	ld bc,#F680 ;; << write data to register
	out (c),c
	ld bc,#F600
	out (c),c

	ld bc,SILENCE_DURATION
2:
	dec bc
	ld a,b
	or c
	jr nz,2B
