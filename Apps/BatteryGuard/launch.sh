#!/bin/sh
mkdir -p /mnt/SDCARD/Data/batteryguard
echo "executed $(date)" > /mnt/SDCARD/Data/batteryguard/test.txt
sync
exit 0
