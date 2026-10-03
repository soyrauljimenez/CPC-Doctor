/*
    cpcemu — emulador de Amstrad CPC sin interfaz, para pruebas automáticas.

    Usa la emulación de https://github.com/floooh/chips (licencia zlib,
    ver chips/LICENSE). Este fichero es parte de CPC Doctor (MIT).

    Uso:
        cpcemu [opciones] orden [orden ...]

    Opciones:
        -m 464|6128        modelo (por defecto 464)
        -r DIR             carpeta con cpc464.rom, cpc6128.rom, amsdos.rom
        -o FICHERO         sustituye la ROM baja (16 KB) por FICHERO
        -b FICHERO         sustituye la ROM del BASIC (ROM alta 0) por FICHERO
        -d FICHERO.dsk     inserta un disco (solo 6128)
        -t FICHERO.cdt     pone una cinta (avanza solo con el motor encendido)
        -l N               puentes LK1-3 (marca): 7=Amstrad, 5=Schneider...
        -60                máquina de 60 Hz (LK4)
        -v N               duración de los pulsos de la cinta en % (105 = motor un 5 % lento)

    Órdenes (se ejecutan en orden):
        wait N             ejecuta N cuadros (1/50 s)
        load FICH.bin      carga un binario con cabecera AMSDOS y lo ejecuta
                           (hace falta estar en el BASIC)
        type TEXTO         teclea TEXTO ('~' = RETURN)
        key R:B            pulsa la tecla de la fila R, bit B de la matriz
        hold R:B           mantiene pulsada la tecla R:B
        release R:B        suelta la tecla R:B
        releaseall         suelta todo
        joy MASCARA        joystick 0: 1=arriba 2=abajo 4=izq 8=der 16=fuego
        shot FICH.png      captura la pantalla
        peek DIR [N]       imprime N bytes (hex) desde DIR
        dump DIR N FICH    guarda N bytes de memoria desde DIR
        vram FICH          guarda los 16 KB de &C000 (lo que ve el CRTC)
        corrupt DIR MASK   invierte bits MASK en la RAM física DIR (0..FFFF)
        tape               informa de la posición de la cinta
        regs               muestra los registros de la CPU
        level N            ejecuta N cuadros y muestra el nivel de audio (RMS)
        ay                 muestra los registros del AY
        sloway N   AY lento: N ciclos tras cambiar de línea del teclado se sigue
                   viendo la anterior (cada tecla aparece también en la siguiente)
        fdcb       la controladora de disco responde como un µPD765B (VERSION = #90)
        slowport N al pasar el puerto A del AY de salida a entrada, se lee 0
                   durante N ciclos (pull-ups débiles)
        fault DIR LEN MASK a partir de aquí, las lecturas de DIR..DIR+LEN-1
                           devuelven los bits MASK a 0 (chip de RAM dañado)
*/
#define CHIPS_IMPL
#include "chips/chips_common.h"
#include "chips/z80.h"
#include "chips/ay38910.h"
#include "chips/i8255.h"
#include "chips/mc6845.h"
#include "chips/am40010.h"
#include "chips/upd765.h"
#include "chips/mem.h"
#include "chips/kbd.h"
#include "chips/clk.h"
#include "chips/fdd.h"
#include "chips/fdd_cpc.h"
#include "chips/cpc.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static cpc_t cpc;
static double audio_sum;
static long audio_count;
static void audio_cb(const float* samples, int num, void* user) {
    (void)user;
    for (int k = 0; k < num; k++) { audio_sum += (double)samples[k] * samples[k]; audio_count++; }
}

/* ---- cinta -------------------------------------------------------------- */
extern uint64_t cpcdoc_ticks;
extern bool cpcdoc_motor;
extern uint8_t cpcdoc_links;
extern bool cpcdoc_50hz;
extern bool (*cpcdoc_tape_bit)(void);
extern uint16_t cpcdoc_fault_start, cpcdoc_fault_len;
extern uint8_t cpcdoc_fault_mask;
extern uint32_t cpcdoc_slow_ay, cpcdoc_slow_port;
bool cpcdoc_fdc_b;      // la controladora responde como un µPD765B

