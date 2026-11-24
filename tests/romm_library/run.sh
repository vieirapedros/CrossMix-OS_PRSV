#!/usr/bin/env bash
# Testes do app RomM Library: unitarios (funcoes) + ponta a ponta (launch.sh inteiro contra um RomM de mentira).
# Uso:  bash tests/romm_library/run.sh [filtro]      ex.: bash tests/romm_library/run.sh flaky
# Requer: python3, jq, curl, dash. Nao toca em nada fora de /tmp.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HERE=$ROOT/tests/romm_library
TMP=$(mktemp -d /tmp/rommtest.XXXXXX)
FILTER=${1:-}
PASS=0
FAIL=0
N=0
SRV_PID=""
trap 'stop_server; rm -rf "$TMP"' EXIT

TOKEN="rmm_$(printf 'ab12%.0s' $(seq 16))"
PASSWD='p@ss"w\ord:1'

ok() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1  (esperado [$3] obtido [$2])"; fi; }
want() { [ -z "$FILTER" ] || [[ "$1" == *"$FILTER"* ]]; }

start_server() {
  PORTFILE=$TMP/port.$RANDOM
  REQLOG=$TMP/req.$RANDOM.log
  : >"$REQLOG"
  python3 -I "$HERE/mock_server.py" --portfile "$PORTFILE" --reqlog "$REQLOG" "$@" &
  SRV_PID=$!
  for _ in $(seq 60); do [ -s "$PORTFILE" ] && break; sleep 0.1; done
  PORT=$(cat "$PORTFILE")
}
stop_server() { [ -n "$SRV_PID" ] && { kill "$SRV_PID" 2>/dev/null; wait "$SRV_PID" 2>/dev/null; SRV_PID=""; }; return 0; }

new_sd() {
  N=$((N + 1))
  SD=$TMP/sd.$N
  M=$TMP/mock.$N
  mkdir -p "$SD/Apps" "$SD/System/bin" "$SD/System/usr/trimui/scripts" "$SD/System/logs" "$SD/Data" "$M"
  cp -r "$ROOT/Apps/RomMLibrary" "$SD/Apps/"
  cp "$HERE"/mocks/{selector,VirtualKeyboard,7zz,df,mocklib.sh} "$SD/System/bin/"
  cp "$HERE"/mocks/{infoscreen.sh,mocklib.sh} "$SD/System/usr/trimui/scripts/"
  for d in GBA PS FBNEO NGP N64 MD SFC; do mkdir -p "$SD/Roms/$d"; done
  mkdir -p "$SD/Emus/PS"
  echo '{"extlist":"iso|cue|img|mdf|pbp|toc|cbn|m3u|ccd|chd"}' >"$SD/Emus/PS/config.json"
  : >"$M/sel.q"; : >"$M/vk.q"; : >"$M/info.q"; : >"$M/prog.q"
  APPLOG=$SD/System/logs/romm_library.log
  CFGF=$SD/Data/romm/config.json
}
q() { local f=$M/$1.q; shift; printf '%s\n' "$@" >>"$f"; }
write_cfg() { mkdir -p "$SD/Data/romm"; printf '%s\n' "$1" >"$SD/Data/romm/config.json"; }
cfg_token() { write_cfg "{\"base_url\":\"http://127.0.0.1:$PORT\",\"token\":\"$TOKEN\"}"; }
run_app() {
  env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY NO_PROXY='*' ROMM_CONNECT_TIMEOUT=2 \
    ROMM_SDCARD="$SD" MOCK_DIR="$M" ${MOCK_FREE_KB:+MOCK_FREE_KB=$MOCK_FREE_KB} \
    timeout 120 sh "$SD/Apps/RomMLibrary/launch.sh" >"$M/out.txt" 2>&1
  RC=$?
}
sha_of() {
  python3 -I -c "
import sys, hashlib
sys.path.insert(0, '$HERE')
import mock_server as m
r = next(x for x in m.ROMS if x['id'] == int(sys.argv[1]))
sys.stdout.write(hashlib.sha256(m.rom_bytes(r)).hexdigest())" "$1"
}
sha_file() { sha256sum "$1" | cut -d' ' -f1; }
dump() {
  echo "    ---- diagnostico ----"
  for f in "$M/sel.log" "$M/info.log" "$M/vk.log" "$M/errors.log" "$APPLOG" "${REQLOG:-/dev/null}" "$M/out.txt"; do
    [ -s "$f" ] && { echo "    >> $(basename "$f")"; tail -n 25 "$f" | sed 's/^/       /'; }
  done
}
scenario() { # nome -> 0 se deve rodar
  want "$1" || return 1
  echo "[$1]"
  FAIL_BEFORE=$FAIL
  return 0
}
end_scenario() {
  # erros de shell que escapam para o log do app (stderr do launch.sh vai para la) reprovam o cenario
  if [ -f "${APPLOG:-/nonexistent}" ] && grep -Eq 'not found|cannot open|Illegal|syntax error|bad substitution|unexpected|parameter not set|Bad' "$APPLOG"; then
    bad "erros de shell no log do app"
  fi
  [ "$FAIL" -gt "$FAIL_BEFORE" ] && dump
  stop_server
  return 0
}

