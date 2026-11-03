# Fred MSX1: presentación en VBlank

Revisión del 18 de octubre de 2026.

- ROM: `build/Fred_MSX1_64K_vblank.rom`, 65536 bytes, mapper ASCII16.
- Construcción: `python fred/build.py`.
- Versión anterior preservada: `build/fred_before_vblank/reference.rom`.
- Ant Attack y el snapshot original de Fred no se modifican.

## Qué cambia

La imagen siguiente se prepara en la tabla de nombres oculta (1800h o
1C00h). El registro R2 cambia durante VBlank, después de preparar mapa y
HUD. No se actualizan las filas de la tabla visible mientras se dibuja.

Cada banco fija los patrones utilizados por la imagen visible y los que ya
necesita la siguiente. Las cargas nuevas solo usan slots libres. Las claves
completas de descriptor permiten descartar entradas antiguas de la caché.
Los gráficos de fuentes modificables siguen cargándose de nuevo.

Los cambios de nombres se registran como tramos de fila. Tras publicar una
imagen, los tramos se llevan a la tabla oculta al preparar el próximo
fotograma. Si la cámara cambia y se reemplazará toda la tabla, se omite esa
copia intermedia. El scroll horizontal de uno a tres tiles desplaza las
sombras existentes y resuelve de nuevo las casillas que entran o cambian.
Otros desplazamientos conservan la ruta general.

Los bancos sin cambios evitan la preparación de la caché. Todavía se
comparan descriptores; no se ha sustituido toda la lógica original por un
sistema de marcas de suciedad en origen.

Los cambios reales del HUD se encolan y se transfieren en lotes de ocho
casillas por VBlank. Una cola llena se vacía antes de continuar. La carga
inicial completa se realiza con la pantalla desactivada.

Los efectos llamados por las rutinas del juego programan el PSG y regresan
sin ejecutar la espera del BEEPER. La interrupción de vídeo descuenta su
duración y apaga el volumen. Fuera de la partida se conserva el adaptador
bloqueante para las melodías. La duración de los efectos está cuantizada
en ticks, con una conversión calculada para 50 Hz; no es sonido idéntico
al Spectrum ni tiene nueva validación auditiva.

## Rendimiento medido

`profile_tearing.py` mide el bucle real en Philips VG 8020. Cada escenario
tiene ocho fotogramas; las medianas excluyen el primero. La versión anterior
está registrada en `tearing_profile.json`, la nueva en `vblank_profile.json`.
Son muestras concretas; no límites garantizados para todas las situaciones.

| Medida | Anterior | Nueva |
|---|---:|---:|
| Mapa sin cambios | 28,45 ms | 16,97 ms |
| Mapa durante scroll horizontal | 100,31 ms | 74,18 ms |
| Fotograma completo sin pulsaciones | 89,61 ms | 78,34 ms |
| Fotograma completo con scroll | 165,90 ms | 139,57 ms |
| Fotograma completo disparando | 124,96 ms | 100,87 ms |

El coste de esperar a VBlank está incluido en los totales nuevos. La lógica
original, entidades y preparación del HUD siguen consumiendo unos 50–60 ms
en estas muestras; no es un juego de 50 fps.

## Verificaciones

Informes en `build/fred_review/`:

- `native_pixels_results.json`: 24 imágenes completas en ejecución y cinco
  escenarios preparados de presión de caché/fuentes mutables, correctos.
- `vblank_present_results.json`: vigilancia durante 64 fotogramas, con 427
  cargas de patrones y 55 publicaciones. Cero escrituras sobre patrones o
  tablas de nombres visibles. Última escritura visible observada a 0,307 ms
  del VBlank. Cero reconstrucciones por agotamiento de caché en esa prueba.
- `cbios_boot_results.json`: menú y 32 fotogramas de movimiento/disparo en
  C-BIOS MSX1, MSX2, MSX2+ y Philips VG 8020; todos correctos, sin escrituras
  del juego a FFFF.
- `native_transition_results.json`: cambio de nivel, fin de partida, menú
  y comienzo de otra partida mediante estados preparados; todos correctos.
- `vblank_replay_results.json`: entradas completas de los 68,04 segundos de
  Araubi, 218 fotogramas de juego y otros 35 después con movimiento/disparo.
  Cero reconstrucciones de caché por falta de slots. Las posiciones pueden
  diferir del replay original al cambiar la velocidad y los tiempos.
- `vblank_sound_results.json`: efecto preparado que regresa en 0,523 ms,
  programa tres ticks y deja el volumen a cero al expirar. Comprobación de
  registros y tiempos, no de calidad audible.
- `vblank_hud_queue_results.json`: actualización preparada de las 240
  casillas del HUD, incluidos desbordamiento de cola y lotes completos de
  ocho. Imagen y colores correctos; última escritura de cada lote como
  máximo a 2,683 ms del VBlank, dentro del margen de 3 ms comprobado.

Todas estas pruebas registraron cero accesos VDP demasiado rápidos.
La comprobación temporal se realiza además de comparar imágenes finales:
una captura correcta por sí sola no demuestra ausencia de tearing.

## Límites y memoria

Si la unión de patrones de dos imágenes supera la capacidad de un banco,
se desactiva la pantalla en VBlank, se reconstruye ese banco y se muestra
la imagen completa. Evita mostrar patrones corruptos, pero puede producir
un apagado breve. Este caso se ejercita en las pruebas sintéticas; no se
activó en los 64 fotogramas vigilados ni en el replay de Araubi. Una
actualización masiva del HUD puede distribuirse entre varios VBlanks.

No se ha completado todo el juego ni probado en hardware real.

Memoria nueva: tabla HUD 2080–216F, tramos 2300–232B, UDG 2330–23D7,
código 2400–2EFF, claves altas 2F00–313F y bajas 3200–343F, descriptores
3440–385F, sombra de nombres/marcas HUD 3A00–3CFF, búsquedas D400–DCFF,
marcas de ocupación/cola HUD DD00–DDFF y sombra HUD E420–EC8F. La capa
MSX ocupa B900–BBE9. La construcción comprueba los límites de código.
