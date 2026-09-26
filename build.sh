#!/bin/sh
# Compila CPC Doctor en todas sus variantes e idiomas.
#
#   ./build.sh            todo (es y en)
#   ./build.sh es         solo español
#
# Necesita sjasmplus >= 1.21 (en el PATH, en tools/bin o en $SJASMPLUS)
# y python3. No hacen falta iDSK ni 2cdt: tools/cpcfile.py genera los
# discos y las cintas.
set -e
cd "$(dirname "$0")"

SJASMPLUS="${SJASMPLUS:-$(command -v sjasmplus || echo tools/bin/sjasmplus)}"
[ -x "$SJASMPLUS" ] || { echo "No encuentro sjasmplus. Ver docs/COMPILAR.md"; exit 1; }
VER=$("$SJASMPLUS" --version 2>&1 | sed -n 's/.*v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\).*/\1 \2/p')
set -- ${1:-es en}
LANGS="$*"
if [ "$(echo "$VER" | awk '{print ($1*100+$2 >= 121)}')" != 1 ]; then
	echo "Hace falta sjasmplus 1.21 o posterior (para SAVECPR)"; exit 1
fi

rm -rf build
mkdir -p build/dist

asm() {	# idioma variante salida
	"$SJASMPLUS" --nologo --msg=war -Ibuild/$1 -D$2=1 -DLANG_$(echo $1 | tr a-z A-Z)=1 \
		"-DOutFile=\"$3\"" --lst=build/$1/$2.lst src/Main.asm
}

for L in $LANGS; do
	mkdir -p build/$L
	python3 tools/gentext.py $L build/$L/texts.asm

	asm $L LowerROMBuild build/$L/lower.rom
	asm $L UpperROMBuild build/$L/upper.rom
	asm $L CartridgeBuild build/$L/cartridge.cpr
	asm $L RAMBuild build/$L/doctor.raw

	# Comprimido con su descompresor: carga un tercio más rápido
	python3 tools/pack.py build/$L/doctor.raw 0x400 build/$L/DOCTOR.BIN DOCTOR.BIN "$SJASMPLUS"
	python3 tools/cpcfile.py dsk build/dist/cpcdoctor-$L.dsk build/$L/DOCTOR.BIN
	python3 tools/cpcfile.py cdt build/dist/cpcdoctor-$L.cdt --tono 60 build/$L/DOCTOR.BIN
	python3 tools/cpcfile.py wav build/dist/cpcdoctor-$L.wav --tono 60 build/$L/DOCTOR.BIN
	cp build/$L/lower.rom build/dist/cpcdoctor-$L-lower.rom
	cp build/$L/upper.rom build/dist/cpcdoctor-$L-upper.rom
	cp build/$L/cartridge.cpr build/dist/cpcdoctor-$L.cpr
done

# Solo el tono de calibración, para la prueba de cassette. Se guarda también
# en audio/, que va en el repositorio (el fichero es siempre el mismo).
python3 tools/cpcfile.py cdt audio/cpcdoctor-tono-2000hz.cdt --tono 120
python3 tools/cpcfile.py wav audio/cpcdoctor-tono-2000hz.wav --tono 120
cp audio/cpcdoctor-tono-2000hz.cdt build/dist/cpcdoctor-tono-2000hz.cdt
cp audio/cpcdoctor-tono-2000hz.wav build/dist/cpcdoctor-tono-2000hz.wav

(cd build/dist && zip -q ../cpcdoctor.zip * && cd .. && mv cpcdoctor.zip dist/)
ls -l build/dist
