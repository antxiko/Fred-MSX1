# Fred: renderizado nativo MSX1

Documento de la versión anterior: `build/Fred_MSX1_64K_tiles_cbios.rom`.
La revisión actual, su construcción y sus pruebas están en `VBLANK.md`.

## Funcionamiento

`tiles.asm` sustituye el dibujo del mapa Spectrum durante el juego. Lee los
descriptores originales y mantiene patrones y colores residentes en cada uno
de los tres bancos de SCREEN 2. Una sombra de los descriptores descarta las
casillas sin cambios. Los cambios de nombres se envían por tramos de fila.
Un tramo puede incluir nombres intermedios sin cambios para ahorrar accesos
al puerto de dirección.

Cada banco tiene su propia caché: 168, 192 y 168 patrones para el mapa.
Los restantes 88, 64 y 88 corresponden al HUD. No caben todos los gráficos
del juego simultáneamente: los gráficos nuevos se cargan cuando hacen falta.
Al agotarse una caché se reconstruye únicamente ese banco. Los gráficos de
fuentes modificables se recargan para conservar su contenido actual.

Los escritores originales de texto y atributos marcan casillas del HUD.
Solo se inspeccionan las marcadas y solo se transfieren patrones o colores
que realmente cambian. Una pantalla sin cambios no genera escrituras VRAM.
Menús y pantallas especiales conservan el dibujado bitmap, con restauración
de la tabla de nombres al cambiar de modo.

El código nuevo ocupa 2B00–31FF; las sombras y claves se distribuyen en
3200–385F, 3A00–3CFF, D400–DCFF y E420–EC8F. Los límites se comprueban
durante la construcción. Se conservan los registros alternativos, IX e IY,
y el acceso VDP respeta las interrupciones y los tiempos del MSX1.

## Verificación del 17 de octubre de 2026

Resultados detallados en `build/fred_review/`:

- `native_renderer_results.json`: 32 escenas comparadas contra el renderer
  anterior, con igualdad de todos los patrones y colores visibles. Mediana
  de renderizado sin la carga inicial: 36,53 ms; pantalla sin cambios:
  28,47 ms y cero escrituras VRAM. Son tiempos de renderizado, no de un
  fotograma completo de juego.
- `native_game_results.json`: secuencia de 32 fotogramas con movimiento y
  disparo. Mediana del fotograma completo: 191,85 ms antes y 145,68 ms ahora,
  reducción del 24,07 %. Partida nueva con cursores y espacio redefinidos:
  48 fotogramas adicionales. Sin escrituras en los gráficos fuente estáticos.
- `native_pixels_results.json`: 24 pantallas completas durante ejecución
  real y cinco escenarios preparados de presión de caché y fuentes
  modificables, todos correctos.
- `native_transition_results.json`: cambio de nivel, fin de partida,
  regreso al menú y nueva partida correctos mediante estados preparados.
  Estos casos no equivalen a completar los niveles jugando.
- `native_replay_results.json`: reproducción completa de los 68,04 segundos
  de entradas de `Fred.omr` sobre la ROM nueva; 210 fotogramas del juego y
  otros 37 después con movimiento y disparo. Al cambiar la velocidad, las
  posiciones no coinciden necesariamente con la grabación original.

Las pruebas detectaron cero accesos demasiado rápidos al VDP. Las pruebas
habituales usan Philips VG 8020; el replay conserva el Sony HB20P original.
No se ha validado esta versión en hardware real ni completado todo el juego.

## Límites conocidos

El scroll y las reconstrucciones de caché siguen costando más que una
pantalla casi estática. La lógica y los sonidos bloqueantes originales
también consumen tiempo; esta entrega no convierte el juego en 50 fps.
La adaptación sonora existente se conserva, sin nueva validación auditiva.
La ROM anterior y el snapshot ZX original se mantienen separados.

## Corrección de compatibilidad C-BIOS

El arranque anterior funcionaba con C-BIOS MSX1, pero fallaba con las
configuraciones MSX2/MSX2+ con RAM en un subslot y mapper. Se corrigieron
tres accesos heredados del Spectrum:

- El descompresor omite el byte FFFF del snapshot: en slots expandidos esa
  dirección es el registro de selección de subslots.
- Los 21 caracteres UDG originales ocupaban FF58–FFFF. Su área mutable
  se traslada a 3139–31E0 y se actualiza el puntero Spectrum 5C7B.
- Se neutralizan los OUT (FE),A originales del juego y de la ROM Spectrum.
  En MSX ese puerto controla la página 2 del mapper de RAM. El sonido
  sigue pasando por el adaptador PSG existente.

`python fred/check_cbios.py` comprueba menú, comienzo de partida y 32
fotogramas con movimiento/disparo en C-BIOS MSX1, MSX2, MSX2+ y Philips
VG 8020. Los cuatro casos pasan, sin escrituras FFFF durante esos
fotogramas ni accesos VDP demasiado rápidos. Resultados:
`build/fred_review/cbios_boot_results.json`.
