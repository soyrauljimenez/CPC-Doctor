#!/usr/bin/env python3
"""pngzip.py — recomprime los PNG que genera el emulador (que no comprime).

    pngzip.py FICHERO.png [...]
"""
import struct
import sys
import zlib


def recompress(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    chunks, pos, idat = [], 8, b''
    while pos < len(data):
        length, = struct.unpack('>I', data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b'IDAT':
            idat += body
        else:
            chunks.append((kind, body))
    raw = zlib.decompress(idat)
    out = bytearray(data[:8])
    for kind, body in chunks:
        if kind == b'IEND':
            packed = zlib.compress(raw, 9)
            out += struct.pack('>I', len(packed)) + b'IDAT' + packed
            out += struct.pack('>I', zlib.crc32(b'IDAT' + packed) & 0xFFFFFFFF)
        out += struct.pack('>I', len(body)) + kind + body
        out += struct.pack('>I', zlib.crc32(kind + body) & 0xFFFFFFFF)
    open(path, 'wb').write(out)


for p in sys.argv[1:]:
    recompress(p)
