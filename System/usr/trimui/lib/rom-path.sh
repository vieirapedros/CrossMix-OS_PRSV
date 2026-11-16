#!/bin/sh
# ROM path helpers for CrossMix-OS launchers.

resolve_rom_path() {
    rom_input="$1"

    if [ -z "$rom_input" ]; then
        log_error "No ROM path was provided"
        return 1
    fi

    if [ ! -f "$rom_input" ]; then
        log_error "ROM file not found: $rom_input"
        return 1
    fi

    ROM_REAL_PATH=$(realpath -- "$rom_input")
    ROM_FILENAME=$(basename -- "$rom_input")
    ROM_FILENAME_NOEXT=${ROM_FILENAME%.*}

    case "$rom_input" in
        /tmp/folderspoof/*)
            ROM_DIR=$(dirname -- "$rom_input")
            ;;
        *)
            ROM_DIR=$(printf '%s' "$rom_input" | sed -E 's|(.*Roms/[^/]+)/.*|\1|')
            ;;
    esac
}

resolve_emulator_dir() {
    launcher_path="$1"
    EMU_DIR=$(printf '%s' "$launcher_path" | sed -E 's|(.*Emus/[^/]+)/.*|\1|')

    if [ ! -d "$EMU_DIR" ]; then
        log_error "Emulator directory not found: $EMU_DIR"
        return 1
    fi
}
