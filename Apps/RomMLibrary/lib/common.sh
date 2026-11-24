#!/bin/sh
# RomM Library - common.sh: caminhos, log, config e UI. Carregado por launch.sh.
# Regras: POSIX sh (BusyBox ash), sem "local", sem arrays, sem /bin/bash.

NL='
'
US=$(printf '\037')
TAB=$(printf '\t')

SDCARD=${ROMM_SDCARD:-/mnt/SDCARD}
BIN_DIR="$SDCARD/System/bin"
SCRIPTS_DIR="$SDCARD/System/usr/trimui/scripts"
ROMS_DIR="$SDCARD/Roms"
LOGS_DIR="$SDCARD/System/logs"
DATA_DIR="$SDCARD/Data/romm"
DL_DIR="$DATA_DIR/dl"   # lista dos arquivos de cada jogo baixado (<id>.lst), usada para excluir
CFG="$DATA_DIR/config.json"
LOG="$LOGS_DIR/romm_library.log"
TS_BIN="$BIN_DIR/tailscale"
SELECTOR="$BIN_DIR/selector"
VKEYBOARD="$BIN_DIR/VirtualKeyboard"
INFOSCREEN="$SCRIPTS_DIR/infoscreen.sh"

TMPD="/tmp/rommlib.$$"
STAY_AWAKE=""
DL_PID=""

pick_bin() { # nome... -> caminho do primeiro que existir (System/bin, depois PATH)
  for _pb in "$@"; do
    if [ -x "$BIN_DIR/$_pb" ]; then printf '%s' "$BIN_DIR/$_pb"; return 0; fi
  done
  for _pb in "$@"; do
    _pp=$(command -v "$_pb" 2>/dev/null) && [ -n "$_pp" ] && { printf '%s' "$_pp"; return 0; }
  done
  return 1
}
JQ=$(pick_bin jq)
CURL=$(pick_bin curl-aarch64 curl)
SEVENZ=$(pick_bin 7zz 7z)

# ---------------------------------------------------------------- log
log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG" 2>/dev/null; }

log_rotate() {
  [ -f "$LOG" ] || return 0
  _lr=$(wc -c <"$LOG" 2>/dev/null | tr -d ' ')
  [ "${_lr:-0}" -gt 262144 ] && mv -f "$LOG" "$LOG.1" 2>/dev/null
  return 0
}

# ---------------------------------------------------------------- tmp / limpeza
tmp_init() {
  rm -rf "$TMPD"
  (umask 077; mkdir -p "$TMPD")
}

cleanup() {
  [ -n "$DL_PID" ] && kill "$DL_PID" 2>/dev/null
  [ -n "$STAY_AWAKE" ] && rm -f /tmp/stay_awake
  rm -rf "$TMPD"
}

# ---------------------------------------------------------------- utilidades
fsize() {
  [ -f "$1" ] || { printf '0'; return 0; }
  _fs=$(wc -c <"$1" 2>/dev/null | tr -d ' ')
  printf '%s' "${_fs:-0}"
}

fmt_size() { # bytes -> "12.3 MB"
  awk -v b="${1:-0}" 'BEGIN{
    if (b >= 1073741824) printf "%.2f GB", b/1073741824;
    else if (b >= 1048576) printf "%.1f MB", b/1048576;
    else if (b >= 1024) printf "%.0f KB", b/1024;
    else printf "%d B", b }'
}

urlenc() { "$JQ" -rn --arg s "$1" '$s|@uri'; }

# nome seguro para FAT/exFAT: sem / \ : * ? " < > | nem controles; sem ponto/espaco nas pontas
dl_sanitize() {
  _sn=$(printf '%s' "$1" | tr -d '\000-\037' | tr '\\/:*?"<>|' '_________' |
    sed -e 's/^[. ]*//' -e 's/[. ]*$//')
  [ -n "$_sn" ] || _sn="rom"
  printf '%s' "$_sn"
}

free_kb() { df -Pk "$1" 2>/dev/null | awk 'NR==2{print $4}'; }

# ---------------------------------------------------------------- config (json; valores sempre string)
cfg_valid() { [ -s "$CFG" ] && "$JQ" -e 'type=="object"' "$CFG" >/dev/null 2>&1; }

cfg_get() {
  [ -f "$CFG" ] || return 0
  "$JQ" -r --arg k "$1" '.[$k] // empty | tostring' "$CFG" 2>/dev/null
}

cfg_write() { # le o filtro jq em $@ e aplica de forma atomica
  mkdir -p "$DATA_DIR" 2>/dev/null
  [ -s "$CFG" ] || printf '{}\n' >"$CFG"
  "$JQ" "$@" "$CFG" >"$CFG.new" 2>/dev/null && mv -f "$CFG.new" "$CFG"
}

cfg_set() { cfg_write --arg k "$1" --arg v "$2" '.[$k]=$v'; }

