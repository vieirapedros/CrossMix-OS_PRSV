#!/bin/sh
# RomM Library - screens.sh: telas (assistente, menus, lista de jogos, detalhe, configuracoes).

APP_VERSION="1.0.0"

# ---------------------------------------------------------------- linhas das tabelas
row_load() { # n -> R_* (a partir de $TMPD/page.tsv)
  awk -v n="$1" 'NR == n { print; exit }' "$TMPD/page.tsv" >"$TMPD/row.txt"
  IFS=$US read -r R_ID R_NAME R_SIZE R_FS R_MULTI R_FID R_PID R_PSLUG R_PFS R_PNAME R_REG <"$TMPD/row.txt"
  for _rv in R_PID R_PSLUG R_PFS R_PNAME R_REG; do
    eval "[ \"\$$_rv\" = - ] && $_rv=''"
  done
  [ "$R_SIZE" = - ] && R_SIZE=0
  return 0
}

plat_name_by_id() {
  awk -F"$US" -v id="$1" '$1 == id { print $2; exit }' "$TMPD/platforms.tsv" 2>/dev/null
}

# ---------------------------------------------------------------- detalhe do jogo
screen_game() { # usa R_*
  _sg_folder=$(plat_folder "$R_PID" "$R_PSLUG" "$R_PFS")
  _sg_pname=$R_PNAME
  [ -n "$_sg_pname" ] || _sg_pname=$(plat_name_by_id "$R_PID")
  while :; do
    _sg_ex=""
    if [ -n "$_sg_folder" ] && [ "$R_MULTI" != 1 ] && [ "$R_FS" != - ] &&
      [ -f "$ROMS_DIR/$_sg_folder/$(dl_sanitize "$R_FS")" ]; then
      _sg_ex=1
    fi
    _sg_l2=$_sg_pname
    [ "$R_SIZE" != 0 ] && _sg_l2="${_sg_l2:+$_sg_l2  -  }$(fmt_size "$R_SIZE")"
    [ -n "$R_REG" ] && _sg_l2="${_sg_l2:+$_sg_l2  -  }$R_REG"
    if [ -n "$_sg_folder" ]; then _sg_dest="Roms/$_sg_folder"; else _sg_dest="?"; fi
    if [ -n "$_sg_ex" ]; then _sg_dl="$L_DL_AGAIN"; else _sg_dl="$L_DL"; fi
    _sg_c=$(ui_choose "$R_NAME${NL}$_sg_l2${NL}$L_DEST: $_sg_dest" \
      "1. $_sg_dl" "2. $L_DL_FOLDER" "3. $L_DL_BACK")
    case "$(choice_num "$_sg_c")" in
    1)
      if [ -z "$_sg_folder" ]; then
        _sg_folder=$(plat_ask_folder "$R_PID" "$R_PSLUG" "$R_PFS")
        if [ -z "$_sg_folder" ]; then
          ui_notice "$L_NO_FOLDER"
          continue
        fi
      fi
      rom_download "$R_ID" "$R_FS" "$R_MULTI" "$R_FID" "$R_SIZE" "$_sg_folder" "$R_NAME"
      _sg_rc=$?
      ui_notice "$DL_MSG"
      [ "$_sg_rc" = 0 ] && return 0
      ;;
    2)
      _sg_nf=$(plat_ask_folder "$R_PID" "$R_PSLUG" "$R_PFS")
      [ -n "$_sg_nf" ] && _sg_folder=$_sg_nf
      ;;
    *) return 0 ;;
    esac
  done
}

