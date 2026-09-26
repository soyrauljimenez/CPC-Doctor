#!/bin/bash
# Sube CPC Doctor a la M4 Board y lo ejecuta en el CPC real.
#
#   tools/m4.sh          versión en español (build/es/DOCTOR.BIN)
#   tools/m4.sh en       versión en inglés
#   M4=192.168.1.42 tools/m4.sh    sin buscar la placa
#
# La M4 contesta 200 aunque no haya guardado nada, así que después de subir
# se relee el listado de la raíz de la SD para confirmar el tamaño.
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
L="${1:-es}"
BIN="$DIR/build/$L/DOCTOR.BIN"
[ -f "$BIN" ] || { echo "no existe $BIN: compila antes con ./build.sh"; exit 1; }

M4=$("$DIR/tools/buscam4.sh") || exit 1
echo "M4 en $M4"

curl -s -m 40 -F "file=@$BIN;filename=/DOCTOR.BIN" "http://$M4/" \
     -o /dev/null -w "subida    : http:%{http_code}\n"
# El listado muestra la última carpeta abierta en la M4: primero la raíz
curl -s -m 10 "http://$M4/config.cgi?ls=%2F" -o /dev/null
KB=$(( $(wc -c < "$BIN") / 1024 ))		# la M4 redondea hacia abajo
curl -s -m 10 "http://$M4/sd/m4/dir.txt" | grep -q "^DOCTOR.BIN,1,${KB}K" ||
	{ echo "ERROR: DOCTOR.BIN no está en la SD con ${KB}K"; exit 1; }
echo "en la SD : DOCTOR.BIN (${KB}K)"
sleep 1
curl -s -m 10 "http://$M4/config.cgi?run2=%2FDOCTOR.BIN" \
     -o /dev/null -w "ejecución : http:%{http_code}\n"
