# Compilar CPC Doctor

## Requisitos

- **sjasmplus 1.21 o posterior** (hace falta `SAVECPR` para el cartucho).
  `build.sh` lo busca en `$SJASMPLUS`, en el `PATH` o en `tools/bin/sjasmplus`.
- **Python 3** (solo la biblioteca estándar).

No hacen falta iDSK ni 2cdt: `tools/cpcfile.py` genera los discos, las cintas
CDT y los WAV.

### sjasmplus en macOS

    git clone https://github.com/z00m128/sjasmplus.git
    cd sjasmplus && git submodule update --init
    make CXX="clang++ -isysroot $(xcrun --show-sdk-path) -I$(xcrun --show-sdk-path)/usr/include/c++/v1"
    cp sjasmplus ../CPCDoctor/tools/bin/

(Los parámetros de `CXX` solo hacen falta si las Command Line Tools no
encuentran las cabeceras de C++.)

## Compilar

    ./build.sh          # español e inglés
    ./build.sh es       # solo español

Los ficheros quedan en `build/dist/` y el listado de cada variante en
`build/<idioma>/*.lst`.

| Variante | Define | Qué es |
|---|---|---|
| `RAMBuild` | `GUIDED` | Cinta y disco, con todas las pruebas guiadas. Se carga en #0400, comprimida con `tools/pack.py`. |
| `LowerROMBuild` | | Sustituye a la ROM del sistema (16 KB). |
| `UpperROMBuild` | | ROM de expansión, `|DOCTOR` o `|DIAG` (16 KB). |
| `CartridgeBuild` | | Cartucho CPR para Plus y GX4000. |

La ROM baja va muy justa de espacio (quedan unos 500 bytes). Todo lo guiado está
dentro de `IFDEF GUIDED`, y sus textos en la sección `[GUIDED]` de
`lang/*.txt`.

## Pruebas automáticas

    tools/emu/build.sh  # compila el emulador y descarga las ROM del CPC
    tests/run.sh

`tools/emu/cpcemu` es un emulador de 464 y 6128 sin interfaz, basado en
[chips](https://github.com/floooh/chips). Permite teclear, pulsar posiciones de
la matriz, mover el joystick y reproducir cintas CDT (a su velocidad o más
lenta con `-v`). También puede simular un chip de RAM dañado (`fault`) y sacar
capturas o la memoria de vídeo. `tools/screentext.py` lee el texto de la
pantalla a partir de esa memoria, y las pruebas comprueban lo que aparece.

Ejemplo:

    tools/emu/cpcemu -m 6128 -d build/dist/cpcdoctor-es.dsk \
        wait 150 type 'run"doctor~' wait 400 shot menu.png

Las ROM del CPC no se incluyen en el repositorio. `tools/emu/getroms.sh` las
descarga del proyecto Caprice32, que las distribuye con permiso de Amstrad.

## Probar en un CPC real con M4

    ./build.sh es && tools/m4.sh

`tools/m4.sh` busca la M4 Board en la red local, sube `DOCTOR.BIN` a la raíz
de la SD, comprueba que ha llegado (la M4 contesta 200 aunque no guarde nada) y
lo ejecuta en el CPC. La IP se busca sola (`tools/buscam4.sh`) y se recuerda en
`.m4ip`; también se puede fijar con `M4=192.168.1.42 tools/m4.sh`.

## Estructura

| Carpeta | Contenido |
|---|---|
| `src/` | Código Z80. `Main.asm` es la entrada; `Config.asm` define las variantes. |
| `src/loader/` | Descompresor de la versión de cinta y disco. |
| `lang/` | Textos traducibles. |
| `tools/` | Generación de textos, ficheros de CPC, compresor, lector de pantalla y emulador. |
| `tests/` | Pruebas automáticas. |
| `ROMDump/` | Utilidad heredada de Amstrad Diagnostics para volcar ROMs. |
