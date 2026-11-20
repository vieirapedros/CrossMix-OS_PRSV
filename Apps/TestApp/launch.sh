#!/bin/sh
mkdir -p /mnt/SDCARD/Data/testapp
echo "executed $(date)" > /mnt/SDCARD/Data/testapp/test.txt
sync
exit 0
