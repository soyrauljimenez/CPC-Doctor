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
# Mientras carga la cinta se pulsa de vez en cuando el cursor derecha (no hace
# nada en el menú) para que no salte el modo automático de los 30 s
TAPEWAIT=$(for i in $(seq 17); do printf ' wait 1000 key 0:1'; done)
BOOT='wait 150 type run"doctor~ wait 400'

# ---------------------------------------------------------------- arranque
$EMU $DISK_ES $BOOT vram $OUT/menu6128.vram shot $OUT/menu6128.png
check menu6128 "CPC 6128" "128KB" "AY-3-8912" "Disquetera: Sí (765A)" "1. Teclado y joystick" "5. Disquetera" "0. Resumen final"

# Controladora que responde a la orden VERSION (µPD765B o posterior)
$EMU $DISK_ES fdcb $BOOT vram $OUT/fdc765b.vram
check fdc765b "Disquetera: Sí (765B)"

# ---------------------------------------------------------------- RAM alta
$EMU $DISK_ES $BOOT key 5:1 wait 900 vram $OUT/upperram.vram shot $OUT/upperram.png
check upperram "RAM alta encontrada: 64KB" "Prueba de la RAM alta superada" "Configuración C3: admitida"

# ---------------------------------------------------------------- RAM baja
$EMU $DISK_ES $BOOT key 6:0 wait 80 key 2:2 wait 600 vram $OUT/lowerram.vram shot $OUT/lowerram.png
check lowerram "KB de 64 KB." "Resultado: Superado"

# Chip de RAM dañado: el bit 3 se lee siempre a 0 en #B000-#B3FF
$EMU $DISK_ES $BOOT fault B000 400 08 key 6:0 wait 80 key 2:2 wait 600 vram $OUT/lowerramfault.vram shot $OUT/lowerramfault.png
check lowerramfault "Resultado: Error bits 03" " X " "Chips a revisar (6128, placa original): IC130"

# Qué chip es cada bit según la placa (esquemas de Amstrad). Se cambian a mano
# el modelo (6128 -> 464: 3 xor 2) y el CRTC (1 -> 4: 1 xor 5; 1 -> 3: 1 xor 2)
VAR() { grep -E "^\s*[0-9]+\+?\s+[0-9A-F]{4}\s.*\b$1:" build/es/RAMBuild.lst | awk '{print $2}' | grep -E "^A" | head -1; }
$EMU $DISK_ES $BOOT corrupt $(VAR ModelType) 02 fault B000 400 81 key 6:0 wait 80 key 2:2 wait 600 vram $OUT/chips464.vram
check chips464 "Error bits 00 07" "Chips a revisar (464/664): IC120 IC124"
$EMU $DISK_ES $BOOT corrupt $(VAR CRTCType) 05 fault B000 400 FF key 6:0 wait 80 key 2:2 wait 600 vram $OUT/chips40226.vram
check chips40226 "(6128 con 40226, probable): IC109" "IC110 IC111 IC112 IC113 IC114 IC115 IC116"
$EMU $DISK_ES $BOOT corrupt $(VAR CRTCType) 02 fault B000 400 81 key 6:0 wait 80 key 2:2 wait 600 vram $OUT/chipsplus.vram
check chipsplus "Chips a revisar (Plus): IC110 IC111"

# RAM alta del 6128 con los bits 0 y 7 rotos en su segunda página: se ven
# los dos (antes la prueba se paraba en el primero) y sus chips
$EMU $DISK_ES $BOOT faultbank 5 81 key 5:1 wait 1500 vram $OUT/upperramfault.vram shot $OUT/upperramfault.png
check upperramfault "Error en la RAM alta. Bits: 00 07" "Chips a revisar (6128, placa original): IC119 IC126"

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
check keyboard "Teclas que han respondido: 2/73" "Pulsadas desde el principio (atascadas): C" "Resultado: Error"

# Líneas 0 y 1 de la matriz unidas (visto en un 464 real): una tecla enciende
# también la de la misma columna en la otra línea. Se imita pulsando las dos
# en el mismo cuadro, dos veces.
$EMU $DISK_ES $BOOT key 8:0 wait 150 key 2:2 wait 250 hold 0:2 hold 1:2 wait 4 release 0:2 release 1:2 wait 20 hold 0:2 hold 1:2 wait 4 release 0:2 release 1:2 wait 20 hold 8:2 wait 80 release 8:2 wait 80 vram $OUT/keyjoined.vram shot $OUT/keyjoined.png
check keyjoined "Líneas unidas: 0-1" "Resultado: Error" "líneas de la matriz están unidas"

