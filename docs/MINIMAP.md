# Fred minimap pickup repair (2026-10-18)

Current build output and subsequent exit-transition repair are documented
in [EXIT_TRANSITION.md](EXIT_TRANSITION.md). Pickup-only map behavior is retained.

## Retired test: map from start (2026-10-19)

The temporary test artifact is preserved separately as
`build/Fred_MSX1_64K_map_start.rom`. On native renderer initialization it
calls the original map routine before the forced initial HUD upload. The
local map is therefore available at the start of each level without picking
up the item. It remains the original static local map, not a new tracking
map. Pickups still redraw it normally. The previous minimap ROM is preserved.
Start and a prepared level transition were checked against the bitmap in
actual VRAM; screenshot: `build/fred_review/minimap_from_start.png`.

At the user's request this test modification has been removed from the
sources and test targets. The current build again produces the pickup-only
version described below, with the minimap rendering repair retained.

Build: `python fred/build.py`
Output: `build/Fred_MSX1_64K_minimap.rom` (64 KB, ASCII16).
Previous shared_tiles ROM preserved; source baseline in
`build/fred_before_minimap/`.

The original item dispatcher at AE2B calls AEC8 from AE72 when a map is
collected. AEC8 draws a 40 by 40 pixel minimap at x=208, y=48 using direct
Spectrum bitmap writes at AF27. These writes bypassed all native HUD dirty
notifications. No new key or always-visible map is introduced.

AE72 now calls hud_minimap, which runs the unchanged original drawing routine
and marks only its 25 HUD cells (columns 26-30, rows 6-10). Existing queued
VBlank updates publish their patterns and colours. The original routine's
returned registers/flags are preserved by the notification wrapper.

`python fred/check_minimap.py` reproduces the defect with the previous ROM:
25 mismatched displayed cells after a prepared map-item collision. It runs
the actual item collection dispatcher, followed by two additional map draws
near opposite world boundaries. The new ROM has zero mismatched cells in
all three cases, with exact original bitmap and palette output, then runs
12 movement frames without VDP timing violations.

This is prepared-state emulator validation, not a claim of collecting the
map through an unassisted full playthrough or testing physical hardware.
Evidence: `build/fred_review/minimap_results.json`.
