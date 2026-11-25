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
  UI_ENC=$(cfg_get ui_encoding)   # latin1 | utf8 (como o selector desenha os acentos); vazio = ainda nao calibrado
  case "$UI_ENC" in latin1 | utf8) ;; *) UI_ENC="" ;; esac
  FONT_SIZE=$(cfg_get font_size)
  case "$FONT_SIZE" in *[!0-9]*) FONT_SIZE="" ;; esac
  INSECURE=$(cfg_get insecure)
}

# ---------------------------------------------------------------- UI (selector / infoscreen / VirtualKeyboard)
# Textos podem conter "\n" literal ou quebra real: o infoscreen recebe quebra real, o selector "\n" literal.
to_real_nl() { printf '%s' "$1" | awk '{ gsub(/\\n/, "\n"); print }'; }
to_lit_nl() { printf '%s' "$1" | awk 'NR > 1 { printf "%s", "\\n" } { printf "%s", $0 }'; }

# ---- texto para os programas de tela do sistema ------------------------------------------------------
# infoscreen (sdl2imgshow) e selector desenham com TTF_RenderText_*, que leem o texto como Latin-1, nao UTF-8.
# O infoscreen so desenha UMA linha (quebra de linha vira quadradinho, o que passa da largura sai da tela);
# o selector aceita varias linhas no titulo.  Por isso: infoscreen so para frases curtas e para o progresso do
# download (screen_line); avisos e confirmacoes usam o selector (ui_notice/ui_confirm).  Ver lib/screentext.awk.
SCREEN_PX=1150 # largura util (px) de uma linha do infoscreen; o Brick tem tela menor
case "$(head -n 1 /etc/trimui_device.txt 2>/dev/null)" in brick) SCREEN_PX=900 ;; esac

screen_awk() { # modo corpo-da-fonte largura-px [fim]: o texto vem no stdin
  LC_ALL=C awk -v mode="$1" -v fs="$2" -v px="$3" -v tail="$4" -v tbl="$APP_DIR/data/latin1.tsv" \
    -f "$APP_DIR/lib/screentext.awk" 2>/dev/null
}

latin1_out() { LC_ALL=C tr -c '\11\12\40-\176' '?' | LC_ALL=C tr -s '?'; } # sobras nao Latin-1 viram "?"

to_latin1() { # texto (varias linhas ok) -> o mesmo texto em Latin-1 (acentos 1 byte; o resto vira ASCII ou "?")
  _l1=$(printf '%s\n' "$1" | screen_awk conv 30 880 | latin1_out)
  if [ -n "$_l1" ]; then printf '%b' "$_l1"; else printf '%s' "$1"; fi
}

screen_line() { # texto [corpo-da-fonte] [fim] -> UMA linha em Latin-1 que cabe na tela (corta o texto, nunca o fim)
  _sl=$(printf '%s\n' "$1" | screen_awk line "${2:-30}" "$SCREEN_PX" "$3" | latin1_out)
  if [ -n "$_sl" ]; then printf '%b' "$_sl"; else printf '%s' "$1" | tr '\n' ' '; fi
}

screen_wrap() { # texto -> o mesmo texto (UTF-8) com as linhas longas quebradas por palavra (titulos do selector)
  _sw=$(printf '%s\n' "$1" | screen_awk wrap 24 720)
  if [ -n "$_sw" ]; then printf '%s' "$_sw"; else printf '%s' "$1"; fi
}

ui_text() { # texto -> no encoding que o selector desenha (Latin-1, ou UTF-8 se ui_encoding = utf8)
  if [ "$UI_ENC" = utf8 ]; then printf '%s' "$1"; else to_latin1 "$1"; fi
}

ui_info() { # frase curta no infoscreen e segue (a imagem fica na tela); varias linhas viram uma
  "$INFOSCREEN" -m "$(screen_line "$(to_real_nl "$1")" "${2:-32}")" -fs "${2:-32}" >/dev/null 2>&1
}

ui_wait() { # texto [teclas] -> imprime A (OK) ou B (voltou/cancelou)
  _uw=$(ui_choose "$(screen_wrap "$(to_real_nl "$1")")" "$L_OK")
  if [ -n "$_uw" ]; then printf 'A'; else printf 'B'; fi
}

ui_notice() { # aviso: menu de um item so (A: OK; B tambem fecha)
  ui_choose "$(screen_wrap "$(to_real_nl "$1")")" "$L_OK" >/dev/null
}

ui_confirm() { # texto [rotulo-do-sim] -> 0 so se escolher "sim"; B ou "nao" = 1.  "Nao" vem primeiro (item inicial)
  _uk=$(ui_choose "$(screen_wrap "$(to_real_nl "$1")")" "1. $L_NO" "2. ${2:-$L_YES}")
  [ "$(choice_num "$_uk")" = 2 ]
}

ui_choose() { # titulo item... -> imprime o item escolhido, no texto ORIGINAL (UTF-8); vazio = cancelou
  _ct=$(to_lit_nl "$(ui_text "$1")")
  shift
  _cconv=0
  if [ "$UI_ENC" != utf8 ] && [ "$#" -gt 0 ]; then
    # converte todos os itens de uma vez (um processo, nao um por item) e remonta os argumentos;
    # os originais ficam num arquivo para devolver o item escolhido no texto original (as telas comparam com ele)
    printf '%s\n' "$@" >"$TMPD/ui_orig"
    _ci=$(ui_text "$(cat "$TMPD/ui_orig")")
    if [ -n "$_ci" ]; then
      printf '%s\n' "$_ci" >"$TMPD/ui_conv"
      set --
      while IFS= read -r _cl; do set -- "$@" "$_cl"; done <"$TMPD/ui_conv"
      _cconv=1
    fi
  fi
  if [ -n "$FONT_SIZE" ]; then
    _co=$("$SELECTOR" -fs "$FONT_SIZE" -t "$_ct" -c "$@" 2>/dev/null | grep 'You selected')
  else
    _co=$("$SELECTOR" -t "$_ct" -c "$@" 2>/dev/null | grep 'You selected')
  fi
  _co=${_co#*You selected: }
  [ "$_co" = "You selected:" ] && _co=""
  if [ "$_cconv" = 1 ] && [ -n "$_co" ]; then
    while IFS= read -r _cv <&3 && IFS= read -r _cg <&4; do
      if [ "$_cv" = "$_co" ]; then
        _co=$_cg
        break
      fi
    done 3<"$TMPD/ui_conv" 4<"$TMPD/ui_orig"
  fi
  printf '%s' "$_co"
}

calibrate_encoding() { # mostra uma linha em cada codificacao; quem escolher a que aparece certa define ui_encoding
  # (so ASCII no titulo: ele precisa ser legivel nas duas). B pula e deixa como esta (latin1 nesta sessao).
  _ea=$(to_latin1 "1. ação coração você é ü")
  _eb="2. ação coração você é ü"
  if [ -n "$FONT_SIZE" ]; then
    _ec=$("$SELECTOR" -fs "$FONT_SIZE" -t "$L_ENC_TITLE" -c "$_ea" "$_eb" 2>/dev/null | grep 'You selected')
  else
    _ec=$("$SELECTOR" -t "$L_ENC_TITLE" -c "$_ea" "$_eb" 2>/dev/null | grep 'You selected')
  fi
  _ec=${_ec#*You selected: }
  case "$(choice_num "$_ec")" in
  1) UI_ENC=latin1 ;;
  2) UI_ENC=utf8 ;;
  *) return 1 ;;
  esac
  cfg_set ui_encoding "$UI_ENC"
  log "ui_encoding=$UI_ENC"
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