# ---------------------------------------------------------------- lista de jogos (paginada)
screen_games() { # platform_id nome slug fs_slug busca
  _gpid=$1
  _gname=$2
  _gslug=$3
  _gfs=$4
  _gq=$5
  _goff=0
  _gfetch=1
  _gfolder=""
  [ -n "$_gpid" ] && _gfolder=$(plat_folder "$_gpid" "$_gslug" "$_gfs")
  while :; do
    if [ "$_gfetch" = 1 ]; then
      ui_info "$L_LOADING"
      if ! roms_page "$_gpid" "$_gq" "$_goff" "$PAGE_SIZE"; then
        ui_notice "$NET_ERR"
        return 0
      fi
      _gfetch=0
    fi
    if [ "$ROMS_COUNT" -eq 0 ]; then
      if [ "$_goff" -gt 0 ]; then
        _goff=0
        _gfetch=1
        continue
      fi
      if [ -n "$_gq" ]; then ui_notice "$L_NO_RESULTS"; else ui_notice "$L_EMPTY_PAGE"; fi
      return 0
    fi

    set --
    set -- "$@" "$L_SEARCH"
    [ -s "$TMPD/letters.tsv" ] && set -- "$@" "$L_LETTER"
    _gn=0
    while IFS=$US read -r _a _b _c _d _e _f _g _h _i _j _k; do
      _gn=$((_gn + 1))
      [ "$_h" = - ] && _h=""
      [ "$_i" = - ] && _i=""
      _gl=$_b
      if [ -z "$_gpid" ]; then
        [ "$_j" != - ] && _gl="$_gl [$_j]"
        _gmf=$(plat_folder "$_g" "$_h" "$_i")
      else
        _gmf=$_gfolder
      fi
      if [ -n "$_gmf" ] && [ "$_e" != 1 ] && [ "$_d" != - ] &&
        [ -f "$ROMS_DIR/$_gmf/$(dl_sanitize "$_d")" ]; then
        _gl="* $_gl"
      fi
      set -- "$@" "$_gn. $_gl"
    done <"$TMPD/page.tsv"
    [ "$_goff" -gt 0 ] && set -- "$@" "$L_PREV"
    [ "$ROMS_HASNEXT" = 1 ] && set -- "$@" "$L_NEXT"

    _gfrom=$((_goff + 1))
    _gto=$((_goff + ROMS_COUNT))
    if [ -n "$ROMS_TOTAL" ]; then _grange="$_gfrom-$_gto $L_GAMES_FMT $ROMS_TOTAL"; else _grange="$_gfrom-$_gto"; fi
    _gt="$_gname"
    [ -n "$_gq" ] && _gt="$_gt: \"$_gq\""
    _gc=$(ui_choose "$_gt  ($_grange)${NL}* = SD  |  $L_BACK_HINT" "$@")
    [ -n "$_gc" ] || return 0

    case "$_gc" in
    "$L_NEXT")
      _goff=$((_goff + PAGE_SIZE))
      _gfetch=1
      ;;
    "$L_PREV")
      _goff=$((_goff - PAGE_SIZE))
      [ "$_goff" -lt 0 ] && _goff=0
      _gfetch=1
      ;;
    "$L_SEARCH")
      _gs=$(ui_input search "$_gq")
      if [ -n "$_gs" ]; then
        _gq=$_gs
        _goff=0
        _gfetch=1
      fi
      ;;
    "$L_LETTER")
      set --
      while IFS=$US read -r _lk _lv; do
        set -- "$@" "$_lk"
      done <"$TMPD/letters.tsv"
      _glc=$(ui_choose "$L_LETTER_TITLE" "$@")
      if [ -n "$_glc" ]; then
        _glo=$(awk -F"$US" -v k="$_glc" '$1 == k { print $2; exit }' "$TMPD/letters.tsv")
        case "$_glo" in
        '' | *[!0-9]*) : ;;
        *)
          _goff=$_glo
          _gfetch=1
          ;;
        esac
      fi
      ;;
    *)
      row_load "$(choice_num "$_gc")"
      screen_game
      ;;
    esac
  done
}

