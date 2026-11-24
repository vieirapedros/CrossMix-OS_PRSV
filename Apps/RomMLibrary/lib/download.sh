#!/bin/sh
# RomM Library - download.sh: baixa uma ROM para Roms/<pasta>, com retomada e verificacoes.
#
# rom_download id fs_name multi file_id tamanho pasta titulo
#   retorno: 0 ok | 1 falhou | 2 parado pelo usuario.  Texto do resultado em DL_MSG.
#
# Enderecos tentados, em ordem (versoes diferentes do RomM expoem rotas diferentes):
#   1) /api/roms/{id}/content/{arquivo}        (arquivo unico = o proprio arquivo; multi-arquivo = ZIP)
#   2) /api/roms/download?rom_ids={id}&filename=...   (sempre um ZIP)
#   3) /api/romsfiles/{file_id}/content/{arquivo}     (so arquivo unico)

DL_MSG=""
DL_RC=0
DL_CODE=000
DL_CANCELLED=""

dl_lower() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

# Roda o curl em segundo plano e mostra o progresso; B para.
dl_run() { # url parcial retomar(0|1) total titulo
  _dr_url=$1
  _dr_part=$2
  _dr_total=$4
  _dr_title=$5
  _dr_opt=""
  [ "$3" = 1 ] && _dr_opt="-C -"
  : >"$TMPD/dlcode"
  # shellcheck disable=SC2086
  "$CURL" -sSf -L --max-redirs 3 --connect-timeout 10 --speed-limit 1024 --speed-time 60 \
    -K "$AUTH_CFG" $CURL_EXTRA $RESOLVE_OPT $_dr_opt -o "$_dr_part" -w '%{http_code}' "$_dr_url" \
    >"$TMPD/dlcode" 2>"$TMPD/dlerr" &
  DL_PID=$!
  DL_CANCELLED=""
  _dr_t0=$(date +%s)
  _dr_b0=$(fsize "$_dr_part")
  while kill -0 "$DL_PID" 2>/dev/null; do
    _dr_cur=$(fsize "$_dr_part")
    _dr_dt=$(($(date +%s) - _dr_t0))
    _dr_speed=""
    if [ "$_dr_dt" -ge 2 ] && [ "$_dr_cur" -gt "$_dr_b0" ]; then
      _dr_speed="  -  $(fmt_size $(((_dr_cur - _dr_b0) / _dr_dt)))/s"
    fi
    if [ "$_dr_total" -gt 0 ]; then
      _dr_pct=$((_dr_cur * 100 / _dr_total))
      [ "$_dr_pct" -gt 99 ] && _dr_pct=99
      _dr_line="${_dr_pct}%   $(fmt_size "$_dr_cur") / $(fmt_size "$_dr_total")$_dr_speed"
    else
      _dr_line="$(fmt_size "$_dr_cur")$_dr_speed"
    fi
    _dr_k=$("$INFOSCREEN" -m "$(screen_text "$L_DL_PROGRESS${NL}${NL}$_dr_title${NL}${NL}$_dr_line${NL}${NL}$L_DL_CANCEL_HINT" 28)" -fs 28 -k B -t 1 2>/dev/null)
    if [ "$_dr_k" = B ]; then
      DL_CANCELLED=1
      kill "$DL_PID" 2>/dev/null
      break
    fi
  done
  wait "$DL_PID" 2>/dev/null
  DL_RC=$?
  DL_PID=""
  DL_CODE=$(cat "$TMPD/dlcode" 2>/dev/null)
  [ -n "$DL_CODE" ] || DL_CODE=000
  log "download id=$_dr_url -> http $DL_CODE rc $DL_RC bytes $(fsize "$_dr_part")"
}

