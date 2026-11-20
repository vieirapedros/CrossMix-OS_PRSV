#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
BG="/mnt/SDCARD/trimui/res/crossmix-os/bg-info.png"
[ -f "$BG" ] || BG="/mnt/SDCARD/trimui/res/crossmix-os/bg.png"

CFG="/mnt/SDCARD/Data/romm/config.json"
MSG="RomM Library\n\nNot configured"

if [ -f "$CFG" ]; then
  URL=$(jq -r '.url // ""' "$CFG")
  TOKEN=$(jq -r '.token // ""' "$CFG")
  if [ -n "$URL" ] && [ -n "$TOKEN" ]; then
    CODE=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "$URL/api/platforms" 2>/dev/null)
    if [ "$CODE" = "200" ]; then
      MSG="RomM Library\n\nConnected\n$URL\n\nPress MENU to exit"
    else
      MSG="RomM Library\n\nConnection failed\nHTTP $CODE\n$URL\n\nPress MENU to exit"
    fi
  fi
fi

/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "$BG" -m "$MSG" -k "MENU"
exit 0