screen_platforms() {
  while :; do
    if ! [ -s "$TMPD/platforms.tsv" ]; then
      ui_info "$L_LOADING"
      fetch_platforms || { ui_notice "$NET_ERR"; return 0; }
    fi
    [ -s "$TMPD/platforms.tsv" ] || { ui_notice "$L_NO_PLATFORMS"; return 0; }
    set --
    _pn=0
    while IFS=$US read -r _pi _pname _pc _ps _pf; do
      _pn=$((_pn + 1))
      if [ "$_pc" = - ]; then set -- "$@" "$_pn. $_pname"; else set -- "$@" "$_pn. $_pname ($_pc)"; fi
    done <"$TMPD/platforms.tsv"
    _pch=$(ui_choose "$L_PLATFORMS_TITLE" "$@")
    [ -n "$_pch" ] || return 0
    awk -v n="$(choice_num "$_pch")" 'NR == n { print; exit }' "$TMPD/platforms.tsv" >"$TMPD/row.txt"
    IFS=$US read -r P_ID P_NAME P_COUNT P_SLUG P_FS <"$TMPD/row.txt"
    [ "$P_SLUG" = - ] && P_SLUG=""
    [ "$P_FS" = - ] && P_FS=""
    screen_games "$P_ID" "$P_NAME" "$P_SLUG" "$P_FS" ""
  done
}

screen_search() {
  _sq=$(ui_input search "")
  [ -n "$_sq" ] || return 0
  screen_games "" "$L_SEARCH_RESULTS" "" "" "$_sq"
}

# ---------------------------------------------------------------- login / servidor
ask_server() {
  _as=$(cfg_get base_url)
  [ -n "$_as" ] || _as="http://"
  _av=$(ui_input url "$_as")
  [ -n "$_av" ] || return 1
  _av=$(net_normalize_url "$_av") || return 1
  cfg_set base_url "$_av"
}

ask_auth() {
  _aa=$(ui_choose "$L_AUTH_TITLE" "1. $L_AUTH_USER" "2. $L_AUTH_TOKEN")
  case "$(choice_num "$_aa")" in
  1)
    _au=$(ui_input user "$(cfg_get username)")
    [ -n "$_au" ] || return 1
    _ap=$(ui_input pass "" pw)
    cfg_set username "$_au"
    cfg_set password "$_ap"
    cfg_set token ""
    ;;
  2)
    _at=$(ui_input token "$(cfg_get token)")
    [ -n "$_at" ] || return 1
    cfg_set token "$_at"
    cfg_set username ""
    cfg_set password ""
    ;;
  *) return 1 ;;
  esac
  return 0
}

connect_report() { # tenta conectar; mostra o resultado. 0 = conectou
  net_init
  rm -f "$TMPD/platforms.tsv"
  ui_info "$L_CONNECTING"
  if net_connect; then
    return 0
  fi
  return 1
}

wizard() {
  _wk=$(ui_wait "$L_WIZ_WELCOME" "A B")
  [ "$_wk" = A ] || return 1
  ask_server || return 1
  ask_auth || return 1
  while :; do
    if connect_report; then
      ui_notice "$L_TEST_OK${NL}RomM ${NET_VERSION:-?}${NL}$PLATFORM_COUNT $L_TEST_PLAT"
      return 0
    fi
    _wc=$(ui_choose "$L_CONN_ERR_TITLE${NL}$NET_ERR" \
      "1. $L_RETRY" "2. $L_EDIT_SERVER" "3. $L_EDIT_LOGIN" "4. $L_EXIT")
    case "$(choice_num "$_wc")" in
    1) : ;;
    2) ask_server ;;
    3) ask_auth ;;
    *) return 1 ;;
    esac
  done
}

startup_check() { # conecta ao abrir o app; se falhar, oferece tentar de novo / configuracoes / sair
  while :; do
    if connect_report; then return 0; fi
    _sc=$(ui_choose "$L_CONN_ERR_TITLE${NL}$NET_ERR" \
      "1. $L_RETRY" "2. $L_MAIN_SETTINGS" "3. $L_EXIT")
    case "$(choice_num "$_sc")" in
    1) : ;;
    2) screen_settings ;;
    *) return 1 ;;
    esac
  done
}

# ---------------------------------------------------------------- configuracoes
settings_test() {
  if connect_report; then
    _st_ts=$(ts_state)
    case "$_st_ts" in running*) _st_ts="$L_TS_UP (${_st_ts#running })" ;; *) _st_ts="" ;; esac
    ui_notice "$L_TEST_OK${NL}RomM ${NET_VERSION:-?}${NL}$PLATFORM_COUNT $L_TEST_PLAT${NL}$_st_ts"
  else
    ui_notice "$L_CONN_ERR_TITLE${NL}$NET_ERR"
  fi
}

