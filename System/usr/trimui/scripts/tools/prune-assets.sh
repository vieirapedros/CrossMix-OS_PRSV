#!/bin/sh
# Move unused theme, icon and background packs to a recoverable trash folder.
# This script does not permanently delete files.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "${SCRIPT_DIR}/../../lib/crossmix-env.sh"
. "${SCRIPT_DIR}/../../lib/device.sh"

TRASH_DIR="${CROSSMIX_SDCARD}/.Trash/assets-$(date '+%Y%m%d-%H%M%S')"

mkdir -p "$TRASH_DIR/Themes" "$TRASH_DIR/Icons" "$TRASH_DIR/Backgrounds"

move_asset() {
    category="$1"
    name="$2"
    source_path="${CROSSMIX_SDCARD}/${category}/${name}"

    if [ -d "$source_path" ]; then
        mv -- "$source_path" "${TRASH_DIR}/${category}/"
        log_info "Moved unused asset to trash: ${category}/${name}"
    fi
}

# Themes kept: Epic Noir.
for theme in \
    'BlazeWind' \
    'Burst!' \
    'Chilltro' \
    'Cozy' \
    'CrossMix - OS' \
    'Fallout - Pipboy' \
    'Greys-Dark' \
    'PSP' \
    'Pokedex - Blue' \
    'Retro Genesis' \
    'Simple Blue' \
    'TRIMUI Blue' \
    'TRIMUI Energy' \
    'TRIMUI HeyDW White' \
    'TRIMUI Retro' \
    'TRIMUI YaHei' \
    'Windows95'
do
    move_asset Themes "$theme"
done

# Icon packs kept: Epic Noir (Controllers) and Default.
for icon_pack in \
    'BlazeWind' \
    'Burst! (Centered)' \
    'Burst! (Tiles)' \
    'Burst!' \
    'Cozy' \
    'Epic Noir (Tile images)' \
    'Fallout - Pipboy' \
    'Greys-Dark' \
    'Pokedex (Flow)' \
    'Pokedex (Grid)' \
    'Windows95' \
    'XMB Automatic'
do
    move_asset Icons "$icon_pack"
done

# Background packs kept: No Backgrounds and Default.
for background in \
    'Burst!' \
    'Epic Noir' \
    'Tronkyfran' \
    'Windows95'
do
    move_asset Backgrounds "$background"
done

printf 'Unused asset packs moved to:\n%s\n' "$TRASH_DIR"
log_info "Asset pruning completed: $TRASH_DIR"
