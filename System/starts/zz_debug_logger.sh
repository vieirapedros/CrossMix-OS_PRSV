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

# Test TestApp launch.sh directly (once, 20s after boot)
(
  sleep 20
  /mnt/SDCARD/Apps/TestApp/launch.sh > /mnt/SDCARD/Logs/launch_test.log 2>&1
  echo "exit_code=$?" >> /mnt/SDCARD/Logs/launch_test.log
) &
