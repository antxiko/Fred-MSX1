# Fred10: dos disparos durante una pulsación

Último ajuste solicitado: `Fred_MSX1_64K_fire_repeat_slow.rom` aumenta los
contadores a 35 y 25 interrupciones (700/500 ms a 50 Hz; 583/417 ms a 60 Hz).
El primer disparo sigue sin retardo añadido. `check_fire_repeat_slow_keys.py`
pasó con espacio y F, incluida suelta rápida entre fotogramas. En la escena
de prueba se observaron intervalos de unos 957 ms y 638 ms respectivamente,
por el ritmo de lectura del juego. Las versiones anteriores se conservan.

## Preferencia final: conservar la repetición con retardo

El usuario ha elegido mantener el disparo automático al sostener la tecla.
La versión actual es `build/Fred_MSX1_64K_fire_repeat.rom` (64 KB).
El primer disparo no tiene retardo añadido. Después espera 25 interrupciones
de vídeo para permitir la primera repetición y 15 para las siguientes
(aproximadamente 500 y 300 ms a 50 Hz). La lectura por fotograma del juego
puede alargar esos intervalos; a 60 Hz los contadores equivalen a 417 y 250 ms.
Soltar y volver a pulsar permite un disparo nuevo sin esperar ese contador.

`check_fire_repeat_replay.py` confirma una sola bala en cada uno de los dos
intervalos problemáticos del OMR. `check_fire_repeat_keys.py` comprueba
repetición mantenida y una suelta de 40 ms entre fotogramas, con espacio y
con F configurada. En esa escena los intervalos observados fueron unos
658 ms para la primera repetición y 439 ms para las siguientes, debido
al ritmo de lectura del motor. No se detectaron accesos VDP demasiado rápidos.
Resultados: `Fred10_repeat_results.json` y `fire_repeat_keys.json`.
La variante anterior de una bala por pulsación queda conservada por separado.

La grabación usa `Fred_MSX1_64K_map_cached.rom` y dura 1041,469 segundos.
`inspect_replay10.py` reproduce las entradas desde el inicio y registra
creación de balas, final de bala y lecturas del teclado. Se observan
40 disparos y 44 intervalos de espacio pulsado. Ningún disparo ocurre
fuera de esos intervalos.

Dos intervalos contienen dos balas:

| Pulsación | Suelta | Duración | Primera bala | Segunda bala |
| --- | --- | --- | --- | --- |
| 300,444746 s | 300,723859 s | 279 ms | 300,512492 s | 300,672279 s |
| 684,181351 s | 684,403961 s | 223 ms | 684,232390 s | 684,392005 s |

La rutina original acepta disparar mientras la tecla está pulsada si la
bala anterior ha desaparecido. En esos dos casos, la bala anterior termina
a los 300,585228 y 684,306217 segundos, respectivamente. La siguiente
lectura del juego todavía encuentra espacio pulsado. Es repetición por
tecla mantenida; no se duplica un evento de teclado ni aparece un disparo
tras soltar la tecla.

## Variante de un disparo por pulsación

`build/Fred_MSX1_64K_single_fire.rom`, ASCII16, 65536 bytes. La versión
terminada anterior se conserva. Esta variante exige soltar para disparar
de nuevo; cambia deliberadamente el comportamiento del disparo mantenido.

`fire.inc` recibe el resultado de la comprobación de la tecla original,
incluida su redefinición. Mantiene una marca hasta soltar. La interrupción
de vídeo también detecta la suelta para que una liberación entre dos
fotogramas del juego no bloquee la siguiente pulsación. Esa lectura
preserva el selector y la fila física del teclado que estuvieran usando
las rutinas interrumpidas.

## Verificación

- `check_single_fire_replay.py` alcanza el primer disparo de cada caso en
  el OMR original. Conserva RAM, VRAM y registros, aplica el código compilado
  nuevo y programa las mismas entradas restantes del intervalo. El control
  reproduce exactamente las dos balas originales; la variante crea una.
- `check_single_fire_keys.py`: cuatro lecturas con tecla mantenida producen
  una bala. Soltar 40 ms entre dos lecturas del juego y volver a pulsar
  permite otra bala. Probado con espacio y con selector/máscara de F como
  tecla redefinida. No constituye una prueba de recorrer el menú de redefinición.
- `check_single_fire_cbios.py` y `check_single_fire_exit.py`: arranque,
  movimiento y disparo con C-BIOS MSX1, salida y siguiente nivel. Sin avisos
  de accesos VDP demasiado rápidos.

Resultados: `build/fred_review/Fred10_fire.json`,
`Fred10_single_fire_results.json` y `single_fire_keys.json`.
Pruebas en openMSX; la variante no tiene una partida completa ni prueba
de hardware. La partida completada por Rubén corresponde a `map_cached`.
