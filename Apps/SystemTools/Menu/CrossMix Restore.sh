#!/bin/sh
# Guided restore entry for CrossMix backups.

export LD_LIBRARY_PATH="./lib:/mnt/SDCARD/System/lib:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:${PATH:+:$PATH}"

RESTORE_TOOL="/mnt/SDCARD/System/usr/trimui/scripts/tools/restore.sh"
BACKUP_ROOT="/mnt/SDCARD/Backups"

if [ ! -d "$BACKUP_ROOT" ]; then
    infoscreen.sh -m "No CrossMix backups found."
    exit 0
fi

backup_selection=$(selector -fs 150 -t "Choose a CrossMix backup:" -d "$BACKUP_ROOT")

case "$backup_selection" in
    *"No file selected"*|"")
        infoscreen.sh -m "Restore cancelled."
        exit 0
        ;;
esac

BACKUP_DIR="${backup_selection#*: }"

if [ ! -d "$BACKUP_DIR" ]; then
    infoscreen.sh -m "Invalid backup directory."
    exit 1
fi

component_selection=$(selector -fs 200 -t "Choose what to restore:                           (B to cancel)" -c "Saves" "Save states" "RetroArch config" "Themes" "CrossMix data")

case "$component_selection" in
    *"No file selected"*|"")
        infoscreen.sh -m "Restore cancelled."
        exit 0
        ;;
    "Saves") COMPONENT="saves" ;;
    "Save states") COMPONENT="states" ;;
    "RetroArch config") COMPONENT="config" ;;
    "Themes") COMPONENT="themes" ;;
    "CrossMix data") COMPONENT="data" ;;
    *)
        infoscreen.sh -m "Invalid component."
        exit 1
        ;;
esac

confirm_selection=$(selector -fs 200 -t "Restore $COMPONENT from this backup?" -c "Yes" "No")

case "$confirm_selection" in
    *"Yes") ;;
    *)
        infoscreen.sh -m "Restore cancelled."
        exit 0
        ;;
esac

"$RESTORE_TOOL" "$BACKUP_DIR" "$COMPONENT"

if [ $? -eq 0 ]; then
    infoscreen.sh -m "$COMPONENT restored successfully." -t 2
else
    infoscreen.sh -m "Restore failed. Check /mnt/SDCARD/Logs/crossmix.log." -t 3
fi

sync
