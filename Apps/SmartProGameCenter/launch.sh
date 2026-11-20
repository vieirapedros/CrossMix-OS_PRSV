#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
BG="/mnt/SDCARD/trimui/res/crossmix-os/bg-info.png"
[ -f "$BG" ] || BG="/mnt/SDCARD/trimui/res/crossmix-os/bg.png"

DATA="/mnt/SDCARD/Data/gamecenter"
mkdir -p "$DATA"
touch "$DATA/favorites.txt" "$DATA/recent.log" "$DATA/playtime.csv"

FAVS=$(grep -c . "$DATA/favorites.txt" 2>/dev/null || echo 0)
LAST=$(tail -n 1 "$DATA/recent.log" 2>/dev/null)
[ -z "$LAST" ] && LAST="No recent games"

MSG="Smart Pro Game Center\n\nFavorites: $FAVS\nLast: $LAST\n\nPress MENU to exit"
/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "$BG" -m "$MSG" -k "MENU"
exit 0