typedef struct { uint32_t len; uint8_t level; } pulse_t;   // len en ticks de 4 MHz
static pulse_t* tape;
static int tape_speed = 100;    // % de la duración nominal (105 = cinta un 5 % lenta)
static size_t tape_count, tape_cap, tape_pos;
static uint64_t tape_elapsed, tape_last;
static uint8_t tape_level;

static void tape_add(uint32_t tstates35, int level) {
    if (tape_count == tape_cap) {
        tape_cap = tape_cap ? tape_cap * 2 : 65536;
        tape = realloc(tape, tape_cap * sizeof(pulse_t));
    }
    tape[tape_count].len = (uint32_t)((uint64_t)tstates35 * 8 * tape_speed / 700);
    tape[tape_count].level = (uint8_t)level;
    tape_count++;
}
static void tape_toggle(uint32_t t) { tape_level ^= 1; tape_add(t, tape_level); }
static void tape_pause(uint32_t ms) { if (ms) { tape_level = 0; tape_add(ms * 3500, 0); } }
static void tape_data(const uint8_t* d, uint32_t len, int used, uint16_t zero, uint16_t one) {
    for (uint32_t i = 0; i < len; i++) {
        int bits = (i == len - 1) ? used : 8;
        for (int b = 7; b >= 8 - bits; b--) {
            uint16_t t = (d[i] >> b & 1) ? one : zero;
            tape_toggle(t);
            tape_toggle(t);
        }
    }
}

static void load_cdt(const uint8_t* d, size_t n) {
    if (n < 10 || memcmp(d, "ZXTape!\x1A", 8)) { fprintf(stderr, "cpcemu: no es un CDT\n"); exit(1); }
    size_t p = 10;
#define W(o) ((uint16_t)(d[p + (o)] | d[p + (o) + 1] << 8))
#define T(o) ((uint32_t)(d[p + (o)] | d[p + (o) + 1] << 8 | d[p + (o) + 2] << 16))
    while (p < n) {
        uint8_t id = d[p++];
        switch (id) {
        case 0x10: { uint16_t pause = W(0), len = W(2);
            int pilots = (d[p + 4] < 128) ? 8063 : 3223;
            for (int k = 0; k < pilots; k++) tape_toggle(2168);
            tape_toggle(667); tape_toggle(735);
            tape_data(d + p + 4, len, 8, 855, 1710); tape_pause(pause); p += 4 + len; break; }
        case 0x11: { uint16_t pilot = W(0), s1 = W(2), s2 = W(4), zero = W(6), one = W(8), pcount = W(10);
            int used = d[p + 12]; uint16_t pause = W(13); uint32_t len = T(15);
            for (int k = 0; k < pcount; k++) tape_toggle(pilot);
            tape_toggle(s1); tape_toggle(s2);
            tape_data(d + p + 18, len, used, zero, one); tape_pause(pause); p += 18 + len; break; }
        case 0x12: { uint16_t len = W(0), count = W(2); for (int k = 0; k < count; k++) tape_toggle(len); p += 4; break; }
        case 0x13: { int cnt = d[p]; for (int k = 0; k < cnt; k++) tape_toggle(W(1 + 2 * k)); p += 1 + 2 * cnt; break; }
        case 0x14: { uint16_t zero = W(0), one = W(2); int used = d[p + 4]; uint16_t pause = W(5); uint32_t len = T(7);
            tape_data(d + p + 10, len, used, zero, one); tape_pause(pause); p += 10 + len; break; }
        case 0x20: tape_pause(W(0)); p += 2; break;
        case 0x21: case 0x30: p += 1 + d[p]; break;
        case 0x22: break;
        case 0x32: p += 2 + W(0); break;
        default: fprintf(stderr, "cpcemu: bloque CDT %02X no soportado\n", id); exit(1);
        }
    }
#undef W
#undef T
}

