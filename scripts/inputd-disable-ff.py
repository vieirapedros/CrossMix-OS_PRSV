#!/usr/bin/env python3
"""Stop a JukaMix trimui_inputd (aarch64) from advertising force feedback.

Why
---
The tsp/tsps input daemons built since 2025-11-26 create the virtual Xbox-360 pad with
EV_FF, six FF_* bits and ff_effects_max=16 (function trimui_setup_xpad), but nothing in
the daemon ever reads the uinput fd or answers UI_BEGIN_FF_UPLOAD / UI_END_FF_UPLOAD.
Any program that uploads a rumble effect to that pad (SDL2 does it when it opens the pad,
and RetroArch's SDL2 joypad driver does that at start-up) then sleeps for ever in
uinput_request_submit(), state D, and cannot be killed.  The effect: Apps > RetroArch (and
every game launched through it) stays on the loading screen.

What it changes
---------------
Eight 32-bit instructions inside trimui_setup_xpad:
  * the seven `bl ioctl` calls that do UI_SET_EVBIT(EV_FF) and UI_SET_FFBIT(...) x6
    become `nop`  (their return values are never checked);
  * `mov w0,#16` (uinput_user_dev.ff_effects_max) becomes `mov w0,#0`.
Nothing else in the file changes, so every newer input fix in the daemon is kept.

Usage
-----
  inputd-disable-ff.py --check FILE            prints original | patched | unknown
  inputd-disable-ff.py FILE -o OUT             writes the patched copy (FILE is not touched)
  inputd-disable-ff.py FILE --in-place         patches FILE (a .orig copy is kept)

Exit status: 0 on success (also when already patched), 1 when the file is not the build
this script knows how to patch (nothing is written in that case).
"""
import argparse
import hashlib
import shutil
import struct
import sys

NOP = 0xD503201F
MOV_W0_0 = 0x52800000          # mov w0, #0
MOV_W0_16 = 0x52800200         # mov w0, #0x10
IOCTL_PLT = 0x4011A0           # ioctl@plt in the 41144-byte tsp/tsps build

# Each call site: (address of the `bl ioctl`, address of `mov w2,#code`, w2 value,
#                  address of `mov x1,#request` (low half; the high half 0x4004 follows)).
#   UI_SET_EVBIT = 0x40045564 (w2 = EV_FF = 0x15), UI_SET_FFBIT = 0x4004556b (w2 = FF_*).
CALL_SITES = (
    (0x403C4C, 0x403C38, 0x15, 0x403C3C, 0x5564),
    (0x403C60, 0x403C50, 0x50, 0x403C54, 0x556B),
    (0x403C74, 0x403C64, 0x60, 0x403C68, 0x556B),
    (0x403C88, 0x403C78, 0x51, 0x403C7C, 0x556B),
    (0x403C9C, 0x403C8C, 0x58, 0x403C90, 0x556B),
    (0x403CB0, 0x403CA0, 0x59, 0x403CA4, 0x556B),
    (0x403CC4, 0x403CB4, 0x5A, 0x403CB8, 0x556B),
)
MOV_SITE = 0x403CC8            # mov w0,#16  (uinput_user_dev.ff_effects_max)


def mov_w2(imm):
    return 0x52800000 | (imm << 5) | 2


def mov_x1(imm):
    return 0xD2800000 | (imm << 5) | 1


def load_segments(data):
    if data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        raise ValueError("not a 64-bit little-endian ELF file")
    if struct.unpack_from("<H", data, 0x12)[0] != 0xB7:
        raise ValueError("not an aarch64 ELF file")
    phoff = struct.unpack_from("<Q", data, 0x20)[0]
    phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
    segs = []
    for i in range(phnum):
        ptype, _flags, off, va, _pa, filesz, _memsz, _align = struct.unpack_from(
            "<IIQQQQQQ", data, phoff + i * phentsize)
        if ptype == 1:
            segs.append((va, off, filesz))
    return segs


def file_offset(segs, va):
    for seg_va, off, size in segs:
        if seg_va <= va < seg_va + size:
            return off + va - seg_va
    raise ValueError("address %#x is not in a loadable segment" % va)


def word(data, segs, va):
    return struct.unpack_from("<I", data, file_offset(segs, va))[0]


def bl_target(w, va):
    if (w >> 26) != 0b100101:
        return None
    imm = w & 0x3FFFFFF
    if imm & (1 << 25):
        imm -= 1 << 26
    return va + imm * 4


def state(data):
    """original | patched | unknown for the bytes of this file."""
    try:
        segs = load_segments(data)
        calls = nops = 0
        for bl_va, w2_va, w2_imm, x1_va, x1_imm in CALL_SITES:
            # the surrounding instructions must be exactly the ones we expect, otherwise
            # this is another build and the offsets mean nothing
            if word(data, segs, w2_va) != mov_w2(w2_imm):
                return "unknown"
            if word(data, segs, x1_va) != mov_x1(x1_imm):
                return "unknown"
            w = word(data, segs, bl_va)
            if bl_target(w, bl_va) == IOCTL_PLT:
                calls += 1
            elif w == NOP:
                nops += 1
            else:
                return "unknown"
        mov = word(data, segs, MOV_SITE)
        if calls == len(CALL_SITES) and mov == MOV_W0_16:
            return "original"
        if nops == len(CALL_SITES) and mov == MOV_W0_0:
            return "patched"
        return "unknown"
    except (ValueError, struct.error):
        return "unknown"


def patch(data):
    segs = load_segments(data)
    out = bytearray(data)
    for bl_va, *_rest in CALL_SITES:
        struct.pack_into("<I", out, file_offset(segs, bl_va), NOP)
    struct.pack_into("<I", out, file_offset(segs, MOV_SITE), MOV_W0_0)
    return bytes(out)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("file")
    ap.add_argument("-o", "--output")
    ap.add_argument("--in-place", action="store_true")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args(argv)

    with open(args.file, "rb") as fh:
        data = fh.read()
    st = state(data)

    if args.check:
        print(st)
        return 0 if st in ("original", "patched") else 1

    if st == "unknown":
        print("%s: not the tsp/tsps build this script knows (nothing written)" % args.file,
              file=sys.stderr)
        return 1

    new = patch(data) if st == "original" else data
    if args.in_place:
        if st == "original":
            shutil.copy2(args.file, args.file + ".orig")
            with open(args.file, "wb") as fh:
                fh.write(new)
        target = args.file
    elif args.output:
        with open(args.output, "wb") as fh:
            fh.write(new)
        target = args.output
    else:
        ap.error("give -o OUT or --in-place")

    print("%s: %s -> patched, %d bytes, sha256 %s" % (
        target, st, len(new), sha(new)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
