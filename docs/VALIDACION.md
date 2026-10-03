# Validación

Lo que está comprobado y lo que falta. CPC Doctor 0.9 **no se ha probado todavía
en máquinas reales**. Si lo pruebas en la tuya, anota el modelo, la
configuración y el resultado, y añádelo a la tabla de abajo.

## Comprobado en el emulador (pruebas automáticas de `tests/run.sh` y revisión de capturas)

| Qué | 464 | 6128 |
|---|---|---|
| Carga desde cinta (CDT a 1000 baudios, comprimida) | ✔ | — |
| Carga desde disco | — | ✔ |
| ROM baja en lugar de la del sistema | ✔ | ✔ |
| Identificación: modelo, RAM, CRTC, chip de sonido | ✔ | ✔ |
| RAM baja con mapa, sin fallos y con un bit dañado simulado | — | ✔ |
| RAM alta (64 KB del 6128) y configuración C3 | — | ✔ |
| Identificación de ROMs por CRC (OS, BASIC, AMSDOS) | — | ✔ |
| Teclado: tecla atascada, rebotes y resultado | — | ✔ |
| Cassette: velocidad nominal y motor un 3 % y un 5 % lento | ✔ | — |
| Imagen y sonido: pantallas, preguntas y consejos | — | ✔ |
| Resumen final | — | ✔ |
| Textos en español e inglés | ✔ | ✔ |

## Sin comprobar

El emulador no puede reproducir estas situaciones:

- **CRTC distintos del tipo 1.** La detección de los tipos 0, 2, 3, 4 y 5 viene
  de Amstrad Diagnostics y de Lordheavy/Cheshirecat, pero no se ha probado aquí.
- **664**, **CPC Plus**, **GX4000**, el cartucho CPR y la ROM alta (M4 o placa de
  ROMs).
- **Ampliaciones de RAM de más de 64 KB** (DDI-5, 512 KB, 4 MB). La nueva
  detección con firmas está pensada para el issue #13, pero hay que confirmarla.
- **Cinta a 2000 baudios**: en el emulador no carga, así que se usa 1000.
- **El WAV** cargado desde un móvil en un 464 real.
- **La prueba de cassette con una pletina de verdad.** Hay que comprobar que la
  estabilidad baja de verdad con el azimut desajustado y que los márgenes (±3 %,
  90 %) son razonables.
- **El sonido.** El emulador no reproduce audio en las pruebas.
- **La confirmación del AY lento en hardware real.** El patrón se vio en un 464
  real con un AY-3-8912A de recambio, pero la comparación entre la lectura
  normal y la lenta solo se ha probado con la avería imitada en el emulador
  (`sloway`). Hace falta un CPC con un AY así para confirmarla.
- **La medida del puerto A del AY al arrancar.** Pone el puerto como salida a
  0, lo suelta y mira cuánto tarda en volver a 1. La primera lectura llega a
  unos 42 µs, así que un puerto que tarde entre 6 µs (lo que espera la lectura
  normal del teclado) y 42 µs hace fallar el teclado pero no se detecta. Solo
  se ha probado en el emulador (`slowport`). Falta comprobar en un CPC real
  que un AY sano no da el aviso y, si se puede, que uno lento sí.
- **Monitores reales.** Hay que ver si los patrones y las preguntas se entienden
  en un CTM, un GT65 y por modulador.
- **La prueba de la disquetera.** Viene del fork de issalig, que la probó en
  hardware real, pero el emulador no reproduce el giro del disco: en CPC Doctor
  solo se ha comprobado que termina y avisa sin colgarse.
- **La detección del tipo de Z80** en más máquinas: en un 464 real dio "NMOS,
  Zilog" (el emulador da "NEC" porque no imita esos flags al detalle).
- **El CRC del 6128 danés (#15).** Procede de un solo equipo.
- **La prueba continua** durante horas.

## Resultados en máquinas reales

| Fecha | Modelo | Configuración | Variante | Resultado | Quién |
|---|---|---|---|---|---|
| 2026-09-23 | CPC 464 | M4 Board | Disco (DOCTOR.BIN lanzado desde la M4), español | Carga, descomprime y muestra el menú principal. Pruebas pendientes. | Raul Jimenez |
| 2026-09-23 | CPC 464 | M4 Board, ROM del 6128 (OS y BASIC 1.1) | Disco (DOCTOR.BIN desde la M4), español | Detecta CRTC 0, AY-3-8912, 64 KB. Sin preguntar salía "CPC 6128"; con la pregunta del modelo (0.9, commit posterior) se elige 464 y se muestra bien. | Raul Jimenez |
| 2026-09-23 | CPC 464 | M4 Board, ROM del 6128 | Disco desde la M4, español | **Primer diagnóstico real.** Sonido: el canal B y la envolvente no se oyen y el ruido (también por el canal B) sí. Confirmado en BASIC: `SOUND 2,239,200,15` no suena y `SOUND 2,0,200,15,0,0,15` sí. Falla el generador de tono B del AY-3-8912. La prueba lo explica desde entonces de forma específica. | Raul Jimenez |
| 2026-09-26 | CPC 464 | M4 Board, ROM del 6128 | Disco desde la M4, español | Z80 detectado como **NMOS, Zilog** (el emulador daba NEC). Disquetera: "No disponible" (la M4 no tiene FDC), correcto. Ayuda y salida al BASIC con ESC funcionan. | Raul Jimenez |
| 2026-10-03 | CPC 464 | M4 Board, ROM del 6128, AY-3-8912 sustituido | Disco desde la M4, español | Sonido: con el chip nuevo suenan todos los canales y da **Superado**. **Segundo diagnóstico real:** cada tecla encendía también la de la línea siguiente de la matriz (↓ y f7, H y G, espacio y V). Desde entonces la prueba de teclado detecta las teclas que se encienden juntas. | Raul Jimenez |
| 2026-10-03 | CPC 464 | M4 Board, ROM del 6128 | Disco desde la M4, español | **La causa era el AY nuevo (AY-3-8912A):** leyendo el teclado con una espera de unos 100 µs antes de cada línea, cada tecla aparecía una sola vez, y con el AY original el teclado iba bien. El puerto A del recambio tarda en volver a reposo al cambiar de línea. Desde entonces la prueba reconoce el patrón (líneas consecutivas unidas) y lo confirma comparando la lectura normal con una lenta. | Raul Jimenez |

## Fallos del programa encontrados en máquinas reales

- La envolvente de volumen duraba 0,1 s (periodo mal calculado): en el CPC solo
  se oía un chasquido. Corregido.
- ROM de 6128 en un 464: el modelo salía como "CPC 6128". Ahora se indica la
  duda y se pregunta.
- Prueba continua sin RAM alta: se quedaba colgada (variable sin inicializar).
  Corregido.
- La prueba continua borraba el modelo confirmado y los resultados. Corregido.
- La prueba de cassette con la cinta de un juego daba una velocidad absurda.
  Ahora dice que la señal no es el tono.
