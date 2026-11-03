"""Construye una ROM Fred MSX1 de 64 KB sin modificar el .z80 original."""
from __future__ import annotations

import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools"))
from inspect_ant import load_snapshot

SNAP = ROOT / "JUEBOS/Fred_1984_Quicksilva_re_release.z80"
SHA256 = "05e2437c513c91e88ec986ff173b2f7d97ee4f8e16b82c8237abe5fc888271e0"
OUT = ROOT / "build/Fred_MSX1_64K_fire_repeat_slow.rom"


def assemble(source: str, output: str, symbols: str) -> dict[str, int]:
    p = subprocess.run(["pasmo", source, output, symbols], cwd=HERE,
                       capture_output=True, text=True)
    if p.returncode:
        raise RuntimeError(p.stdout + p.stderr)
    result = {}
    for line in (HERE / symbols).read_text().splitlines():
        match = re.match(r"(\w+)\s+EQU\s+0?([0-9A-F]+)H", line, re.I)
        if match:
            result[match.group(1)] = int(match.group(2), 16)
    return result


def pack(data: bytes) -> bytes:
    out = bytearray()
    i = 0
    while i < len(data):
        j = i + 1
        while j < len(data) and data[j] == data[i] and j-i < 130:
            j += 1
        if j-i >= 4:
            out.extend((128 + j-i-3, data[i]))
            i = j
            continue
        start = i
        i += 1
        while i < len(data) and i-start < 128:
            j = i + 1
            while j < len(data) and data[j] == data[i] and j-i < 130:
                j += 1
            if j-i >= 4:
                break
            i += 1
        out.append(i-start-1)
        out.extend(data[start:i])
    return bytes(out)


def keypos(key: str) -> int:
    if key.isdigit():
        n = int(key)
        row, bit = (0, n) if n < 8 else (1, n-8)
    elif len(key) == 1:
        if key in "AB":
            row, bit = 2, 6 + "AB".index(key)
        else:
            offset = ord(key) - ord("C")
            row, bit = 3 + offset // 8, offset % 8
    else:
        row, bit = {"CAPS": (6, 0), "SYM": (6, 1),
                    "ENTER": (7, 7), "SPACE": (8, 0)}[key]
    return row*16 + bit


def make_includes() -> None:
    stage = (HERE / "stage0.asm").read_text()
    (HERE / "runtime_slots.inc").write_text(
        stage[stage.index("set_page:"):].replace("slot_save", "runtime_slot_save"))
    # vdp.inc y dump.inc son fuentes propias de Fred. No copiar la capa de
    # Ant Attack: su mapa de RAM, HUD y regiones de pantalla son diferentes.
    keyboard = [["CAPS", "Z", "X", "C", "V"], list("ASDFG"), list("QWERT"),
                list("12345"), list("09876"), list("POIUY"),
                ["ENTER", "L", "K", "J", "H"], ["SPACE", "SYM", "M", "N", "B"]]
    zx = [1, 4, 6, 13, 12, 7, 10, 14]
    bright = [1, 5, 8, 13, 2, 7, 11, 15]
    lines = ["keymap:"]
    for row in keyboard:
        lines.append(" db " + ",".join(f"0{keypos(k):02X}h" for k in row))
    (HERE / "tables.inc").write_text("\n".join(lines) + "\n")
    lines = [" org 03980h", "attr2col:"]
    for a in range(0, 128, 16):
        values = []
        for value in range(a, a+16):
            pal = bright if value & 0x40 else zx
            values.append(f"0{(pal[value & 7] << 4 | pal[(value >> 3) & 7]):02X}h")
        lines.append(" db " + ",".join(values))
    (HERE / "palette.asm").write_text("\n".join(lines) + "\n")


