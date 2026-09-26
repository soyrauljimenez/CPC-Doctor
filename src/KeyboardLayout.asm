

@KEYBOARD_LAYOUT_464	EQU 0
@KEYBOARD_LAYOUT_6128	EQU 1
@KEYBOARD_LAYOUT_MATRIX	EQU 2

@KEYBOARD_LANGUAGE_ENGLISH EQU 0
@KEYBOARD_LANGUAGE_SPANISH EQU 1
@KEYBOARD_LANGUAGE_FRENCH EQU 2


KEY_HEIGHT EQU 15


; IN	KeyboardLayout - Layout to set
SetKeyboardTables:
	ld	a, (KeyboardLayout)
	cp	KEYBOARD_LAYOUT_MATRIX
	jr	z, .layoutMatrix

	cp	KEYBOARD_LAYOUT_6128
	jr	z, .layout6128

.layout464:
	ld	hl, KeyboardLocations464
	ld 	(KeyboardLocationTable), hl
	ld	hl, SpecialKeysTable464
	ld 	(SpecialKeysTable), hl
	jr	.setLabels

.layout6128:
	ld	hl, KeyboardLocations6128
	ld 	(KeyboardLocationTable), hl
	ld	hl, SpecialKeysTable6128
	ld 	(SpecialKeysTable), hl
	jr	.setLabels

.layoutMatrix:
	ld	hl, KeyboardLocationsMatrix
	ld 	(KeyboardLocationTable), hl
	ld	hl, SpecialKeysTableMatrix
	ld 	(SpecialKeysTable), hl
	jr	.setLabels

.setLabels:
	ld	hl, KeyboardLabelsEnglish
	ld	de, KeyboardLabels
	ld	bc, KeyboardLabelsTableSize
	ldir

	ld	ix, KeyboardLabels
	ld	a, (KeyboardLanguage)
	cp	KEYBOARD_LANGUAGE_SPANISH
	jr	z, .patchSpanishLabels

	cp	KEYBOARD_LANGUAGE_FRENCH
	jr	z, .patchFrenchLabels

	ret

.patchSpanishLabels:
	ld	(ix+29), #86		; Ñ
	ret

.patchFrenchLabels:
	ld	(ix+25), ')'
	ld	(ix+24), '-'

	ld	(ix+67), 'A'
	ld	(ix+59), 'Z'
	ld	(ix+26), '^'
	ld	(ix+17), '*'

	ld	(ix+69), 'Q'
	ld	(ix+29), 'M'
	ld	(ix+28), #8A		; ù
	ld	(ix+19), '#'

	ld	(ix+71), 'W'
	ld	(ix+38), ','
	ld	(ix+39), ';'
	ld	(ix+31), ':'
	ld	(ix+30), '='
	ld	(ix+22), '$'

	ret



KEYB_TABLE_ROW_SIZE EQU 2
RIGHTSHIFT_TABLE_OFFSET EQU KEY_COUNT*KEYB_TABLE_ROW_SIZE

KEYB_ROW_SPACING EQU KEY_HEIGHT + 1
KEYB_COL_SPACING EQU 4

 DEFINE KEYB_ROW_1 KEYB_Y
 DEFINE KEYB_ROW_2 KEYB_ROW_1 + KEYB_ROW_SPACING
 DEFINE KEYB_ROW_3 KEYB_ROW_2 + KEYB_ROW_SPACING
 DEFINE KEYB_ROW_4 KEYB_ROW_3 + KEYB_ROW_SPACING
 DEFINE KEYB_ROW_5 KEYB_ROW_4 + KEYB_ROW_SPACING
 DEFINE KEYB_ROW_6 KEYB_ROW_5 + KEYB_ROW_SPACING
 DEFINE KEYB_ROW_7 KEYB_ROW_6 + KEYB_ROW_SPACING
 DEFINE KEYB_ROW_8 KEYB_ROW_7 + KEYB_ROW_SPACING
 DEFINE KEYB_ROW_9 KEYB_ROW_8 + KEYB_ROW_SPACING
 DEFINE KEYB_ROW_10 KEYB_ROW_9 + KEYB_ROW_SPACING




SPECIALKEY_FIRST	EQU #E0		; Los códigos #80-#DF son caracteres de la fuente
SPECIALKEY_RETURN	EQU 0 + SPECIALKEY_FIRST
SPECIALKEY_SPACE 	EQU 1 + SPECIALKEY_FIRST
SPECIALKEY_CONTROL 	EQU 2 + SPECIALKEY_FIRST
SPECIALKEY_COPY		EQU 3 + SPECIALKEY_FIRST
SPECIALKEY_CAPS		EQU 4 + SPECIALKEY_FIRST
SPECIALKEY_TAB		EQU 5 + SPECIALKEY_FIRST
SPECIALKEY_ENTER	EQU 6 + SPECIALKEY_FIRST
SPECIALKEY_SHIFTL	EQU 7 + SPECIALKEY_FIRST
SPECIALKEY_SHIFTR	EQU 8 + SPECIALKEY_FIRST
SPECIALKEY_DEL		EQU 9 + SPECIALKEY_FIRST

; Los símbolos de teclas especiales están en #90-#9E (ver Font.asm)


TxtKeySpace: 		db '       SPACE',0
TxtKeySpaceShort:	db ' ',0
TxtKeyShiftL: 		db 'SHFT',0
TxtKeyShiftR: 		db 'SHF',0
TxtKeyShiftShort:	db #9B,0
TxtKeyControl: 		db 'CTRL',0
TxtKeyControlShort:	db #9C,0
TxtKeyCopy: 		db 'COPY',0
TxtKeyCopyShort: 	db #9E,0
TxtKeyCaps: 		db 'CAP',0
TxtKeyCapsShort:	db #9A,0
TxtKeyTab: 		db '->',0
TxtKeyTabShort:		db #99,0
TxtKeyEnter: 		db 'ENTER',0
TxtKeyEnterShort: 	db #95,0
TxtKeyDel:		db 'DE',0
TxtKeyDelShort:		db #98,0
TxtKeyReturn: 		db ' ',#94,0



 INCLUDE "KeyboardLayout6128.asm"
 INCLUDE "KeyboardLayout464.asm"
 INCLUDE "KeyboardLayoutMatrix.asm"

