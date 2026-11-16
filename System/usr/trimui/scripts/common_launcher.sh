#!/bin/sh
# Common launcher for CrossMix-OS.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "${SCRIPT_DIR}/../lib/crossmix-env.sh"
. "${SCRIPT_DIR}/../lib/rom-path.sh"

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

print_blue() {
    printf "${BLUE}%s${RESET}\n" "$1"
}

print_var() {
    printf "${GREEN}%-20s${RESET}: %s\n" "$1" "$2"
}

print_blue "$0 $*"
PM_DIR="${CROSSMIX_PORTMASTER_DIR}"

if [ -z "$1" ]; then
    log_error "Usage: $0 <rom-path> [extra-argument]"
    exit 1
fi

resolve_rom_path "$1" || exit 1
resolve_emulator_dir "$0" || exit 1

printf "\n"
print_blue "=== ROM Information ==="
print_var "ROM_REAL_PATH" "$ROM_REAL_PATH"
print_var "ROM_DIR" "$ROM_DIR"
print_var "ROM_FILENAME" "$ROM_FILENAME"
print_var "ROM_FILENAME_NOEXT" "$ROM_FILENAME_NOEXT"
print_var "EMU_DIR" "$EMU_DIR"
print_blue "======================="

run_button_state A
if [ $? -eq 10 ]; then
    if ! pgrep -f "activities gui"; then
        "${CROSSMIX_SYSTEM_DIR}/bin/activities" gui "$1"
        exit 0
    fi
fi

run_button_state Y
if [ $? -eq 10 ]; then
    . "${CROSSMIX_SCRIPTS_DIR}/romscripts/.romscript_launcher.sh"
    exit
fi

. "${CROSSMIX_SCRIPTS_DIR}/save_launcher.sh"

if [ -z "$2" ]; then
    "${CROSSMIX_SYSTEM_DIR}/bin/activities" time "$1" $$ &
fi

if grep -q ra64.trimui "$0"; then
    export PATH="${PATH}:${CROSSMIX_RETROARCH_DIR}"
    . "${CROSSMIX_SCRIPTS_DIR}/FolderOverrideFinder.sh"
    "${CROSSMIX_SCRIPTS_DIR}/ra_audio_switcher.sh"
    touch /var/trimui_inputd/ra_hotkey
fi

cd "$EMU_DIR"
