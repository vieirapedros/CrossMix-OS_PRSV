#!/bin/sh
SDCARD="/mnt/SDCARD"
BIOS="$SDCARD/BIOS"
APP_DIR="/mnt/SDCARD/Apps/BIOSDoctor"
REPORT="$SDCARD/Data/biosdoctor/report.txt"

mkdir -p "$SDCARD/Data/biosdoctor"

: > "$REPORT"

echo "===== BIOS Doctor =====" | tee -a "$REPORT"
echo "Verificando BIOS em: $BIOS" | tee -a "$REPORT"
echo "" | tee -a "$REPORT"

jq -r 'to_entries[] | "\(.key)\t\(.value | join(","))"' "$APP_DIR/bios.json" |
while IFS="$(printf '\t')" read -r system files; do
  echo "[$system]" | tee -a "$REPORT"

  oldIFS="$IFS"
  IFS=','
  for file in $files; do
    if [ -z "$file" ]; then
      continue
    fi

    if find "$BIOS" -type f -iname "$file" 2>/dev/null | grep -q .; then
      echo "  OK: $file" | tee -a "$REPORT"
    else
      echo "  FALTANDO: $file" | tee -a "$REPORT"
    fi
  done
  IFS="$oldIFS"

done

sync
echo ""
echo "Relatorio salvo em: $REPORT"
