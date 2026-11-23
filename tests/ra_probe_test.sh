#!/usr/bin/env bash
# Off-device checks for System/usr/trimui/scripts/ra_probe.sh (the RetroArch launch sidecar).
# Usage: bash tests/ra_probe_test.sh     Needs: bash, sh (dash/ash), a Linux /proc.
#
# Real processes cover the normal path; a fabricated /proc tree covers the
# "thread stuck in state D" path (which cannot be produced on demand) with a fake strace.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROBE=$ROOT/System/usr/trimui/scripts/ra_probe.sh
T=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$T"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
has() { # <label> <file> <pattern>
    if grep -qE -- "$3" "$2"; then ok "$1"; else bad "$1  (pattern: $3)"; fi
}
hasnt() { # <label> <file> <pattern>
    if grep -qE -- "$3" "$2"; then bad "$1  (unexpected: $3)"; else ok "$1"; fi
}

mkdir -p "$T/sd/RetroArch/.retroarch/playlists" "$T/sd/System/logs" "$T/tmp"
printf 'menu_driver = "xmb"\naudio_driver = "oss"\n' >"$T/sd/RetroArch/retroarch.cfg"

export JUKAMIX_SDCARD=$T/sd
export JUKAMIX_TMP=$T/tmp
export JUKAMIX_RA_PROBE_INTERVAL=1

# ---- 1. real process: found, sampled, and noticed when it exits ----------------------
BIN=ra64.trimui_tsp_9.9.9.bin
cat >"$T/sd/RetroArch/$BIN" <<'EOF'
#!/bin/sh
# stand-in for RetroArch: burns a little CPU, then exits
end=$(( $(date +%s) + 4 ))
while [ "$(date +%s)" -lt "$end" ]; do ls / >/dev/null; done
EOF
chmod +x "$T/sd/RetroArch/$BIN"

LOG=$T/sd/System/logs/ra_probe.log
"$T/sd/RetroArch/$BIN" &
JUKAMIX_RA_PROBE_SECONDS=30 JUKAMIX_RA_PROBE_FIND_SECONDS=5 JUKAMIX_STRACE=$T/none \
    sh "$PROBE" "$BIN"
has "real: header names the binary" "$LOG" "==== ra_probe .*binary=$BIN"
has "real: records retroarch.cfg drivers" "$LOG" 'retroarch.cfg: menu_driver = xmb;audio_driver = oss'
has "real: sample with load" "$LOG" '^-- t=\+0s .*load: '
has "real: process line" "$LOG" 'process: .*State:'
has "real: per-thread line" "$LOG" '   thread [0-9]+ \(.*\) state=. cpu_ticks=[0-9]+'
has "real: cpu total" "$LOG" 'cpu total: [0-9]+ ticks'
has "real: open descriptors" "$LOG" 'open descriptors: [0-9]+'
has "real: notices the exit" "$LOG" 'RetroArch exited'
hasnt "real: no strace for a healthy run" "$LOG" 'strace:'

# ---- 2. the process never appears -----------------------------------------------------
: >"$LOG"
JUKAMIX_RA_PROBE_FIND_SECONDS=2 sh "$PROBE" ra64.trimui_does_not_exist.bin
has "missing: says so and stops" "$LOG" 'process not found after 2s'

# ---- 3. the probe does not match itself ------------------------------------------------
: >"$LOG"
JUKAMIX_RA_PROBE_FIND_SECONDS=2 sh "$PROBE" "$BIN" &
sleep 1
JUKAMIX_RA_PROBE_FIND_SECONDS=2 sh "$PROBE" "$BIN"
wait
hasnt "self: never mistakes a probe for RetroArch" "$LOG" 'binary=.* pid='

# ---- 4. log rotation --------------------------------------------------------------------
head -c 300000 /dev/zero | tr '\0' 'x' >"$LOG"
printf '\nTAIL-MARKER\n' >>"$LOG"
JUKAMIX_RA_PROBE_FIND_SECONDS=1 sh "$PROBE" ra64.trimui_does_not_exist.bin
size=$(wc -c <"$LOG")
if [ "$size" -lt 200000 ]; then ok "rotate: oversized log is trimmed ($size bytes)"; else bad "rotate: log still $size bytes"; fi
has "rotate: keeps the newest part" "$LOG" 'TAIL-MARKER'

