#!/bin/sh
SDCARD="/mnt/SDCARD"
DATA="$SDCARD/Data/gamecenter"
FAVORITES="$DATA/favorites.txt"
RECENT="$DATA/recent.log"
PLAYTIME="$DATA/playtime.csv"

mkdir -p "$DATA"
touch "$FAVORITES" "$RECENT" "$PLAYTIME"

while :; do
  echo ""
  echo "===== Smart Pro Game Center ====="
  echo "1) Favoritos"
  echo "2) Adicionar favorito"
  echo "3) Remover favorito"
  echo "4) Jogos recentes"
  echo "5) Registrar tempo de jogo"
  echo "0) Sair"
  printf "Opcao: "
  read -r choice

  case "$choice" in
    1)
      echo "--- Favoritos ---"
      cat "$FAVORITES"
      ;;
    2)
      printf "Caminho da ROM: "
      read -r rom
      [ -n "$rom" ] && echo "$rom" >> "$FAVORITES"
      ;;
    3)
      printf "Caminho exato da ROM: "
      read -r rom
      grep -v -F -x "$rom" "$FAVORITES" > "$FAVORITES.tmp" 2>/dev/null || true
      mv "$FAVORITES.tmp" "$FAVORITES"
      ;;
    4)
      echo "--- Recentes ---"
      tail -n 20 "$RECENT"
      ;;
    5)
      printf "Caminho da ROM: "
      read -r rom
      printf "Minutos jogados: "
      read -r minutes
      printf '%s,%s\n' "$(date +%Y-%m-%d_%H:%M:%S)" "$minutes" >> "$PLAYTIME"
      echo "$rom" >> "$RECENT"
      sync
      ;;
    0) exit 0 ;;
    *) echo "Opcao invalida" ;;
  esac
done