# AY lento (visto en un 464 real con un AY-3-8912A de recambio): cada tecla
# aparece también en la línea siguiente. Se pulsan dos teclas de cada línea,
# se sale y se mantiene la H cuando lo pide: la lectura lenta lo confirma.
KEYS=""
for r in 0 1 2 3 4 5 6 7; do for b in 3 4; do KEYS="$KEYS key $r:$b wait 12"; done; done
$EMU $DISK_ES $BOOT sloway 100 key 8:0 wait 150 key 2:2 wait 250 $KEYS hold 8:2 wait 80 release 8:2 wait 30 vram $OUT/slowayhold.vram hold 5:4 wait 170 release 5:4 wait 60 vram $OUT/sloway.vram shot $OUT/sloway.png
check slowayhold "mantén pulsada una tecla"
check sloway "Líneas unidas: 0-1 1-2 2-3" "Comprobado: leyendo despacio" "AY-3-8912"

# Líneas consecutivas unidas de verdad (0-1 y 1-2) con un AY normal: la
# lectura lenta ve lo mismo, así que no se culpa al AY
J=""
for p in "0:2 1:2" "1:3 2:3"; do set -- $p; J="$J hold $1 hold $2 wait 4 release $1 release $2 wait 20 hold $1 hold $2 wait 4 release $1 release $2 wait 20"; done
$EMU $DISK_ES $BOOT key 8:0 wait 150 key 2:2 wait 250 $J hold 8:2 wait 80 release 8:2 wait 30 hold 5:4 wait 170 release 5:4 wait 60 vram $OUT/joinednotay.vram shot $OUT/joinednotay.png
check joinednotay "Líneas unidas: 0-1 1-2" "líneas de la matriz están unidas"

# ---------------------------------------------------------------- modo automático
# Sin tocar nada 30 s: hace las pruebas que no necesitan respuestas y acaba en
# el resumen. La C atascada desde el arranque no debe impedirlo.
$EMU $DISK_ES wait 150 type 'run"doctor~' wait 100 hold 7:6 wait 3400 vram $OUT/autokb.vram shot $OUT/autokb.png wait 350 vram $OUT/autovideo.vram wait 12250 vram $OUT/auto.vram shot $OUT/auto.png
check autokb "Pulsadas desde el principio (atascadas): C" "Resultado: Error" "sigue solo en 5 s"
check autovideo "Imagen" "mira la pantalla (no se pregunta)"
check auto "Resumen final" "Imagen   : Sin probar" "Sonido   : Sin probar" "Teclado  : Error" "RAM baja : Superado" "RAM alta : Superado" "ROM baja : Superado" "Disco    : Inconcluso"

# AY con el puerto A lento (pull-ups débiles): se mide al arrancar, sin
# pulsar teclas. La primera lectura llega a unos 170 ciclos de soltarlo.
$EMU $DISK_ES slowport 400 wait 150 type 'run"doctor~' wait 400 key 8:0 wait 150 key 2:2 wait 250 hold 8:2 wait 80 release 8:2 wait 30 vram $OUT/slowport.vram shot $OUT/slowport.png wait 60 key 2:2 wait 80 key 4:0 wait 100 vram $OUT/slowportsum.vram
check slowport "Puerto A del AY: lento" "Resultado: Error" "resistencias pull-up"
check slowportsum "AVISO: el puerto A del AY es lento"

# Prueba de teclado sin pulsar nada: termina sola a los 10 s
$EMU $DISK_ES $BOOT key 8:0 wait 150 key 2:2 wait 650 vram $OUT/kbidle.vram shot $OUT/kbidle.png
check kbidle "Nadie ha pulsado ninguna tecla en 10 segundos" "volver al menú"

# ---------------------------------------------------------------- sonido
# Las respuestas del 464 real con el tono B averiado: A sí, B no, C sí,
# ruido sí, volumen no
$EMU $DISK_ES $BOOT key 7:1 wait 100 key 2:2 wait 130 key 8:0 wait 130 key 8:1 wait 130 key 8:0 wait 130 key 8:0 wait 130 key 8:1 wait 100 vram $OUT/soundtoneb.vram shot $OUT/soundtoneb.png
check soundtoneb "Resultado: Error" "generador de tono B"

# Patilla DA1 del AY con mal contacto (llega siempre a 1): al releer los
# registros no coinciden. La avería se activa ya dentro de la prueba, porque
# también deja sin leer una columna del teclado; se contesta con el 1.
$EMU $DISK_ES $BOOT key 7:1 wait 100 aybus 02 key 2:2 wait 130 key 8:0 wait 130 key 8:0 wait 130 key 8:0 wait 130 key 8:0 wait 130 key 8:0 wait 100 vram $OUT/soundbus.vram shot $OUT/soundbus.png
check soundbus "Registros del AY: no guarda bien DA1" "Resultado: Error" "patilla DA"

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
# Un AY sano no da el aviso del puerto A
if grep -qF "AVISO" $OUT/summary.txt; then FAIL=$((FAIL + 1)); echo "FALLO  summary: aviso del puerto con un AY sano"; else PASS=$((PASS + 1)); fi

