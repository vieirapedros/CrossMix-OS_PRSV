#!/bin/sh
APP_DIR="/mnt/SDCARD/Apps/RomMLibrary"
TERMINAL="/mnt/SDCARD/Apps/Terminal/launch.sh"

if [ -x "$TERMINAL" ]; then
  exec "$TERMINAL" "$APP_DIR/romm.sh"
fi

exec "$APP_DIR/romm.sh"