static bool tape_bit(void) {
    uint64_t now = cpcdoc_ticks;
    if (cpcdoc_motor) tape_elapsed += now - tape_last;
    tape_last = now;
    while (tape_pos < tape_count && tape_elapsed >= tape[tape_pos].len) {
        tape_elapsed -= tape[tape_pos].len;
        tape_pos++;
    }
    return tape_pos < tape_count && tape[tape_pos].level;
}
static uint8_t os_rom[0x4000], basic_rom[0x4000], amsdos_rom[0x4000];
static uint8_t matrix_hold[10];

#define MATRIX_KEY(r, b) (0x80 + (r) * 8 + (b))

static void die(const char* msg, const char* arg) {
    fprintf(stderr, "cpcemu: %s %s\n", msg, arg ? arg : "");
    exit(1);
}

static long load_file(const char* path, uint8_t* buf, long max) {
    FILE* f = fopen(path, "rb");
    if (!f) die("no puedo abrir", path);
    long n = (long)fread(buf, 1, (size_t)max, f);
    fclose(f);
    return n;
}

static void frames(int n) {
    for (int i = 0; i < n; i++) {
        cpc_exec(&cpc, 20000);
    }
}

/* ---- PNG mínimo (bloques deflate sin comprimir) ------------------------- */
static uint32_t crc_table[256];
static void crc_init(void) {
    for (uint32_t n = 0; n < 256; n++) {
        uint32_t c = n;
        for (int k = 0; k < 8; k++) c = (c & 1) ? 0xEDB88320u ^ (c >> 1) : c >> 1;
        crc_table[n] = c;
    }
}
static uint32_t crc(uint32_t c, const uint8_t* p, size_t n) {
    c ^= 0xFFFFFFFFu;
    while (n--) c = crc_table[(c ^ *p++) & 0xFF] ^ (c >> 8);
    return c ^ 0xFFFFFFFFu;
}
static void put32(FILE* f, uint32_t v) {
    uint8_t b[4] = { (uint8_t)(v >> 24), (uint8_t)(v >> 16), (uint8_t)(v >> 8), (uint8_t)v };
    fwrite(b, 1, 4, f);
}
static void chunk(FILE* f, const char* type, const uint8_t* data, uint32_t len) {
    put32(f, len);
    uint8_t* tmp = malloc(len + 4);
    memcpy(tmp, type, 4);
    if (len) memcpy(tmp + 4, data, len);
    fwrite(tmp, 1, len + 4, f);
    put32(f, crc(0, tmp, len + 4));
    free(tmp);
}
static void write_png(const char* path, const uint8_t* rgb, int w, int h) {
    FILE* f = fopen(path, "wb");
    if (!f) die("no puedo escribir", path);
    static const uint8_t sig[8] = { 137, 80, 78, 71, 13, 10, 26, 10 };
    fwrite(sig, 1, 8, f);
    uint8_t ihdr[13] = { 0 };
    ihdr[0] = (uint8_t)(w >> 24); ihdr[1] = (uint8_t)(w >> 16); ihdr[2] = (uint8_t)(w >> 8); ihdr[3] = (uint8_t)w;
    ihdr[4] = (uint8_t)(h >> 24); ihdr[5] = (uint8_t)(h >> 16); ihdr[6] = (uint8_t)(h >> 8); ihdr[7] = (uint8_t)h;
    ihdr[8] = 8; ihdr[9] = 2;
    chunk(f, "IHDR", ihdr, 13);
    size_t raw_len = (size_t)h * (1 + w * 3);
    uint8_t* raw = malloc(raw_len);
    for (int y = 0; y < h; y++) {
        raw[y * (1 + w * 3)] = 0;
        memcpy(raw + y * (1 + w * 3) + 1, rgb + y * w * 3, (size_t)w * 3);
    }
    size_t nblocks = (raw_len + 65534) / 65535;
    size_t z_len = 2 + raw_len + nblocks * 5 + 4;
    uint8_t* z = malloc(z_len);
    size_t p = 0;
    z[p++] = 0x78; z[p++] = 0x01;
    uint32_t a = 1, b = 0;
    for (size_t i = 0; i < raw_len; i++) { a = (a + raw[i]) % 65521; b = (b + a) % 65521; }
    for (size_t off = 0; off < raw_len; off += 65535) {
        size_t n = raw_len - off < 65535 ? raw_len - off : 65535;
        z[p++] = (off + n >= raw_len) ? 1 : 0;
        z[p++] = (uint8_t)n; z[p++] = (uint8_t)(n >> 8);
        z[p++] = (uint8_t)~n; z[p++] = (uint8_t)(~n >> 8);
        memcpy(z + p, raw + off, n);
        p += n;
    }
    uint32_t adler = (b << 16) | a;
    z[p++] = (uint8_t)(adler >> 24); z[p++] = (uint8_t)(adler >> 16); z[p++] = (uint8_t)(adler >> 8); z[p++] = (uint8_t)adler;
    chunk(f, "IDAT", z, (uint32_t)p);
    chunk(f, "IEND", NULL, 0);
    fclose(f);
    free(raw);
    free(z);
}