# ---- 5. thread stuck in state D: fabricated /proc + fake strace -------------------------
P=$T/proc
mkdir -p "$P/4321/task/4321" "$P/4321/task/4322" "$P/4321/fd"
printf '%s\0' "$T/sd/RetroArch/$BIN" >"$P/4321/cmdline"
printf 'Name:\tra64.trimui_tsp\nState:\tD (disk sleep)\nThreads:\t2\nVmRSS:\t  54321 kB\n' >"$P/4321/status"
printf 'io_schedule' >"$P/4321/wchan"
printf '0 0x3 0x0\n' >"$P/4321/syscall"
printf '4321 (ra64.trimui_tsp) D 1 1 1 0 -1 4194560 100 0 0 0 3000 1700 0 0 20 0 2 0 100 1000 100 18446744073709551615\n' >"$P/4321/task/4321/stat"
printf '4322 (task thread) S 1 1 1 0 -1 4194560 100 0 0 0 20 10 0 0 20 0 2 0 100 1000 100 18446744073709551615\n' >"$P/4321/task/4322/stat"
printf 'io_schedule' >"$P/4321/task/4321/wchan"
ln -s "$T/sd/Roms/PS/big.cue" "$P/4321/fd/7"
ln -s "$T/sd/Roms/PS/big.cue" "$P/4321/fd/8"
ln -s "$T/sd/RetroArch/.retroarch/playlists/History.lpl" "$P/4321/fd/9"
printf '0.5 0.5 0.5 1/100 99\n' >"$P/loadavg"
printf 'MemFree: 700000 kB\nDirty: 120 kB\nWriteback: 0 kB\n' >"$P/meminfo"
printf '   179       0 mmcblk1 100 0 8000 50 20 0 640 10 0 40 60\n' >"$P/diskstats"

cat >"$T/fake_strace" <<'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do
    case "$1" in -o) out=$2; shift ;; esac
    shift
done
printf '12:00:00.100 openat(AT_FDCWD, "/mnt/SDCARD/Roms/PS/big.cue", O_RDONLY) = 7 <0.000100>\n' >"$out"
printf '12:00:00.200 read(7, "", 4096) = 0 <1.500000>\n' >>"$out"
sleep 60
EOF
chmod +x "$T/fake_strace"

: >"$LOG"
JUKAMIX_PROC=$P JUKAMIX_RA_PROBE_SECONDS=5 JUKAMIX_RA_PROBE_FIND_SECONDS=2 JUKAMIX_STRACE=$T/fake_strace \
    sh "$PROBE" "$BIN"
has "D: finds the process in the fake /proc" "$LOG" 'pid=4321'
has "D: thread in D shows its wchan" "$LOG" 'state=D cpu_ticks=4700 wchan=io_schedule'
has "D: CPU ticks add up over threads" "$LOG" 'cpu total: 4730 ticks \(about 47 s'
has "D: open files are counted and grouped" "$LOG" '2 .*big\.cue'
has "D: wchan and syscall recorded" "$LOG" 'wchan=io_schedule syscall=0 0x3 0x0'
has "D: disk counters recorded" "$LOG" 'diskstats mmcblk1: .*mmcblk1 100'
has "D: strace runs after two samples in D" "$LOG" 'strace: attaching'
has "D: strace output is logged" "$LOG" 'strace: 2 lines captured'
has "D: most-touched paths summarised" "$LOG" '1 +"/mnt/SDCARD/Roms/PS/big.cue"'
has "D: probe ends after its time budget" "$LOG" 'probe finished after 5s'
if pgrep -f "$T/fake_strace" >/dev/null; then bad "D: fake strace was left running"; else ok "D: strace is stopped again"; fi

# ---- 6. flag file asks for strace even without a D state ----------------------------
sed -i 's/ D 1 1 1/ S 1 1 1/' "$P/4321/task/4321/stat"
mkdir -p "$T/sd/System/etc"
: >"$T/sd/System/etc/ra_strace"
: >"$LOG"
JUKAMIX_PROC=$P JUKAMIX_RA_PROBE_SECONDS=17 JUKAMIX_RA_PROBE_FIND_SECONDS=2 JUKAMIX_STRACE=$T/fake_strace \
    JUKAMIX_RA_PROBE_INTERVAL=5 sh "$PROBE" "$BIN"
has "flag: strace requested by System/etc/ra_strace" "$LOG" 'strace: attaching'
rm -f "$T/sd/System/etc/ra_strace"

# ---- 6b. main thread blocked in a force-feedback upload (the field failure) -------------
# aarch64 syscall 29 = ioctl, 0x40304580 = EVIOCSFF, fd 12 = a uinput-backed pad
sed -i 's/ S 1 1 1/ D 1 1 1/' "$P/4321/task/4321/stat"
printf 'uinput_request_submit.part.1' >"$P/4321/wchan"
printf '29 0xc 0x40304580 0xb3761d0 0x435 0xb376200 0x0 0x7fec367830 0x7f9a26bd90\n' >"$P/4321/syscall"
ln -s /dev/input/event3 "$P/4321/fd/12"
ln -s /dev/input/event0 "$P/4321/fd/11"
mkdir -p "$P/bus/input" "$P/2272/fd" "$T/sd/trimui/app" "$T/sd/System/resources"
cat >"$P/bus/input/devices" <<'EOF'
I: Bus=0019 Vendor=0001 Product=0001 Version=0100
N: Name="axp2202-pek"
H: Handlers=kbd event0
B: EV=3

