#!/usr/bin/env python3
"""
gentext.py — convierte los textos de lang/<idioma>.txt en ensamblador.

    gentext.py IDIOMA SALIDA.asm

Formato de lang/<idioma>.txt (UTF-8):

    # comentario
    Clave = texto
    Clave = primera línea|segunda línea       ('|' = salto de línea)
    Clave = texto con {ARRIBA} y otros símbolos
    [GUIDED]         los textos siguientes solo entran si se define GUIDED
    [ALL]            vuelta a los textos comunes

Cada clave genera la etiqueta global TxtClave terminada en 0 y la
constante TxtClaveLen con su longitud.
Todas las claves deben existir en todos los idiomas: si falta alguna,
la compilación se detiene.

Parte de CPC Doctor. Licencia MIT.
"""
import os
import re
import sys

# Juego de caracteres de la fuente (src/Font.asm). Debe coincidir con ella.
CHARMAP = {
    'á': 0x80, 'é': 0x81, 'í': 0x82, 'ó': 0x83, 'ú': 0x84,
    'ñ': 0x85, 'Ñ': 0x86, 'ü': 0x87, '¿': 0x88, '¡': 0x89,
    'ù': 0x8A, 'º': 0x8B, 'Ü': 0x8C, 'ç': 0x8D, 'è': 0x8E, 'à': 0x8F,
}
# Símbolos con nombre: {ARRIBA}, {ABAJO}...
SYMBOLS = {
    'ARRIBA': 0x90, 'ABAJO': 0x91, 'IZQUIERDA': 0x92, 'DERECHA': 0x93,
    'ENTER_GRANDE': 0x94, 'ENTER': 0x95, 'ESC': 0x96, 'CLR': 0x97,
    'DEL': 0x98, 'TAB': 0x99, 'CAPS': 0x9A, 'SHIFT': 0x9B, 'CTRL': 0x9C,
    'COPY': 0x9E, 'BLOQUE': 0x7F, 'TRAMA': 0x7E,
}
NEWLINE = 0x0A
LINE = re.compile(r'^([A-Za-z][A-Za-z0-9_]*)\s*=\s?(.*)$')
SECTION = re.compile(r'^\[([A-Z_]+)\]\s*$')


def parse(path):
    entries = {}
    order = []
    section = 'ALL'
    with open(path, encoding='utf-8') as f:
        for n, raw in enumerate(f, 1):
            line = raw.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            sm = SECTION.match(line)
            if sm:
                section = sm.group(1)
                continue
            m = LINE.match(line)
            if not m:
                raise SystemExit(f'{path}:{n}: línea no válida: {line!r}')
            key, text = m.group(1), m.group(2)
            if key in entries:
                raise SystemExit(f'{path}:{n}: clave repetida {key}')
            entries[key] = (text, n, section)
            order.append(key)
    return entries, order


def encode(text, where):
    out = []
    i = 0
    while i < len(text):
        c = text[i]
        if c == '{':
            j = text.index('}', i)
            name = text[i + 1:j]
            if name not in SYMBOLS:
                raise SystemExit(f'{where}: símbolo desconocido {{{name}}}')
            out.append(SYMBOLS[name])
            i = j + 1
            continue
        if c == '|':
            out.append(NEWLINE)
        elif c in CHARMAP:
            out.append(CHARMAP[c])
        elif ' ' <= c <= '~':
            out.append(ord(c))
        else:
            raise SystemExit(f'{where}: carácter no disponible en la fuente: {c!r}')
        i += 1
    return out


def main():
    lang, out = sys.argv[1], sys.argv[2]
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lang')
    entries, order = parse(os.path.join(root, lang + '.txt'))
    # Todas las claves de todos los idiomas deben coincidir
    for other in sorted(os.listdir(root)):
        if other.endswith('.txt') and other != lang + '.txt':
            o, _ = parse(os.path.join(root, other))
            missing = sorted(set(o) - set(entries))
            extra = sorted(set(entries) - set(o))
            if missing or extra:
                raise SystemExit(f'lang/{lang}.txt y lang/{other} no coinciden.'
                                 f' Faltan: {missing} Sobran: {extra}')
    lines = [f'; Generado por tools/gentext.py desde lang/{lang}.txt. No editar.']
    total = 0
    current = 'ALL'
    for key in order:
        text, n, section = entries[key]
        if section != current:
            if current != 'ALL':
                lines.append(' ENDIF')
            if section != 'ALL':
                lines.append(f' IFDEF {section}')
            current = section
        data = encode(text, f'lang/{lang}.txt:{n}') + [0]
        total += len(data)
        chunks = [data[k:k + 24] for k in range(0, len(data), 24)]
        lines.append(f'@Txt{key}Len EQU {len(data) - 1}')
        lines.append(f'@Txt{key}:')
        for ch in chunks:
            lines.append('\tdb ' + ','.join(f'#{b:02X}' for b in ch))
    if current != 'ALL':
        lines.append(' ENDIF')
    lines.append(f'; {len(order)} textos, {total} bytes')
    with open(out, 'w', encoding='ascii') as f:
        f.write('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
