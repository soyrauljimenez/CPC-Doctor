# Cambios

## 1.0.0

Primera versión estable. Reúne todo lo de las 0.9.x.

### Nuevo
- Resumen: la línea del teclado dice también las líneas o columnas de la
  matriz que no responden ("columna 3") y si hay líneas o columnas unidas.
- Teclado: una línea o columna cuenta como sin respuesta también cuando
  solo responde una de sus teclas.
- CPC 472: con la ROM del 664 y sin disquetera ni RAM alta, el modelo es
  "CPC 472" y se trata como un 464 (dibujo del teclado, chips de RAM).

### Corregido
- Resumen: mientras se guarda el informe en la M4 (unos segundos) se avisa
  en la línea de ayuda, y la ayuda dice "ENTER o espacio" (si ENTER falla,
  se puede usar el espacio).
- Con una M4 que pone su propio BASIC, CPC Doctor podía seguir mandándole
  órdenes mientras recargaba sus ROMs y colgarse en los detalles del
  equipo, si el BASIC de la M4 y el de la placa tenían la misma versión.
  Ahora espera a que la ROM 0 vuelva a ser exactamente la de antes.

## 0.9.9

### Nuevo
- Detalles del equipo: si la M4 pone su propia ROM baja y su BASIC, se lee
  también el BASIC de la placa. Para eso se apagan un momento las ROMs de
  la M4 (C_ROMSOFF, sin reiniciar), se lee la ROM 0 y se vuelven a cargar
  (C_ROMSUPDATE). Sale en su propia línea, "BASIC de la placa". Sustituye
  al aviso de la 0.9.8.

## 0.9.8

### Nuevo
- Detalles del equipo: si la M4 pone su propia ROM baja, la línea del
  BASIC avisa de que probablemente es el de la M4 y no el de la placa (el
  de la placa no se puede leer por debajo).

## 0.9.7

### Nuevo
- Detalles del equipo: el BASIC de la ROM 0, con su versión (del texto que
  muestra al arrancar, "BASIC 1.0", "1.1"...) y su nombre por la firma,
  con el país.

### Cambiado
- La opción 0 del menú se llama "Resumen y equipo", el consejo del menú
  dice que ahí está qué equipo es, y en el resumen "ENTER: detalles del
  equipo" va en la línea de ayuda, aparte. También lo explica la Ayuda.
- El bloque de trabajo de la versión de disco y cinta pasa a #B400.

## 0.9.6

### Cambiado
- El teclado del equipo se deduce de la tabla de teclas de la ROM del
  sistema, sea cual sea la ROM: Ñ (española), FR (AZERTY), DE (QWERTZ),
  DK (por su firma) o EN (QWERTY inglés). Antes, cualquier ROM que no fuera
  española ni francesa salía como inglesa; ahora, si no se puede saber, no
  se indica.

## 0.9.5

### Nuevo
- Ficha del menú y resumen: la versión del equipo detrás del modelo, por la
  ROM del sistema (Ñ, FR, DK o EN; "1988+" con la placa abaratada), una
  línea con la ROM del sistema y quién fabrica el CRTC (Hitachi/UMC, UMC
  6845R, Motorola, o el ASIC o Gate Array que lo lleva dentro).
- Detalles del equipo: con la ROM española dice "teclado con Ñ" y explica
  aparte cómo saber si la placa es larga o corta.
- Pitido de arranque por los canales A y B a la vez (versión de disco y
  cinta), para oírlo aunque falle uno de los dos.

## 0.9.4

### Nuevo
- Página "Detalles del equipo", al pulsar ENTER en el resumen: de dónde sale
  el modelo, la ROM del sistema y la que pone la M4 encima, las ROMs de
  expansión y lo que se puede deducir de la placa: placa abaratada (CRTC 4,
  1988 o posterior), ROM española del 464 (vendido desde septiembre de 1985,
  no es de teclas altas) o ROM del 664 sin disquetera (probable CPC 472).
  Si no se puede deducir, explica cómo mirarlo (altura de las teclas,
  etiqueta del número de serie). Fuentes: CPCWiki (Keyboard Versions,
  Mainboard Versions, 472) y la AUA.
- El modelo se deduce de la ROM del sistema, aunque la M4 ponga encima la
  de otro modelo: ya no se pregunta en ese caso.
- Informe en la M4 Board: al mostrar el resumen, si el CPC tiene una M4,
  se escribe también /DOCTOR.TXT en su tarjeta (el resumen y las ROMs) y
  /DOCTOR.ROM (copia de la ROM del sistema), para leerlos por la red desde
  otro ordenador sin fotos de la pantalla. Se usan las órdenes de la M4
  directamente, sin el firmware del CPC.
- ROMs: si la M4 pone su propia ROM baja encima de la del sistema, se lee
  la del sistema apartando la de la M4, y se indica también la que pone la
  M4.
- ROMs: nueva variante de la ROM del sistema del 6128 español (B3A1).

### Cambiado
- El cargador de la versión de disco y cinta sube los datos comprimidos a
  lo alto de la memoria antes de descomprimir: el programa ya no está
  limitado a #A600. El bloque de trabajo pasa a #B000.

## 0.9.3

### Nuevo
- Sonido: después de configurar cada sonido se releen los registros del AY,
  y antes y después de la prueba se comprueba su bus de datos con patrones.
  Si un bit no se guarda bien, se indica la patilla (DA0-DA7) y se explica
  que el fallo está en el camino de los datos (soldadura, pista o el zócalo
  si se ha puesto uno), no en el generador.
- Sonido: el consejo para cambiar el AY ya no da a entender que en algunos
  464 va en zócalo: siempre viene soldado. Puede hacer que un sonido salga unas veces sí y otras no.
- Emulador de pruebas: opción `aybus` para imitar una patilla de datos del
  AY con mal contacto.

## 0.9.2

### Nuevo
- Identificación: versión de la controladora de disco. Los µPD765A y sus
  clones no conocen la orden VERSION; el µPD765B y posteriores sí. Se
  muestra como "Sí (765A)" o "Sí (765B)".
- Identificación: con un CRTC de tipo 4 se indica el Gate Array 40226 (464
  y 6128 abaratados), y con el 3 el ASIC 40489 de los Plus, que llevan el
  CRTC dentro. El 40007, el 40008 y el 40010 no se pueden distinguir por
  software: sus diferencias solo se ven en pantalla.
- RAM: cuando falla un bit, se dice qué chip de la placa revisar: 464 y
  664 (IC117-IC124, que no van en orden de bit), 6128 con placa original
  (IC127-IC134 la RAM base, IC119-IC126 la alta), 6128 abaratado con 40226
  (IC109-IC124, "probable") y Plus (IC110-IC113). Sale de los manuales de
  servicio de Amstrad. Del 464 abaratado no hay esquema: solo se da el bit.
- Emulador de pruebas: opción `fdcb` para imitar un µPD765B, y `faultbank`
  para estropear una página física de RAM.

### Corregido
- RAM alta: la prueba se paraba en el primer bit erróneo de cada bloque, y
  con dos chips averiados solo se veía uno. Ahora comprueba los 8 bits.

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
