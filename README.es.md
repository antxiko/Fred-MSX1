# Fred para MSX1

*(También disponible [en inglés](README.md).)*

Conversión no oficial de *Fred* (Quicksilva, 1984) desde ZX Spectrum a un
cartucho ASCII16 de 64 KB para MSX1 con 64 KB de RAM.

**Web:** https://antxiko.github.io/Fred-MSX1/es/

Conserva el motor del juego y añade presentación por VBlank, renderizado nativo
de tiles para SCREEN 2, teclado redefinible, sonido por PSG y un mapa de
seguimiento mejorado que mantiene a Fred centrado mediante un sprite.

## Aplicar el parche

Necesitas Python 3, SkoolKit y Pasmo en el `PATH`. Coloca tu snapshot con este
nombre:

`JUEBOS/Fred_1984_Quicksilva_re_release.z80`

La copia debe tener SHA-256
`05e2437c513c91e88ec986ff173b2f7d97ee4f8e16b82c8237abe5fc888271e0`.

```powershell
python -m pip install -r requirements.txt
python tools\normalize.py
python tools\make_ips.py apply build\Fred_MSX1_base.rom patch\Fred_MSX1.ips build\Fred_MSX1.rom
```

El resultado es `build/Fred_MSX1.rom`, de 65.536 bytes.
La compilación de referencia tiene SHA-256
`4f5dc53e4922b7f3187a55b4ec06a1b9c6509173f638e938545e473b184c59b1`.

El IPS se aplica a la base normalizada, no directamente al `.z80`. De ese modo
el parche contiene la conversión y sus cambios, no una copia completa del
juego. `python fred\build.py` reconstruye la ROM desde las fuentes del parche
y permite verificar que produce exactamente la misma huella.

El desensamblado de referencia está en
[`disassembly/fred_zx.asm`](disassembly/fred_zx.asm).

## Mejoras de esta versión

- Renderizado y publicación sincronizados con VBlank para evitar tearing y
  pantallas negras durante la partida.
- Caché de patrones y actualización de las casillas que cambian.
- Mapa adquirido durante la partida con scroll centrado en Fred y marcador
  rojo mediante sprite de hardware.
- Prevención de objetos superpuestos en la generación del nivel.
- Redefinición de controles estable.
- Disparo mantenido: primer tiro inmediato, repetición retrasada 35 VBlanks y
  repeticiones posteriores cada 25 VBlanks.
- Sonido del beeper adaptado al PSG sin bloquear el bucle del juego.

## Estado y validación

Araubi completó manualmente el juego con esta rama de conversión. Las pruebas
automatizadas cubren el renderizado, el mapa, la colocación de objetos, las
transiciones, C-BIOS y la cadencia de disparo con la tecla predeterminada y una
tecla redefinida. No se ha certificado en hardware real.

La documentación técnica está en [`docs/`](docs/). Consulta también el
[aviso legal](AVISO-LEGAL.md).