I: Bus=0003 Vendor=045e Product=028e Version=0110
N: Name="Microsoft X-Box 360 pad"
P: Phys=
H: Handlers=js0 event3
B: EV=20000b
B: FF=100040000 0
EOF
ln -s /dev/uinput "$P/2272/fd/5"
printf 'trimui_inputd\n' >"$P/2272/comm"
ln -s /mnt/SDCARD/trimui/app/trimui_inputd "$P/2272/exe"
head -c 41144 /dev/zero >"$T/sd/trimui/app/trimui_inputd"
head -c 26912 /dev/zero >"$T/sd/System/resources/tsp_inputd"
: >"$LOG"
JUKAMIX_PROC=$P JUKAMIX_RA_PROBE_SECONDS=6 JUKAMIX_RA_PROBE_FIND_SECONDS=2 JUKAMIX_STRACE=$T/fake_strace \
    JUKAMIX_RA_PROBE_INTERVAL=2 sh "$PROBE" "$BIN"
has "FF: says the thread waits in the uinput request" "$LOG" 'wchan=uinput_request_submit'
has "FF: recognises EVIOCSFF and the fd" "$LOG" 'blocked in EVIOCSFF .* on fd 12'
has "FF: resolves the fd to the event node" "$LOG" 'fd 12 -> /dev/input/event3'
has "FF: names the pad behind that node" "$LOG" 'N: Name="Microsoft X-Box 360 pad"'
has "FF: shows the pad advertises force feedback" "$LOG" 'B: FF=100040000'
hasnt "FF: leaves out the unrelated device block" "$LOG" 'H: Handlers=kbd event0'
has "FF: lists who holds /dev/uinput" "$LOG" 'pid 2272 \(trimui_inputd\) fd 5'
has "FF: reports the installed daemon size" "$LOG" 'installed input daemon: 41144 bytes'
has "FF: reports the shipped daemon size" "$LOG" 'resources/tsp_inputd: 26912 bytes'
n=$(grep -c 'blocked in EVIOCSFF' "$LOG")
if [ "$n" = 1 ]; then ok "FF: the input context is logged once, not every sample"; else bad "FF: input context logged $n times"; fi
sed -i 's/ D 1 1 1/ S 1 1 1/' "$P/4321/task/4321/stat"
printf 'io_schedule' >"$P/4321/wchan"
printf '0 0x3 0x0\n' >"$P/4321/syscall"

# ---- 6c. real time: a sleep that returns early must not shorten the probe ---------------
# stub sleep: every odd call returns at once (the busybox-ash behaviour seen on the device),
# every even call "sleeps" one second by moving the fake uptime forward
mkdir -p "$T/bin"
printf '100.00 200.00\n' >"$P/uptime"
: >"$T/sleep_calls"
cat >"$T/bin/sleep" <<EOF2
#!/bin/sh
echo "\$1" >>"$T/sleep_calls"
n=\$(wc -l <"$T/sleep_calls")
if [ \$((n % 2)) -eq 0 ]; then
    read -r up rest <"$P/uptime"
    printf '%s.00 %s\n' \$((\${up%%.*} + 1)) "\$rest" >"$P/uptime"
fi
EOF2
chmod +x "$T/bin/sleep"
: >"$LOG"
PATH=$T/bin:$PATH JUKAMIX_PROC=$P JUKAMIX_RA_PROBE_SECONDS=6 JUKAMIX_RA_PROBE_FIND_SECONDS=2 \
    JUKAMIX_STRACE=$T/none JUKAMIX_RA_PROBE_INTERVAL=3 sh "$PROBE" "$BIN"
has "time: first sample at +0 s" "$LOG" '^-- t=\+0s .*uptime=100'
has "time: second sample after 3 real seconds" "$LOG" '^-- t=\+3s .*uptime=103'
has "time: ends after 6 real seconds" "$LOG" 'probe finished after 6s'
calls=$(wc -l <"$T/sleep_calls")
if [ "$calls" -ge 12 ]; then ok "time: retried the early-returning sleep ($calls calls for 6 s)"; else bad "time: only $calls sleep calls"; fi

# ---- 7. the launcher hooks the probe in and stays valid POSIX sh --------------------------
grep -q 'ra_probe.sh' "$ROOT/Apps/RetroArch/launch.sh" && ok "launch.sh starts the probe" || bad "launch.sh does not start the probe"
last=$(tail -n 1 "$ROOT/Apps/RetroArch/launch.sh")
[ "$last" = 'HOME="$RA_DIR/" "$RA_DIR/$SELECTED_FILE"' ] && ok "launch.sh still ends by running RetroArch in the foreground" || bad "launch.sh last line changed: $last"
for sh in dash sh; do
    command -v "$sh" >/dev/null 2>&1 || continue
    "$sh" -n "$PROBE" && "$sh" -n "$ROOT/Apps/RetroArch/launch.sh" && ok "$sh -n accepts both scripts" || bad "$sh -n rejects a script"
done
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -s sh "$PROBE" && ok "shellcheck clean" || bad "shellcheck findings"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
