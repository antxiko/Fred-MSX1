# Fred for MSX1

*(También disponible [en castellano](README.es.md).)*

An unofficial conversion of *Fred* (Quicksilva, 1984) from ZX Spectrum to a
64 KB ASCII16 cartridge for an MSX1 with 64 KB of RAM.

It retains the game engine and adds VBlank presentation, a native SCREEN 2
tile renderer, redefinable keys, PSG sound and a scrolling tracking map that
keeps Fred centred with a hardware sprite.

## Applying the patch

Install Python 3, SkoolKit and Pasmo. Put your own snapshot at:

`JUEBOS/Fred_1984_Quicksilva_re_release.z80`

Its SHA-256 must be
`05e2437c513c91e88ec986ff173b2f7d97ee4f8e16b82c8237abe5fc888271e0`.

```powershell
python -m pip install -r requirements.txt
python tools\normalize.py
python tools\make_ips.py apply build\Fred_MSX1_base.rom patch\Fred_MSX1.ips build\Fred_MSX1.rom
```

The 65,536-byte result must have SHA-256
`4f5dc53e4922b7f3187a55b4ec06a1b9c6509173f638e938545e473b184c59b1`.
The IPS targets the normalised base rather than the compressed `.z80`, so it
contains the conversion changes rather than a complete copy of the game.

The reference disassembly is in [`disassembly/fred_zx.asm`](disassembly/fred_zx.asm).
Patch sources are included and `python fred\build.py` reproduces the same ROM.

## Main changes

- VBlank-synchronised presentation and a cached SCREEN 2 renderer.
- A centred scrolling tracking map with a red hardware-sprite marker.
- Duplicate item-position prevention and stable key redefinition.
- Immediate first shot with delayed held-fire repetition.
- Non-blocking adaptation of the beeper routines to the PSG.

Araubi completed the game manually. Automated tests cover rendering, mapping,
item placement, transitions, C-BIOS and held-fire cadence. Real hardware has
not been certified.

See the [legal notice](AVISO-LEGAL.md).

