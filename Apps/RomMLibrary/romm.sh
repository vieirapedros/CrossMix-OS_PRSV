#!/bin/sh
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$APP_DIR/lib/api.sh"
. "$APP_DIR/lib/download.sh"

CONFIG="/mnt/SDCARD/Data/romm/config.json"

if [ ! -f "$CONFIG" ]; then
  echo "RomM nao configurado."
  echo "Crie o arquivo: $CONFIG"
  read -r dummy
  exit 1
fi

romm_menu() {
  while :; do
    echo ""
    echo "=============================="
    echo " RomM Library - Smart Pro"
    echo "=============================="
    echo "1) Test connection"
    echo "2) List platforms"
    echo "3) Search ROMs"
    echo "4) Browse platforms and download"
    echo "5) Download ROM by ID"
    echo "6) Show configuration"
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
      4) romm_browse "$CONFIG" ;;
      5)
        printf "ROM ID: "
        read -r rom_id
        romm_download "$CONFIG" "$rom_id"
        ;;
      6) cat "$CONFIG" ;;
      0) exit 0 ;;
      *) echo "Invalid option" ;;
    esac
  done
}

romm_menu
