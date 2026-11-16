#!/bin/sh
# Restore saves, states, configurations, themes or CrossMix data
# from a versioned backup created by backup.sh.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "${SCRIPT_DIR}/../../lib/crossmix-env.sh"
. "${SCRIPT_DIR}/../../lib/device.sh"

BACKUP_ROOT="${CROSSMIX_SDCARD}/Backups"
RETROARCH_DIR="${CROSSMIX_SDCARD}/RetroArch"

usage() {
    printf 'Usage: %s <backup-directory> <component>\n' "$0"
    printf '\n'
    printf 'Components:\n'
    printf '  saves       Restore RetroArch saves\n'
    printf '  states      Restore RetroArch save states\n'
    printf '  config      Restore RetroArch configuration\n'
    printf '  themes      Restore themes\n'
    printf '  data        Restore CrossMix data\n'
    printf '\n'
    printf 'Example:\n'
    printf '  %s /mnt/SDCARD/Backups/crossmix-20260101-120000 saves\n' "$0"
}

if [ "$#" -ne 2 ]; then
    usage
    exit 1
fi

BACKUP_DIR="$1"
COMPONENT="$2"

if [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup directory not found: $BACKUP_DIR"
    exit 1
fi

case "$COMPONENT" in
    saves)
        ARCHIVE="${BACKUP_DIR}/retroarch-saves.tar.gz"
        DESTINATION="${RETROARCH_DIR}/saves"
        ;;
    states)
        ARCHIVE="${BACKUP_DIR}/retroarch-states.tar.gz"
        DESTINATION="${RETROARCH_DIR}/states"
        ;;
    config)
        ARCHIVE="${BACKUP_DIR}/retroarch-config.tar.gz"
        DESTINATION="${RETROARCH_DIR}/config"
        ;;
    themes)
        ARCHIVE="${BACKUP_DIR}/themes.tar.gz"
        DESTINATION="${CROSSMIX_SDCARD}/Themes"
        ;;
    data)
        ARCHIVE="${BACKUP_DIR}/crossmix-data.tar.gz"
        DESTINATION="${CROSSMIX_SDCARD}/Data"
        ;;
    *)
        log_error "Unknown component: $COMPONENT"
        usage
        exit 1
        ;;
esac

if [ ! -f "$ARCHIVE" ]; then
    log_error "Backup archive not found: $ARCHIVE"
    exit 1
fi

SAFETY_BACKUP="${BACKUP_ROOT}/pre-restore-$(date '+%Y%m%d-%H%M%S')-${COMPONENT}.tar.gz"

if [ -e "$DESTINATION" ]; then
    mkdir -p "$BACKUP_ROOT"
    tar -czf "$SAFETY_BACKUP" \
        -C "$(dirname "$DESTINATION")" \
        "$(basename "$DESTINATION")" \
        2>>"${CROSSMIX_LOG_DIR}/crossmix.log"

    if [ $? -ne 0 ]; then
        log_error "Failed to create safety backup: $SAFETY_BACKUP"
        exit 1
    fi

    log_info "Safety backup created: $SAFETY_BACKUP"
fi

mkdir -p "$DESTINATION"

tar -xzf "$ARCHIVE" -C "$(dirname "$DESTINATION")" \
    2>>"${CROSSMIX_LOG_DIR}/crossmix.log"

if [ $? -ne 0 ]; then
    log_error "Failed to restore archive: $ARCHIVE"
    exit 1
fi

printf 'Restored %s from:\n%s\n' "$COMPONENT" "$ARCHIVE"
log_info "Restored $COMPONENT from $ARCHIVE"
