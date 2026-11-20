#!/bin/sh
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$APP_DIR/lib/api.sh"
. "$APP_DIR/lib/download.sh"

CONFIG="$APP_DIR/config.json"

romm_menu() {
  while :; do
    echo ""
    echo "=============================="
    echo " RomM Library - Smart Pro"
    echo "=============================="
    echo "1) Test connection"
    echo "2) List platforms"
    echo "3) Search ROMs"
    echo "4) Download ROM by ID"
    echo "5) Show configuration"
    echo "0) Exit"
    printf "Option: "
    read -r choice
    case "$choice" in
      1) romm_test "$CONFIG" ;;
      2) romm_platforms "$CONFIG" ;;
      3)
        printf "Search term: "
        read -r term
        romm_search "$CONFIG" "$term"
        ;;
      4)
        printf "ROM ID: "
        read -r rom_id
        romm_download "$CONFIG" "$rom_id"
        ;;
      5) cat "$CONFIG" ;;
      0) exit 0 ;;
      *) echo "Invalid option" ;;
    esac
  done
}

romm_menu
