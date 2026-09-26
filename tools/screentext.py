#!/usr/bin/env python3
"""
screentext.py — lee el texto de la pantalla de CPC Doctor a partir de un
volcado de la memoria de vídeo (orden "vram" de tools/emu/cpcemu).

    screentext.py VRAM.bin

Reconoce la fuente de 6x8 píxeles en Mode 1 (53 columnas, 25 filas) y
escribe el texto en UTF-8. Sirve para las pruebas automáticas.

Parte de CPC Doctor. Licencia MIT.
"""
import os
import re
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gentext import CHARMAP, SYMBOLS  # noqa: E402

COLS, ROWS = 53, 25


def load_font():
    glyphs = {}
    code = 0x20
    for line in open(os.path.join(HERE, '..', 'src', 'Font.asm'), encoding='utf-8'):
        m = re.match(r'\s*defb\s+(.*?)\s*(;.*)?$', line)
        if not m:
            continue
        values = tuple(int(v.strip().lstrip('#'), 16) & 0xFC for v in m.group(1).split(','))
        glyphs.setdefault(values, code)
        code += 1
    return glyphs


def char_for(code):
    for k, v in CHARMAP.items():
        if v == code:
            return k
    for k, v in SYMBOLS.items():
        if v == code:
            return {'ARRIBA': '↑', 'ABAJO': '↓', 'IZQUIERDA': '←', 'DERECHA': '→'}.get(k, '·')
    return chr(code) if 0x20 <= code < 0x7F else '?'


def pen(vram, x, y):
    addr = (y % 8) * 0x800 + (y // 8) * 80 + x // 4
    b = vram[addr]
    p = x % 4
    return (b >> (7 - p) & 1) | ((b >> (3 - p) & 1) << 1)


def read(vram):
    glyphs = load_font()
    lines = []
    for row in range(ROWS):
        text = ''
        for col in range(COLS):
            x0 = (col // 2) * 12 + (col & 1) * 6
            cell = [[pen(vram, x0 + dx, row * 8 + dy) for dx in range(6)] for dy in range(8)]
            bg = Counter(p for r in cell for p in r).most_common(1)[0][0]
            rows = tuple(sum((1 << (7 - dx)) for dx in range(6) if r[dx] != bg) for r in cell)
            code = glyphs.get(rows)
            text += char_for(code) if code else ('?' if any(rows) else ' ')
        lines.append(text.rstrip())
    return '\n'.join(lines)


if __name__ == '__main__':
    print(read(open(sys.argv[1], 'rb').read()))