# Con un CRTC de tipo 4 el Gate Array es el 40226. El emulador solo tiene el
# tipo 1: se cambia la variable a mano (1 xor 5 = 4) antes del resumen.
CRTCVAR=$(grep -E "^\s*[0-9]+\+?\s+[0-9A-F]{4}\s.*CRTCType:" build/es/RAMBuild.lst | awk '{print $2}' | grep -E "^A" | head -1)
$EMU $DISK_ES $BOOT corrupt $CRTCVAR 05 key 4:0 wait 80 vram $OUT/crtc4.vram
check crtc4 "CRTC 4 (40226)"

# ---------------------------------------------------------------- inglés, 464 y cinta
$EMU -m 464 -t build/dist/cpcdoctor-en.cdt wait 150 type 'run"~' wait 20 key 5:7 $TAPEWAIT vram $OUT/tape464.vram shot $OUT/tape464.png
check tape464 "CPC 464" "64KB" "Upper RAM : Not available" "4. Cassette"

# Prueba de cassette con el motor un 5 % lento (la cinta sigue tras el programa)
$EMU -m 464 -v 105 -t build/dist/cpcdoctor-es.cdt wait 150 type 'run"~' wait 20 key 5:7 $TAPEWAIT wait 500 key 7:0 wait 80 key 2:2 wait 300 vram $OUT/cassette.vram shot $OUT/cassette.png
check cassette "Velocidad: -4," "Estabilidad: 100%"

# Prueba continua en un 464 sin RAM alta: debe dar vueltas (antes se colgaba)
SOAKCOUNT=$(grep -E "^\s*[0-9]+\+?\s+[0-9A-F]{4}\s.*SoakTestCount:" build/es/RAMBuild.lst | awk '{print $2}')
$EMU -m 464 -t build/dist/cpcdoctor-es.cdt wait 150 type 'run"~' wait 20 key 5:7 $TAPEWAIT key 4:1 wait 2500 peek $SOAKCOUNT vram $OUT/soak464.vram shot $OUT/soak464.png > $OUT/soak464.peek
if [ $((0x$(awk '{print $2}' $OUT/soak464.peek))) -ge 3 ]; then PASS=$((PASS + 1)); echo "ok     soak464 ($(cat $OUT/soak464.peek))"; else FAIL=$((FAIL + 1)); echo "FALLO  soak464: menos de 3 vueltas ($(cat $OUT/soak464.peek))"; fi

# Prueba continua con un chip de RAM dañado: debe pararse y decirlo
$EMU $DISK_ES $BOOT fault B000 400 08 key 4:1 wait 700 vram $OUT/soakfault.vram shot $OUT/soakfault.png
check soakfault "Prueba detenida por un error en la vuelta 1"

# 464 con las ROM del 6128 (ampliación habitual): debe preguntar el modelo
head -c 16384 tools/emu/roms/cpc6128.rom > $OUT/os6128.rom
tail -c 16384 tools/emu/roms/cpc6128.rom > $OUT/basic11.rom
$EMU -m 464 -o $OUT/os6128.rom -b $OUT/basic11.rom -t build/dist/cpcdoctor-es.cdt wait 200 type 'run"~' wait 20 key 5:7 $TAPEWAIT vram $OUT/modeldoubt.vram key 8:0 wait 100 vram $OUT/modelconfirmed.vram shot $OUT/modelconfirmed.png
check modeldoubt "La ROM de este ordenador es la de un CPC 6128" "1. CPC 464"
check modelconfirmed "Modelo    : CPC 464" "RAM alta  : No disponible"

# Tras una vuelta de prueba continua se conservan el modelo y los resultados
$EMU -m 464 -o $OUT/os6128.rom -b $OUT/basic11.rom -t build/dist/cpcdoctor-es.cdt wait 200 type 'run"~' wait 20 key 5:7 $TAPEWAIT key 8:0 wait 100 key 4:1 wait 1200 hold 8:2 wait 400 release 8:2 wait 150 key 4:0 wait 100 vram $OUT/aftersoak.vram shot $OUT/aftersoak.png
check aftersoak "CPC 464, 64KB" "RAM alta : No disponible" "Sonido," "Cassette" 

# ---------------------------------------------------------------- ROM baja
$EMU -m 464 -o build/dist/cpcdoctor-es-lower.rom wait 700 vram $OUT/lowerrom.vram shot $OUT/lowerrom.png
check lowerrom "CPC Doctor V0.9.2L" "RAM baja  : Superado" "6. Prueba continua"

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