SH() { # roda um trecho de sh (dash) com as libs carregadas
  ROMM_SDCARD=$SD APP_DIR=$SD/Apps/RomMLibrary TMPD=$TMP/unit_tmp \
    dash -c ". \"\$APP_DIR/lib/i18n.sh\"; . \"\$APP_DIR/lib/common.sh\"; . \"\$APP_DIR/lib/net.sh\"; . \"\$APP_DIR/lib/platforms.sh\"; . \"\$APP_DIR/lib/download.sh\"; mkdir -p \"\$TMPD\"; lang_load pt; $1"
}

# ============================================================== UNITARIOS
if scenario "unit"; then
  new_sd
  eq "normalize: host:porta/" "$(SH 'net_normalize_url " nas.ts.net:8080/ "')" "http://nas.ts.net:8080"
  eq "normalize: remove /api" "$(SH 'net_normalize_url "http://10.0.0.5:8080/api/"')" "http://10.0.0.5:8080"
  eq "normalize: HTTPS maiusculo" "$(SH 'net_normalize_url "HTTPS://Nas/"')" "https://Nas"
  SH 'net_normalize_url "http://"' >/dev/null 2>&1 && bad "normalize: 'http://' deveria falhar" || ok "normalize: 'http://' falha"
  SH 'net_normalize_url ""' >/dev/null 2>&1 && bad "normalize: vazio deveria falhar" || ok "normalize: vazio falha"

  eq "sanitize: : & ( )" "$(SH 'dl_sanitize "Pokémon: Emerald & Co. (USA).gba"')" "Pokémon_ Emerald & Co. (USA).gba"
  eq "sanitize: / ? \" < >" "$(SH 'dl_sanitize "Zelda/Link? \"Minish\" <Cap> (USA).gba"')" 'Zelda_Link_ _Minish_ _Cap_ (USA).gba'
  eq "sanitize: ponto final" "$(SH 'dl_sanitize "nome."')" "nome"
  eq "sanitize: so pontos" "$(SH 'dl_sanitize "..."')" "rom"
  eq "sanitize: barra invertida" "$(SH 'dl_sanitize "a\\b|c*d"')" "a_b_c_d"

  # ---- texto do infoscreen: sdl2imgshow le Latin-1 (TTF_RenderText_Solid) e nao quebra linhas
  hex_of() { od -An -v -tx1 | tr -d ' \n'; }
  eq "screen_text: acentos viram 1 byte Latin-1" "$(SH 'screen_text "Não é possível ç Ç õ ü"' | hex_of)" "$(printf 'N\343o \351 poss\355vel \347 \307 \365 \374' | hex_of)"
  eq "screen_text: aspas curvas, travessao e reticencias viram ASCII" "$(SH 'screen_text "“A” – ‘B’ — C…"')" "\"A\" - 'B' - C..."
  eq "screen_text: macron vira a letra base" "$(SH 'screen_text "Ōkami Šibenik Łódź"')" "Okami Sibenik L$(printf '\363')d""z"
  eq "screen_text: CJK vira um unico ?" "$(SH 'screen_text "ドラゴンクエスト"')" "?"
  eq "screen_text: barra invertida e % ficam como estao" "$(SH 'screen_text "C:\\dir\\0343 100%s %d"')" 'C:\dir\0343 100%s %d'
  eq "screen_text: texto ASCII curto nao muda" "$(SH 'screen_text "Downloading 45%   12.3 MB / 40.0 MB  -  1.2 MB/s" 28')" "Downloading 45%   12.3 MB / 40.0 MB  -  1.2 MB/s"
  eq "screen_text: linha em branco e quebra real preservadas" "$(SH 'screen_text "Baixando