dl_flatten_ok() { # dir pasta -> 0 se o dir contem arquivo com extensao aceita pelo emulador da pasta
  _fl_ex=$("$JQ" -r '.extlist // empty' "$SDCARD/Emus/$2/config.json" 2>/dev/null)
  [ -n "$_fl_ex" ] || return 1
  _fl_ex=$(dl_lower "$_fl_ex")
  for _fl_f in "$1"/*; do
    [ -f "$_fl_f" ] || continue
    _fl_e=$(dl_lower "${_fl_f##*.}")
    case "|$_fl_ex|" in *"|$_fl_e|"*) return 0 ;; esac
  done
  return 1
}

dl_move_into() { # origem destino: move tudo (inclusive ocultos), sobrescrevendo
  for _mv_f in "$1"/* "$1"/.[!.]*; do
    [ -e "$_mv_f" ] || continue
    _mv_t="$2/$(basename "$_mv_f")"
    [ -d "$_mv_f" ] && [ -d "$_mv_t" ] && rm -rf "$_mv_t"
    mv -f "$_mv_f" "$2/" || return 1
  done
  return 0
}

dl_extract() { # zip pasta-destino pasta-rom id [nome-final-se-arquivo-unico]
  [ -n "$SEVENZ" ] || return 1
  _ex_tmp="$2/.romm_extract_$4"
  rm -rf "$_ex_tmp"
  mkdir -p "$_ex_tmp" || return 1
  "$SEVENZ" x -y -o"$_ex_tmp" "$1" >/dev/null 2>&1 || {
    log "7zz falhou em $1"
    rm -rf "$_ex_tmp"
    return 1
  }
  _ex_n=0
  _ex_one=""
  for _ex_f in "$_ex_tmp"/* "$_ex_tmp"/.[!.]*; do
    [ -e "$_ex_f" ] || continue
    _ex_n=$((_ex_n + 1))
    _ex_one=$_ex_f
  done
  # arquivo unico entregue dentro de um ZIP (rota /api/roms/download): grava com o nome ja sanitizado
  if [ -n "$5" ] && [ "$_ex_n" = 1 ] && [ -f "$_ex_one" ]; then
    mv -f "$_ex_one" "$2/$5" || { rm -rf "$_ex_tmp"; return 1; }
    rm -rf "$_ex_tmp"
    return 0
  fi
  _ex_src=$_ex_tmp
  if [ "$_ex_n" = 1 ] && [ -d "$_ex_one" ] && dl_flatten_ok "$_ex_one" "$3"; then
    _ex_src=$_ex_one
  fi
  dl_move_into "$_ex_src" "$2" || { rm -rf "$_ex_tmp"; return 1; }
  rm -rf "$_ex_tmp"
  return 0
}

rom_download() {
  _id=$1
  _fs=$2
  _multi=$3
  _fid=$4
  _size=$5
  _folder=$6
  _title=$7
  case "$_size" in '' | *[!0-9]*) _size=0 ;; esac
  [ "$_fid" = - ] && _fid=""
  [ "$_fs" = - ] && _fs="rom_$_id"
  DL_MSG=""
  _dir="$ROMS_DIR/$_folder"
  mkdir -p "$_dir" 2>/dev/null || { DL_MSG="$L_DL_FAILED ($_dir)"; return 1; }
  _clean=$(dl_sanitize "$_fs")

  _need=$_size
  [ "$_multi" = 1 ] && _need=$((_size * 2))
  if [ "$_need" -gt 0 ]; then
    _free=$(free_kb "$_dir")
    case "$_free" in
    '' | *[!0-9]*) : ;;
    *) if [ $((_free * 1024)) -lt $((_need + 8388608)) ]; then DL_MSG="$L_DL_NOSPACE"; return 1; fi ;;
    esac
  fi

  _enc=$(urlenc "$_fs")
  _path1="/api/roms/$_id/content/$_enc"
  _path2="/api/roms/download?rom_ids=$_id&filename=$_enc"
  _path3=""
  [ -n "$_fid" ] && [ "$_multi" != 1 ] && _path3="/api/romsfiles/$_fid/content/$_enc"
  if [ "$_multi" = 1 ]; then _kind1=zip; else _kind1=raw; fi

  _state="$_dir/.romm_$_id.state"
  _start=1
  if [ -f "$_state" ]; then
    _start=$(cat "$_state" 2>/dev/null)
    case "$_start" in 1 | 2 | 3) : ;; *) _start=1 ;; esac
  fi
  _order="$_start"
  for _o in 1 2 3; do [ "$_o" != "$_start" ] && _order="$_order $_o"; done

  echo 1 >/tmp/stay_awake 2>/dev/null && STAY_AWAKE=1
  ui_info "$L_DL_STARTING"

  _ok=""
  _stop=""
  for _i in $_order; do
    case "$_i" in
    1) _path=$_path1; _kind=$_kind1 ;;
    2) _path=$_path2; _kind=zip ;;
    3) _path=$_path3; _kind=raw ;;
    esac
    [ -n "$_path" ] || continue
    if [ "$_kind" = zip ]; then _part="$_dir/$_clean.zip.rommpart"; else _part="$_dir/$_clean.rommpart"; fi

    _resume=0
    if [ -s "$_part" ] && [ "$_i" = "$_start" ] && [ -f "$_state" ]; then _resume=1; else rm -f "$_part"; fi
    echo "$_i" >"$_state"

    _tries=0
    while [ "$_tries" -lt 2 ]; do
      _tries=$((_tries + 1))
      dl_run "$NET_BASE$_path" "$_part" "$_resume" "$_size" "$_title"
      if [ -n "$DL_CANCELLED" ]; then
        _stop=cancel
        break 2
      fi
      if [ "$DL_RC" = 0 ] && { [ "$DL_CODE" = 200 ] || [ "$DL_CODE" = 206 ]; }; then
        _ok=$_i
        break 2
      fi
      # servidor sem suporte a Range, ou arquivo mudou: recomeca do zero uma vez
      if [ "$_resume" = 1 ] && { [ "$DL_RC" = 33 ] || [ "$DL_CODE" = 416 ]; }; then
        rm -f "$_part"
        _resume=0
        continue
      fi
      break
    done

    case "$DL_CODE" in
    401 | 403)
      DL_MSG="$L_E_AUTH"
      _stop=fail
      break
      ;;
    esac
    case "$DL_RC" in
    6 | 7 | 18 | 28 | 52 | 55 | 56)
      DL_MSG="$L_DL_INTERRUPTED"
      _stop=fail
      break
      ;;
    esac
    rm -f "$_part"
  done

  if [ -n "$STAY_AWAKE" ]; then rm -f /tmp/stay_awake; STAY_AWAKE=""; fi

  if [ "$_stop" = cancel ]; then
    DL_MSG="$L_DL_CANCELLED"
    return 2
  fi
  if [ -z "$_ok" ]; then
    if [ -z "$_stop" ]; then
      rm -f "$_state"
      DL_MSG="$L_DL_NOTFOUND (HTTP $DL_CODE)"
    fi
    [ -n "$DL_MSG" ] || DL_MSG="$L_DL_FAILED"
    return 1
  fi

  # ---- sucesso no curl: confere, move/extrai, limpa
  if [ "$_kind" = zip ]; then
    ui_info "$L_DL_EXTRACT"
    _single=""
    [ "$_multi" = 1 ] || _single=$_clean
    if ! dl_extract "$_part" "$_dir" "$_folder" "$_id" "$_single"; then
      rm -f "$_part" "$_state"
      DL_MSG="$L_DL_EXTRACT_FAIL"
      return 1
    fi
    rm -f "$_part"
    _shown="$_clean"
  else
    if [ "$_size" -gt 0 ] && [ "$(fsize "$_part")" -lt "$_size" ]; then
      DL_MSG="$L_DL_SIZE_BAD"
      return 1
    fi
    if [ "$(fsize "$_part")" -le 0 ]; then
      rm -f "$_part" "$_state"
      DL_MSG="$L_DL_FAILED"
      return 1
    fi
    mv -f "$_part" "$_dir/$_clean" || { DL_MSG="$L_DL_FAILED"; return 1; }
    _shown="$_clean"
  fi
  rm -f "$_state"
  rm -f "$_dir"/*_cache*.db 2>/dev/null
  sync
  DL_FINAL="$_dir/$_clean"
  DL_MSG="$L_DL_OK Roms/$_folder/${NL}$_shown${NL}${NL}$L_DL_OK2"
  log "download ok: id=$_id -> Roms/$_folder/$_shown"
  return 0
}

dl_clean_parts() { # apaga restos de downloads incompletos; imprime quantos
  _cp_n=0
  for _cp_d in "$ROMS_DIR"/*; do
    [ -d "$_cp_d" ] || continue
    for _cp_f in "$_cp_d"/*.rommpart "$_cp_d"/.romm_*.state "$_cp_d"/.romm_extract_*; do
      [ -e "$_cp_f" ] || continue
      rm -rf "$_cp_f" && _cp_n=$((_cp_n + 1))
    done
  done
  printf '%s' "$_cp_n"
}
