# Fred: shared immutable patterns

Revision: 2026-10-18. Current build: `python fred/build.py`.
Output: `build/Fred_MSX1_64K_shared_tiles.rom`, 65536 bytes, ASCII16.
The previous `rope_fix` and `vblank` ROMs are preserved.

## Reproduced failure

Araubi's `Fred (3).omr` uses the previous rope_fix ROM. Its ordered replay
produced two display-disable intervals around 242.865 and 243.224 seconds,
each lasting about 259 ms. Both entered the cache-full recovery path.

This was fixed-capacity exhaustion, not an indefinitely growing buffer:
the protected union of old and new screen contents required 169 descriptors
in a bank with 168 slots. These descriptors represented only 117 distinct
bitmap/colour combinations. No out-of-bounds write was established.

## Implementation

A 768-byte canonical source table at CPU address 1800-1AFF maps identical
immutable 8-byte graphics to the same source index within each source page.
The 768 original indices reduce to 588 canonical indices. Colour and page
remain part of the cache key. Dynamic graphics bypass this table.
The original descriptor shadows and all source graphics are preserved.

CPU address 1800 is unrelated to the VRAM name table at the same address.
The game does read the replaced Spectrum ROM bytes as random data for enemy
movement. Therefore random sequences and replay routes can change. Monitoring
the full recording found only those original RNG readers in this region;
the candidate additionally reads the canonical table from the renderer.

The renderer still pins visible patterns, uploads into free slots, writes the
hidden name table and presents at VBlank. The existing recovery path remains
for a genuinely excessive union of distinct patterns.

## Validation

- Exact reconstruction of both failing Fred3 transitions: one recovery each
  before, zero after; complete map pixels and colours match in all cases.
- Regression on all five exact Fred2 transitions: one recovery each with
  the original vblank ROM, zero with this ROM; complete map pixels match.
- Full 252.557-second Fred3 input recording followed through 264 seconds:
  no gameplay display-disable interval or cache-full recovery with this ROM.
  Startup blanking remains. This is not a frame-identical gameplay replay,
  because the changed timing and ROM-byte RNG can change the route.
- 24 live map comparisons and 7 prepared pixel stress scenes passed, including
  dynamic graphics and colour/hash collisions.
- 64-frame presentation trace: 257 pattern uploads, 55 presentations, zero
  writes into visible patterns/names and zero cache-full recovery events.
- Scroll median: map 74.47 ms, total 139.57 ms (previous map 75.81 ms,
  total 139.57 ms). Overall speed is maintained.
- C-BIOS MSX1/MSX2/MSX2+ and Philips VG8020: menu, gameplay, movement and fire.
- Prepared level transition, game over, return to menu and new game passed.
- All 768 aliases checked for byte equality and idempotence. Cursor/space
  redefinition followed by 32 game frames passed; no writes to the table or
  execution inside it. VDP timing violation counters were zero.

Evidence is in `build/fred_review/`, especially `Fred3_*`,
`pattern_table_checks.json`, and the current pixel/presentation/boot reports.
These are emulator checks; no physical MSX validation is claimed.
