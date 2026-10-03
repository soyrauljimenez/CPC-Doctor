

 IFDEF UpperROMBuild
UpperROMConfig: db 0				; Here we store the upper ROM we were launched from
 ENDIF

;; System info
ModelType: db 0
ModelDoubt: db 0				; 1: ROM de 6128 sin RAM alta
KeyboardLanguage: db 0
FDCPresent: db 0
VendorName: db 0
RefreshFrequency: db 0
CRTCType: db 0
PSGType: db 0					; 0 = AY-3-8912, 1 = YM2149

;; Upper RAM test
ValidBankCount: db 0
FailingBits: db 0
C3ConfigFailed: db 0
UpperBankMap: ds 8				; Un bit por banco de 64 KB, un byte por tramo de 512 KB
HighestBankId: db 0
FailingBankCount: db 0
SavedMain4000: dw 0

;; ROM test
ROMStringBuffer: ds 16

;; Soak test
SoakTestIndicator: ds 4				; Save 4 bytes
SoakTestCount: db 0

;; Sound test
MixerDataPtr: dw 0
SoundTestY: db 0

;; Keyboard test
KeyboardLayout: db 0				; 0: 6128, 1: 464
FramesESCPressed: db 0
FillKeyPattern: db 0
KeyboardLocationTable: dw 0
SpecialKeysTable: dw 0
KeyboardLabels: ds KeyboardLabelsTableSize	; Copy of the labels, patched up with correct language variations
;;KeyboardResult: ds

;; Keyboard
;; This buffer has one byte per keyboard line.
;; Each byte defines a single keyboard line, which defines
;; the state for up to 8 keys.
;;
;; A bit in a byte will be '1' if the corresponding key
;; is pressed, '0' if the key is not pressed.

KeyboardBufferSize equ 10
KeyboardMatrixBuffer: 	     defs KeyboardBufferSize
LastKeyboardMatrixBuffer:    defs KeyboardBufferSize
EdgeOnKeyboardMatrixBuffer:  defs KeyboardBufferSize
EdgeOffKeyboardMatrixBuffer: defs KeyboardBufferSize
PresseddMatrixBuffer: 	     defs KeyboardBufferSize

;; Print char
@TxtCoords:
@txt_y: defb 0
@txt_x: defb 0
@txt_pixels_y: defb 0
@txt_byte_x: defb 0
@txt_right: db 0			; 0 = draw left char at that byte, 1 = draw right char

@bk_color: db 0
@fg_color: db 0
bk_all: db 0
fg_all: db 0

@scr_table: defs 200*2
char_depack_buffer: defs 16

;; Interfaz (UI.asm)
InputFlags: db 0
NumberPressed: db 0
WrapLeft: db 0
WrapRight: db 0
ChooseTable: dw 0
ChoosePos: dw 0
ChooseSelected: db 0
ChooseCount: db 0
InfoRow: dw 0

;; Prueba de sonido guiada
SoundStep: db 0
SoundAnswers: ds 5
SoundNoCount: db 0

;; Prueba de teclado guiada
StuckMatrixBuffer: ds 10
FlakyMatrixBuffer: ds 10
PrevOff1Buffer: ds 10
PrevOff2Buffer: ds 10
KbTempBuffer: ds 10
KbPressedCount: db 0
KbStuckCount: db 0
KbFlakyCount: db 0
KbPatternFound: db 0

;; Prueba de imagen guiada
DisplayType: db 0
VideoStep: db 0
VideoAnswers: ds 8
FillByte: db 0

;; Resumen
SumRow: dw 0

;; RAM baja (versión cargada)
BlockStatus: ds 64
LowRAMFailBits: db 0

;; Prueba de cassette
TapeEdges: dw 0
TapeMinFrame: db 0
TapeMaxFrame: db 0
TapeSpeed: dw 0
TapeQuality: db 0
TapeGoodCount: db 0
TapeMeasured: db 0
TapeHasSignal: db 0
TapeStop: db 0
TapeKeyRow: db 0

;; Barra de título del menú
TitleBuffer: ds 48
RAMBlockCopied: db 0

;; Tipo de Z80 (Z80Detect.asm)
Z80Type: db 0
Z80Flavor: db 0
Z80XcfResults: ds 12

;; Disquetera (DiskTest.asm)
DiskCount: dw 0
DiskRPM10: dw 0
DiskMeasured: db 0
DiskGoodCount: db 0
DiskFailCount: db 0
DivCounter: db 0

;; Teclas que se encienden a la vez (KeyboardGuide.asm)
KbEdgeCount: db 0
KbEdges: ds 4
KbPairs: ds 12 * 5
