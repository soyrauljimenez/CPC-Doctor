#!/bin/sh
# Descarga las ROM del CPC que distribuye Caprice32 (Amstrad autorizó su
# distribución con emuladores). Solo hacen falta para el emulador de pruebas.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)/roms"
URL=https://raw.githubusercontent.com/ColinPitrat/caprice32/master/rom
mkdir -p "$DIR"
for f in cpc464.rom cpc664.rom cpc6128.rom amsdos.rom; do
	[ -f "$DIR/$f" ] || curl -sfL "$URL/$f" -o "$DIR/$f"
done
echo "ROM listas en $DIR"
