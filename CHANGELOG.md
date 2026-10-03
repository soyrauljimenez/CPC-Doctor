# Cambios

## Sin publicar

### Nuevo
- Identificación: versión de la controladora de disco. Los µPD765A y sus
  clones no conocen la orden VERSION; el µPD765B y posteriores sí. Se
  muestra como "Sí (765A)" o "Sí (765B)".
- Emulador de pruebas: opción `fdcb` para imitar un µPD765B.

## 0.9.1

### Nuevo
- Teclado: detecta teclas que se encienden a la vez (líneas o columnas de la
  matriz unidas) y las lista todas.
- Teclado: si cada tecla aparece también en la línea siguiente, comprueba si
  es el chip AY, que lee el teclado y tarda en reaccionar al cambiar de
  línea. Pide mantener una tecla y compara la lectura normal con otra más
  lenta. Pasa con algunos AY de recambio, aunque suenen bien.
- Modo automático: si al arrancar no se pulsa nada en 30 segundos, se hacen
  solas las pruebas que no necesitan respuestas (teclado y joystick,
  disquetera, RAM baja, RAM alta y ROMs) y se termina en el resumen. Sirve
  cuando el teclado no funciona.
- En el modo automático también se muestran los patrones de imagen y suenan
  los sonidos, sin preguntar. Quedan sin probar.
- Al arrancar se mide si el puerto A del AY tarda en volver a reposo, sin
  pulsar teclas. Si es lento se avisa en la prueba de teclado y en el resumen.
- Teclado y joystick: la prueba termina sola tras 10 segundos sin
  pulsaciones.
- Emulador de pruebas: averías `sloway` y `slowport` para imitar ese AY.
- La versión cargada pone su bloque de trabajo en #A800 (antes #A000) para
  tener sitio; el compresor comprueba que el programa no pise el
  descompresor.

### Cambiado
- Teclado: una tecla atascada da Error aunque se hayan probado pocas teclas
  (antes, Inconcluso).

### Corregido
- La lista de líneas unidas se salía de la pantalla.

## 0.9 — primera versión de CPC Doctor

Basada en Amstrad Diagnostics 1.4 (commit 7ac70fc).

### Nuevo
- Pruebas guiadas en la versión de cinta y disco: explicación previa,
  resultado, lo observado o medido y qué comprobar después.
- Resultados "inconcluso" y "no disponible", además de superado, error y sin
  probar.
- Teclado: teclas atascadas, rebotes y análisis por líneas y columnas de la
  matriz.
- Imagen: niveles de color, escala de brillo, geometría, nitidez y
  estabilidad, con consejos según la pantalla.
- Sonido: cada canal por separado, ruido y envolvente, con preguntas.
- Cassette: velocidad del motor y estabilidad de la señal con un tono de
  calibración.
- RAM baja en la versión cargada: todo lo que no ocupa el programa, con mapa.
- Resumen final para fotografiar, con código de resultados.
- Español e inglés; fuente con minúsculas, tildes, ñ, ¿ y ¡.
- Menú numerado, manejable con teclado o joystick.
- Chip de sonido (AY o YM) y CRTC 5 en la identificación.
- Carga desde cinta comprimida (un tercio más rápida). Discos, cintas CDT y
  WAV generados sin herramientas externas.
- Emulador de pruebas y pruebas automáticas.

- Disquetera: velocidad de giro en rpm, y tipo de Z80 en la ficha del equipo,
  portados del fork de Ismael Salvador (issalig).
- Salir al BASIC con ESC desde el menú.

### Corregido
- Issues #11, #12, #13, #15 y #17 de Amstrad Diagnostics; PRs #14 y #18
  incorporados.
- Salida con ESC de la RAM alta, comprobación C3, ClearScreen,
  WaitForVsync, vuelta 255 de la prueba continua, escritura en #4000 al
  detectar el Plus y cobertura real de la RAM baja en la versión cargada.
