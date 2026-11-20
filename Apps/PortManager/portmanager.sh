#!/bin/sh
SDCARD="/mnt/SDCARD"
PORTS="$SDCARD/Roms/PORTS"
DATA="$SDCARD/Data/portmanager"

mkdir -p "$PORTS" "$DATA"

while :; do
  echo ""
  echo "===== Port Manager ====="
  echo "1) Listar ports instalados"
  echo "2) Instalar port de uma pasta"
  echo "3) Instalar port de um arquivo .zip"
  echo "4) Remover port"
  echo "0) Sair"
  printf "Opcao: "
  read -r choice

  case "$choice" in
    1)
      echo "--- Ports instalados ---"
      find "$PORTS" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null || \
        find "$PORTS" -mindepth 1 -maxdepth 1 -type d | sed 's|.*/||'
      ;;
    2)
      printf "Caminho da pasta do port: "
      read -r source
      if [ -d "$source" ]; then
        name="$(basename "$source")"
        cp -a "$source" "$PORTS/$name"
        sync
        echo "Port instalado: $name"
      else
        echo "Pasta invalida."
      fi
      ;;
    3)
      printf "Caminho do arquivo .zip: "
      read -r zipfile
      if [ -f "$zipfile" ] && command -v unzip >/dev/null 2>&1; then
        name="$(basename "$zipfile" .zip)"
        mkdir -p "$PORTS/$name"
        unzip -o "$zipfile" -d "$PORTS/$name"
        sync
        echo "Port instalado: $name"
      else
        echo "Arquivo invalido ou unzip nao disponivel."
      fi
      ;;
    4)
      printf "Nome do port: "
      read -r name
      if [ -d "$PORTS/$name" ]; then
        mv "$PORTS/$name" "$SDCARD/.Trash/PortManager_$name_$(date +%s)" 2>/dev/null || true
        sync
        echo "Port movido para a lixeira."
      else
        echo "Port nao encontrado."
      fi
      ;;
    0) exit 0 ;;
    *) echo "Opcao invalida" ;;
  esac
done
