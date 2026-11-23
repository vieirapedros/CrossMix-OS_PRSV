#!/usr/bin/env bash
# Off-device checks for the tsp/tsps input daemon that no longer advertises force feedback
# (scripts/inputd-disable-ff.py and the daemons shipped on the card).
# Usage: bash tests/inputd_noff_test.sh     Needs: python3. Optional: llvm-objdump, git, sha256sum.
#
# The daemon cannot be executed here (aarch64 build, needs /dev/uinput and the UART), so the
# checks are structural: which bytes change, what the disassembly of the patched function
# looks like, and that the files on the card are the patched build.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PATCHER=$ROOT/scripts/inputd-disable-ff.py
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1  (got '$2', want '$3')"; fi; }

command -v python3 >/dev/null 2>&1 || {
    echo "python3 not found"
    exit 1
}

# The pristine upstream build (JukaMix d5102fab) is the reference for the byte diff.  Inside a
# clone it comes from git; otherwise the tests that need it are skipped.
UP=$T/upstream_tsp_inputd
have_up=0
if git -C "$ROOT" show d5102fab:System/resources/tsp_inputd >"$UP" 2>/dev/null && [ -s "$UP" ]; then
    have_up=1
fi

# ---- 1. what the script recognises -------------------------------------------------------
if [ "$have_up" = 1 ]; then
    eq "upstream tsp build is recognised as original" "$(python3 -I "$PATCHER" --check "$UP")" original
    eq "upstream tsp build size" "$(wc -c <"$UP" | tr -d ' ')" 41144
fi
python3 -I "$PATCHER" --check "$ROOT/trimui/app/trimui_inputd" >/dev/null 2>&1
st=$?
# either the patched tsp build (this card) or the old 26912-byte build: never "original"
out=$(python3 -I "$PATCHER" --check "$ROOT/trimui/app/trimui_inputd" 2>&1)
case "$out" in
    patched | unknown) ok "default daemon is not the unpatched tsp build ($out, status $st)" ;;
    *) bad "default daemon is the unpatched tsp build" ;;
esac
head -c 4096 /dev/urandom >"$T/junk.bin"
eq "random bytes are refused" "$(python3 -I "$PATCHER" --check "$T/junk.bin" 2>/dev/null)" unknown
if python3 -I "$PATCHER" "$T/junk.bin" -o "$T/junk.out" 2>/dev/null; then bad "patcher accepted a foreign file"; else ok "patcher refuses a foreign file"; fi
[ -e "$T/junk.out" ] && bad "patcher wrote output for a foreign file" || ok "nothing written for a foreign file"

# ---- 2. the patch itself ------------------------------------------------------------------
if [ "$have_up" = 1 ]; then
    python3 -I "$PATCHER" "$UP" -o "$T/patched.bin" >/dev/null
    eq "patched copy is recognised" "$(python3 -I "$PATCHER" --check "$T/patched.bin")" patched
    eq "size is unchanged" "$(wc -c <"$T/patched.bin" | tr -d ' ')" "$(wc -c <"$UP" | tr -d ' ')"
    python3 -I "$PATCHER" "$T/patched.bin" -o "$T/twice.bin" >/dev/null
    cmp -s "$T/patched.bin" "$T/twice.bin" && ok "patching twice changes nothing" || bad "patching twice changed the file"
    changed=$(python3 -I - "$UP" "$T/patched.bin" <<'PY'
import sys
a = open(sys.argv[1], 'rb').read()
b = open(sys.argv[2], 'rb').read()
words = sorted({i // 4 * 4 for i in range(len(a)) if a[i] != b[i]})
print(len(words), ' '.join('%x' % w for w in words))
PY
)
    eq "exactly eight 32-bit words differ, at the expected offsets" "$changed" "8 3c4c 3c60 3c74 3c88 3c9c 3cb0 3cc4 3cc8"
    [ "$(cmp -l "$UP" "$T/patched.bin" | awk '$1 < 15437 || $1 > 15564' | wc -l)" = 0 ] \
        && ok "no byte outside the 8 patched words changes (file offsets 0x3c4c-0x3ccb)" || bad "bytes changed outside the function"
    cp "$UP" "$T/inplace.bin"
    python3 -I "$PATCHER" "$T/inplace.bin" --in-place >/dev/null
    cmp -s "$T/inplace.bin.orig" "$UP" && ok "--in-place keeps the original as .orig" || bad "--in-place lost the original"
    cmp -s "$T/inplace.bin" "$T/patched.bin" && ok "--in-place result equals -o result" || bad "--in-place differs from -o"
fi

# ---- 3. disassembly of the patched function ------------------------------------------------
SRC=$ROOT/System/resources/tsp_inputd
if command -v llvm-objdump >/dev/null 2>&1; then
    dis=$(llvm-objdump -d --no-show-raw-insn "$SRC" 2>/dev/null | sed -n '/^ *403c38:/,/^ *403cf0:/p')
    n_nop=$(printf '%s\n' "$dis" | grep -cE '^ *403c(4c|60|74|88|9c|b0|c4):\s+nop')
    eq "the seven FF ioctl calls are nops" "$n_nop" 7
    printf '%s\n' "$dis" | grep -qE '^ *403cc8:\s+mov\s+w0, #0x0\b' && ok "ff_effects_max is set to 0" || bad "ff_effects_max is not 0"
    # what must survive: the UI_DEV_SETUP (0x405c5503) and UI_DEV_CREATE (0x5501) calls
    printf '%s\n' "$dis" | grep -qE '#0x5503' && printf '%s\n' "$dis" | grep -qE '#0x5501' \
        && ok "UI_DEV_SETUP and UI_DEV_CREATE are still issued" || bad "device creation calls are missing"
    # no ioctl at all between the EV_FF setup and UI_DEV_SETUP any more
    between=$(printf '%s\n' "$dis" | sed -n '/^ *403c38:/,/^ *403cdc:/p' | grep -c 'bl.*ioctl')
    eq "no ioctl left between the FF setup and UI_DEV_SETUP" "$between" 0
    # nothing else in the whole daemon uploads or sets FF bits any more
    ffbits=$(llvm-objdump -d --no-show-raw-insn "$SRC" 2>/dev/null | grep -A3 '#0x556b' | grep -c 'bl.*ioctl')
    eq "no UI_SET_FFBIT request is followed by an ioctl anywhere" "$ffbits" 0
else
    echo "skip disassembly checks (llvm-objdump not found)"
fi

# ---- 4. what is shipped on the card ---------------------------------------------------------
eq "tsp_inputd on the card is patched" "$(python3 -I "$PATCHER" --check "$SRC")" patched
eq "tsps_inputd on the card is patched" "$(python3 -I "$PATCHER" --check "$ROOT/System/resources/tsps_inputd")" patched
cmp -s "$SRC" "$ROOT/System/resources/tsps_inputd" && ok "tsp and tsps builds are the same file" || bad "tsp and tsps builds differ"
cmp -s "$SRC" "$ROOT/trimui/app/trimui_inputd" && ok "the installed default daemon equals the patched tsp build" || bad "trimui/app/trimui_inputd is not the patched tsp build"
if [ "$have_up" = 1 ]; then
    # same function, same size, different bytes: the card must not still carry the original
    cmp -s "$SRC" "$UP" && bad "tsp_inputd on the card is still the upstream build" || ok "tsp_inputd on the card differs from upstream"
fi
python3 -I -m py_compile "$PATCHER" 2>/dev/null && ok "patcher compiles" || bad "patcher does not compile"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
