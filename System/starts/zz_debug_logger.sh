#!/bin/sh
# Debug logger: snapshot /tmp/log/messages to SD every 5s
mkdir -p /mnt/SDCARD/Logs
(
  while true; do
    tail -n 300 /tmp/log/messages > /mnt/SDCARD/Logs/mainui.log 2>/dev/null
    sleep 5
  done
) &
