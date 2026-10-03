#!/usr/bin/env python3
"""
pack.py — comprime el programa para que cargue antes desde cinta.

    pack.py ENTRADA.raw DESTINO SALIDA.BIN NOMBRE.EXT SJASMPLUS

ENTRADA.raw es el programa tal cual se ejecuta en DESTINO (por ejemplo
#0400). Se genera un .BIN con cabecera AMSDOS que contiene los datos
comprimidos y, detrás, un pequeño descompresor (src/loader/unpack.asm).
El fichero se carga lo más arriba posible sin pisar el firmware (#A600) y
el descompresor lo expande sobre DESTINO y salta allí.

Formato (LZ sencillo):
    0LLLLLLL                 L+1 bytes literales (1-128) a continuación
    10LLLLLL d               copia de L+2 bytes (2-65) desde DE - (d+1)
    11LLLLLL lo hi           copia de L+3 bytes (3-66) desde DE - (hi*256+lo)

Parte de CPC Doctor. Licencia MIT.
"""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cpcfile import amsdos_header  # noqa: E402

TOP = 0xA600            # el firmware y el BASIC usan lo que hay por encima
MAX_LITERAL = 128
WINDOW = 0x7FFF
SHORT_MAX, LONG_MAX = 65, 66


def _match(data, i, chains, n):
    """Mejor coincidencia en i: (longitud, distancia) o (0, 0)."""
    best_len, best_off, best_gain = 0, 0, 0
    for j in reversed(chains.get(bytes(data[i:i + 2]), [])[-512:]):
        off = i - j
        if off > WINDOW:
            break
        short = off <= 256
        limit = SHORT_MAX if short else LONG_MAX
        length = 0
        while length < limit and i + length < n and data[j + length] == data[i + length]:
            length += 1
        if (short and length < 2) or (not short and length < 3):
            continue
        gain = length - (2 if short else 3)
        if gain > best_gain:
            best_len, best_off, best_gain = length, off, gain
    return best_len, best_off


def compress(data):
    out = bytearray()
    literals = bytearray()
    chains = {}
    n = len(data)
    i = 0

    def flush():
        nonlocal literals
        while literals:
            chunk = literals[:MAX_LITERAL]
            out.append(len(chunk) - 1)
            out.extend(chunk)
            literals = literals[MAX_LITERAL:]

    def insert(pos):
        if pos + 2 <= n:
            chains.setdefault(bytes(data[pos:pos + 2]), []).append(pos)

    while i < n:
        length, off = _match(data, i, chains, n) if i + 2 <= n else (0, 0)
        if length:
            flush()
            if off <= 256:
                out += bytes([0x80 | (length - 2), off - 1])
            else:
                out += bytes([0xC0 | (length - 3), off & 0xFF, off >> 8])
            for k in range(length):
                insert(i + k)
            i += length
        else:
            literals.append(data[i])
            insert(i)
            i += 1
    flush()
    return bytes(out)


def _tokens(packed):
    """(bytes del token, bytes que produce) de cada token."""
    i = 0
    while i < len(packed):
        t = packed[i]
        if t & 0x80 == 0:
            yield t + 2, t + 1
        elif t & 0x40 == 0:
            yield 2, (t & 0x3F) + 2
        else:
            yield 3, (t & 0x3F) + 3
        i += (t + 2) if t & 0x80 == 0 else (2 if t & 0x40 == 0 else 3)


def decompress(packed, size):
    out = bytearray()
    i = 0
    while len(out) < size:
        t = packed[i]
        if t & 0x80 == 0:
            out += packed[i + 1:i + t + 2]
            i += t + 2
            continue
        if t & 0x40 == 0:
            length, off = (t & 0x3F) + 2, packed[i + 1] + 1
            i += 2
        else:
            length, off = (t & 0x3F) + 3, packed[i + 1] | packed[i + 2] << 8
            i += 3
        for _ in range(length):
            out.append(out[-off])
    return bytes(out)


def check_in_place(packed, dest, src):
    """El descompresor escribe en DEST mientras lee de SRC: comprueba que la
    escritura nunca alcanza a lo que aún no se ha leído."""
    produced = consumed = 0
    for used, made in _tokens(packed):
        consumed += used
        produced += made
        if consumed < len(packed) and dest + produced > src + consumed:
            raise SystemExit('la descompresión pisaría los datos comprimidos')


def main():
    raw_path, dest, out_path, name, sjasmplus = sys.argv[1:6]
    dest = int(dest, 0)
    data = open(raw_path, 'rb').read()
    packed = compress(data)
    assert decompress(packed, len(data)) == data

    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
    with tempfile.TemporaryDirectory() as tmp:
        stub_path = os.path.join(tmp, 'stub.bin')
        # Primero con una dirección cualquiera, para saber cuánto ocupa
        def assemble(src, stub_addr):
            subprocess.run([sjasmplus, '--nologo', '--msg=err',
                            f'-DPACKED={src}', f'-DUNPACK_TO={dest}',
                            f'-DUNPACK_END={dest + len(data)}',
                            f'-DSTUB_AT={stub_addr}', f'-DOutFile="{stub_path}"',
                            os.path.join(root, 'src', 'loader', 'unpack.asm')],
                           check=True)
            return open(stub_path, 'rb').read()
        stub = assemble(0x8000, 0x9000)
        load = TOP - len(stub) - len(packed)
        stub_addr = load + len(packed)
        stub = assemble(load, stub_addr)
    check_in_place(packed, dest, load)
    if dest + len(data) > stub_addr:
        raise SystemExit('el programa descomprimido pisaría el descompresor')
    if load <= dest:
        raise SystemExit('el programa comprimido no cabe')
    body = packed + stub
    open(out_path, 'wb').write(amsdos_header(name, load, stub_addr, len(body)) + body)
    print(f'{os.path.basename(out_path)}: {len(data)} -> {len(body)} bytes '
          f'({100 * len(body) // len(data)} %), carga en &{load:04X}, '
          f'arranque en &{stub_addr:04X}')


if __name__ == '__main__':
    main()
