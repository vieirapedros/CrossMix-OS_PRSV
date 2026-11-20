#!/bin/sh
# Debug logger: snapshot /tmp/log/messages and mount options to SD
mkdir -p /mnt/SDCARD/Logs
mount > /mnt/SDCARD/Logs/mount.txt 2>&1
(
  while true; do
    tail -n 300 /tmp/log/messages > /mnt/SDCARD/Logs/mainui.log 2>/dev/null
    if [ -f /tmp/cmd_to_run.sh ]; then
      cp /tmp/cmd_to_run.sh /mnt/SDCARD/Logs/cmd_to_run_snapshot.txt 2>/dev/null
    fi
    sleep 2
  done
) &

# Extract MainUI launch-related strings
{
  echo "=== MainUI binary location ==="
  ls -la /usr/trimui/bin/MainUI 2>&1
  echo "=== Launch-related strings ==="
  /mnt/SDCARD/System/bin/strings /usr/trimui/bin/MainUI 2>/dev/null | grep -iE "launch|cmd_to_run|/mnt/SDCARD/Apps|system\\(" | head -n 100
} > /mnt/SDCARD/Logs/mainui_strings.txt 2>&1

# Test TestApp launch.sh directly
{
  echo "=== Running launch.sh ==="
  /mnt/SDCARD/Apps/TestApp/launch.sh
  echo "exit_code=$?"
} > /mnt/SDCARD/Logs/launch_test.log 2>&1
