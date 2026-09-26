#!/bin/sh
# Compila el emulador de pruebas.
set -e
cd "$(dirname "$0")"
SDK=""
if command -v xcrun >/dev/null 2>&1; then SDK="-isysroot $(xcrun --show-sdk-path)"; fi
${CC:-cc} -O2 -Wall $SDK -o cpcemu cpcemu.c
[ -f roms/cpc464.rom ] || ./getroms.sh
