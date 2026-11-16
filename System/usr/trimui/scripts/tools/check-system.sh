#!/bin/sh
# Local integrity check for the TrimUI Smart Pro CrossMix installation.
# This tool does not download anything or modify system files.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "${SCRIPT_DIR}/../../lib/crossmix-env.sh"
. "${SCRIPT_DIR}/../../lib/device.sh"

REPORT_FILE="${CROSSMIX_LOG_DIR}/system-check-$(date '+%Y%m%d-%H%M%S').txt"
ISSUES=0

mkdir -p "$CROSSMIX_LOG_DIR"

check_directory() {
    path="$1"
    label="$2"

    if [ -d "$path" ]; then
        printf 'OK: %s\n' "$label"
    else
        printf 'MISSING: %s (%s)\n' "$label" "$path"
        ISSUES=$((ISSUES + 1))
    fi
}

check_file() {
    path="$1"
    label="$2"

    if [ -f "$path" ]; then
        printf 'OK: %s\n' "$label"
    else
        printf 'MISSING: %s (%s)\n' "$label" "$path"
        ISSUES=$((ISSUES + 1))
    fi
}

check_script_permissions() {
    printf '== Script permissions ==\n'

    find "${CROSSMIX_SCRIPTS_DIR}" -type f -name '*.sh' | while IFS= read -r script; do
        if [ ! -x "$script" ]; then
            printf 'NOT EXECUTABLE: %s\n' "$script"
        fi
    done

    printf '\n'
}

{
    printf 'CrossMix-OS local system check\n'
    printf 'Generated: %s\n' "$(date '+%F %T')"
    printf 'Device: %s\n\n' "$CROSSMIX_DEVICE_NAME"

    printf '== Essential directories ==\n'
    check_directory "$CROSSMIX_SDCARD" "SD card root"
    check_directory "$CROSSMIX_SYSTEM_DIR" "System directory"
    check_directory "$CROSSMIX_SCRIPTS_DIR" "Scripts directory"
    check_directory "${CROSSMIX_SDCARD}/Emus" "Emulators directory"
    check_directory "${CROSSMIX_SDCARD}/RetroArch" "RetroArch directory"
    check_directory "${CROSSMIX_SDCARD}/BIOS" "BIOS directory"
    check_directory "${CROSSMIX_SDCARD}/Roms" "ROMs directory"
    check_directory "${CROSSMIX_SDCARD}/Apps" "Applications directory"
    printf '\n'

    printf '== Essential files ==\n'
    check_file "${CROSSMIX_SCRIPTS_DIR}/common_launcher.sh" "Common launcher"
    check_file "${CROSSMIX_SCRIPTS_DIR}/button_state.sh" "Button state helper"
    check_file "${CROSSMIX_SCRIPTS_DIR}/save_launcher.sh" "Save launcher"
    check_file "${CROSSMIX_LIB_DIR}/crossmix-env.sh" "Shared environment library"
    check_file "${CROSSMIX_LIB_DIR}/rom-path.sh" "ROM path library"
    check_file "${CROSSMIX_LIB_DIR}/device.sh" "Device scope library"
    printf '\n'

    check_script_permissions

    printf '== Result ==\n'
    if [ "$ISSUES" -eq 0 ]; then
        printf 'No missing essential directories or files were found.\n'
    else
        printf '%d essential item(s) are missing.\n' "$ISSUES"
    fi

    printf '\nThis check does not validate BIOS files, ROM compatibility or emulator binaries.\n'
} > "$REPORT_FILE" 2>&1

printf 'System check report created:\n%s\n' "$REPORT_FILE"
log_info "Local system check created: $REPORT_FILE"
