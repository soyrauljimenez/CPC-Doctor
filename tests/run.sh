#!/bin/sh
# Pruebas automáticas de CPC Doctor en el emulador sin interfaz.
#
#   tests/run.sh           compila y ejecuta todas las pruebas
#
# Cada prueba arranca un CPC emulado, pulsa teclas, lee el texto de la
# pantalla (tools/screentext.py) y comprueba que aparecen los textos
# esperados. Las capturas quedan en tests/out/ para revisarlas.
#
# Lo que NO se puede comprobar aquí (ver docs/VALIDACION.md): CRTC distintos
# del tipo 1, CPC Plus, expansiones reales, monitores y sonido.
set -e
cd "$(dirname "$0")/.."
[ -x tools/emu/cpcemu ] || tools/emu/build.sh
[ -f build/dist/cpcdoctor-es.dsk ] || ./build.sh >/dev/null
OUT=tests/out
rm -rf $OUT
mkdir -p $OUT
EMU=tools/emu/cpcemu
PASS=0
FAIL=0

# check NOMBRE "texto esperado" ["otro texto" ...]  (lee $OUT/NOMBRE.vram)
check() {
	name=$1; shift
	python3 tools/screentext.py $OUT/$name.vram > $OUT/$name.txt
	for expected in "$@"; do
		if grep -qF -- "$expected" $OUT/$name.txt; then
			PASS=$((PASS + 1))
		else
			FAIL=$((FAIL + 1))
			echo "FALLO  $name: no aparece \"$expected\""
			sed 's/^/        | /' $OUT/$name.txt
		fi
	done
	echo "ok     $name"
}

DISK_ES="-m 6128 -d build/dist/cpcdoctor-es.dsk"
BOOT='wait 150 type run"doctor~ wait 400'

# ---------------------------------------------------------------- arranque
$EMU $DISK_ES $BOOT vram $OUT/menu6128.vram shot $OUT/menu6128.png
check menu6128 "CPC 6128" "128KB" "AY-3-8912" "1. Teclado y joystick" "5. Disquetera" "0. Resumen final"

# ---------------------------------------------------------------- RAM alta
$EMU $DISK_ES $BOOT key 5:1 wait 900 vram $OUT/upperram.vram shot $OUT/upperram.png
check upperram "RAM alta encontrada: 64KB" "Prueba de la RAM alta superada" "Configuración C3: admitida"

# ---------------------------------------------------------------- RAM baja
$EMU $DISK_ES $BOOT key 6:0 wait 80 key 2:2 wait 600 vram $OUT/lowerram.vram shot $OUT/lowerram.png
check lowerram "KB de 64 KB." "Resultado: Superado"

# Chip de RAM dañado: el bit 3 se lee siempre a 0 en #B000-#B3FF
$EMU $DISK_ES $BOOT fault B000 400 08 key 6:0 wait 80 key 2:2 wait 600 vram $OUT/lowerramfault.vram shot $OUT/lowerramfault.png
check lowerramfault "Resultado: Error bits 03" " X "

# ---------------------------------------------------------------- disquetera
# El emulador no reproduce el giro del disco: solo se comprueba que la prueba
# termina y avisa en vez de quedarse esperando
$EMU $DISK_ES $BOOT key 6:1 wait 150 key 2:2 wait 300 vram $OUT/disk.vram shot $OUT/disk.png
check disk "LO QUE SE HA MEDIDO" "Resultado:"

# ---------------------------------------------------------------- ROMs
$EMU $DISK_ES $BOOT key 5:0 wait 800 vram $OUT/roms.vram shot $OUT/roms.png
check roms "OS 6128 EN (B360)" "6128 BASIC EN (CAA0)" "AMSDOS (0F91)"

# ---------------------------------------------------------------- teclado
# La tecla C atascada desde el principio; se pulsa Q y se sale con ESC
$EMU $DISK_ES $BOOT key 8:0 wait 100 hold 7:6 wait 20 key 2:2 wait 250 key 8:3 wait 20 hold 8:2 wait 80 release 8:2 wait 60 vram $OUT/keyboard.vram shot $OUT/keyboard.png
check keyboard "Teclas que han respondido: 2/73" "Pulsadas desde el principio (atascadas): C" "Resultado: Inconcluso"

# Líneas 0 y 1 de la matriz unidas (visto en un 464 real): una tecla enciende
# también la de la misma columna en la otra línea. Se imita pulsando las dos
# en el mismo cuadro, dos veces.
$EMU $DISK_ES $BOOT key 8:0 wait 150 key 2:2 wait 250 hold 0:2 hold 1:2 wait 4 release 0:2 release 1:2 wait 20 hold 0:2 hold 1:2 wait 4 release 0:2 release 1:2 wait 20 hold 8:2 wait 80 release 8:2 wait 80 vram $OUT/keyjoined.vram shot $OUT/keyjoined.png
check keyjoined "(líneas 0 y 1)" "Resultado: Error" "líneas de la matriz están unidas"

# ---------------------------------------------------------------- sonido
# Las respuestas del 464 real con el tono B averiado: A sí, B no, C sí,
# ruido sí, volumen no
$EMU $DISK_ES $BOOT key 7:1 wait 100 key 2:2 wait 130 key 8:0 wait 130 key 8:1 wait 130 key 8:0 wait 130 key 8:0 wait 130 key 8:1 wait 100 vram $OUT/soundtoneb.vram shot $OUT/soundtoneb.png
check soundtoneb "Resultado: Error" "generador de tono B"