def main() -> None:
    actual = hashlib.sha256(SNAP.read_bytes()).hexdigest()
    if actual != SHA256:
        raise ValueError(f"Snapshot inesperado: {actual}")
    memory, regs = load_snapshot(SNAP)
    ram = bytearray(memory)
    # Spectrum ULA port FE is the MSX RAM mapper's page-2 register.
    # These writes only set the original border; sound uses our PSG hook.
    for addr in (0x6043, 0x76C0, 0x7C38, 0x7CA6, 0x7E62, 0x7F65, 0xB6EE):
        if ram[addr:addr+2] != b"\xd3\xfe":
            raise ValueError(f"ULA output changed at {addr:04X}")
        ram[addr:addr+2] = b"\0\0"
    # The Spectrum discards these background saves by writing to ROM at 0.
    # Page zero is writable in this port: use an isolated 40-byte sink instead.
    for addr in (0x7AFA, 0x7BDC, 0x8D2C, 0x937C):
        if ram[addr:addr+6] != b"\x21\x00\x00\x22\x36\x64":
            raise ValueError(f"Discard buffer changed at {addr:04X}")
        ram[addr+1:addr+3] = b"\xc0\x38"
    if ram[0x6391:0x6394] != b"\x2a\x8f\x63":
        raise ValueError("Renderer original inesperado")
    make_includes()
    import skoolkit
    zx_rom = (Path(skoolkit.__file__).parent / "resources/48.rom").read_bytes()
    zx_rom = bytearray(zx_rom)
    for addr in (0x03E1, 0x04DA, 0x04EC, 0x04F4, 0x051C, 0x0548,
                 0x055C, 0x0601, 0x11CE, 0x229B):
        if zx_rom[addr:addr+2] != b"\xd3\xfe":
            raise ValueError(f"ROM ULA output changed at {addr:04X}")
        zx_rom[addr:addr+2] = b"\0\0"
    (HERE / "rom_attribute.inc").write_text(" db " + ",".join(
        f"0{x:02X}h" for x in zx_rom[0x0BDB:0x0C08]) + "\n")
    (HERE / "hud_cells.inc").write_text("\n".join(
        f" db 0{((y%8)*32 + x):02X}h"
        for y in range(24) for x in range(32)
        if not (1 <= y <= 22 and 1 <= x <= 24)) + "\n")
    (HERE / "tiles_runtime.inc").write_text("dump_legacy equ 0\ngame_active equ 0\ntracking_reset equ 0\ntracking_acquire equ 0\ntracking_pending equ 0\ntracking_commit equ 0\n")
    tsym = assemble("tiles.asm", "tiles.bin", "tiles.sym")
    (HERE / "tracking_targets.inc").write_text(f'minimap_mark equ 0{tsym["minimap_mark"]:04X}h\ntracking_hud_dirty equ 0{tsym["hud_dirty"]:04X}h\nfire_game_active equ 0\nfire_selector_saved equ 0\nfire_kbd equ 0\n')
    tracking = assemble("tracking.asm", "tracking.bin", "tracking.sym")
    (HERE / "tiles_runtime.inc").write_text("dump_legacy equ 0\ngame_active equ 0\n" + "".join(f'{n} equ 0{tracking[n]:04X}h\n' for n in ('tracking_reset','tracking_acquire','tracking_pending','tracking_commit')))
    tsym = assemble("tiles.asm", "tiles.bin", "tiles.sym")
    (HERE / "tracking_targets.inc").write_text(f'minimap_mark equ 0{tsym["minimap_mark"]:04X}h\ntracking_hud_dirty equ 0{tsym["hud_dirty"]:04X}h\nfire_game_active equ 0\nfire_selector_saved equ 0\nfire_kbd equ 0\n')
    tracking = assemble("tracking.asm", "tracking.bin", "tracking.sym")
    if tracking['tracking_end'] > 0x2000:
        raise ValueError('Tracking code overlaps Spectrum printing routine')
    if ram[0x5C7B:0x5C7D] != b"\x58\xff":
        raise ValueError("Unexpected original UDG pointer")
    ram[0x5C7B:0x5C7D] = tsym["udg_workspace"].to_bytes(2, "little")
    (HERE / "tile_targets.inc").write_text("".join(
        f"{name} equ 0{tsym[name]:04X}h\n"
        for name in ("tile_present", "tile_title", "sound_tick", "legacy_ready")) +
        f'tracking_tick equ 0{tracking["tracking_tick"]:04X}h\nfire_poll equ 0{tracking["fire_poll"]:04X}h\n')
    ram[0x6391:0x6394] = bytes((0xC3, tsym["tile_legacy"] & 255, tsym["tile_legacy"] >> 8))
    if ram[0x790A:0x790D] != b"\xcd\x91\x63":
        raise ValueError("Main render call changed")
    ram[0x790A:0x790D] = bytes((0xCD, tsym["tile_enter"] & 255, tsym["tile_enter"] >> 8))
    for addr, expected, name, opcode in (
        (0x6155, b"\xcd\xb5\x03", "async_beeper", 0xCD),
        (0x7ABE, b"\xcd\xb5\x03", "async_beeper", 0xCD),
        (0x6103, b"\x77\x23\x79", "hud_small_left", 0xCD),
        (0x6107, b"\x77\x2b\x13", "hud_small_right", 0xCD),
        (0x8E02, b"\x06\x03\x21", "hud_health", 0xC3),
        (0xAE72, b"\xcd\xc8\xae", "hud_minimap", 0xCD),
        (0x7AD1, b"\xcd\x91\x63", "tile_exit_frame", 0xCD),
        (0x76FF, b"\xcd\xf4\x62", "prepare_game_screen", 0xCD),
    ):
        if ram[addr:addr+3] != expected:
            raise ValueError(f"HUD writer changed at {addr:04X}")
        target = tsym[name]
        ram[addr:addr+3] = bytes((opcode, target & 255, target >> 8))
    if ram[0xACE7:0xACEA] != b"\xcd\xb7\x6b":
        raise ValueError("Item placement changed")
    target = tracking["tracking_unique_item"]
    ram[0xACE7:0xACEA] = bytes((0xCD, target & 255, target >> 8))
    if ram[0x78A3:0x78A8] != b"\x20\x03\xcd\x03\x92":
        raise ValueError("Fire branch changed")
    target = tracking["fire_gate"]
    ram[0x78A3:0x78A8] = bytes((0, 0, 0xCD, target & 255, target >> 8))
    reads = (0x6076, 0x7674, 0x7D6F, 0x7E9E, 0x7EC8, 0x7F7A, 0x7F95,
             0xB3F2, 0xB4BE, 0xB4CF, 0x7800, 0x7825, 0x7838, 0x7861, 0x789F)
    for addr in reads:
        if ram[addr:addr+2] not in (b"\xdb\xfe", b"\xdb\xde"):
            raise ValueError(f"Lectura de teclado cambiada: {addr:04X}")
        ram[addr:addr+2] = b"\xc7\x00"
    # Fred reescribe el operando de los cinco IN A,(n) al entrar en juego.
    # Ese segundo byte es ahora el NOP que sigue a RST 00h; conservarlo evita
    # que el selector FE/FB/7F se ejecute como opcode. La fila ZX ya está en A.
    keyboard_operand_writes = (
        (0x7CF5, b"\x32\x01\x78"),
        (0x7CF8, b"\x32\x26\x78"),
        (0x7CFB, b"\x32\x39\x78"),
        (0x7CFE, b"\x32\x62\x78"),
        (0x7D01, b"\x32\xa0\x78"),
    )
    for addr, expected in keyboard_operand_writes:
        if ram[addr:addr+3] != expected:
            raise ValueError(f"Operand write changed at {addr:04X}")
        ram[addr:addr+3] = b"\0\0\0"
    chunks = [pack(ram[a:a+0x4000]) for a in (0x4000, 0x8000, 0xC000)]
    if len(chunks[0]) + len(chunks[2]) > 0x4000 or len(chunks[1]) > 0x4000:
        raise ValueError(f"Los datos no caben: {[len(x) for x in chunks]}")
    make_includes()
    (HERE / "stage_syms.inc").write_text(
        f"CHUNK1_LEN equ {len(chunks[0])}\nRUNTIME_CART equ 0\nRUNTIME_LEN equ 0\n")
    stage = assemble("stage0.asm", "stage0.bin", "stage0.sym")
    (HERE / "stage_symbols.inc").write_text("".join(
        f"{name} equ 0{stage[name]:04X}h\n"
        for name in ("F_start", "F_RAMV", "F_CARTV")))
    # Volcar pantalla tras completar cada frame, no durante el dibujado.
    rsym = assemble("runtime.asm", "runtime.bin", "runtime.sym")
    (HERE / "tiles_runtime.inc").write_text(f"dump_legacy equ 0{rsym['dump_legacy']:04X}h\ngame_active equ 0{rsym['game_active']:04X}h\n" + "".join(f'{n} equ 0{tracking[n]:04X}h\n' for n in ('tracking_reset','tracking_acquire','tracking_pending','tracking_commit')))
    tsym = assemble("tiles.asm", "tiles.bin", "tiles.sym")
    (HERE / "tracking_targets.inc").write_text(
        f'minimap_mark equ 0{tsym["minimap_mark"]:04X}h\ntracking_hud_dirty equ 0{tsym["hud_dirty"]:04X}h\n'
        f'fire_game_active equ 0{rsym["game_active"]:04X}h\n'
        f'fire_selector_saved equ 0{rsym["selector_saved"]:04X}h\nfire_kbd equ 0{rsym["kbd"]:04X}h\n')
    assemble("tracking.asm", "tracking.bin", "tracking.sym")
    if rsym["R_END"] > 0xBC00:
        raise ValueError("La capa Fred invade los datos del motor")
    for addr, expected, name, opcode in (
        (0x7664, b"\xcd\xb0\x60", "title_hook", 0xCD),
        (0x79BC, b"\xc3\xf1\x77", "frame_hook", 0xC3),
        (0x7CCD, b"\xcd\x6a\x7d", "rebind_key", 0xCD),
    ):
        if ram[addr:addr+3] != expected:
            raise ValueError(f"Hook inesperado en {addr:04X}")
        target = rsym[name]
        ram[addr:addr+3] = bytes((opcode, target & 255, target >> 8))
    chunks = [pack(ram[a:a+0x4000]) for a in (0x4000, 0x8000, 0xC000)]
    if len(chunks[0]) + len(chunks[2]) > 0x4000 or len(chunks[1]) > 0x4000:
        raise ValueError(f"Los datos no caben: {[len(x) for x in chunks]}")
    runtime_len = len((HERE / "runtime.bin").read_bytes())
    (HERE / "stage_syms.inc").write_text(
        f"CHUNK1_LEN equ {len(chunks[0])}\nRUNTIME_CART equ 0\nRUNTIME_LEN equ {runtime_len}\n")
    arr = assemble("arranque.asm", "arranque.bin", "arranque.sym")
    runtime_cart = arr["runtime_blob"]
    (HERE / "stage_syms.inc").write_text(
        f"CHUNK1_LEN equ {len(chunks[0])}\nRUNTIME_CART equ 0{runtime_cart:04X}h\nRUNTIME_LEN equ {runtime_len}\n")
    assemble("stage0.asm", "stage0.bin", "stage0.sym")
    assemble("arranque.asm", "arranque.bin", "arranque.sym")
    bank0 = (HERE / "arranque.bin").read_bytes()
    if len(bank0) > 0x4000:
        raise ValueError(f"Bootstrap demasiado grande: {len(bank0)}")
    import skoolkit
    spectrum_rom = bytearray(zx_rom)
    # Fred uses machine-code menu/keyboard/printing, not the BASIC line
    # interpreter at 1800-1AFF. Its ROM-byte random reader also traverses
    # this area (as it does existing renderer code); random sequences can
    # change. Keep a canonical index for each immutable
    # graphics source, local to its 256-pattern page. Pixel bytes are equal;
    # descriptor colour bits remain part of the runtime cache key.
    canonical = bytearray()
    for page in range(3):
        seen = {}
        for index in range(256):
            start = 0x9400 + (page * 256 + index) * 8
            pattern = bytes(ram[start:start+8])
            canonical.append(seen.setdefault(pattern, index))
    assert len(canonical) == 768
    spectrum_rom[0x1800:0x1B00] = canonical

    spectrum_rom[0x2080:0x2170] = bytes((y%8)*32+x for y in range(24) for x in range(32) if not (1<=y<=22 and 1<=x<=24))
    tracking_code = (HERE / 'tracking.bin').read_bytes()
    spectrum_rom[0x1C20:0x1C20+len(tracking_code)] = tracking_code
    if len(spectrum_rom) != 0x4000:
        raise ValueError("ROM Spectrum incorrecta")
    if spectrum_rom[0x03B5:0x03B9] != b"\xf3\x7d\xcb\x3d":
        raise ValueError("Entrada BEEPER Spectrum inesperada")
    if spectrum_rom[0x386E:0x3D00] != b"\xff" * (0x3D00 - 0x386E):
        raise ValueError("Hueco de la ROM Spectrum inesperado")
    sound_syms = assemble("sound.asm", "sound.bin", "sound.sym")
    if sound_syms["sound_beeper"] != 0x386E:
        raise ValueError("Direccion de sonido inesperada")
    sound = (HERE / "sound.bin").read_bytes()
    if len(sound) > 0x3D00 - 0x386E:
        raise ValueError("El sonido no cabe en el hueco de la ROM")
    spectrum_rom[0x386E:0x386E + len(sound)] = sound
    render_syms = assemble("render.asm", "render.bin", "render.sym")
    renderer = (HERE / "render.bin").read_bytes()
    if render_syms["fast_render"] != 0x3900 or render_syms["render_end"] > 0x3980:
        raise ValueError("Renderer fuera del hueco reservado")
    if spectrum_rom[0x3900:0x3900+len(renderer)] != b"\xff"*len(renderer):
        raise ValueError("Renderer pisaria codigo ROM")
    spectrum_rom[0x3900:0x3900+len(renderer)] = renderer
    if sound_syms["sound_beeper"] + len(sound) > 0x38C0:
        raise ValueError("Sound overlaps discard sink")
    assemble("palette.asm", "palette.bin", "palette.sym")
    spectrum_rom[0x3980:0x3A00] = (HERE / "palette.bin").read_bytes()
    if tsym["tile_enter"] != 0x2400 or tsym["tile_end"] > 0x2F00:
        raise ValueError("Native renderer overlaps slot keys at 2F00h")
    native = (HERE / "tiles.bin").read_bytes()
    spectrum_rom[0x2400:0x2400+len(native)] = native
    for addr, expected, name, opcode in (
        (0x0BB8, b"\x1a\xa0\xae\xa9\x12", "hud_rom_pixel", 0xCD),
        (0x0BDB, b"\x7c\x0f\x0f", "hud_rom_attribute", 0xC3),
    ):
        if spectrum_rom[addr:addr+len(expected)] != expected:
            raise ValueError(f"ROM HUD writer changed at {addr:04X}")
        target = tsym[name]
        spectrum_rom[addr:addr+len(expected)] = bytes((opcode,target & 255,target >> 8)) + bytes(len(expected)-3)
    rom = (bank0.ljust(0x4000, b"\0") + spectrum_rom
           + (chunks[0] + chunks[2]).ljust(0x4000, b"\0")
           + chunks[1].ljust(0x4000, b"\0"))
    assert len(rom) == 65536
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_bytes(rom)
    print(f"{OUT} ({len(rom)} bytes), chunks={[len(x) for x in chunks]}, "
          f"runtime={runtime_len}, PC snapshot={regs['pc']:04X}")


if __name__ == "__main__":
    main()

