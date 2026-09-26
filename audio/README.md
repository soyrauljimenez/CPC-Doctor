# Sonidos de prueba

## `cpcdoctor-tono-2000hz.wav` y `.cdt`

Tono de calibración para la **prueba de cassette** de CPC Doctor (opción 4).
Es una onda cuadrada de 2000 Hz durante dos minutos, precedida de 4 segundos
de silencio. El programa mide su frecuencia y su estabilidad para calcular la
velocidad del motor y ajustar el azimut del cabezal.

La cinta de CPC Doctor (`cpcdoctor-es.cdt` / `.wav`) ya lleva un minuto de este
tono justo después del programa. Estos ficheros sirven cuando se carga CPC
Doctor desde disco o con una M4, o cuando hace falta más tiempo para ajustar.

### Cómo usarlo

- **CPC 464 con un adaptador de cassette a jack** (los de coche o los de
  "casete a móvil"): mete el adaptador en el cassette del 464, conéctalo al
  móvil o al ordenador y reproduce el WAV cuando CPC Doctor lo pida.
  Ojo: así la cinta no se mueve, de modo que se mide el reproductor, no el
  motor del 464. Sirve para comprobar el cabezal y la lectura, no la velocidad.
- **Para medir la velocidad del motor** hay que grabar el WAV en una cinta
  normal (con un radiocassette o una pletina que funcione bien) y reproducirla
  en el cassette del CPC.
- **664, 6128 o pletina externa:** conecta la salida de audio del reproductor
  a la entrada de cassette del CPC (o graba una cinta y ponla en la pletina).

### Consejos

- Volumen alto pero sin distorsión (en el móvil, alrededor del 75 %).
- Desactiva el ecualizador y los "mejoradores" de sonido del móvil.
- El `.cdt` sirve para emuladores y reproductores tipo TZXduino/CASduino.

Los ficheros se generan con `./build.sh` (`tools/cpcfile.py`).

## Disquetera

La prueba de la disquetera (opción 5) no necesita ningún sonido: basta con
meter un disco cualquiera en la unidad A, por ejemplo el de CPC Doctor.
