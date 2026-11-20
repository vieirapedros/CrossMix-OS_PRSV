#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
BG="/mnt/SDCARD/trimui/res/crossmix-os/bg-info.png"
[ -f "$BG" ] || BG="/mnt/SDCARD/trimui/res/crossmix-os/bg.png"

NET=$(ip addr 2>/dev/null | grep 'inet ' | head -n 3)
[ -z "$NET" ] && NET=$(ifconfig 2>/dev/null | grep 'inet ' | head -n 3)
[ -z "$NET" ] && NET="No network information"

ROMM_STATUS="RomM: not configured"
CFG="/mnt/SDCARD/Data/romm/config.json"
if [ -f "$CFG" ]; then
  URL=$(jq -r '.url // ""' "$CFG")
  TOKEN=$(jq -r '.token // ""' "$CFG")
  if [ -n "$URL" ] && [ -n "$TOKEN" ]; then
    CODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "$URL/api/platforms" 2>/dev/null)
    if [ "$CODE" = "200" ]; then
      ROMM_STATUS="RomM: connected"
    else
      ROMM_STATUS="RomM: unreachable (HTTP $CODE)"
    fi
  fi
fi

MSG="Wi-Fi Tools\n\n$NET\n\n$ROMM_STATUS\n\nPress MENU to exit"
/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "$BG" -m "$MSG" -k "MENU"
exit 0
