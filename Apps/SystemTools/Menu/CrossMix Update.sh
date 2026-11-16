#!/bin/sh
# Check for and apply a CrossMix update from GitHub Releases.

export LD_LIBRARY_PATH="./lib:/mnt/SDCARD/System/lib:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:${PATH:+:$PATH}"

UPDATE_TOOL="/mnt/SDCARD/System/usr/trimui/scripts/tools/update.sh"

confirm_selection=$(selector -fs 200 -t "Check for CrossMix updates?" -c "Yes" "No")

case "$confirm_selection" in
    *"Yes") ;;
    *)
        infoscreen.sh -m "Update cancelled."
        exit 0
        ;;
esac

infoscreen.sh -m "Checking for updates..."

"$UPDATE_TOOL"

if [ $? -eq 0 ]; then
    infoscreen.sh -m "CrossMix update applied successfully." -t 2
else
    infoscreen.sh -m "Update failed. Check /mnt/SDCARD/Logs/crossmix.log." -t 3
fi

sync
