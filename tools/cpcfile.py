#!/usr/bin/env python3
"""
cpcfile.py — genera ficheros para el Amstrad CPC sin herramientas externas.

    cpcfile.py bin  ENTRADA SALIDA.BIN NOMBRE.EXT CARGA EJECUCION
        Añade la cabecera AMSDOS de 128 bytes a un binario.

    cpcfile.py dsk  SALIDA.dsk FICHERO.BIN [FICHERO.BIN ...]
        Crea un disco en formato DATA (178K) con los ficheros indicados.
        Los ficheros ya deben llevar cabecera AMSDOS.

    cpcfile.py cdt  SALIDA.cdt [--baud 1000|2000] [--tono SEGUNDOS] FICHERO.BIN [...]
    cpcfile.py wav  SALIDA.wav [--baud 1000|2000] [--tono SEGUNDOS] FICHERO.BIN [...]
        Crea una cinta (CDT para emuladores y reproductores, WAV para cargar
        en un CPC real desde un móvil u ordenador) con los ficheros
        indicados, grabados como los grabaría el firmware.
        --tono añade al final un tono de calibración de 2000 Hz para la prueba
        de cassette.

Parte de CPC Doctor. Licencia MIT.
"""
import struct
import sys
import wave

# ---------------------------------------------------------------- AMSDOS


def amsdos_header(name, load, exec_, length):
    h = bytearray(128)
    base, _, ext = name.upper().partition('.')
    h[1:9] = base[:8].ljust(8).encode('ascii')
    h[9:12] = ext[:3].ljust(3).encode('ascii')
    h[18] = 2                                   # binario
    h[21:23] = struct.pack('<H', load)
    h[24:26] = struct.pack('<H', length)
    h[26:28] = struct.pack('<H', exec_)
    h[64:67] = struct.pack('<I', length)[:3]
    h[67:69] = struct.pack('<H', sum(h[0:67]))
    return bytes(h)


def parse_amsdos(data):
    """Devuelve (nombre, carga, ejecución, contenido) de un .BIN con cabecera."""
    h = data[:128]
    if struct.unpack('<H', h[67:69])[0] != sum(h[0:67]) & 0xFFFF:
        raise SystemExit('el fichero no tiene cabecera AMSDOS válida')
    base = h[1:9].decode('ascii').rstrip()
    ext = h[9:12].decode('ascii').rstrip()
    load, = struct.unpack('<H', h[21:23])
    exec_, = struct.unpack('<H', h[26:28])
    length = h[64] | h[65] << 8 | h[66] << 16
    return base, ext, load, exec_, data[128:128 + length]

# ---------------------------------------------------------------- DSK

TRACKS, SECTORS, SECTOR_SIZE, FIRST_ID = 40, 9, 512, 0xC1
DIR_ENTRIES, BLOCK = 64, 1024


