#!/bin/sh
# Genera las capturas de docs/img con el emulador de pruebas.
#
#   tools/capturas.sh
#
# Hace falta haber compilado (./build.sh) y tener el emulador
# (tools/emu/build.sh). Las pulsaciones siguen la numeración del menú de la
# versión guiada: 1 teclado, 2 imagen, 3 sonido, 4 cassette, 5 disquetera,
# 6 RAM baja, 7 RAM alta, 8 ROMs, 9 prueba continua, 0 resumen.
set -e
cd "$(dirname "$0")/.."
EMU=tools/emu/cpcemu
IMG=docs/img
mkdir -p $IMG
rm -f $IMG/*.png
DISK="-m 6128 -d build/dist/cpcdoctor-es.dsk"
BOOT='wait 150 type run"doctor~ wait 450'
OK='key 2:2'
SI='key 8:0'
NO='key 8:1'
# Mientras carga la cinta, el cursor derecha evita el modo automático de 30 s
TAPEWAIT=$(for i in $(seq 17); do printf ' wait 1000 key 0:1'; done)

# Menú principal
$EMU $DISK $BOOT shot $IMG/menu.png

# Teclado: dibujo con algunas teclas probadas y resultado
$EMU $DISK $BOOT $SI wait 150 $OK wait 250 key 8:3 key 7:3 key 7:2 key 6:2 key 6:3 key 5:3 key 5:2 key 4:3 key 4:2 key 3:3 joy 1 wait 5 joy 0 wait 20 shot $IMG/teclado.png

# Imagen: franjas de rojo, rejilla y consejo tras un fallo
$EMU $DISK $BOOT key 8:1 wait 120 $OK wait 60 $OK wait 40 shot $IMG/imagen-color.png
$EMU $DISK $BOOT key 8:1 wait 120 $OK wait 60 $OK wait 60 $OK wait 60 $SI wait 60 $OK wait 60 $SI wait 60 $OK wait 60 $SI wait 60 $OK wait 60 $SI wait 120 shot $IMG/imagen-rejilla.png

# Sonido: resultado con el canal B sin tono pero con ruido
$EMU $DISK $BOOT key 7:1 wait 150 $OK wait 130 $SI wait 130 $NO wait 130 $SI wait 130 $SI wait 130 $NO wait 100 shot $IMG/sonido.png

# RAM baja con un chip dañado simulado (bit 3)
$EMU $DISK $BOOT fault A000 400 08 key 6:0 wait 150 $OK wait 600 shot $IMG/ram-baja.png

# Resumen final
$EMU $DISK $BOOT key 4:0 wait 100 shot $IMG/resumen.png

# Cassette: medida con el motor un 3 % lento (464 desde cinta)
$EMU -m 464 -v 103 -t build/dist/cpcdoctor-es.cdt wait 150 type 'run"~' wait 20 key 5:7 $TAPEWAIT wait 500 key 7:0 wait 150 $OK wait 300 shot $IMG/cassette.png

# 464 con las ROM del 6128: pregunta del modelo
head -c 16384 tools/emu/roms/cpc6128.rom > /tmp/cpcdoctor-os6128.rom
tail -c 16384 tools/emu/roms/cpc6128.rom > /tmp/cpcdoctor-basic11.rom
$EMU -m 464 -o /tmp/cpcdoctor-os6128.rom -b /tmp/cpcdoctor-basic11.rom -t build/dist/cpcdoctor-es.cdt wait 200 type 'run"~' wait 20 key 5:7 $TAPEWAIT shot $IMG/modelo.png

# Versión en ROM baja
$EMU -m 464 -o build/dist/cpcdoctor-es-lower.rom wait 700 shot $IMG/rom-baja.png

python3 tools/pngzip.py $IMG/*.png
ls -l $IMG
