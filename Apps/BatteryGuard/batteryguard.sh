#!/bin/sh
APP_DIR="/mnt/SDCARD/Apps/BatteryGuard"
CONFIG="$APP_DIR/config.json"
LOG="/mnt/SDCARD/Data/batteryguard/battery.log"

mkdir -p "$(dirname "$LOG")"

warning="$(jq -r '.warning // 20' "$CONFIG")"
critical="$(jq -r '.critical // 10' "$CONFIG")"
interval="$(jq -r '.interval_seconds // 60' "$CONFIG")"

echo "Battery Guard iniciado."
echo "Aviso: $warning% | Critico: $critical% | Intervalo: ${interval}s"
echo "Ctrl+C para sair."

while :; do
  capacity=""

  for supply in /sys/class/power_supply/*; do
    if [ -f "$supply/capacity" ]; then
      capacity="$(cat "$supply/capacity" 2>/dev/null)"
      break
    fi
  done

  if [ -n "$capacity" ]; then
    now="$(date +%Y-%m-%d_%H:%M:%S)"
    echo "$now,$capacity" >> "$LOG"

    if [ "$capacity" -le "$critical" ]; then
      echo "ALERTA CRITICO: bateria em $capacity%. Salve o progresso e carregue o console."
    elif [ "$capacity" -le "$warning" ]; then
      echo "AVISO: bateria em $capacity%."
    else
      echo "Bateria: $capacity%"
    fi
  else
    echo "Nao foi possivel ler a bateria."
  fi

  sleep "$interval"
done