screen_about() {
  _ab_ts=$(ts_state)
  ui_notice "RomM Library $APP_VERSION${NL}$L_ABOUT_SRV: ${NET_VERSION:-?}${NL}Tailscale: ${_ab_ts%% *}${NL}$L_ABOUT_CFG: Data/romm/config.json${NL}$L_ABOUT_LOG: System/logs/romm_library.log"
}

screen_settings() {
  while :; do
    _ss_srv=$(cfg_get base_url)
    if [ -n "$(cfg_get token)" ]; then _ss_login="$L_S_LOGIN_TOKEN"; else _ss_login=$(cfg_get username); fi
    if [ "$(cfg_get insecure)" = 1 ]; then _ss_ins="$L_ON"; else _ss_ins="$L_OFF"; fi
    _ss_c=$(ui_choose "$L_SETTINGS  ($L_BACK_HINT)" \
      "1. $L_S_SERVER: $_ss_srv" "2. $L_S_LOGIN: $_ss_login" "3. $L_S_TEST" \
      "4. $L_S_PAGE: $PAGE_SIZE" "5. $L_S_LANG: $LANG_UI" "6. $L_S_INSECURE: $_ss_ins" \
      "7. $L_S_FOLDERS" "8. $L_S_PARTS" "9. $L_S_ABOUT")
    case "$(choice_num "$_ss_c")" in
    1) ask_server && settings_test ;;
    2) ask_auth && settings_test ;;
    3) settings_test ;;
    4)
      case "$PAGE_SIZE" in
      20) _ss_n=30 ;;
      30) _ss_n=50 ;;
      50) _ss_n=100 ;;
      *) _ss_n=20 ;;
      esac
      cfg_set page_size "$_ss_n"
      PAGE_SIZE=$_ss_n
      ;;
    5)
      if [ "$LANG_UI" = en ]; then cfg_set lang pt; else cfg_set lang en; fi
      load_settings
      ;;
    6)
      if [ "$(cfg_get insecure)" = 1 ]; then cfg_set insecure 0; else cfg_set insecure 1; fi
      net_init
      ;;
    7)
      map_clear
      ui_notice "$L_FOLDERS_CLEARED"
      ;;
    8)
      _ss_k=$(dl_clean_parts)
      if [ "$_ss_k" = 0 ]; then ui_notice "$L_PARTS_NONE"; else ui_notice "$L_PARTS_DONE $_ss_k"; fi
      ;;
    9) screen_about ;;
    *) return 0 ;;
    esac
  done
}

# ---------------------------------------------------------------- menu principal e entrada
screen_main() {
  while :; do
    _mc=$(ui_choose "$L_MAIN_TITLE" "1. $L_MAIN_BROWSE" "2. $L_MAIN_SEARCH" \
      "3. $L_MAIN_SETTINGS" "4. $L_MAIN_EXIT")
    case "$(choice_num "$_mc")" in
    1) screen_platforms ;;
    2) screen_search ;;
    3) screen_settings ;;
    4 | "") return 0 ;;
    esac
  done
}

app_main() {
  tmp_init
  lang_load pt
  if [ -z "$JQ" ] || [ -z "$CURL" ]; then
    log "faltam ferramentas: jq='$JQ' curl='$CURL'"
    ui_notice "$L_NEED_TOOLS"
    return 1
  fi
  mkdir -p "$DATA_DIR" 2>/dev/null
  if [ -s "$CFG" ] && ! cfg_valid; then
    mv -f "$CFG" "$CFG.bad" 2>/dev/null
    log "config.json invalido: guardado como config.json.bad"
  fi
  load_settings
  if [ -z "$(cfg_get base_url)" ]; then
    wizard || return 0
  fi
  net_init
  if [ -n "$(cfg_get base_url)" ] && ! [ -s "$TMPD/platforms.tsv" ]; then
    startup_check || return 0
  fi
  screen_main
  return 0
}
