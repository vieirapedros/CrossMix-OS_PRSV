#!/bin/sh
while :; do
  echo ""
  echo "===== Wi-Fi Tools ====="
  echo "1) Status de rede"
  echo "2) Ping 8.8.8.8"
  echo "3) Testar DNS"
  echo "4) Testar RomM"
  echo "0) Sair"
  printf "Opcao: "
  read -r choice

  case "$choice" in
    1)
      if command -v ip >/dev/null 2>&1; then
        ip addr show
      elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig
      else
        echo "Comando de rede nao disponivel."
      fi
      ;;
    2)
      ping -c 4 8.8.8.8
      ;;
    3)
      if command -v nslookup >/dev/null 2>&1; then
        nslookup github.com
      else
        curl -fsSI https://github.com >/dev/null 2>&1 && echo "DNS OK" || echo "DNS falhou"
      fi
      ;;
    4)
      if [ -f /mnt/SDCARD/Apps/RomMLibrary/config.json ]; then
        url="$(jq -r '.url' /mnt/SDCARD/Apps/RomMLibrary/config.json)"
        curl -fsSI "$url" >/dev/null 2>&1 && echo "RomM acessivel: $url" || echo "RomM inacessivel: $url"
      else
        echo "RomM Library nao esta configurado."
      fi
      ;;
    0) exit 0 ;;
    *) echo "Opcao invalida" ;;
  esac
done
