#!/bin/sh
# RomM Library - net.sh: acesso a API do RomM (curl), Tailscale e diagnostico.

NET_BASE=""
NET_SCHEME=""
NET_HOST=""
NET_PORT=""
NET_ERR=""
NET_VERSION=""
AUTH_CFG=""
RESOLVE_OPT=""
CURL_EXTRA=""
API_CODE=000
API_RC=0
OAUTH_DONE=""
CONNECT_TO=${ROMM_CONNECT_TIMEOUT:-8}
MAX_TIME=${ROMM_MAX_TIME:-45}

net_normalize_url() { # "nas:8080/" -> "http://nas:8080"; falha se nao sobrar host
  _nu=$(printf '%s' "$1" | tr -d ' \t\r\n')
  [ -n "$_nu" ] || return 1
  case "$_nu" in
  [Hh][Tt][Tt][Pp]://* | [Hh][Tt][Tt][Pp][Ss]://*)
    _ns=$(printf '%s' "${_nu%%://*}" | tr 'A-Z' 'a-z')
    _nr=${_nu#*://}
    ;;
  *)
    _ns=http
    _nr=$_nu
    ;;
  esac
  while :; do
    case "$_nr" in */) _nr=${_nr%/} ;; *) break ;; esac
  done
  case "$_nr" in */api) _nr=${_nr%/api} ;; esac
  case "$_nr" in '' | /* | :*) return 1 ;; esac
  printf '%s://%s' "$_ns" "$_nr"
}

net_parts() { # define NET_SCHEME NET_HOST NET_PORT a partir de NET_BASE
  NET_SCHEME=${NET_BASE%%://*}
  _np=${NET_BASE#*://}
  _np=${_np%%/*}
  case "$_np" in
  *:*)
    NET_HOST=${_np%%:*}
    NET_PORT=${_np#*:}
    ;;
  *)
    NET_HOST=$_np
    if [ "$NET_SCHEME" = https ]; then NET_PORT=443; else NET_PORT=80; fi
    ;;
  esac
}

curlcfg_esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

net_write_auth() { # grava o arquivo de credenciais do curl (em /tmp; nunca em argv nem no log)
  AUTH_CFG="$TMPD/auth.cfg"
  : >"$AUTH_CFG"
  _tok=$(cfg_get token)
  _usr=$(cfg_get username)
  _pw=$(cfg_get password)
  if [ -n "$_tok" ]; then
    printf 'header = "Authorization: Bearer %s"\n' "$(curlcfg_esc "$_tok")" >"$AUTH_CFG"
  elif [ -n "$_usr" ]; then
    printf 'user = "%s:%s"\nbasic\n' "$(curlcfg_esc "$_usr")" "$(curlcfg_esc "$_pw")" >"$AUTH_CFG"
  fi
}

net_init() {
  NET_BASE=$(cfg_get base_url)
  net_parts
  RESOLVE_OPT=""
  OAUTH_DONE=""
  CURL_EXTRA=""
  [ "$(cfg_get insecure)" = 1 ] && CURL_EXTRA="-k"
  net_write_auth
}

# ---------------------------------------------------------------- Tailscale
ts_state() { # imprime: absent | stopped | running <ip>
  [ -x "$TS_BIN" ] || { printf 'absent'; return 0; }
  _tj=$("$TS_BIN" status --json 2>/dev/null) || { printf 'stopped'; return 0; }
  _ts=$(printf '%s' "$_tj" | "$JQ" -r '.BackendState // empty' 2>/dev/null)
  if [ "$_ts" = Running ]; then
    printf 'running %s' "$(printf '%s' "$_tj" | "$JQ" -r '.Self.TailscaleIPs[0] // empty' 2>/dev/null)"
  else
    printf 'stopped'
  fi
}

host_is_tailnet() {
  case "$NET_HOST" in
  100.6[4-9].* | 100.[7-9][0-9].* | 100.1[01][0-9].* | 100.12[0-7].* | *.ts.net) return 0 ;;
  esac
  return 1
}

ts_hint() { # texto de dica, se fizer sentido, em $TS_HINT
  TS_HINT=""
  _th=$(ts_state)
  case "$_th" in
  absent) host_is_tailnet && TS_HINT="$L_TS_ABSENT" ;;
  running*) : ;;
  *) TS_HINT="$L_TS_DOWN" ;;
  esac
}

ts_resolve() { # MagicDNS pode nao resolver no aparelho: pergunta o IP ao proprio Tailscale
  [ -x "$TS_BIN" ] || return 1
  [ -z "$RESOLVE_OPT" ] || return 1
  _tn=${NET_HOST%%.*}
  _ti=$("$TS_BIN" ip -4 "$_tn" 2>/dev/null | head -n 1)
  case "$_ti" in
  [0-9]*.[0-9]*.[0-9]*.[0-9]*)
    RESOLVE_OPT="--resolve $NET_HOST:$NET_PORT:$_ti"
    log "dns: $NET_HOST resolvido via tailscale"
    return 0
    ;;
  esac
  return 1
}

# ---------------------------------------------------------------- requisicoes
api_curl() { # saida url [args...]  -> API_RC, API_CODE
  _ao=$1
  _au=$2
  shift 2
  # shellcheck disable=SC2086
  "$CURL" -sS -L --max-redirs 3 --connect-timeout "$CONNECT_TO" --max-time "$MAX_TIME" \
    --retry 2 --retry-delay 1 -K "$AUTH_CFG" $CURL_EXTRA $RESOLVE_OPT "$@" \
    -o "$_ao" -w '%{http_code}' "$_au" >"$TMPD/code" 2>"$TMPD/curl.err"
  API_RC=$?
  API_CODE=$(cat "$TMPD/code" 2>/dev/null)
  [ -n "$API_CODE" ] || API_CODE=000
  if [ "$API_RC" = 6 ] && ts_resolve; then
    api_curl "$_ao" "$_au" "$@"
    return
  fi
  if [ "$API_CODE" = 401 ] && [ -z "$OAUTH_DONE" ] && net_oauth_login; then
    api_curl "$_ao" "$_au" "$@"
    return
  fi
  log "GET ${_au#"$NET_BASE"} -> http $API_CODE rc $API_RC"
}

api_get() { # saida caminho [chave=valor ...]
  _go=$1
  _gp=$2
  shift 2
  _gn=$#
  while [ "$_gn" -gt 0 ]; do
    set -- "$@" --data-urlencode "$1"
    shift
    _gn=$((_gn - 1))
  done
  api_curl "$_go" "$NET_BASE$_gp" -G "$@"
}

# Alguns servidores recusam Basic: tenta o login OAuth2 (password grant) uma vez por sessao.
net_oauth_login() {
  OAUTH_DONE=1
  [ -z "$(cfg_get token)" ] || return 1
  _ou=$(cfg_get username)
  _op=$(cfg_get password)
  [ -n "$_ou" ] || return 1
  # shellcheck disable=SC2086
  "$CURL" -sS --connect-timeout "$CONNECT_TO" --max-time 20 $CURL_EXTRA $RESOLVE_OPT \
    --data-urlencode "grant_type=password" --data-urlencode "username=$_ou" \
    --data-urlencode "password=$_op" \
    --data-urlencode "scope=me.read roms.read platforms.read assets.read firmware.read collections.read" \
    -o "$TMPD/oauth.json" "$NET_BASE/api/token" >/dev/null 2>&1 || return 1
  _oa=$("$JQ" -r '.access_token // empty' "$TMPD/oauth.json" 2>/dev/null)
  [ -n "$_oa" ] || return 1
  printf 'header = "Authorization: Bearer %s"\n' "$(curlcfg_esc "$_oa")" >"$AUTH_CFG"
  log "auth: Basic recusado; usando token OAuth da sessao"
  return 0
}

# ---------------------------------------------------------------- diagnostico
net_explain() { # rc code -> NET_ERR (+ dica do Tailscale)
  case "$1" in
  0)
    case "$2" in
    401 | 403) NET_ERR="$L_E_AUTH" ;;
    404 | 405) NET_ERR="$L_E_NOTROMM" ;;
    5??) NET_ERR="$L_E_SERVER $2." ;;
    *) NET_ERR="$L_E_OTHER (HTTP $2)." ;;
    esac
    ;;
  6) NET_ERR="$L_E_DNS" ;;
  7) NET_ERR="$L_E_REFUSED" ;;
  28) NET_ERR="$L_E_TIMEOUT" ;;
  35 | 51 | 58 | 59 | 60 | 77 | 83) NET_ERR="$L_E_TLS" ;;
  *) NET_ERR="$L_E_OTHER (curl $1, HTTP $2)." ;;
  esac
  case "$1" in
  6 | 7 | 28)
    ts_hint
    [ -n "$TS_HINT" ] && NET_ERR="$NET_ERR$NL$TS_HINT"
    ;;
  *)
    if host_is_tailnet; then
      ts_hint
      [ -n "$TS_HINT" ] && NET_ERR="$NET_ERR$NL$TS_HINT"
    fi
    ;;
  esac
  return 0
}

# ---------------------------------------------------------------- operacoes de alto nivel
net_connect() { # testa servidor + login e carrega as plataformas. 0 = ok; senao NET_ERR
  NET_ERR=""
  NET_VERSION=""
  api_get "$TMPD/heartbeat.json" /api/heartbeat
  if [ "$API_RC" != 0 ] || [ "$API_CODE" != 200 ]; then
    net_explain "$API_RC" "$API_CODE"
    return 1
  fi
  NET_VERSION=$("$JQ" -r '.SYSTEM.VERSION // empty' "$TMPD/heartbeat.json" 2>/dev/null)
  if [ -z "$NET_VERSION" ] && ! "$JQ" -e 'type=="object"' "$TMPD/heartbeat.json" >/dev/null 2>&1; then
    net_explain 0 404
    return 1
  fi
  fetch_platforms || return 1
  return 0
}

fetch_platforms() { # /api/platforms -> $TMPD/platforms.tsv (id, nome, qtd, slug, fs_slug)
  api_get "$TMPD/platforms.json" /api/platforms
  if [ "$API_RC" != 0 ] || [ "$API_CODE" != 200 ]; then
    net_explain "$API_RC" "$API_CODE"
    return 1
  fi
  "$JQ" -r '
    def s: if . == null or . == "" then "-" else (tostring | gsub("[\u001f\t\r\n]"; " ") | gsub("^ +| +$"; "")) end;
    (if type == "array" then . else (.items // .platforms // []) end)
    | map(select((.rom_count // 1) > 0))
    | sort_by(((.display_name // .custom_name // .name // .slug // "") | ascii_downcase))
    | .[]
    | [ (.id | s), ((.display_name // .custom_name // .name // .slug) | s), (.rom_count | s),
        (.slug | s), (.fs_slug | s) ]
    | join("\u001f")' "$TMPD/platforms.json" >"$TMPD/platforms.tsv" 2>>"$LOG"
  if ! [ -f "$TMPD/platforms.tsv" ]; then
    NET_ERR="$L_E_OTHER (JSON)."
    log "platforms: resposta inesperada: $(head -c 300 "$TMPD/platforms.json" 2>/dev/null)"
    return 1
  fi
  PLATFORM_COUNT=$(wc -l <"$TMPD/platforms.tsv" | tr -d ' ')
  return 0
}

# Pagina de ROMs. platform_id e busca podem ser vazios.
# Saida: $TMPD/page.tsv (1 jogo por linha), $TMPD/letters.tsv, e as variaveis ROMS_COUNT / ROMS_TOTAL / ROMS_HASNEXT.
roms_page() { # platform_id busca offset limite
  _rp=$1
  _rq=$2
  _ro=$3
  _rl=$4
  set -- "limit=$_rl" "offset=$_ro" "order_by=name" "order_dir=asc" "with_char_index=true"
  [ -n "$_rp" ] && set -- "$@" "platform_ids=$_rp" "platform_id=$_rp"
  [ -n "$_rq" ] && set -- "$@" "search_term=$_rq"
  api_get "$TMPD/roms.json" /api/roms "$@"
  if [ "$API_RC" != 0 ] || [ "$API_CODE" != 200 ]; then
    net_explain "$API_RC" "$API_CODE"
    return 1
  fi
  "$JQ" -r --argjson off "$_ro" --argjson lim "$_rl" '
    def s: if . == null or . == "" then "-" else (tostring | gsub("[\u001f\t\r\n]"; " ") | gsub("^ +| +$"; "")) end;
    def items: if type == "array" then . else (.items // .roms // .results // []) end;
    (if type == "array" then items | .[$off:$off + $lim] else items end)
    | .[]
    | [ (.id | s),
        ((.name // .fs_name_no_ext // .fs_name) | s),
        ((.fs_size_bytes // .file_size_bytes // 0) | s),
        (.fs_name | s),
        ((if ((.has_multiple_files // .multi // false) or ((.files // []) | length > 1)) then 1 else 0 end) | s),
        ((.files // [])[0].id | s),
        (.platform_id | s),
        (.platform_slug | s),
        (.platform_fs_slug | s),
        ((.platform_display_name // .platform_name) | s),
        (((.regions // []) | join(",")) | s) ]
    | join("\u001f")' "$TMPD/roms.json" >"$TMPD/page.tsv" 2>>"$LOG"
  if ! [ -f "$TMPD/page.tsv" ]; then
    NET_ERR="$L_E_OTHER (JSON)."
    log "roms: resposta inesperada: $(head -c 300 "$TMPD/roms.json" 2>/dev/null)"
    return 1
  fi
  "$JQ" -r --argjson off "$_ro" --argjson lim "$_rl" '
    def items: if type == "array" then . else (.items // .roms // .results // []) end;
    (if type == "array" then (items | .[$off:$off + $lim] | length) else (items | length) end) as $count
    | (if type == "array" then length else (.total // null) end) as $total
    | "\($count)\u001f\($total // "-")"' "$TMPD/roms.json" >"$TMPD/page.meta" 2>/dev/null
  IFS=$US read -r ROMS_COUNT ROMS_TOTAL <"$TMPD/page.meta"
  case "$ROMS_COUNT" in '' | *[!0-9]*) ROMS_COUNT=$(wc -l <"$TMPD/page.tsv" | tr -d ' ') ;; esac
  case "$ROMS_TOTAL" in '' | *[!0-9]*) ROMS_TOTAL="" ;; esac
  if [ -n "$ROMS_TOTAL" ]; then
    # total conhecido (envelope, ou array legado): ha proxima pagina se ainda faltar
    if [ $((_ro + ROMS_COUNT)) -lt "$ROMS_TOTAL" ]; then ROMS_HASNEXT=1; else ROMS_HASNEXT=0; fi
  elif [ "$ROMS_COUNT" -ge "$_rl" ]; then
    ROMS_HASNEXT=1
  else
    ROMS_HASNEXT=0
  fi
  "$JQ" -r '
    (if type == "object" then (.char_index // {}) else {} end)
    | to_entries | map(select(.value | type == "number")) | sort_by(.value)
    | .[] | "\(.key)\u001f\(.value)"' "$TMPD/roms.json" >"$TMPD/letters.tsv" 2>/dev/null
  return 0
}
