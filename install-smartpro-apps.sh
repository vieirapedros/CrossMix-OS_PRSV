#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"

APPS=(
  RomMLibrary
  SmartProGameCenter
  PortManager
  BIOSDoctor
  WiFiTools
  BatteryGuard
  ThemeSwitcher
)

if [ -z "$TARGET" ]; then
  read -rp "Caminho do cartao SD montado: " TARGET
fi

TARGET="${TARGET%/}"

if [ ! -d "$TARGET" ]; then
  echo "Erro: $TARGET nao existe."
  exit 1
fi

if [ ! -d "$TARGET/Apps" ]; then
  read -rp "$TARGET nao parece ser um cartao CrossMix. Continuar mesmo assim? [y/N] " answer
  case "$answer" in
    [yY]*) ;;
    *) exit 1 ;;
  esac
fi

mkdir -p "$TARGET/Data/romm/cache/covers" "$TARGET/Data/romm/cache/metadata" \
  "$TARGET/Data/gamecenter" "$TARGET/Data/portmanager" \
  "$TARGET/Data/biosdoctor" "$TARGET/Data/batteryguard" \
  "$TARGET/Data/theme-switcher"

for app in "${APPS[@]}"; do
  if [ ! -d "$REPO_ROOT/Apps/$app" ]; then
    echo "Aviso: $app nao encontrado no repositorio."
    continue
  fi

  mkdir -p "$TARGET/Apps/$app"
  cp -a "$REPO_ROOT/Apps/$app/." "$TARGET/Apps/$app/"

  find "$TARGET/Apps/$app" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
  echo "Instalado: $app"
done

sync 2>/dev/null || true

echo ""
echo "Instalacao concluida em: $TARGET"
echo "Configure RomM em: $TARGET/Apps/RomMLibrary/config.json"
