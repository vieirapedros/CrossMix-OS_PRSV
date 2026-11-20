#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
BG="/mnt/SDCARD/trimui/res/crossmix-os/bg-info.png"
[ -f "$BG" ] || BG="/mnt/SDCARD/trimui/res/crossmix-os/bg.png"

CAP=""
for SUPPLY in /sys/class/power_supply/*; do
  if [ -f "$SUPPLY/capacity" ]; then
    CAP=$(cat "$SUPPLY/capacity" 2>/dev/null)
    break
  fi
done

[ -z "$CAP" ] && CAP="unknown"
LOG="/mnt/SDCARD/Data/batteryguard/battery.log"
mkdir -p "$(dirname "$LOG")"
echo "$(date +%Y-%m-%d_%H:%M:%S),$CAP" >> "$LOG"
sync

MSG="Battery Guard\n\nBattery: $CAP%\n\nLog: $LOG\n\nPress MENU to exit"
/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "$BG" -m "$MSG" -k "MENU"
exit 0
