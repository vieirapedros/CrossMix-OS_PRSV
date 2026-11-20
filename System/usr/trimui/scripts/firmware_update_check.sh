#!/bin/sh
# Firmware update checker for TrimUI Smart Pro
PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts/:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

CUR_FW=$(cat /etc/version 2>/dev/null)
CUR_REV=$(grep 'DISTRIB_DESCRIPTION' /etc/openwrt_release 2>/dev/null | cut -d '.' -f 3)
CUR_NUM=$(echo "$CUR_FW" | tr -d '.')
[ -z "$CUR_NUM" ] && CUR_NUM=0

INFO="/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh"
FONT="/mnt/SDCARD/Themes/CrossMix - OS/wqy-microhei.ttf"

show() {
  $INFO -m "$1" -fs 14 -k "A B" -ff "$FONT"
}

RELEASE_JSON=$(/mnt/SDCARD/System/bin/curl-aarch64 -s -L \
  "https://api.github.com/repos/trimui/firmware_smartpro/releases/latest")

LATEST_TAG=$(echo "$RELEASE_JSON" | /mnt/SDCARD/System/bin/jq -r '.tag_name // empty')
if [ -z "$LATEST_TAG" ]; then
  show "Nao foi possivel verificar atualizacoes de firmware."
  exit 1
fi

LATEST_VER=$(echo "$LATEST_TAG" | sed 's/^v//; s/-.*//')
LATEST_REV=$(echo "$LATEST_TAG" | sed 's/.*-//')
LATEST_NUM=$(echo "$LATEST_VER" | tr -d '.')

ASSET_URL=$(echo "$RELEASE_JSON" | /mnt/SDCARD/System/bin/jq -r \
  '.assets[] | select(.name | test("^trimui_tg5040_.*_v[0-9.]+\\.zip$")) | .browser_download_url' | head -n 1)

if [ -z "$ASSET_URL" ]; then
  show "Nenhum pacote de firmware compativel encontrado."
  exit 1
fi

if [ "$LATEST_NUM" -le "$CUR_NUM" ]; then
  show "Firmware ja esta atualizado.\n\nAtual: $CUR_FW ($CUR_REV)\nMais recente: $LATEST_VER ($LATEST_REV)"
  exit 0
fi

button=$(show "Firmware $LATEST_VER ($LATEST_REV) disponivel.\n\nAtual: $CUR_FW ($CUR_REV)\n\nA = Baixar e preparar\nB = Cancelar")
[ "$button" != "A" ] && exit 0

mkdir -p /mnt/SDCARD/trimui/firmwares
TMP=/tmp/trimui_fw_update.zip
show "Baixando firmware $LATEST_VER...\nIsso pode levar alguns minutos."
/mnt/SDCARD/System/bin/curl-aarch64 -L -o "$TMP" "$ASSET_URL" || { show "Falha no download."; exit 1; }

show "Extraindo pacote do firmware..."
/mnt/SDCARD/System/bin/7zz x "$TMP" -o"/mnt/SDCARD/trimui/firmwares" -y || { show "Falha na extracao."; rm -f "$TMP"; exit 1; }
rm -f "$TMP"

printf '%s\n%s\n' "$LATEST_VER" "$LATEST_REV" > /mnt/SDCARD/trimui/firmwares/MinFwVersion.txt
sync

button=$(show "Firmware $LATEST_VER preparado.\n\nAo reiniciar, o CrossMix oferecera a atualizacao.\n\nA = Reiniciar agora\nB = Depois")
[ "$button" = "A" ] && /mnt/SDCARD/System/bin/shutdown -r
exit 0
