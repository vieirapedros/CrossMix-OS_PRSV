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

# Check both SD and UDISK app dirs
{
  echo "=== SD trimui/app ==="
  ls -la /mnt/SDCARD/trimui/app/ 2>&1
  echo "=== UDISK trimui/app ==="
  ls -la /mnt/UDISK/trimui/app/ 2>&1
  echo "=== UDISK cmd_to_run.sh ==="
  cat /mnt/UDISK/trimui/app/cmd_to_run.sh 2>&1
} > /mnt/SDCARD/Logs/udisk_app.txt 2>&1

# Test TestApp launch.sh directly
{
  echo "=== Running launch.sh ==="
  /mnt/SDCARD/Apps/TestApp/launch.sh
  echo "exit_code=$?"
} > /mnt/SDCARD/Logs/launch_test.log 2>&1
