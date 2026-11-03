# Fred4 exit transition repair, 2026-10-21

For the current build and subsequent fixes see [DAMAGE_START.md](DAMAGE_START.md).

Build: `python fred/build.py` produces `build/Fred_MSX1_64K_exit_fix.rom`.
The pickup-only minimap remains unchanged. Old release and source backup:
`build/fred_before_exit_fix/`; the original minimap ROM is also preserved.

## Reproduction

Fred (4).omr uses the minimap ROM (SHA1
b06c1b4a8fdb0b88818ee175a4d3a65f1aa86426), duration 613.489427 seconds.
Full ordered input playback reaches level exit at 605.199979 seconds.
At 605.227038, the first exit-animation call to 6391 invokes tile_leave.
It immediately replaces the displayed name table with sequential names,
while VRAM still contains the native cache patterns and colours. The next
legacy bitmap transfer repairs it, but meanwhile the whole screen is wrong.
VDP mode registers remain valid. `Fred4_before_01.png` reproduces the user's
striped map/HUD image. This was a renderer layout transition, not cache overflow.

## Change

- The four exit-animation frames call native tile_enter/tile_present through
  tile_exit_frame, preserving the native VRAM layout throughout the animation.
- tile_leave disables the display before changing the name-table layout.
- tile_legacy renders and uploads the complete legacy bitmap with interrupts
  held off. legacy_ready enables display at VBlank only after patterns and
  colours have been uploaded. There is a brief intentional blank for this
  one layout conversion; invalid mixed layouts are never presented.
- Title/game-over paths share the guarded layout transition.

## Evidence and limits

`check_exit_scene.py` restores the actual pre-exit game RAM and CPU registers
captured from the OMR, rebuilds the native cache and retains the candidate's
patched call sites. All four animation calls remain native; no sequential
name writes occur with the display enabled. All 768 legacy screen cells
match the bitmap/palette before display is re-enabled. The next level starts,
with zero VDP-too-fast events. Report: `exit_scene_results.json`.

Full input playback of the candidate was also run through 624 seconds, but
its route diverges and Fred dies at 188.78 seconds. Original ROM-byte random
reads and changed timing mean this is NOT an end-to-end exit reproduction.
The exact captured exit-state test supplies that evidence instead.

Prepared game-over/menu/new-game and C-BIOS/Philips boot checks are separate
regressions. Screenshots and traces are in `build/fred_review/Fred4_*`.
No physical hardware validation is claimed.