def make_dsk(out, files):
    disk = bytearray([0xE5]) * (TRACKS * SECTORS * SECTOR_SIZE)
    directory = bytearray([0xE5]) * (DIR_ENTRIES * 32)
    next_block, entry = 2, 0            # bloques 0 y 1: directorio
    for path in files:
        data = open(path, 'rb').read()
        base, ext, *_ = parse_amsdos(data)
        records = (len(data) + 127) // 128
        blocks = (len(data) + BLOCK - 1) // BLOCK
        first = next_block
        if first + blocks > (TRACKS * SECTORS * SECTOR_SIZE) // BLOCK:
            raise SystemExit('no cabe en el disco: ' + path)
        disk[first * BLOCK:first * BLOCK + len(data)] = data
        pad = (-len(data)) % 128
        disk[first * BLOCK + len(data):first * BLOCK + len(data) + pad] = b'\x1A' * pad
        next_block += blocks
        for extent in range((blocks + 15) // 16 or 1):
            if entry >= DIR_ENTRIES:
                raise SystemExit('directorio lleno')
            e = bytearray(32)
            e[0] = 0
            e[1:9] = base.ljust(8).encode('ascii')
            e[9:12] = ext.ljust(3).encode('ascii')
            e[12] = extent
            e[15] = min(128, records - extent * 128)
            for k in range(16):
                b = extent * 16 + k
                e[16 + k] = first + b if b < blocks else 0
            directory[entry * 32:(entry + 1) * 32] = e
            entry += 1
    disk[0:len(directory)] = directory

    img = bytearray(256)
    img[0:34] = b'MV - CPCEMU Disk-File\r\nDisk-Info\r\n'
    img[34:48] = b'CPCDoctor'.ljust(14, b' ')
    img[48] = TRACKS
    img[49] = 1
    track_size = 256 + SECTORS * SECTOR_SIZE
    img[50:52] = struct.pack('<H', track_size)
    order = [0, 5, 1, 6, 2, 7, 3, 8, 4]     # entrelazado habitual del CPC
    for t in range(TRACKS):
        ti = bytearray(256)
        ti[0:12] = b'Track-Info\r\n'
        ti[16] = t
        ti[17] = 0
        ti[20] = 2                          # 512 bytes
        ti[21] = SECTORS
        ti[22] = 0x4E
        ti[23] = 0xE5
        body = bytearray()
        for k, s in enumerate(order):
            ti[24 + k * 8:24 + k * 8 + 4] = bytes([t, 0, FIRST_ID + s, 2])
            off = (t * SECTORS + s) * SECTOR_SIZE
            body += disk[off:off + SECTOR_SIZE]
        img += ti + body
    open(out, 'wb').write(img)

# ---------------------------------------------------------------- cinta


def crc16(data):
    crc = 0xFFFF
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else crc << 1
            crc &= 0xFFFF
    return (~crc) & 0xFFFF


def tape_record(sync, payload):
    """Un registro del firmware: byte de sincronía, segmentos de 256 bytes
    con su CRC y 4 bytes de cola."""
    out = bytearray([sync])
    for off in range(0, len(payload), 256):
        seg = payload[off:off + 256].ljust(256, b'\0')
        out += seg + struct.pack('>H', crc16(seg))
    out += b'\xFF' * 4
    return bytes(out)


def tape_records(files):
    for path in files:
        data = open(path, 'rb').read()
        base, ext, load, exec_, body = parse_amsdos(data)
        name = (base + ('.' + ext if ext else '')).encode('ascii')[:16].ljust(16, b'\0')
        chunks = [body[i:i + 2048] for i in range(0, len(body), 2048)] or [b'']
        for n, chunk in enumerate(chunks):
            h = bytearray(64)
            h[0:16] = name
            h[16] = n + 1
            h[17] = 0xFF if n == len(chunks) - 1 else 0
            h[18] = 2
            h[19:21] = struct.pack('<H', len(chunk))
            h[21:23] = struct.pack('<H', (load + n * 2048) & 0xFFFF)
            h[23] = 0xFF if n == 0 else 0
            h[24:26] = struct.pack('<H', len(body))
            h[26:28] = struct.pack('<H', exec_)
            yield tape_record(0x2C, bytes(h))
            yield tape_record(0x16, chunk)


def timings(baud):
    # T-estados de 3,5 MHz (unidad del formato TZX/CDT) por semiperiodo
    zero = round(3500000 / (baud * 3))
    return zero, zero * 2


def make_cdt(out, files, baud, tone):
    zero, one = timings(baud)
    cdt = bytearray(b'ZXTape!\x1A\x01\x14')
    # el firmware espera unos 2 s a que el motor coja velocidad
    cdt += bytes([0x20]) + struct.pack('<H', 3000)
    for rec in tape_records(files):
        cdt += bytes([0x11]) + struct.pack('<HHHHHH', one, zero, zero, zero, one, 4096)
        cdt += bytes([8]) + struct.pack('<H', 800) + struct.pack('<I', len(rec))[:3] + rec
    if tone:
        half = 875                          # 2000 Hz a 3,5 MHz
        cdt += bytes([0x20]) + struct.pack('<H', 1000)
        count = int(tone * 4000)
        while count:
            n = min(count, 65534)
            cdt += bytes([0x12]) + struct.pack('<HH', half, n)
            count -= n
    open(out, 'wb').write(cdt)


def make_wav(out, files, baud, tone, rate=44100):
    zero, one = timings(baud)
    samples = bytearray()
    level = [False]
    clock = [0.0]

    def pulse(tstates):
        clock[0] += tstates * rate / 3500000
        n = int(clock[0])
        clock[0] -= n
        samples.extend((0xE0 if level[0] else 0x20,) * n)
        level[0] = not level[0]

    def silence(ms):
        samples.extend((0x80,) * int(rate * ms / 1000))
        level[0] = False

    silence(3000)
    for rec in tape_records(files):
        for _ in range(4096):
            pulse(one)
        pulse(zero)
        pulse(zero)
        for byte in rec:
            for bit in range(7, -1, -1):
                t = one if byte >> bit & 1 else zero
                pulse(t)
                pulse(t)
        silence(800)
    if tone:
        silence(1000)
        for _ in range(int(tone * 4000)):
            pulse(875)
        silence(500)
    with wave.open(out, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(1)
        w.setframerate(rate)
        w.writeframes(bytes(samples))

# ---------------------------------------------------------------- main


def main(argv):
    if len(argv) < 2:
        raise SystemExit(__doc__)
    cmd, args = argv[1], argv[2:]
    if cmd == 'bin':
        src, dst, name, load, exec_ = args
        data = open(src, 'rb').read()
        open(dst, 'wb').write(amsdos_header(name, int(load, 0), int(exec_, 0), len(data)) + data)
    elif cmd == 'dsk':
        make_dsk(args[0], args[1:])
    elif cmd in ('cdt', 'wav'):
        out, rest = args[0], args[1:]
        baud, tone, files = 1000, 0.0, []
        it = iter(rest)
        for a in it:
            if a == '--baud':
                baud = int(next(it))
            elif a == '--tono':
                tone = float(next(it))
            else:
                files.append(a)
        (make_cdt if cmd == 'cdt' else make_wav)(out, files, baud, tone)
    else:
        raise SystemExit(__doc__)


if __name__ == '__main__':
    main(sys.argv)
