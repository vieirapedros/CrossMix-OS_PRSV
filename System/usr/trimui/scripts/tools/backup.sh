#!/bin/sh
# Create a versioned backup of saves and important CrossMix configurations.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "${SCRIPT_DIR}/../../lib/crossmix-env.sh"
. "${SCRIPT_DIR}/../../lib/device.sh"

BACKUP_ROOT="${CROSSMIX_SDCARD}/Backups"
BACKUP_DIR="${BACKUP_ROOT}/crossmix-$(date '+%Y%m%d-%H%M%S')"
RETROARCH_DIR="${CROSSMIX_SDCARD}/RetroArch"

mkdir -p "$BACKUP_DIR"

backup_path() {
    source_path="$1"
    destination_name="$2"

    if [ ! -e "$source_path" ]; then
        log_warn "Backup source not found: $source_path"
        return 0
    fi

    tar -czf "${BACKUP_DIR}/${destination_name}.tar.gz" -C "$(dirname "$source_path")" "$(basename "$source_path")" 2>>"${CROSSMIX_LOG_DIR}/crossmix.log"
}

backup_path "${RETROARCH_DIR}/saves" "retroarch-saves"
backup_path "${RETROARCH_DIR}/states" "retroarch-states"
backup_path "${RETROARCH_DIR}/config" "retroarch-config"
backup_path "${CROSSMIX_SDCARD}/Themes" "themes"
backup_path "${CROSSMIX_SDCARD}/Data" "crossmix-data"

printf 'Backup created:\n%s\n' "$BACKUP_DIR"
log_info "Backup created: $BACKUP_DIR"
