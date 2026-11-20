#!/bin/sh
# Navegador RomM: plataformas, ROMs e download

CONFIG="${1:-/mnt/SDCARD/Data/romm/config.json}"
. "$(dirname "$0")/api.sh"
. "$(dirname "$0")/download.sh"

romm_browse() {
  echo "===== Plataformas ====="
  romm_platforms "$CONFIG"

  printf "\nID da plataforma: "
  read -r platform_id
  [ -z "$platform_id" ] && return 0

  echo "===== ROMs ====="
  romm_request "$CONFIG" "/api/roms?platform_id=$platform_id" |
    jq -r '.[] | "\(.id)\t\(.name // .file_name)"' | head -n 50

  printf "\nID da ROM para baixar (vazio para sair): "
  read -r rom_id
  [ -z "$rom_id" ] && return 0

  romm_download "$CONFIG" "$rom_id"
}

romm_browse