map_get() { # chave -> pasta lembrada
  [ -f "$CFG" ] || return 0
  "$JQ" -r --arg k "$1" '(.platform_map // {})[$k] // empty' "$CFG" 2>/dev/null
}
map_set() { cfg_write --arg k "$1" --arg v "$2" '.platform_map[$k]=$v'; }
map_clear() { cfg_write 'del(.platform_map)'; }

load_settings() {
  PAGE_SIZE=$(cfg_get page_size)
  case "$PAGE_SIZE" in '' | *[!0-9]*) PAGE_SIZE=30 ;; esac
  [ "$PAGE_SIZE" -lt 5 ] && PAGE_SIZE=30
  [ "$PAGE_SIZE" -gt 100 ] && PAGE_SIZE=100
  LANG_UI=$(cfg_get lang)
  [ "$LANG_UI" = en ] || LANG_UI=pt
  lang_load "$LANG_UI"
  FONT_SIZE=$(cfg_get font_size)
  case "$FONT_SIZE" in *[!0-9]*) FONT_SIZE="" ;; esac
  INSECURE=$(cfg_get insecure)
}

# ---------------------------------------------------------------- UI (selector / infoscreen / VirtualKeyboard)
# Textos podem conter "\n" literal ou quebra real: o infoscreen recebe quebra real, o selector "\n" literal.
to_real_nl() { printf '%s' "$1" | awk '{ gsub(/\\n/, "\n"); print }'; }
to_lit_nl() { printf '%s' "$1" | awk 'NR > 1 { printf "%s", "\\n" } { printf "%s", $0 }'; }

# O infoscreen (sdl2imgshow) le o texto como Latin-1 e nao quebra linhas; o selector e o teclado leem UTF-8.
# screen_text converte (acentos viram 1 byte Latin-1, aspas curvas etc. viram ASCII, o resto vira "?")
# e quebra as linhas longas na largura da tela.  Ver lib/screentext.awk.
screen_text() { # texto [corpo-da-fonte] -> texto pronto para "infoscreen -m"
  _st=$(printf '%s\n' "$1" | LC_ALL=C awk -v fs="${2:-30}" -v px=880 -v tbl="$APP_DIR/data/latin1.tsv" \
    -f "$APP_DIR/lib/screentext.awk" 2>/dev/null | LC_ALL=C tr -c '\11\12\40-\176' '?' | LC_ALL=C tr -s '?')
  if [ -n "$_st" ]; then printf '%b' "$_st"; else printf '%s' "$1"; fi
}

ui_info() { # mostra o texto e segue (a imagem fica na tela)
  "$INFOSCREEN" -m "$(screen_text "$(to_real_nl "$1")" "${2:-32}")" -fs "${2:-32}" >/dev/null 2>&1
}

ui_wait() { # texto [teclas] -> imprime a tecla pressionada
  "$INFOSCREEN" -m "$(screen_text "$(to_real_nl "$1")" 30)" -fs 30 -k "${2:-A B}" 2>/dev/null
}

ui_notice() { ui_wait "$1${NL}${NL}A: $L_OK" "A B" >/dev/null; }

ui_confirm() { # texto -> 0 se A (sim)
  _uk=$("$INFOSCREEN" -m "$(screen_text "$(to_real_nl "$1")${NL}${NL}A: $L_YES      B: $L_NO" 30)" -fs 30 -k "A B" 2>/dev/null)
  [ "$_uk" = A ]
}

ui_choose() { # titulo item... -> imprime o item escolhido (vazio = cancelou)
  _ct=$(to_lit_nl "$1")
  shift
  if [ -n "$FONT_SIZE" ]; then
    _co=$("$SELECTOR" -fs "$FONT_SIZE" -t "$_ct" -c "$@" 2>/dev/null | grep 'You selected')
  else
    _co=$("$SELECTOR" -t "$_ct" -c "$@" 2>/dev/null | grep 'You selected')
  fi
  _co=${_co#*You selected: }
  [ "$_co" = "You selected:" ] && _co=""
  printf '%s' "$_co"
}

ui_input() { # nome-do-fundo texto-inicial [pw] -> imprime o texto digitado (vazio = cancelou)
  _ib="$APP_DIR/res/kb_$1_$LANG_UI.png"
  [ -f "$_ib" ] || _ib="$SDCARD/trimui/res/crossmix-os/bg-plain.png"
  if [ "$3" = pw ]; then
    _ir=$("$VKEYBOARD" -i "$_ib" -p 2>/dev/null)
  else
    _ir=$("$VKEYBOARD" -i "$_ib" -t "$2" 2>/dev/null)
  fi
  printf '%s' "$_ir" | grep -o '\[VKStart\].*\[VKEnd\]' | sed -e 's/\[VKStart\]//' -e 's/\[VKEnd\]//'
}

# "1. texto" -> 1
choice_num() { printf '%s' "${1%%. *}"; }
