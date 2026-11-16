#!/bin/sh
# Shared environment for CrossMix-OS scripts.

CROSSMIX_SDCARD="${CROSSMIX_SDCARD:-/mnt/SDCARD}"
CROSSMIX_SYSTEM_DIR="${CROSSMIX_SDCARD}/System"
CROSSMIX_SCRIPTS_DIR="${CROSSMIX_SYSTEM_DIR}/usr/trimui/scripts"
CROSSMIX_LIB_DIR="${CROSSMIX_SYSTEM_DIR}/usr/trimui/lib"
CROSSMIX_LOG_DIR="${CROSSMIX_SDCARD}/Logs"
CROSSMIX_PORTMASTER_DIR="${CROSSMIX_SDCARD}/Apps/PortMaster/PortMaster"
CROSSMIX_RETROARCH_DIR="${CROSSMIX_SDCARD}/RetroArch"

export PATH="${CROSSMIX_SCRIPTS_DIR}:${CROSSMIX_SYSTEM_DIR}/bin:${PM_DIR:-}:${PATH:+:$PATH}"
export LD_LIBRARY_PATH="/usr/trimui/lib:${CROSSMIX_SYSTEM_DIR}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

log_info() {
    printf '[INFO] %s: %s\n' "$(date '+%F %T')" "$1" >> "${CROSSMIX_LOG_DIR}/crossmix.log"
}

log_warn() {
    printf '[WARN] %s: %s\n' "$(date '+%F %T')" "$1" >> "${CROSSMIX_LOG_DIR}/crossmix.log"
}

log_error() {
    printf '[ERROR] %s: %s\n' "$(date '+%F %T')" "$1" >> "${CROSSMIX_LOG_DIR}/crossmix.log"
}

require_file() {
    if [ ! -f "$1" ]; then
        log_error "Required file not found: $1"
        return 1
    fi
}

require_directory() {
    if [ ! -d "$1" ]; then
        log_error "Required directory not found: $1"
        return 1
    fi
}

run_button_state() {
    button="$1"
    "${CROSSMIX_SCRIPTS_DIR}/button_state.sh" "$button"
}