static void screenshot(const char* path) {
    chips_display_info_t info = cpc_display_info(&cpc);
    const int w = info.screen.width, h = info.screen.height;
    const uint32_t* pal = (const uint32_t*)info.palette.ptr;
    const uint8_t* fb = (const uint8_t*)info.frame.buffer.ptr;
    const int fbw = info.frame.dim.width;
    /* cada línea se duplica para recuperar la proporción real */
    uint8_t* rgb = malloc((size_t)w * h * 2 * 3);
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            uint32_t c = pal[fb[y * fbw + x] & 0x1F];
            for (int d = 0; d < 2; d++) {
                uint8_t* px = rgb + (((y * 2 + d) * w) + x) * 3;
                px[0] = (uint8_t)c; px[1] = (uint8_t)(c >> 8); px[2] = (uint8_t)(c >> 16);
            }
        }
    }
    write_png(path, rgb, w, h * 2);
    free(rgb);
}

/* ---- teclado ------------------------------------------------------------ */
static void parse_key(const char* s, int* r, int* b) {
    if (sscanf(s, "%d:%d", r, b) != 2 || *r < 0 || *r > 9 || *b < 0 || *b > 7) die("tecla no válida:", s);
}

static void press_key(int code) {
    cpc_key_down(&cpc, code);
    frames(3);
    cpc_key_up(&cpc, code);
    frames(3);
}

static void type_text(const char* s) {
    for (; *s; s++) {
        int c = (*s == '~') ? 0x0D : (unsigned char)*s;
        press_key(c);
    }
}

/* ---- memoria ------------------------------------------------------------ */
static uint8_t rd(uint16_t addr) { return mem_rd(&cpc.mem, addr); }

