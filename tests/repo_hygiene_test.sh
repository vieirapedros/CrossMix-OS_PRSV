#!/usr/bin/env bash
# Repository hygiene checks: files that must never be versioned or shipped on the card.
# Usage: bash tests/repo_hygiene_test.sh     Needs: git (inside a clone) or find.
#
# Today this covers the Windows "Zone.Identifier" marks (NTFS alternate data streams that show up
# as stray files, e.g. "000.ogg:Zone.Identifier", when downloaded files are copied through WSL or
# some archivers).  They are useless on the device and only add noise to the image.

ROOT=$(cd "$(dirname "$0")/.." && pwd)

pass=0
fail=0
ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }

# Tracked files when inside a git clone, otherwise whatever is on disk.
list_files() {
    if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$ROOT" ls-files
    else
        (cd "$ROOT" && find . -type f ! -path './.git/*' | sed 's|^\./||')
    fi
}

# ---- 1. no Zone.Identifier files ---------------------------------------------------------
# The ADS name is "<file>:Zone.Identifier"; copied through some tools the ":" becomes another
# character, so match on the suffix only.
n=$(list_files | grep -c 'Zone\.Identifier')
if [ "$n" = 0 ]; then
    ok "no Zone.Identifier files in the repository"
else
    bad "$n Zone.Identifier file(s) in the repository:"
    list_files | grep 'Zone\.Identifier' | head -5 | sed 's/^/       /'
fi

# ---- 2. .gitignore keeps them out --------------------------------------------------------
if grep -q 'Zone\.Identifier' "$ROOT/.gitignore" 2>/dev/null; then
    ok ".gitignore ignores Zone.Identifier files"
else
    bad ".gitignore does not mention Zone.Identifier"
fi

# ---- 3. the ignore rule really matches the odd names that were committed -----------------
# (git is needed for check-ignore; skipped elsewhere)
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    probe='Apps/PortMaster/PortMaster/themes/ff_VII/000.ogg∩Ç║Zone.Identifier'
    if git -C "$ROOT" check-ignore -q -- "$probe"; then
        ok ".gitignore matches the mangled name (000.ogg∩Ç║Zone.Identifier)"
    else
        bad ".gitignore does not match the mangled name"
    fi
    probe2='Apps/PortMaster/PortMaster/themes/Zelda/x.ogg:Zone.Identifier'
    if git -C "$ROOT" check-ignore -q -- "$probe2"; then
        ok ".gitignore matches the plain name (x.ogg:Zone.Identifier)"
    else
        bad ".gitignore does not match the plain name"
    fi
fi

# ---- 4. CJK fonts live once, in pylibs/resources -----------------------------------------
# PortMaster unpacks NotoSans.tar.xz into pylibs/resources on first run (pugwash) and adds that
# folder to the GUI resource search path, so the themes do not need their own copies (the stock
# default_theme already has none).  Six themes used to carry the same five ~6-10 MB fonts: 210 MB.
PM=Apps/PortMaster/PortMaster
dup=$(list_files | grep -cE "^$PM/themes/[^/]+/NotoSans[A-Z]+-Regular\.ttf$")
if [ "$dup" = 0 ]; then
    ok "themes carry no private copy of the NotoSans CJK fonts"
else
    bad "$dup NotoSans font copies inside PortMaster themes"
fi

if [ -f "$ROOT/$PM/pylibs/resources/NotoSans.tar.xz" ]; then
    got=$(tar -tf "$ROOT/$PM/pylibs/resources/NotoSans.tar.xz" 2>/dev/null | grep -c 'NotoSans[A-Z]*-Regular\.ttf$')
    if [ "$got" = 5 ]; then
        ok "pylibs/resources/NotoSans.tar.xz holds the 5 fonts (HK JP KR SC TC)"
    else
        bad "NotoSans.tar.xz holds $got fonts, expected 5"
    fi
else
    bad "pylibs/resources/NotoSans.tar.xz is missing"
fi

if grep -q "NotoSans.tar.xz" "$ROOT/$PM/pugwash" 2>/dev/null &&
    grep -q "resources.add_path(PYLIB_PATH / 'resources')" "$ROOT/$PM/pugwash" 2>/dev/null; then
    ok "pugwash unpacks the fonts and searches pylibs/resources"
else
    bad "pugwash no longer unpacks NotoSans.tar.xz or no longer searches pylibs/resources"
fi

# Every theme that names a Noto font in theme.json must still be able to find it: the name has to
# be one of the five shipped in the tarball.
bad_ref=0
for tj in "$ROOT/$PM"/themes/*/theme.json "$ROOT/$PM"/pylibs/default_theme/theme.json; do
    [ -f "$tj" ] || continue
    for name in $(grep -o 'NotoSans[A-Za-z]*-Regular\.ttf' "$tj" | sort -u); do
        case "$name" in
            NotoSansHK-Regular.ttf | NotoSansJP-Regular.ttf | NotoSansKR-Regular.ttf | NotoSansSC-Regular.ttf | NotoSansTC-Regular.ttf) ;;
            *)
                bad "$tj names $name, which the tarball does not ship"
                bad_ref=1
                ;;
        esac
    done
done
[ "$bad_ref" = 0 ] && ok "every Noto font named by a theme.json is one the tarball ships"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
