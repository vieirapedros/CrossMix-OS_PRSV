#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/../../Data/romm/config.json"

if [ ! -f "$CONFIG" ]; then
    echo "Config not found: $CONFIG"
    exit 1
fi

. "$CONFIG"

if [ -z "${url:-}" ]; then
    echo "RomM URL not configured. Edit $CONFIG"
    exit 1
fi

exec "$SCRIPT_DIR/romm.sh"