# ---------------------------------------------------------------- salir al BASIC
$EMU $DISK_ES $BOOT key 8:2 wait 40 key 8:0 wait 200 shot $OUT/basic.png vram $OUT/basic.vram
python3 - $OUT/basic.vram <<'PY' && { PASS=$((PASS + 1)); echo "ok     basic"; } || { FAIL=$((FAIL + 1)); echo "FALLO  basic: no ha vuelto al BASIC"; }
import sys
v = open(sys.argv[1], 'rb').read()
sys.exit(0 if any(v) and v.count(0) > 12000 else 1)   # pantalla del firmware: casi toda vacía
PY

# ---------------------------------------------------------------- resumen
$EMU $DISK_ES $BOOT key 4:0 wait 80 vram $OUT/summary.vram shot $OUT/summary.png
check summary "CPC 6128, 128KB, CRTC 1, AY-3-8912" "PENDIENTE:" "Código: 09A-3-01-"

# ---------------------------------------------------------------- inglés, 464 y cinta
$EMU -m 464 -t build/dist/cpcdoctor-en.cdt wait 150 type 'run"~' wait 20 key 5:7 wait 15000 vram $OUT/tape464.vram shot $OUT/tape464.png
check tape464 "CPC 464" "64KB" "Upper RAM : Not available" "4. Cassette"

# Prueba de cassette con el motor un 5 % lento (la cinta sigue tras el programa)
$EMU -m 464 -v 105 -t build/dist/cpcdoctor-es.cdt wait 150 type 'run"~' wait 20 key 5:7 wait 15500 key 7:0 wait 80 key 2:2 wait 300 vram $OUT/cassette.vram shot $OUT/cassette.png
check cassette "Velocidad: -4," "Estabilidad: 100%"

# Prueba continua en un 464 sin RAM alta: debe dar vueltas (antes se colgaba)
SOAKCOUNT=$(grep -E "^\s*[0-9]+\+?\s+[0-9A-F]{4}\s.*SoakTestCount:" build/es/RAMBuild.lst | awk '{print $2}')
$EMU -m 464 -t build/dist/cpcdoctor-es.cdt wait 150 type 'run"~' wait 20 key 5:7 wait 15000 key 4:1 wait 2500 peek $SOAKCOUNT vram $OUT/soak464.vram shot $OUT/soak464.png > $OUT/soak464.peek
if [ $((0x$(awk '{print $2}' $OUT/soak464.peek))) -ge 3 ]; then PASS=$((PASS + 1)); echo "ok     soak464 ($(cat $OUT/soak464.peek))"; else FAIL=$((FAIL + 1)); echo "FALLO  soak464: menos de 3 vueltas ($(cat $OUT/soak464.peek))"; fi

# Prueba continua con un chip de RAM dañado: debe pararse y decirlo
$EMU $DISK_ES $BOOT fault B000 400 08 key 4:1 wait 700 vram $OUT/soakfault.vram shot $OUT/soakfault.png
check soakfault "Prueba detenida por un error en la vuelta 1"

# 464 con las ROM del 6128 (ampliación habitual): debe preguntar el modelo
head -c 16384 tools/emu/roms/cpc6128.rom > $OUT/os6128.rom
tail -c 16384 tools/emu/roms/cpc6128.rom > $OUT/basic11.rom
$EMU -m 464 -o $OUT/os6128.rom -b $OUT/basic11.rom -t build/dist/cpcdoctor-es.cdt wait 200 type 'run"~' wait 20 key 5:7 wait 15000 vram $OUT/modeldoubt.vram key 8:0 wait 100 vram $OUT/modelconfirmed.vram shot $OUT/modelconfirmed.png
check modeldoubt "La ROM de este ordenador es la de un CPC 6128" "1. CPC 464"
check modelconfirmed "Modelo    : CPC 464" "RAM alta  : No disponible"

# Tras una vuelta de prueba continua se conservan el modelo y los resultados
$EMU -m 464 -o $OUT/os6128.rom -b $OUT/basic11.rom -t build/dist/cpcdoctor-es.cdt wait 200 type 'run"~' wait 20 key 5:7 wait 15000 key 8:0 wait 100 key 4:1 wait 1200 hold 8:2 wait 400 release 8:2 wait 150 key 4:0 wait 100 vram $OUT/aftersoak.vram shot $OUT/aftersoak.png
check aftersoak "CPC 464, 64KB" "RAM alta : No disponible" "Sonido," "Cassette" 

# ---------------------------------------------------------------- ROM baja
$EMU -m 464 -o build/dist/cpcdoctor-es-lower.rom wait 700 vram $OUT/lowerrom.vram shot $OUT/lowerrom.png
check lowerrom "CPC Doctor V0.9L" "RAM baja  : Superado" "6. Prueba continua"

# ---------------------------------------------------------------- tono de calibración
# El WAV de audio/ debe ser un tono de 2000 Hz de unos dos minutos
python3 - audio/cpcdoctor-tono-2000hz.wav <<'PY' && { PASS=$((PASS + 1)); echo "ok     tono"; } || { FAIL=$((FAIL + 1)); echo "FALLO  tono: el WAV no es un tono de 2000 Hz"; }
import sys, wave
w = wave.open(sys.argv[1])
data = w.readframes(w.getnframes())
level = [b > 0x80 for b in data if b != 0x80]          # sin los silencios
edges = sum(1 for a, b in zip(level, level[1:]) if a != b)
seconds = len(level) / w.getframerate()
freq = edges / 2 / seconds
print(f"       {freq:.1f} Hz, {seconds:.0f} s")
sys.exit(0 if abs(freq - 2000) < 5 and seconds > 110 else 1)
PY

echo
echo "$PASS comprobaciones correctas, $FAIL fallidas"
[ $FAIL -eq 0 ]
