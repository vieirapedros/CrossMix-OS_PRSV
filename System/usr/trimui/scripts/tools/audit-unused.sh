#!/bin/sh
# Audit potentially unused emulators, applications and themes.
# This tool only creates a report; it does not remove any file.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "${SCRIPT_DIR}/../../lib/crossmix-env.sh"
. "${SCRIPT_DIR}/../../lib/device.sh"

REPORT_FILE="${CROSSMIX_LOG_DIR}/audit-unused-$(date '+%Y%m%d-%H%M%S').txt"
SEARCH_ROOTS="${CROSSMIX_SYSTEM_DIR}/usr/trimui ${CROSSMIX_SDCARD}/Emus ${CROSSMIX_SDCARD}/Apps ${CROSSMIX_SDCARD}/Themes"

mkdir -p "$CROSSMIX_LOG_DIR"

{
    printf 'CrossMix-OS unused-reference audit\n'
    printf 'Generated: %s\n' "$(date '+%F %T')"
    printf 'Device: %s\n\n' "$CROSSMIX_DEVICE_NAME"

    audit_directory() {
        base_dir="$1"
        label="$2"

        printf '== %s ==\n' "$label"

        if [ ! -d "$base_dir" ]; then
            printf 'Directory not found: %s\n\n' "$base_dir"
            return
        fi

        find "$base_dir" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r item; do
            name=$(basename "$item")
            case "$name" in
                _*) continue ;;
            esac

            references=$(grep -R -F -l -- "$name" $SEARCH_ROOTS 2>/dev/null | grep -v -F "$item" | wc -l)

            if [ "$references" -eq 0 ]; then
                printf 'NO REFERENCES: %s\n' "$name"
            fi
        done

        printf '\n'
    }

    audit_directory "${CROSSMIX_SDCARD}/Emus" "Emulators"
    audit_directory "${CROSSMIX_SDCARD}/Apps" "Applications"
    audit_directory "${CROSSMIX_SDCARD}/Themes" "Themes"

    printf 'This report is informational only.\n'
    printf 'Review launchers, RetroArch configurations, BIOS requirements and ROM folders before removing anything.\n'
} > "$REPORT_FILE" 2>&1

printf 'Audit report created:\n%s\n' "$REPORT_FILE"
log_info "Unused-reference audit created: $REPORT_FILE"
