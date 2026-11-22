#!/bin/sh
# RomM Library - platforms.sh: plataforma do RomM -> pasta de Roms/ do CrossMix/JukaMix.
# Ordem: 1) pasta lembrada no config.json  2) data/platform_map.tsv  3) pergunta ao usuario e lembra.

plat_norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9'; }

plat_key() { # pid slug fs_slug -> chave estavel para lembrar a escolha
  if [ -n "$3" ]; then printf '%s' "$3"; elif [ -n "$2" ]; then printf '%s' "$2"; else printf 'id%s' "$1"; fi
}

plat_builtin() { # slug fs_slug -> pasta (ou nada)
  for _pk in "$2" "$1"; do
    _pn=$(plat_norm "$_pk")
    [ -n "$_pn" ] || continue
    _pf=$(awk -F'\t' -v k="$_pn" '!/^#/ && $1 == k { print $2; exit }' "$APP_DIR/data/platform_map.tsv")
    if [ -n "$_pf" ]; then printf '%s' "$_pf"; return 0; fi
  done
  return 1
}

plat_folder() { # pid slug fs_slug -> pasta ou vazio (nao pergunta nada)
  _pm=$(map_get "$(plat_key "$1" "$2" "$3")")
  if [ -n "$_pm" ]; then printf '%s' "$_pm"; return 0; fi
  plat_builtin "$2" "$3"
}

plat_ask_folder() { # pid slug fs_slug -> pasta escolhida (lembrada) ou vazio
  _pak=$(plat_key "$1" "$2" "$3") # antes do "set --" abaixo, que sobrescreve $1 $2 $3
  _pa="$TMPD/roms_dirs.txt"
  : >"$_pa"
  for _pd in "$ROMS_DIR"/*; do
    [ -d "$_pd" ] || continue
    basename "$_pd" >>"$_pa"
  done
  set --
  while IFS= read -r _pl; do
    [ -n "$_pl" ] && set -- "$@" "$_pl"
  done <"$_pa"
  [ "$#" -gt 0 ] || return 1
  _pc=$(ui_choose "$L_ASK_FOLDER" "$@")
  [ -n "$_pc" ] || return 1
  [ -d "$ROMS_DIR/$_pc" ] || return 1
  map_set "$_pak" "$_pc"
  log "mapeamento: $_pak -> $_pc"
  printf '%s' "$_pc"
}
