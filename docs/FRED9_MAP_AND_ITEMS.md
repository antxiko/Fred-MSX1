# Fred9: coste del mapa y objetos superpuestos

ROM nueva: `build/Fred_MSX1_64K_map_cached.rom`, ASCII16, 65536 bytes.
SHA-256: `070bb49ba3ff39ee4ff880a103ddcd4d8927314c9ff407aed120afd39e7fcbb0`.
ROM anterior conservada: `Fred_MSX1_64K_tracking_fast.rom`.

## Grabación y diagnóstico

Se reprodujo `Fred (9).omr` desde su estado inicial, con las entradas
originales hasta 614,49 segundos. La copia local cambia solo las rutas de
ROM y BIOS y conserva el OMR original. El registro está en
`build/fred_review/Fred9_rows.txt` y `Fred9_pickups.txt`.

No se observó un crecimiento continuo del tiempo de fotograma a lo largo
del OMR. El mapa sí introducía cálculo y esperas adicionales: su publicación
repartida podía esperar un VBlank para cada fila del HUD, además del usado
para publicar la pantalla de juego.

Entre 589,80 y 590,89 segundos se activan seis objetos distintos en la
misma posición del jugador (14,1). El estado anterior a recogerlos ya
contiene seis registros con coordenadas gráficas 39h,08h: D135, D14B,
D161, D16C, D18D y D1B9. No es una repetición de la recogida de un mismo
registro. El generador original acepta posiciones repetidas; la lectura
de bytes de ROM para obtener posiciones hace que los cambios de código
también cambien la distribución de objetos.

## Cambios

- Al recoger el mapa se construye una copia compacta de la geometría del
  laberinto, con un bit por casilla y márgenes vacíos. El seguimiento extrae
  de esa copia la ventana alrededor de Fred. El OMR completo no mostró
  escrituras en la geometría E000-E3FF mientras el mapa estaba activo
  durante el juego (la vigilancia excluye arranque e inicialización).
- Se actualizan los 200 bytes de patrones del minimapa en el mismo VBlank
  que publica la tabla de nombres del juego. No se retransmiten colores
  ni se dejan filas pendientes. El punto rojo sigue siendo un sprite.
- El generador de objetos rechaza coordenadas ocupadas por un objeto
  anterior, conservando su comprobación original del terreno. No se
  reduce el número de objetos. El cambio se aplica a niveles nuevos, no
  a los objetos ya presentes en un estado guardado de la ROM anterior.

## Evidencia

- `check_cached_pixels.py`: píxeles iguales a la rutina original en diez
  posiciones, incluidos bordes y todos los desplazamientos horizontales.
- `check_cached_replay_scenes.py`: doce estados distribuidos por Fred9,
  comparación de bitmap y los 25 tiles realmente visibles en VRAM. Cálculo
  entre 8,25 y 11,32 ms; última escritura a 2,57 ms de observar VBlank.
- `check_cached_speed.py`: subida completa de patrones en 2,544 ms, con
  una sola espera de VBlank por publicación y cero accesos VDP demasiado
  rápidos. Estos son tiempos de rutinas, no una medida global de FPS.
- `check_cached_items.py`: estados de generación de los cuatro niveles
  de la grabación, con 16, 17, 18 y 19 objetos respectivamente; todos en
  posiciones distintas y sobre terreno aceptado por el juego.
- `check_cached_live.py`, `check_cached_cbios.py` y `check_cached_exit.py`:
  movimiento con mapa tras recogida preparada, reinicio del mapa, arranque
  con C-BIOS MSX1, salida y acceso al siguiente nivel.

Resultados JSON: `Fred9_world_cache_audit.json`, `Fred9_cached_scenes.json`,
`cached_speed.json` y `cached_unique_items.json`, en `build/fred_review`.
Validación en openMSX con reproducción original y estados preparados;
no se ha completado una partida entera con la ROM nueva ni probado hardware.
