#!/bin/sh
# Basic diagnostics report for the TrimUI Smart Pro.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "${SCRIPT_DIR}/../../lib/crossmix-env.sh"
. "${SCRIPT_DIR}/../../lib/device.sh"

REPORT_FILE="${CROSSMIX_LOG_DIR}/diagnostics-$(date '+%Y%m%d-%H%M%S').txt"

mkdir -p "$CROSSMIX_LOG_DIR"

{
    printf 'CrossMix-OS diagnostics\n'
    printf 'Generated: %s\n\n' "$(date '+%F %T')"

    printf '== Device ==\n'
    printf '%s\n\n' "$CROSSMIX_DEVICE_NAME"

    printf '== Disk ==\n'
    df -h "$CROSSMIX_SDCARD" 2>&1
    printf '\n'

    printf '== Memory ==\n'
    free -m 2>&1
    printf '\n'

    printf '== BIOS directory ==\n'
    if [ -d "${CROSSMIX_SDCARD}/BIOS" ]; then
        find "${CROSSMIX_SDCARD}/BIOS" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort
    else
        printf 'BIOS directory not found.\n'
    fi
    printf '\n'

    printf '== Recent CrossMix log ==\n'
    if [ -f "${CROSSMIX_LOG_DIR}/crossmix.log" ]; then
        tail -n 100 "${CROSSMIX_LOG_DIR}/crossmix.log"
    else
        printf 'No CrossMix log found.\n'
    fi
} > "$REPORT_FILE" 2>&1

printf 'Diagnostics report created:\n%s\n' "$REPORT_FILE"
log_info "Diagnostics report created: $REPORT_FILE"
