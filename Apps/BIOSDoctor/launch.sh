#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
BG="/mnt/SDCARD/trimui/res/crossmix-os/bg-info.png"
[ -f "$BG" ] || BG="/mnt/SDCARD/trimui/res/crossmix-os/bg.png"

sh /mnt/SDCARD/Apps/BIOSDoctor/biosdoctor.sh >/dev/null 2>&1
REPORT="/mnt/SDCARD/Data/biosdoctor/report.txt"
MISSING=$(grep -c 'FALTANDO' "$REPORT" 2>/dev/null || echo 0)
OK=$(grep -c 'OK:' "$REPORT" 2>/dev/null || echo 0)

MSG="BIOS Doctor\n\nOK: $OK\nMissing: $MISSING\n\nReport:\n$REPORT\n\nPress MENU to exit"
/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "$BG" -m "$MSG" -k "MENU"
exit 0
