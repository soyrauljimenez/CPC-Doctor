

SelectedMenuItem: db 0
ModelConfirmed: db 0				; modelo que ha dicho el usuario (0 = ninguno)


TESTRESULT_UNTESTED 	EQU 0
TESTRESULT_PASSED 	EQU 1
TESTRESULT_FAILED 	EQU 2
TESTRESULT_ABORTED 	EQU 3
TESTRESULT_NOTAVAILABLE EQU 4
TESTRESULT_INCONCLUSIVE EQU 5


TestResultTable:
;; 0 - status
TestResultTableLowerRAM:
 IFDEF GUIDED
	db TESTRESULT_UNTESTED			; se prueba desde el menú
 ELSE
	db TESTRESULT_PASSED			; si no, no habríamos llegado aquí
 ENDIF
TestResultTableUpperRAM:
	db TESTRESULT_UNTESTED
 IFDEF ROM_CHECK
TestResultTableLowerROM:
	db TESTRESULT_UNTESTED
TestResultTableUpperROM:
	db TESTRESULT_UNTESTED
 ELSE
TestResultTableLowerROM:
	db TESTRESULT_NOTAVAILABLE
TestResultTableUpperROM:
	db TESTRESULT_NOTAVAILABLE
 ENDIF
TestResultTableKeyboard:
	db TESTRESULT_UNTESTED
TestResultTableJoystick:
	db TESTRESULT_UNTESTED
TestResultTableVideo:
	db TESTRESULT_UNTESTED
TestResultTableSound:
	db TESTRESULT_UNTESTED
TestResultTableTape:
	db TESTRESULT_UNTESTED
TestResultTableDisk:
	db TESTRESULT_UNTESTED