int main(int argc, char** argv) {
    crc_init();
    const char* model = "464";
    const char* romdir = NULL;
    const char* os_override = NULL;
    const char* basic_override = NULL;
    const char* dsk = NULL;
    const char* cdt = NULL;
    int i = 1;
    for (; i < argc && argv[i][0] == '-'; i++) {
        if (!strcmp(argv[i], "-m") && i + 1 < argc) model = argv[++i];
        else if (!strcmp(argv[i], "-r") && i + 1 < argc) romdir = argv[++i];
        else if (!strcmp(argv[i], "-o") && i + 1 < argc) os_override = argv[++i];
        else if (!strcmp(argv[i], "-b") && i + 1 < argc) basic_override = argv[++i];
        else if (!strcmp(argv[i], "-d") && i + 1 < argc) dsk = argv[++i];
        else if (!strcmp(argv[i], "-t") && i + 1 < argc) cdt = argv[++i];
        else if (!strcmp(argv[i], "-l") && i + 1 < argc) cpcdoc_links = (uint8_t)atoi(argv[++i]);
        else if (!strcmp(argv[i], "-60")) cpcdoc_50hz = false;
        else if (!strcmp(argv[i], "-v") && i + 1 < argc) tape_speed = atoi(argv[++i]);
        else die("opción desconocida", argv[i]);
    }
    if (!romdir) {
        static char buf[1024];
        const char* slash = strrchr(argv[0], '/');
        snprintf(buf, sizeof(buf), "%.*s/roms", slash ? (int)(slash - argv[0]) : 1, slash ? argv[0] : ".");
        romdir = buf;
    }

    char path[1200];
    static uint8_t rom32[0x8000];
    const bool is6128 = !strcmp(model, "6128");
    snprintf(path, sizeof(path), "%s/%s", romdir, is6128 ? "cpc6128.rom" : "cpc464.rom");
    if (load_file(path, rom32, sizeof(rom32)) != 0x8000) die("ROM incompleta:", path);
    memcpy(os_rom, rom32, 0x4000);
    memcpy(basic_rom, rom32 + 0x4000, 0x4000);
    if (is6128) {
        snprintf(path, sizeof(path), "%s/amsdos.rom", romdir);
        load_file(path, amsdos_rom, sizeof(amsdos_rom));
    }
    if (basic_override) {
        memset(basic_rom, 0xFF, sizeof(basic_rom));
        load_file(basic_override, basic_rom, sizeof(basic_rom));
    }
    if (os_override) {
        memset(os_rom, 0xFF, sizeof(os_rom));
        load_file(os_override, os_rom, sizeof(os_rom));
    }

    cpc_desc_t desc = {
        .type = is6128 ? CPC_TYPE_6128 : CPC_TYPE_464,
        .joystick_type = CPC_JOYSTICK_DIGITAL,
        .audio = { .callback = { .func = audio_cb } },
        .roms = {
            .cpc464 = { .os = { os_rom, 0x4000 }, .basic = { basic_rom, 0x4000 } },
            .cpc6128 = { .os = { os_rom, 0x4000 }, .basic = { basic_rom, 0x4000 }, .amsdos = { amsdos_rom, 0x4000 } },
        },
    };
    cpc_init(&cpc, &desc);
    for (int r = 0; r < 10; r++)
        for (int b = 0; b < 8; b++)
            kbd_register_key(&cpc.kbd, MATRIX_KEY(r, b), r, b, 0);

    if (dsk) {
        static uint8_t dskbuf[1024 * 1024];
        long n = load_file(dsk, dskbuf, sizeof(dskbuf));
        if (!cpc_insert_disc(&cpc, (chips_range_t){ dskbuf, (size_t)n })) die("disco no válido:", dsk);
    }

    if (cdt) {
        static uint8_t cdtbuf[512 * 1024];
        long n = load_file(cdt, cdtbuf, sizeof(cdtbuf));
        load_cdt(cdtbuf, (size_t)n);
        cpcdoc_tape_bit = tape_bit;
    }

    for (; i < argc; i++) {
        const char* cmd = argv[i];
        const char* arg = (i + 1 < argc) ? argv[i + 1] : NULL;
        if (!strcmp(cmd, "wait") && arg) { frames(atoi(arg)); i++; }
        else if (!strcmp(cmd, "load") && arg) {
            static uint8_t bin[0x10000 + 128];
            long n = load_file(arg, bin, sizeof(bin));
            if (!cpc_quickload(&cpc, (chips_range_t){ bin, (size_t)n }, true)) die("binario no válido:", arg);
            i++;
        }
        else if (!strcmp(cmd, "type") && arg) { type_text(arg); i++; }
        else if (!strcmp(cmd, "key") && arg) { int r, b; parse_key(arg, &r, &b); press_key(MATRIX_KEY(r, b)); i++; }
        else if (!strcmp(cmd, "hold") && arg) { int r, b; parse_key(arg, &r, &b); cpc_key_down(&cpc, MATRIX_KEY(r, b)); matrix_hold[r] |= 1 << b; i++; }
        else if (!strcmp(cmd, "release") && arg) { int r, b; parse_key(arg, &r, &b); cpc_key_up(&cpc, MATRIX_KEY(r, b)); matrix_hold[r] &= ~(1 << b); i++; }
        else if (!strcmp(cmd, "releaseall")) {
            for (int r = 0; r < 10; r++) for (int b = 0; b < 8; b++) if (matrix_hold[r] & (1 << b)) cpc_key_up(&cpc, MATRIX_KEY(r, b));
            memset(matrix_hold, 0, sizeof(matrix_hold));
        }
        else if (!strcmp(cmd, "joy") && arg) { cpc_joystick(&cpc, (uint8_t)strtol(arg, NULL, 0)); i++; }
        else if (!strcmp(cmd, "fault") && i + 3 < argc) {
            cpcdoc_fault_start = (uint16_t)strtol(argv[i + 1], NULL, 16);
            cpcdoc_fault_len = (uint16_t)strtol(argv[i + 2], NULL, 16);
            cpcdoc_fault_mask = (uint8_t)strtol(argv[i + 3], NULL, 16);
            i += 3;
        }
        else if (!strcmp(cmd, "sloway") && arg) { cpcdoc_slow_ay = (uint32_t)atoi(arg); i++; }
        else if (!strcmp(cmd, "fdcb")) { cpcdoc_fdc_b = true; }
        else if (!strcmp(cmd, "slowport") && arg) { cpcdoc_slow_port = (uint32_t)atoi(arg); i++; }
        else if (!strcmp(cmd, "level") && arg) {
            audio_sum = 0; audio_count = 0;
            frames(atoi(arg));
            printf("audio: %.4f\n", audio_count ? sqrt(audio_sum / audio_count) : 0.0);
            i++;
        }
        else if (!strcmp(cmd, "ay")) {
            printf("AY:");
            for (int r = 0; r < 14; r++) printf(" %02X", cpc.psg.reg[r]);
            printf("\n");
        }
        else if (!strcmp(cmd, "regs")) {
            printf("PC=%04X SP=%04X AF=%04X BC=%04X DE=%04X HL=%04X IX=%04X IY=%04X\n",
                cpc.cpu.pc, cpc.cpu.sp, cpc.cpu.af, cpc.cpu.bc, cpc.cpu.de, cpc.cpu.hl, cpc.cpu.ix, cpc.cpu.iy);
        }
        else if (!strcmp(cmd, "tape")) { printf("cinta: %zu/%zu pulsos, motor %s\n", tape_pos, tape_count, cpcdoc_motor ? "ON" : "OFF"); }
        else if (!strcmp(cmd, "shot") && arg) { screenshot(arg); i++; }
        else if (!strcmp(cmd, "peek") && arg) {
            uint16_t a = (uint16_t)strtol(arg, NULL, 16);
            int n = 1;
            if (i + 2 < argc && argv[i + 2][0] >= '0' && argv[i + 2][0] <= '9') { n = atoi(argv[i + 2]); i++; }
            printf("%04X:", a);
            for (int k = 0; k < n; k++) printf(" %02X", rd((uint16_t)(a + k)));
            printf("\n");
            i++;
        }
        else if (!strcmp(cmd, "dump") && i + 3 < argc) {
            uint16_t a = (uint16_t)strtol(argv[i + 1], NULL, 16);
            int n = (int)strtol(argv[i + 2], NULL, 0);
            FILE* f = fopen(argv[i + 3], "wb");
            if (!f) die("no puedo escribir", argv[i + 3]);
            for (int k = 0; k < n; k++) fputc(rd((uint16_t)(a + k)), f);
            fclose(f);
            i += 3;
        }
        else if (!strcmp(cmd, "vram") && arg) {
            FILE* f = fopen(arg, "wb");
            if (!f) die("no puedo escribir", arg);
            fwrite(cpc.ram[3], 1, 0x4000, f);
            fclose(f);
            i++;
        }
        else if (!strcmp(cmd, "corrupt") && i + 2 < argc) {
            unsigned a = (unsigned)strtol(argv[i + 1], NULL, 16);
            uint8_t m = (uint8_t)strtol(argv[i + 2], NULL, 16);
            cpc.ram[a >> 14][a & 0x3FFF] ^= m;
            i += 2;
        }
        else die("orden desconocida o incompleta:", cmd);
    }
    return 0;
}
