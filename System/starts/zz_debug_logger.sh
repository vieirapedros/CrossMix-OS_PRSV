#!/bin/sh
# Debug logger: snapshot /tmp/log/messages and mount options to SD
mkdir -p /mnt/SDCARD/Logs
mount > /mnt/SDCARD/Logs/mount.txt 2>&1
(
  while true; do
    tail -n 300 /tmp/log/messages > /mnt/SDCARD/Logs/mainui.log 2>/dev/null
    sleep 5
  done
) &