Jogo"')" "$(printf 'Baixando\n\nJogo')"
  _long='O servidor não tem plataformas com jogos (ou o seu usuário não pode vê-las). Confira o login e as permissões no RomM e tente de novo.'
  _wr=$(ROMM_SDCARD=$SD APP_DIR=$SD/Apps/RomMLibrary dash -c '. "$APP_DIR/lib/i18n.sh"; . "$APP_DIR/lib/common.sh"; screen_text "$1" 30' sh "$_long")
  [ "$(printf '%s\n' "$_wr" | wc -l)" -ge 2 ] && ok "screen_text: linha longa e quebrada em varias" || bad "screen_text: linha longa nao quebrou"
  eq "screen_text: quebrar nao perde nem troca palavras" "$(printf '%s' "$_wr" | tr '\n' ' ' | sed 's/ *$//' | hex_of)" "$(printf '%s' "$_long" | iconv -f UTF-8 -t ISO-8859-1 | hex_of)"
  _lw=$(printf '%s\n' "$_wr" | awk '{ if (length($0) > m) m = length($0) } END { print m }')
  [ "$_lw" -le 60 ] && ok "screen_text: nenhuma linha passa de 60 caracteres ($_lw)" || bad "screen_text: linha com $_lw caracteres"
  _wr2=$(ROMM_SDCARD=$SD APP_DIR=$SD/Apps/RomMLibrary dash -c '. "$APP_DIR/lib/i18n.sh"; . "$APP_DIR/lib/common.sh"; screen_text "$1" 30' sh "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ")
  [ "$(printf '%s\n' "$_wr2" | wc -l)" -ge 2 ] && ok "screen_text: palavra maior que a tela sofre quebra dura" || bad "screen_text: palavra gigante nao quebrou"
  # largura real na fonte do tema (so com Pillow)
  if python3 -c 'import PIL' 2>/dev/null; then
    _ww=$(ROMM_SDCARD=$SD APP_DIR=$SD/Apps/RomMLibrary dash -c '. "$APP_DIR/lib/i18n.sh"; . "$APP_DIR/lib/common.sh"; for t in "O servidor não tem plataformas com jogos (ou seu usuário não pode vê-las). Confira o login." "THE LEGEND OF ZELDA: THE WIND WAKER (USA) (DISC 1) [!] MASTER QUEST" "Dragon Ball Z - Budokai Tenkaichi 3 (Europe) (En,Fr,De,Es,It) (Rev 1)" "mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"; do screen_text "$t" 30; printf "\036"; done')
    _mx=$(printf '%s' "$_ww" | python3 -I -c '
import sys
from PIL import ImageFont
f = ImageFont.truetype(sys.argv[1], 30)
raw = sys.stdin.buffer.read().decode("latin-1")
print(int(max(f.getlength(l) for blk in raw.split("\x1e") for l in blk.split("\n") if l)))' "$ROOT/Themes/JukCrossMix-OS/wqy-microhei.ttf")
    [ "$_mx" -le 1000 ] && ok "screen_text: maior linha mede $_mx px na fonte do tema (tela do Brick: 1024)" || bad "screen_text: linha de $_mx px passa da tela"
  fi

  eq "urlenc UTF-8 + simbolos" "$(SH 'urlenc "Pokémon: Emerald & Co. (USA).gba"')" "Pok%C3%A9mon%3A%20Emerald%20%26%20Co.%20%28USA%29.gba"
  eq "fmt_size 0" "$(SH 'fmt_size 0')" "0 B"
  eq "fmt_size KB" "$(SH 'fmt_size 1536')" "2 KB"
  eq "fmt_size MB" "$(SH 'fmt_size 12940000')" "12.3 MB"
  eq "fmt_size GB" "$(SH 'fmt_size 3221225472')" "3.00 GB"
  eq "curlcfg_esc" "$(SH 'curlcfg_esc '"'"'p@ss"w\ord:1'"'"'')" 'p@ss\"w\\ord:1'

  for pair in "gba:gba:GBA" "genesis-slash-megadrive::MD" "turbografx16--1::PCE" "snes:snes:SFC" "psx:psx:PS" "nes::FC" ":Mega_Drive:MD" "sms::MS" "n64:n64:N64" "dc:dc:DC" "ngp::NGP" "wonderswan-color::WSC" "neo-geo-cd::NEOCD"; do
    slug=${pair%%:*}; rest=${pair#*:}; fs=${rest%%:*}; exp=${rest#*:}
    eq "mapa: slug=$slug fs=$fs -> $exp" "$(SH "plat_builtin '$slug' '$fs'")" "$exp"
  done
  for pair in "ngc:ngc" "arcade:arcade" "ps2:ps2" "wii:wii"; do
    slug=${pair%%:*}; fs=${pair#*:}
    eq "mapa: $slug fica sem pasta (app pergunta)" "$(SH "plat_builtin '$slug' '$fs'")" ""
  done
  # todas as pastas da tabela existem no CrossMix/JukaMix de verdade
  missing=$(awk -F'\t' '!/^#/ && NF==2 {print $2}' "$ROOT/Apps/RomMLibrary/data/platform_map.tsv" | sort -u | while read -r f; do [ -d "$ROOT/Roms/$f" ] || echo "$f"; done)
  eq "tabela: toda pasta existe em Roms/ do JukaMix" "$missing" ""

  # config com caracteres especiais
  eq "cfg round-trip (aspas e barra)" "$(SH "cfg_set username 'ped\"ro\\x'; cfg_get username")" 'ped"ro\x'
  eq "map round-trip" "$(SH "map_set arcade FBNEO; map_get arcade")" "FBNEO"
  SH 'map_set a B; map_clear; map_get a' | grep -q . && bad "map_clear" || ok "map_clear"
  printf '{quebrado' >"$SD/Data/romm/config.json"
  SH 'cfg_valid' && bad "cfg_valid aceita json quebrado" || ok "cfg_valid rejeita json quebrado"

  # toda variavel L_ usada no codigo existe nos dois idiomas
  export VARS
  VARS=$(grep -rhoE '\bL_[A-Z0-9_]+' "$ROOT"/Apps/RomMLibrary/lib/{common,net,platforms,download,screens}.sh | sort -u | tr '\n' ' ')
  cat >"$TMP/i18n_check.sh" <<'EOS'
lang_load "$LANGX"
for v in $VARS; do eval "x=\${$v}"; [ -n "$x" ] || echo "$LANGX:$v"; done
EOS
  export LANGX
  miss=""
  for LANGX in pt en; do miss="$miss$(SH ". $TMP/i18n_check.sh")"; done
  eq "i18n: textos usados existem em pt e en" "$miss" ""

  # explicacao de erros
  eq "erro 401" "$(SH 'net_explain 0 401; printf %s "$NET_ERR"')" "Login recusado: usuário/senha ou token incorretos."
  SH 'net_explain 7 000; printf %s "$NET_ERR"' | grep -q "servidor desligado" && ok "erro conexao recusada" || bad "erro conexao recusada"
  SH 'NET_HOST=100.101.2.3; host_is_tailnet' && ok "100.101.x e' tailnet" || bad "100.101.x e' tailnet"
  SH 'NET_HOST=192.168.0.2; host_is_tailnet' && bad "192.168 nao e' tailnet" || ok "192.168 nao e' tailnet"
  SH 'NET_HOST=nas.tail1234.ts.net; host_is_tailnet' && ok "*.ts.net e' tailnet" || bad "*.ts.net e' tailnet"
  end_scenario
fi

# ============================================================== PONTA A PONTA
if scenario "e2e-wizard-token-download"; then
  start_server; new_sd
  q vk "text:127.0.0.1:$PORT" "text:$TOKEN"
  q sel "contains:Token" "contains:Explorar" "contains:Game Boy Advance" "contains:Advançe" "contains:Baixar para"
  run_app
  eq "app terminou sem erro" "$RC" "0"
  eq "config: base_url normalizada" "$(jq -r .base_url "$CFGF")" "http://127.0.0.1:$PORT"
  eq "config: token salvo" "$(jq -r .token "$CFGF")" "$TOKEN"
  f="$SD/Roms/GBA/Advançe_ Emerald & Co. (USA).gba"
  check "ROM com : e & gravada com nome seguro" test -f "$f"
  eq "conteudo identico (sha256)" "$(sha_file "$f" 2>/dev/null)" "$(sha_of 1)"
  check "sem restos .rommpart/.state" sh -c "! ls '$SD/Roms/GBA'/.romm_* '$SD/Roms/GBA'/*.rommpart 2>/dev/null | grep -q ."
  check "requisicao usou Bearer" grep -q "auth=bearer" "$REQLOG"
  check "mensagem de sucesso mostrada" grep -q "Pronto! Salvo em" "$M/info.log"
  check "token nao vaza no log do app" sh -c "! grep -q 'rmm_' '$APPLOG'"
  check "log tem o rastro de inicio" grep -q "launch.sh iniciou" "$APPLOG"
  check "nenhum erro de script (selector/vk sem item)" sh -c "[ ! -s '$M/errors.log' ]"
  check "VirtualKeyboard recebeu o fundo certo" grep -q "bg=kb_url_pt.png" "$M/vk.log"
  end_scenario
fi

if scenario "e2e-legacy-paging-userpass"; then
  start_server --mode legacy; new_sd
  q vk "text:http://127.0.0.1:$PORT/" "text:pedro" "text:$PASSWD"
  q sel "contains:Usuário e senha" "contains:Explorar" "contains:Game Boy Advance" 'exact:>> Próxima página'
  run_app
  eq "app terminou sem erro" "$RC" "0"
  check "Basic aceito com senha cheia de simbolos" grep -q "auth=basic" "$REQLOG"
  check "pagina 1 traz 'Game 30'" grep -q "Game 30" "$M/sel.log"
  check "pagina 2 comeca em 'Game 31'" grep -q "Game 31" "$M/sel.log"
  check "servidor legado: sem opcao de letra" sh -c "! grep -q 'Ir para a letra' '$M/sel.log'"
  check "titulo mostra faixa 31-60 de 79" grep -q "31-60 de 79" "$M/sel.log"
  eq "senha guardada intacta" "$(jq -r .password "$CFGF")" "$PASSWD"
  end_scenario
fi

if scenario "e2e-oauth-fallback"; then
  start_server --mode basicfail; new_sd
  q vk "text:127.0.0.1:$PORT" "text:pedro" "text:$PASSWD"
  q sel "contains:Usuário e senha"
  run_app
  check "Basic recusado e OAuth tentado" grep -q "POST /api/token -> 200" "$REQLOG"
  check "depois usou Bearer" grep -q "GET /api/platforms.*auth=bearer" "$REQLOG"
  check "conectou" grep -q "Conectado!" "$M/info.log"
  end_scenario
fi

if scenario "e2e-wrong-password"; then
  start_server; new_sd
  q vk "text:127.0.0.1:$PORT" "text:pedro" "text:senha-errada"
  q sel "contains:Usuário e senha" "contains:Sair"
  run_app
  check "explica login recusado" grep -q "Login recusado" "$M/sel.log"
  end_scenario
fi

if scenario "e2e-server-down"; then
  start_server; new_sd
  write_cfg '{"base_url":"http://127.0.0.1:9","token":"x"}'
  q sel "contains:Sair"
  run_app
  eq "app terminou sem erro" "$RC" "0"
  check "explica servidor inacessivel" grep -q "Não consegui conectar (servidor desligado" "$M/sel.log"
  check "oferece tentar de novo e configuracoes" grep -q "Tentar de novo" "$M/sel.log"
  end_scenario
fi

if scenario "e2e-tailscale-hint"; then
  start_server; new_sd
  printf '#!/bin/sh\n[ "$1" = status ] && { echo "{\\"BackendState\\":\\"Stopped\\"}"; exit 0; }\nexit 1\n' >"$SD/System/bin/tailscale"; chmod +x "$SD/System/bin/tailscale"
  write_cfg '{"base_url":"http://100.101.2.3:9","token":"x"}'
  q sel "contains:Sair"
  run_app
  check "dica do Tailscale parado aparece" grep -q "Tailscale não está conectado" "$M/sel.log"
  end_scenario
fi

if scenario "e2e-magicdns-fallback"; then
  start_server; new_sd
  cat >"$SD/System/bin/tailscale" <<'EOF'
#!/bin/sh
case "$1" in
status) echo '{"BackendState":"Running","Self":{"TailscaleIPs":["100.64.0.9"]}}' ;;
ip) echo 127.0.0.1 ;;
esac
EOF
  chmod +x "$SD/System/bin/tailscale"
  write_cfg "{\"base_url\":\"http://nas-teste.ts.net:$PORT\",\"token\":\"$TOKEN\"}"
  q sel "contains:Explorar"
  run_app
  check "nome MagicDNS resolvido pelo Tailscale e platformas carregadas" grep -q "Game Boy Advance" "$M/sel.log"
  check "log registra o fallback de DNS" grep -q "resolvido via tailscale" "$APPLOG"
  end_scenario
fi

if scenario "e2e-download-bulkonly"; then
  start_server --mode bulkonly; new_sd; cfg_token
  q sel "contains:Explorar" "contains:Game Boy Advance" "contains:Advançe" "contains:Baixar para"
  run_app
  f="$SD/Roms/GBA/Advançe_ Emerald & Co. (USA).gba"
  eq "ROM chegou pela rota /api/roms/download (ZIP extraido)" "$(sha_file "$f" 2>/dev/null)" "$(sha_of 1)"
  check "tentou a rota 1 antes" grep -q "content/.* -> 404" "$REQLOG"
  check "sem pastas temporarias de extracao" sh -c "! ls -A '$SD/Roms/GBA' | grep -q '^.romm_'"
  end_scenario
fi

if scenario "e2e-download-filesonly"; then
  start_server --mode filesonly; new_sd; cfg_token
  q sel "contains:Explorar" "contains:Game Boy Advance" "contains:Advançe" "contains:Baixar para"
  run_app
  f="$SD/Roms/GBA/Advançe_ Emerald & Co. (USA).gba"
  eq "ROM chegou pela rota /api/romsfiles" "$(sha_file "$f" 2>/dev/null)" "$(sha_of 1)"
  end_scenario
fi

if scenario "e2e-multifile-ps1"; then
  start_server; new_sd; cfg_token
  q sel "contains:Explorar" "contains:PlayStation" "contains:Crash" "contains:Baixar para"
  run_app
  check "CUE na pasta PS (pasta do ZIP desembrulhada)" test -f "$SD/Roms/PS/Crash Test (PS1).cue"
  eq "BIN com o tamanho certo" "$(wc -c <"$SD/Roms/PS/Crash Test (PS1).bin" 2>/dev/null | tr -d ' ')" "499900"
  check "ZIP removido" sh -c "! ls -A '$SD/Roms/PS' | grep -qi 'zip'"
  check "sem restos de extracao" sh -c "! ls -A '$SD/Roms/PS' | grep -q '^.romm_'"
  end_scenario
fi

if scenario "e2e-flaky-resume"; then
  start_server --flaky; new_sd; cfg_token
  q sel "contains:Explorar" "contains:Game Boy Advance" "contains:Big Flaky" "contains:Baixar para" "contains:Baixar para"
  run_app
  check "queda detectada e explicada" grep -q "A conexão caiu" "$M/info.log"
  check "infoscreen recebeu 'conexão' em Latin-1 (1 byte), nao em UTF-8" env LC_ALL=C grep -q "A conex$(printf '\343')o caiu" "$M/info.raw"
  check "nenhum acento UTF-8 chegou ao infoscreen" bash -c "! LC_ALL=C grep -q \"$(printf '\303\243')\" '$M/info.raw'"
  check "servidor derrubou a conexao no meio" grep -q "DROPPED-HALFWAY" "$REQLOG"
  check "segunda tentativa retomou com Range" grep -Eq "range-from=[1-9][0-9]*" "$REQLOG"
  eq "arquivo final identico apos retomar" "$(sha_file "$SD/Roms/GBA/Big Flaky Adventure.gba" 2>/dev/null)" "$(sha_of 3)"
  check "sem restos" sh -c "! ls -A '$SD/Roms/GBA' | grep -Eq 'rommpart|^.romm_'"
  end_scenario
fi

if scenario "e2e-flaky-norange"; then
  start_server --flaky --norange; new_sd; cfg_token
  q sel "contains:Explorar" "contains:Game Boy Advance" "contains:Big Flaky" "contains:Baixar para" "contains:Baixar para"
  run_app
  eq "servidor sem Range: recomecou do zero e terminou certo" "$(sha_file "$SD/Roms/GBA/Big Flaky Adventure.gba" 2>/dev/null)" "$(sha_of 3)"
  end_scenario
fi

if scenario "e2e-cancel-and-resume"; then
  start_server --delay 0.05; new_sd; cfg_token
  q prog "timeout" "key:B"
  q sel "contains:Explorar" "contains:Game Boy Advance" "contains:Big Flaky" "contains:Baixar para" "contains:Baixar para"
  run_app
  check "parada pelo B explicada" grep -q "Download parado" "$M/info.log"
  check "progresso foi exibido" grep -Eq "Baixando" "$M/info.log"
  check "retomou depois (Range)" grep -Eq "range-from=[1-9][0-9]*" "$REQLOG"
  eq "arquivo final identico" "$(sha_file "$SD/Roms/GBA/Big Flaky Adventure.gba" 2>/dev/null)" "$(sha_of 3)"
  end_scenario
fi

if scenario "e2e-unmapped-asks-and-remembers"; then
  start_server; new_sd; cfg_token
  q sel "contains:Explorar" "contains:Arcade" "contains:Metal" "contains:Baixar para" "exact:FBNEO" "contains:Zed" "contains:Baixar para"
  run_app
  eq "ZIP de arcade fica intacto (nao e' extraido)" "$(sha_file "$SD/Roms/FBNEO/mslug.zip" 2>/dev/null)" "$(sha_of 80)"
  check "segundo jogo foi para a pasta lembrada" test -f "$SD/Roms/FBNEO/zedfight.zip"
  eq "perguntou a pasta so uma vez" "$(grep -c 'Em qual pasta' "$M/sel.log")" "1"
  eq "mapeamento salvo" "$(jq -r '.platform_map.arcade' "$CFGF")" "FBNEO"
  end_scenario
fi

if scenario "e2e-gamecube-cancel-folder"; then
  start_server; new_sd; cfg_token
  q sel "contains:Explorar" "contains:GameCube" "contains:Gamecube Thing" "contains:Baixar para"
  run_app
  check "avisa que nada foi baixado" grep -q "Nenhuma pasta escolhida" "$M/info.log"
  check "nada foi gravado em Roms/" sh -c "[ -z \"\$(find '$SD/Roms' -type f)\" ]"
  check "GameCube nao foi empurrado para a pasta NGC (Neo Geo Pocket Color)" sh -c "! grep -q '\"ngc\"' '$CFGF'"
  end_scenario
fi

if scenario "e2e-search-global"; then
  start_server; new_sd
  write_cfg "{\"base_url\":\"http://127.0.0.1:$PORT\",\"token\":\"$TOKEN\",\"platform_map\":{\"arcade\":\"FBNEO\"}}"
  q vk "text:metal"
  q sel "contains:Buscar jogo" "contains:Metal"
  run_app
  check "resultado mostra a plataforma [Arcade]" grep -q "Metal Slug \[Arcade\]" "$M/sel.log"
  check "detalhe mostra destino da pasta lembrada" grep -q "Destino: Roms/FBNEO" "$M/sel.log"
  end_scenario
fi

if scenario "e2e-letter-jump"; then
  start_server; new_sd; cfg_token
  q sel "contains:Explorar" "contains:Game Boy Advance" 'exact:[ Ir para a letra... ]' "exact:G"
  run_app
  check "salta para a letra G (4-33 de 79)" grep -q "4-33 de 79" "$M/sel.log"
  end_scenario
fi

if scenario "e2e-nospace"; then
  start_server; new_sd; cfg_token
  q sel "contains:Explorar" "contains:Game Boy Advance" "contains:Advançe" "contains:Baixar para"
  MOCK_FREE_KB=100 run_app
  check "avisa falta de espaco" grep -q "Sem espaço livre" "$M/info.log"
  check "falta de espaco: 'espaço' chegou em Latin-1" env LC_ALL=C grep -q "espa$(printf '\347')o" "$M/info.raw"
  check "nada gravado" sh -c "[ -z \"\$(find '$SD/Roms' -type f)\" ]"
  end_scenario
fi

if scenario "e2e-settings"; then
  start_server; new_sd; cfg_token
  q sel "contains:Configurações" "contains:Jogos por página" "contains:Aceitar certificado" "contains:Apagar downloads" "contains:Idioma" "cancel" "contains:Exit"
  run_app
  eq "page_size ciclou 30 -> 50" "$(jq -r .page_size "$CFGF")" "50"
  eq "idioma virou en" "$(jq -r .lang "$CFGF")" "en"
  eq "insecure ligado" "$(jq -r .insecure "$CFGF")" "1"
  check "menu passou a ingles" grep -q "Browse platforms" "$M/sel.log"
  end_scenario
fi

if scenario "e2e-bad-config-recovers"; then
  start_server; new_sd
  mkdir -p "$SD/Data/romm"; printf '{quebrado' >"$CFGF"
  q vk "text:127.0.0.1:$PORT" "text:$TOKEN"
  q sel "contains:Token"
  run_app
  check "config quebrada foi guardada como .bad" test -f "$CFGF.bad"
  check "assistente rodou e conectou" grep -q "Conectado!" "$M/info.log"
  end_scenario
fi

echo
echo "RESULTADO: $PASS ok, $FAIL falhas"
[ "$FAIL" -eq 0 ]
