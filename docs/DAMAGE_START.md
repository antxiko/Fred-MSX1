# Fred6: damage render cost and double startup publication

2026-10-23. `python fred/build.py` produces
`build/Fred_MSX1_64K_damage_start_fix.rom` (65536 bytes, ASCII16).
Previous exit_fix ROM and source backup are preserved under
`build/fred_before_damage_fix/`.

## Findings

The 178.911-second Fred (6).omr uses exit_fix (SHA1
ef9d0e57021cd957f17a5c4d4f3abaf2fc3836d1). Sequential playback reproduced damage
at 83.355 and 143.604 seconds. The damage sound processing takes about 4.94 ms;
large stalls occur in map rendering. When Fred changes to red, his colour
variants contend for the same direct lookup entry. Once a collision was
observed, a bank-wide flag caused subsequent stale hints throughout that
bank to trigger linear cache scans, even after the damage flash ended.

During startup, the legacy interrupt uploader published the partially built
frame/HUD while level setup was still running. Native initialization then
blanked the display and uploaded the same screen in its own tile layout.

## Changes

- Red descriptors use a separate XOR-40 hash offset. Black retains XOR-80.
- Collision history is per lookup bucket instead of bank-wide. A 288-byte
  bitset at CPU 1B00-1C1F covers the nine 256-entry tables. Each bank clears
  its 96 bytes when its lookup is cleared. Full descriptor validation and
  pinned-slot recovery remain in place, so genuine collisions still work.
- At 76FF, after optional level configuration menus, prepare_game_screen
  suppresses legacy ISR uploads and blanks once before building the frame.
  Native presentation enables display only when the whole first frame is
  ready. This removes the partial screen followed by a second load; it does
  not eliminate the normal menu-to-game loading interval.
- Map pickup behavior and the previous exit-transition fix are retained.

## Validation

Thirty ordered map frames captured around the original first hit were fed
to both renderers. All 528 map cells in every frame have identical bitmap
and palette output. The two damage-related peaks change from 84.02 to
44.42 ms and 81.42 to 41.83 ms. Mean map render time over the five hurt
frames falls from 52.57 to 35.68 ms. Linear-probe iterations across the
sequence fall from 19586 to 256. Overall warmed sequence mean changes from
89.13 to 81.59 ms; maximum from 215.37 to 185.53 ms. These are map-render
times, not total frame times or a claim that all scrolling stalls are gone.

Startup instrumentation sees zero legacy uploads during screen construction
and zero visible VRAM uploads before the first complete native publication.
Additional emulator checks cover 24 live pixel comparisons, seven stress
scenes, colour collisions, dynamic patterns, 64-frame VBlank safety,
the exact Fred4 exit state, C-BIOS MSX1/MSX2/MSX2+, Philips VG8020, and map
pickup including opposite map boundaries. VDP timing violations are zero.

The full Fred6 input recording was also replayed with the candidate and
extended to 192 seconds. Its route differs because timing and ROM-byte RNG
data changed; it is not a frame-identical gameplay comparison. A watchpoint
checks that no instructions execute from the new bitset region. The exact
30-frame test is the controlled performance/pixel comparison.

Evidence: build/fred_review/damage_frames_results.json,
startup_publication_results.json, Fred6_after_profile.json,
exit_scene_results.json and damage_start_manifest.json.
No physical MSX or human audio validation is claimed for this change.
