# Fred (5): damage near the map pickup

2026-10-21. No ROM/source gameplay changes made.

Input replay: Fred (5).omr, 255.368066891 seconds. ROM SHA1
b06c1b4a8fdb0b88818ee175a4d3a65f1aa86426 matches the supplied minimap ROM.
Local replay changes only resource paths; replayed from the initial snapshot
with all input events retained.

Measured events:

- 242.282122: original drop drawing writes descriptor 8155 to F05C.
  PC 6422, return stack includes 6BF6 and 78AE (drop drawing routine 6BBF).
- 242.288787: original Fred drawing saves that descriptor into 6530-6531.
- 242.292004: original collision routine reaches 6B3F, carry set for damage.
  HL=6531 (saved descriptor high byte 81), DE=F05C.
- 242.292034: health decrement at 79CE, new health 14.
- 242.893089: map pickup at AE72, about 601 ms after damage.

The original collision routine 6AEE checks whether a saved background cell
has a harmful colour class and the corresponding Fred tile has any nonzero
pixels. It does not perform a pixel-to-pixel overlap test with the drop.
The map item drawing also writes to F05C after Fred/drop drawing, making this
shared cell visually ambiguous. The hit originates in a drop, not the map
pickup or minimap HUD update.

Throttled screenshots at 241.72 and 241.96 show an earlier falling drop.
The drop visible after the pickup is a later fall. The disappearance/overlap
and coarse tile collision make the hit look premature.

The actual damage frame's 528 displayed map cells were compared to the
original game's descriptor-selected bitmap bytes: zero mismatches. No
missing native-renderer map tile was established for this hit. This check
does not claim a full independent Spectrum playthrough.

Evidence under build/fred_review:
Fred5_events.txt, Fred5_collision_ram.bin, Fred5_damage_ram.bin,
Fred5_damage_render_check.json, Fred5_scene_00.png through _16.png,
and Fred5_contact.png. Original replay and release ROM remain intact.
