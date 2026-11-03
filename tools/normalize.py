"""Create the deterministic 64 KiB base image expected by the IPS patch."""
from pathlib import Path
import hashlib
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from inspect_ant import load_snapshot

SNAP = ROOT / "JUEBOS" / "Fred_1984_Quicksilva_re_release.z80"
OUT = ROOT / "build" / "Fred_MSX1_base.rom"
SHA256 = "05e2437c513c91e88ec986ff173b2f7d97ee4f8e16b82c8237abe5fc888271e0"


def pack(data: bytes) -> bytes:
    out = bytearray()
    i = 0
    while i < len(data):
        j = i + 1
        while j < len(data) and data[j] == data[i] and j - i < 130:
            j += 1
        if j - i >= 4:
            out.extend((128 + j - i - 3, data[i]))
            i = j
            continue
        start = i
        i += 1
        while i < len(data) and i - start < 128:
            j = i + 1
            while j < len(data) and data[j] == data[i] and j - i < 130:
                j += 1
            if j - i >= 4:
                break
            i += 1
        out.append(i - start - 1)
        out.extend(data[start:i])
    return bytes(out)


def main() -> None:
    if hashlib.sha256(SNAP.read_bytes()).hexdigest() != SHA256:
        raise ValueError("El snapshot no es la revision esperada")
    memory, _ = load_snapshot(SNAP)
    chunks = [pack(memory[a:a + 0x4000]) for a in (0x4000, 0x8000, 0xC000)]
    import skoolkit
    spectrum_rom = (Path(skoolkit.__file__).parent / "resources/48.rom").read_bytes()
    base = (bytes(0x4000) + spectrum_rom
            + (chunks[0] + chunks[2]).ljust(0x4000, b"\0")
            + chunks[1].ljust(0x4000, b"\0"))
    if len(base) != 0x10000:
        raise ValueError("La base no mide 64 KiB")
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_bytes(base)
    print(f"{OUT} ({len(base)} bytes)")


if __name__ == "__main__":
    main()

