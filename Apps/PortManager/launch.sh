#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
BG="/mnt/SDCARD/trimui/res/crossmix-os/bg-info.png"
[ -f "$BG" ] || BG="/mnt/SDCARD/trimui/res/crossmix-os/bg.png"

PORTS="/mnt/SDCARD/Roms/PORTS"
mkdir -p "$PORTS"

COUNT=$(find "$PORTS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
LIST=$(find "$PORTS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's|.*/||' | head -n 5)
[ -z "$LIST" ] && LIST="No ports installed"

MSG="Port Manager\n\nInstalled: $COUNT\n\n$LIST\n\nPress MENU to exit"
/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "$BG" -m "$MSG" -k "MENU"
exit 0
