#!/bin/sh
# RomM Library para JukaMix / CrossMix OS (aba Apps).
# Navega e baixa jogos do seu servidor RomM (ex.: via Tailscale) direto para Roms/.

ROMM_SDCARD=${ROMM_SDCARD:-/mnt/SDCARD}
export ROMM_SDCARD

APP_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
[ -f "$APP_DIR/lib/common.sh" ] || APP_DIR="$ROMM_SDCARD/Apps/RomMLibrary"
export APP_DIR

# Rastro de inicializacao: se o app "nao abre", System/logs/romm_library.log mostra ate onde chegou.
LOGF="$ROMM_SDCARD/System/logs/romm_library.log"
mkdir -p "$ROMM_SDCARD/System/logs" 2>/dev/null
printf '%s launch.sh iniciou (pid %s, dir %s)\n' "$(date '+%F %T')" "$$" "$APP_DIR" >>"$LOGF" 2>/dev/null
exec 2>>"$LOGF"

PATH="$ROMM_SDCARD/System/bin:$ROMM_SDCARD/System/usr/trimui/scripts:$PATH"
LD_LIBRARY_PATH="$ROMM_SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH LD_LIBRARY_PATH

for _lib in i18n common net platforms download screens; do
  if [ -f "$APP_DIR/lib/$_lib.sh" ]; then
    . "$APP_DIR/lib/$_lib.sh"
  else
    printf '%s faltando lib/%s.sh\n' "$(date '+%F %T')" "$_lib" >>"$LOGF" 2>/dev/null
    "$ROMM_SDCARD/System/usr/trimui/scripts/infoscreen.sh" -m "RomM Library: arquivo faltando (lib/$_lib.sh)" -t 3 >/dev/null 2>&1
    exit 1
  fi
done

log_rotate
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

app_main
_rc=$?
log "launch.sh terminou (rc $_rc)"
exit "$_rc"
