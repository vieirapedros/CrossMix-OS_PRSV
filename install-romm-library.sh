#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/vieirapedros/CrossMix-OS_PRSV/main"
TARGET="${1:-}"

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

mkdir -p "$TARGET/Apps/RomMLibrary/lib" "$TARGET/Data/romm/cache/covers" "$TARGET/Data/romm/cache/metadata"

echo "Baixando arquivos do RomMLibrary..."
curl -fsSL "$REPO_RAW/Apps/RomMLibrary/launch.sh" -o "$TARGET/Apps/RomMLibrary/launch.sh"
curl -fsSL "$REPO_RAW/Apps/RomMLibrary/romm.sh" -o "$TARGET/Apps/RomMLibrary/romm.sh"
curl -fsSL "$REPO_RAW/Apps/RomMLibrary/lib/api.sh" -o "$TARGET/Apps/RomMLibrary/lib/api.sh"
curl -fsSL "$REPO_RAW/Apps/RomMLibrary/lib/browse.sh" -o "$TARGET/Apps/RomMLibrary/lib/browse.sh"
curl -fsSL "$REPO_RAW/Apps/RomMLibrary/lib/download.sh" -o "$TARGET/Apps/RomMLibrary/lib/download.sh"
curl -fsSL "$REPO_RAW/Apps/RomMLibrary/config.json" -o "$TARGET/Apps/RomMLibrary/config.json"
curl -fsSL "$REPO_RAW/Apps/RomMLibrary/README.md" -o "$TARGET/Apps/RomMLibrary/README.md"

ICON_SOURCE=""
for candidate in "$TARGET/Apps/MusicPlayer/icon.png" "$TARGET/Apps/Reboot/icon.png"; do
    if [ -f "$candidate" ]; then
        ICON_SOURCE="$candidate"
        break
    fi
done

if [ -n "$ICON_SOURCE" ] && [ ! -f "$TARGET/Apps/RomMLibrary/icon.png" ]; then
    cp "$ICON_SOURCE" "$TARGET/Apps/RomMLibrary/icon.png"
fi

if [ ! -f "$TARGET/Data/romm/config.json" ]; then
    cat > "$TARGET/Data/romm/config.json" <<'EOF'
{
  "url": "https://nas.tail729de1.ts.net:8444",
  "token": "",
  "download_dir": "/mnt/SDCARD/Roms",
  "cache_dir": "/mnt/SDCARD/Data/romm/cache"
}
EOF
fi

chmod +x "$TARGET/Apps/RomMLibrary/launch.sh" \
    "$TARGET/Apps/RomMLibrary/romm.sh" \
    "$TARGET/Apps/RomMLibrary/lib/api.sh" \
    "$TARGET/Apps/RomMLibrary/lib/download.sh" \
    "$TARGET/Apps/RomMLibrary/lib/browse.sh" 2>/dev/null || true

sync 2>/dev/null || true

echo "RomM Library instalado em: $TARGET/Apps/RomMLibrary"
echo "Configure URL e token em: $TARGET/Data/romm/config.json"
