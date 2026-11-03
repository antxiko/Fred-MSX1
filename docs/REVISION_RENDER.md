# Fred MSX1: revision de render, 2026-10-15

Salida: `build/Fred_MSX1_64K_render_fast.rom`, ASCII16, 65536 bytes.
Se conservan el snapshot original y `Fred_MSX1_64K_sonido_beta.rom`.

## Cambios

- Renderer 6391h sustituido por una rutina en 3900h: mismos 22 x 24 tiles,
  copia desenrollada y calculo directo de direcciones y atributos.
- Un NOP menos entre escrituras del bitmap al VDP; comprobado con el detector
  de accesos demasiado rapidos de openMSX y comparacion completa de VRAM.
- Codigo VDP propio de Fred: el build ya no importa rutinas de Ant Attack.
- Cuatro destinos de descarte originalmente en ROM 0000h redirigidos a
  38C0h..38E7h. En MSX la copia de esa ROM es RAM: disparar sobrescribia RST00.
- Paleta trasladada de BC00h a 3980h..39FFh y sombra de atributos trasladada
  de BD00h a 3A00h..3CFFh. BC00h y BF66h pertenecen a entidades del juego.
  Paleta de 128 entradas: FLASH sigue ignorado como en la version anterior.
- Capa residente B900h..BBE3h; guardas de build para no invadir BC00h, la fuente
  Spectrum en 3D00h, ni sonido, renderer o buffer de descarte.

## Comprobacion reproducible

`python fred/build.py`

`python fred/review.py`

`python fred/check_game.py`

Philips_VG_8020 en openMSX. Resultados en `build/fred_review/`:

- 12 estados: bitmap y atributos identicos al renderer anterior (6912 bytes).
- Renderer: 153.490 ms -> 66.864 ms, reduccion 56.44%.
- Mediana de fotograma, secuencia de 12 pasos desde estado comun:
  291.559 ms -> 191.885 ms, reduccion 34.19% (aprox. 3.43 -> 5.21 fps).
  Es una comparacion controlada con estado heredado; no una media de partida.
- 20 fotogramas disparando sin modificar los vectores de pagina cero.
- Partida nueva, redefinicion real cursores/espacio: 6 pasos y otros 32
  fotogramas alternando movimiento y disparos sin corrupcion de vectores.
- Comparacion de 6144 bytes de patrones y 6144 de colores en los tres bancos.
- Cero avisos de acceso excesivamente rapido al VDP.
- Captura real `build/fred_review/fred_fast.png`.

## Limites

Todavia se reconstruye todo el mapa y se envia todo el bitmap (incluido HUD).
Solo los atributos tienen comparacion contra sombra. No se ha implementado
un renderer incremental. Sigue habiendo margen importante de velocidad.
Estas pruebas no equivalen a completar el juego, comprobarlo en hardware ni
validar el sonido de oido. No se ha cambiado la adaptacion de audio esta vez.

## Grabacion Fred.omr de Araubi, comprobada 2026-10-16

- Sony HB-20P, duracion 68.043657783 s. ROM grabada: `sonido_beta`, SHA1
  `681176efc2bff2c6e3e0828c8a59fe25de9ad8e9`, anterior a esta revision.
- BIOS original encontrada localmente y verificada por SHA1. Se cambia solo
  la ruta de los ficheros en una copia de trabajo; Fred.omr queda intacto.
- Recorrido desde t=0: a los 57.639569554 s, 6418h escribe en 0000h al dibujar
  el disparo. Stack contiene retorno 8D43h. Confirmada la causa corregida.
- Estado exacto previo, PC 8D2Ch a 57.639495802 s, transferido a la capa
  revisada: continua 30 fotogramas, sin destruir los vectores.
- Mismas entradas desde el comienzo con ROM revisada y sin reutilizar estados
  intermedios antiguos: 128 fotogramas hasta 68.1 s; despues otros 27 durante
  cinco segundos de movimiento y disparo. Cero avisos VDP demasiado rapido.
- El cambio de velocidad altera las posiciones; esta ultima prueba no es una
  reproduccion identica de la partida. La prueba del estado exacto se realiza
  aparte. Captura inspeccionada: `revised_replay_end.png`.
- Scripts: `inspect_replay.py`, `trace_replay.py`, `validate_replay.py`,
  `verify_crash_state.py`. Informes en `build/fred_review/`.
- Copia para enviar sin confundir versiones: `Fred_MSX1_64K_Araubi_20261016.rom`.
  Identica a render_fast; esta comprobacion no introduce otro cambio de motor.
