#!/bin/sh
SDCARD="/mnt/SDCARD"
THEMES="$SDCARD/Themes"
SYSTEM_JSON="/mnt/UDISK/system.json"
BACKUP="$SDCARD/Data/theme-switcher/system.json.backup"

mkdir -p "$(dirname "$BACKUP")"

if [ ! -f "$SYSTEM_JSON" ]; then
  echo "system.json nao encontrado."
  exit 1
fi

cp "$SYSTEM_JSON" "$BACKUP"

echo "===== Theme Switcher ====="
echo "Tema atual: $(jq -r '.theme // "desconhecido"' "$SYSTEM_JSON")"
echo ""

echo "Temas disponiveis:"
i=1
for theme in "$THEMES"/*/; do
  name="$(basename "$theme")"
  echo "$i) $name"
  i=$((i + 1))
done

printf "Numero do tema: "
read -r choice

selected="$(find "$THEMES" -mindepth 1 -maxdepth 1 -type d | sed -n "${choice}p")"

if [ -z "$selected" ]; then
  echo "Tema invalido."
  exit 1
fi

name="$(basename "$selected")"
tmp="$(mktemp)"
jq --arg theme "$selected" '.theme = $theme' "$SYSTEM_JSON" > "$tmp"
mv "$tmp" "$SYSTEM_JSON"
sync

echo "Tema alterado para: $name"
echo "Backup salvo em: $BACKUP"
echo "Reinicie o console para aplicar completamente."
