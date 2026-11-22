#!/usr/bin/env bash
# Regression checks for bugs found in the JukaMix review (see commit message).
# Usage: bash tests/jukamix_fixes_test.sh     Needs: bash, sh (dash/ash), shellcheck (optional).
cd "$(dirname "$0")/.." || exit 1
PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf 'ok   - %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL - %s\n' "$1"; }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$3], got [$2])"; fi; }

# ---- 1. ScreenScraper system ids: WonderSwan is no longer shadowed by Supervision
SCRAP=System/usr/trimui/scripts/scraper/scrap_screenscraper.sh
fn=$(sed -n '/^get_ssSystemID() {/,/^}/p' "$SCRAP")
sysid() { sh -c "$fn"'
get_ssSystemID "$1" >/dev/null; printf %s "$ssSystemID"' _ "$1"; }
eq "scraper: WS -> WonderSwan (45)" "$(sysid WS)" 45
eq "scraper: WSC -> WonderSwan family (45)" "$(sysid WSC)" 45
eq "scraper: SUPERVISION -> Watara Supervision (207)" "$(sysid SUPERVISION)" 207
eq "scraper: SFX stays PC Engine SuperGrafx (105)" "$(sysid SFX)" 105
eq "scraper: SEGA32X stays 19" "$(sysid SEGA32X)" 19
eq "scraper: NGP/NGC keep their own ids" "$(sysid NGP)/$(sysid NGC)" "25/82"
dups=$(sed -n '/^get_ssSystemID() {/,/^}/p' "$SCRAP" | grep -oE '^ +[A-Z0-9_]+\)' | sort | uniq -d)
eq "scraper: no duplicated case label" "$dups" ""

# ---- 2. Best-folder icons: Neo Geo Pocket Color is NGC (NGP is the plain Pocket)
BEST="Apps/SystemTools/Menu/USER INTERFACE##BEST SECTION/Add icons on best folders.sh"
eq "best icons: NGP maps to the plain Pocket icon (x2)" "$(grep -c 'NGP) new_value="SNK - Neo Geo Pocket" ;;' "$BEST")" 2
eq "best icons: NGC maps to the Color icon (x2)" "$(grep -c 'NGC) new_value="SNK - Neo Geo Pocket Color" ;;' "$BEST")" 2
if [ -e "RetroArch/.retroarch/assets/ozone/png/icons/SNK - Neo Geo Pocket Color.png" ]; then ok "best icons: the Color icon file exists"; else bad "best icons: the Color icon file is missing"; fi

# ---- 3. Tailscale scripts stop the daemon by process name (a full path never matches pkill)
TS="Apps/SystemTools/Menu/NETWORK##Tailscale (state)"
for f in "Tailscale  - enable.sh" "Tailscale - disable.sh" "Tailscale - reset configuration.sh"; do
  s=$TS/$f
  eq "tailscale ($f): TAILSCALE is the CLI, not the daemon" "$(grep -c '^TAILSCALE="/mnt/SDCARD/System/bin/tailscale"$' "$s")" 1
  eq "tailscale ($f): no pkill with a path/variable" "$(grep -cE 'pkill -9 "\$TAILSCALED?"' "$s")" 0
  eq "tailscale ($f): pkill -x tailscaled" "$(grep -c 'pkill -9 -x tailscaled' "$s")" 1
done
# behaviour: pkill -x matches the real process name, the old path pattern does not
tmp=$(mktemp -d /tmp/jukafix.XXXXXX)
cp "$(command -v sleep)" "$tmp/tailscaled"
"$tmp/tailscaled" 30 &
pid=$!
disown "$pid"
sleep 0.2
pkill -9 /mnt/SDCARD/System/bin/tailscaled 2>/dev/null
if kill -0 "$pid" 2>/dev/null && [ "$(ps -o stat= -p "$pid" | cut -c1)" != Z ]; then ok "old pattern (full path) leaves the daemon running"; else bad "old pattern unexpectedly killed it"; fi
pkill -9 -x tailscaled
sleep 0.3
if [ "$(ps -o stat= -p "$pid" 2>/dev/null | cut -c1)" != R ] && ! kill -0 "$pid" 2>/dev/null; then ok "pkill -x tailscaled stops it"; else bad "pkill -x did not stop it"; fi
rm -rf "$tmp"

# ---- 3b. SFTPGo / Syncthing: same pkill-with-a-path defect
NET="Apps/SystemTools/Menu/NETWORK##"
for f in "SFTPGo (state)/SFTPGo Server  - enable.sh" "SFTPGo (state)/SFTPGo Server - disable.sh"; do
  eq "sftpgo ($f): pkill -x sftpgo" "$(grep -c '^pkill -x sftpgo$' "$NET$f")" 1
done
for f in "Syncthing (state)/Syncthing Server  - enable.sh" "Syncthing (state)/Syncthing Server - disable.sh"; do
  eq "syncthing ($f): pkill -x syncthing" "$(grep -c '^pkill -x syncthing$' "$NET$f")" 1
done
left=$(git grep -nE '^[[:space:]]*(pkill|killall)( +-[0-9A-Za-z]+)* +"?(/|\$[A-Za-z_{])' -- 'Apps/SystemTools/Menu/NETWORK*' | grep -v ' -f ' || true)
eq "network scripts: no pkill/killall left that matches by path" "$left" ""

# ---- 4. FW Settings restore: cancelling the file chooser exits cleanly
FW="Apps/SystemTools/Menu/TOOLS/FW Settings Save-Load.sh"
eq "fw restore: no reference to the never-assigned cleaned_input" "$(grep -c 'cleaned_input' "$FW")" 0
eq "fw restore: empty selector_output exits" "$(grep -c 'if \[ -z "\$selector_output" \]' "$FW")" 1

# ---- 5. syntax + no unreachable/duplicate case patterns in the touched scripts
for f in "$SCRAP" "$BEST" "$FW" "$TS"/*.sh; do
  if dash -n "$f" 2>/dev/null; then ok "syntax: ${f##*/}"; else bad "syntax: ${f##*/}"; fi
done
if command -v shellcheck >/dev/null; then
  out=$(shellcheck -s sh -f gcc -i SC2221,SC2222 "$SCRAP" "$BEST" 2>&1)
  eq "shellcheck: no unreachable case pattern" "$out" ""
fi

printf '%s check(s), %s failed\n' "$((PASS + FAIL))" "$FAIL"
[ "$FAIL" -eq 0 ]
