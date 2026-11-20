#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
BG="/mnt/SDCARD/trimui/res/crossmix-os/bg-info.png"
[ -f "$BG" ] || BG="/mnt/SDCARD/trimui/res/crossmix-os/bg.png"

THEMES="/mnt/SDCARD/Themes"
SYSTEM_JSON="/mnt/UDISK/system.json"
BACKUP="/mnt/SDCARD/Data/theme-switcher/system.json.backup"
mkdir -p "$(dirname "$BACKUP")"

while :; do
  CURRENT=$(jq -r '.theme // "unknown"' "$SYSTEM_JSON" 2>/dev/null)
  CURRENT_NAME=$(basename "$CURRENT" 2>/dev/null)
  MSG="Theme Switcher\n\nCurrent: $CURRENT_NAME\n\nA: next theme\nMENU: exit"
  BTN=$(/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "$BG" -m "$MSG" -k "A MENU")

  if [ "$BTN" = "MENU" ]; then
    break
  fi

  if [ "$BTN" = "A" ]; then
    NEXT=$(find "$THEMES" -mindepth 1 -maxdepth 1 -type d | while read -r d; do echo "$d"; done | grep -A1 "$CURRENT" | tail -n 1)
    [ -z "$NEXT" ] && NEXT=$(find "$THEMES" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [ -n "$NEXT" ]; then
      cp "$SYSTEM_JSON" "$BACKUP" 2>/dev/null
      TMP=$(mktemp)
      jq --arg theme "$NEXT" '.theme = $theme' "$SYSTEM_JSON" > "$TMP" && mv "$TMP" "$SYSTEM_JSON"
      sync
    fi
  fi
done
exit 0
