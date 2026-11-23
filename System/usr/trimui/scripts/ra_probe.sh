#!/bin/sh
# Sidecar for Apps -> RetroArch: records what the RetroArch process is doing, so a
# "stuck on the loading screen" run leaves evidence on the card even if the console
# has to be power-cycled.
#
#   ra_probe.sh <binary-name>        (started in the background by Apps/RetroArch/launch.sh)
#
# Every few seconds (default 5 s, for up to 240 s of real time, or until RetroArch exits) it
# appends to System/logs/ra_probe.log: process state, CPU per thread, what each blocked
# thread is waiting on (wchan), the files RetroArch has open, I/O counters and load.
# When the main thread is blocked in a force-feedback upload (ioctl EVIOCSFF) it also logs
# which input device that is, which process owns /dev/uinput and the installed input daemon.
# If a thread stays in uninterruptible sleep (state D) for two samples in a row, or if the
# file System/etc/ra_strace exists, it also attaches strace for a few seconds and logs the
# files/descriptors RetroArch is touching.
#
# It only reads /proc, never signals RetroArch, and never blocks the launcher.
#
# Off-device (tests) the roots can be redirected:
#   JUKAMIX_SDCARD JUKAMIX_LOGDIR JUKAMIX_PROC JUKAMIX_TMP JUKAMIX_RA_DIR JUKAMIX_STRACE
#   JUKAMIX_RA_PROBE_SECONDS JUKAMIX_RA_PROBE_INTERVAL JUKAMIX_RA_PROBE_FIND_SECONDS

# shellcheck disable=SC2009,SC2012  # ps/ls are only read for human-oriented log lines
SDCARD=${JUKAMIX_SDCARD:-/mnt/SDCARD}
LOGDIR=${JUKAMIX_LOGDIR:-$SDCARD/System/logs}
PROC=${JUKAMIX_PROC:-/proc}
TMP=${JUKAMIX_TMP:-/tmp}
RA_DIR=${JUKAMIX_RA_DIR:-$SDCARD/RetroArch}
STRACE=${JUKAMIX_STRACE:-$SDCARD/System/bin/strace}
DURATION=${JUKAMIX_RA_PROBE_SECONDS:-240}
INTERVAL=${JUKAMIX_RA_PROBE_INTERVAL:-5}
FIND_SECONDS=${JUKAMIX_RA_PROBE_FIND_SECONDS:-15}
MAX_LOG_BYTES=262144
KEEP_LOG_BYTES=131072

bin=${1:-ra64.trimui}
target=$RA_DIR/$bin
LOG=$LOGDIR/ra_probe.log

mkdir -p "$LOGDIR" 2>/dev/null || exit 0

# Keep the log from growing without bound: drop the oldest half once it is too big.
if [ -f "$LOG" ]; then
    size=$(wc -c <"$LOG" 2>/dev/null || echo 0)
    if [ "${size:-0}" -gt "$MAX_LOG_BYTES" ]; then
        tail -c "$KEEP_LOG_BYTES" "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
    fi
fi

log() { printf '%s\n' "$*" >>"$LOG"; }
stamp() { date '+%Y-%m-%d %H:%M:%S'; }
flush() { sync >/dev/null 2>&1 & }

# Whole seconds since boot, from /proc/uptime (not affected by the clock being set by ntp).
uptime_s() {
    [ -r "$PROC/uptime" ] || return 1
    read -r up _ <"$PROC/uptime" || return 1
    up=${up%%.*}
    case "$up" in
        '' | *[!0-9]*) return 1 ;;
    esac
    printf '%s' "$up"
}

# Wait <seconds> of real time.  A single `sleep` is not enough on the console: the
# background `sync` started by flush() ends while the shell sleeps, and with the busybox
# ash `sleep` that returns at once, so a "240 s" probe lasted 15 s in the first field log.
nap() {
    start=$(uptime_s) || {
        sleep "$1"
        return 0
    }
    end=$((start + $1))
    while now=$(uptime_s) && [ "$now" -lt "$end" ]; do
        sleep 1
    done
    return 0
}

# PID whose first two arguments name the RetroArch binary (argv[0] for the real ELF
# binary; argv[1] when it is run through an interpreter, as the tests do).
find_pid() {
    for d in "$PROC"/[0-9]*; do
        [ -r "$d/cmdline" ] || continue
        args=$(tr '\0' '\n' <"$d/cmdline" 2>/dev/null | head -n 2)
        case "
$args
" in
            *"
$target
"*)
                printf '%s' "${d##*/}"
                return 0
                ;;
        esac
    done
    return 1
}

# One line per thread: tid, name, state, CPU ticks (utime+stime) and, for threads that
# are not running or sleeping normally, the kernel function they wait in.
threads() { # <pid>
    tpid=$1
    total=0
    anyd=0
    for t in "$PROC/$tpid"/task/[0-9]*; do
        [ -r "$t/stat" ] || continue
        stat=$(cat "$t/stat" 2>/dev/null) || continue
        name=${stat#*(}
        name=${name%)*}
        rest=${stat##*) }
        # shellcheck disable=SC2086
        set -- $rest
        state=$1
        ticks=$((${12:-0} + ${13:-0}))
        total=$((total + ticks))
        extra=
        if [ "$state" = "D" ]; then
            anyd=1
            extra=" wchan=$(cat "$t/wchan" 2>/dev/null)"
        fi
        log "   thread ${t##*/} ($name) state=$state cpu_ticks=$ticks$extra"
    done
    THREAD_TICKS=$total
    THREAD_ANY_D=$anyd
}

open_files() { # <pid>
    n=0
    for f in "$PROC/$1"/fd/*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        n=$((n + 1))
    done
    log "   open descriptors: $n (most common targets below)"
    for f in "$PROC/$1"/fd/*; do
        readlink "$f" 2>/dev/null
    done | sort | uniq -c | sort -rn | head -n 25 | sed 's/^/     /' >>"$LOG"
}

strace_burst() { # <pid> <seconds>
    if [ ! -x "$STRACE" ]; then
        log "   strace: not available ($STRACE)"
        return
    fi
    out=$TMP/ra_probe_strace.$$
    log "   strace: attaching for $2 s (files and descriptors only)"
    "$STRACE" -f -tt -T -s 100 -e trace=file,desc -o "$out" -p "$1" >/dev/null 2>&1 &
    spid=$!
    sleep "$2"
    # A background job of a non-interactive shell ignores SIGINT, so ask with TERM (strace
    # detaches cleanly on it) and fall back to KILL, which also detaches the tracee.
    kill -TERM "$spid" 2>/dev/null
    sleep 1
    kill -KILL "$spid" 2>/dev/null
    if [ -s "$out" ]; then
        lines=$(wc -l <"$out")
        log "   strace: $lines lines captured; first 40 and last 40 follow"
        head -n 40 "$out" | sed 's/^/     | /' >>"$LOG"
        log "     | ..."
        tail -n 40 "$out" | sed 's/^/     | /' >>"$LOG"
        log "   strace: paths touched most often"
        grep -o '"[^"]*"' "$out" | sort | uniq -c | sort -rn | head -n 20 | sed 's/^/     /' >>"$LOG"
    else
        log "   strace: no output (the process was most likely blocked inside a system call)"
    fi
    rm -f "$out"
}

# Which input device is the blocked thread talking to, and who is on the other end?
input_context() { # <pid> <fd>
    log "   --- blocked in EVIOCSFF (force-feedback upload) on fd $2 ---"
    tgt=$(readlink "$PROC/$1/fd/$2" 2>/dev/null)
    log "   fd $2 -> ${tgt:-unknown}"
    ev=${tgt##*/}
    if [ -r "$PROC/bus/input/devices" ] && [ -n "$ev" ]; then
        awk -v ev="$ev" '
            /^$/ { if (hit) printf "%s", blk; blk = ""; hit = 0; next }
            /^(I|N|P|H|B: EV|B: FF)/ { blk = blk "     " $0 "\n" }
            /^H: Handlers/ { h = $0 " "; if (index(h, "=" ev " ") || index(h, " " ev " ")) hit = 1 }
            END { if (hit) printf "%s", blk }
        ' "$PROC/bus/input/devices" 2>/dev/null >>"$LOG"
    fi
    log "   input devices known to the kernel:"
    grep -E '^N: Name' "$PROC/bus/input/devices" 2>/dev/null | sed 's/^/     /' >>"$LOG"
    log "   processes holding /dev/uinput open:"
    for f in "$PROC"/[0-9]*/fd/*; do
        case "$(readlink "$f" 2>/dev/null)" in
            *uinput*)
                p=${f#"$PROC"/}
                p=${p%%/*}
                log "     pid $p ($(cat "$PROC/$p/comm" 2>/dev/null)) fd ${f##*/} exe=$(readlink "$PROC/$p/exe" 2>/dev/null)"
                ;;
        esac
    done
    inputd=$SDCARD/trimui/app/trimui_inputd
    log "   installed input daemon: $(wc -c 2>/dev/null <"$inputd") bytes crc32=$(crc32 "$inputd" 2>/dev/null | head -n 1)"
    for r in tsp tsps; do
        [ -f "$SDCARD/System/resources/${r}_inputd" ] && log "   resources/${r}_inputd: $(wc -c <"$SDCARD/System/resources/${r}_inputd") bytes crc32=$(crc32 "$SDCARD/System/resources/${r}_inputd" 2>/dev/null | head -n 1)"
    done
    log "   --- end of input context ---"
}

sample() { # <pid> <elapsed>
    pid=$1
    log "-- t=+${2}s $(stamp)  uptime=$(cut -d' ' -f1 "$PROC/uptime" 2>/dev/null)  load: $(cat "$PROC/loadavg" 2>/dev/null)"
    log "   $(grep -E '^(MemFree|Dirty|Writeback):' "$PROC/meminfo" 2>/dev/null | tr -s ' ' | tr '\n' ' ')"
    disk=$(grep ' mmcblk1 ' "$PROC/diskstats" 2>/dev/null | head -n 1 | tr -s ' ')
    [ -n "$disk" ] && log "   diskstats mmcblk1: $disk"
    log "   process: $(grep -E '^(State|Threads|VmRSS):' "$PROC/$pid/status" 2>/dev/null | tr -s ' \t' ' ' | tr '\n' ' ')"
    sc=$(cat "$PROC/$pid/syscall" 2>/dev/null)
    log "   wchan=$(cat "$PROC/$pid/wchan" 2>/dev/null) syscall=$sc"
    # aarch64: syscall 29 is ioctl; 0x40304580 is EVIOCSFF (upload a force-feedback effect)
    case "$sc" in
        "29 "*" 0x40304580 "*)
            if [ "$ffdone" = 0 ]; then
                ffdone=1
                # shellcheck disable=SC2086
                set -- $sc
                input_context "$pid" "$(($2))"
            fi
            ;;
    esac
    io=$(tr '\n' ' ' 2>/dev/null <"$PROC/$pid/io")
    [ -n "$io" ] && log "   io: $io"
    threads "$pid"
    log "   cpu total: $THREAD_TICKS ticks (about $((THREAD_TICKS / 100)) s at 100 Hz)"
    open_files "$pid"
    stack=$(cat "$PROC/$pid/stack" 2>/dev/null)
    [ -n "$stack" ] && log "   kernel stack: $stack"
}

context() { # <pid>
    log ""
    log "==== ra_probe $(stamp)  binary=$bin  pid=$1 ===="
    log "device=$(head -n 1 /etc/trimui_device.txt 2>/dev/null) kernel=$(uname -r 2>/dev/null) governor=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null)"
    log "retroarch.cfg: $(grep -E '^(menu_driver|video_driver|audio_driver|menu_enable_widgets) ' "$RA_DIR/retroarch.cfg" 2>/dev/null | tr -d '"' | tr '\n' ';')"
    log "playlists: $(ls "$RA_DIR/.retroarch/playlists" 2>/dev/null | wc -l) file(s); history: $(wc -c 2>/dev/null <"$RA_DIR/.retroarch/content_history.lpl") bytes"
    log "music/audio processes: $(ps 2>/dev/null | grep -E 'mplayer|musicserver|presenter|selector' | grep -v grep | tr -s ' ' | tr '\n' ';')"
}

# --- wait for RetroArch to appear -----------------------------------------------------
pid=
waited=0
while [ "$waited" -lt "$FIND_SECONDS" ]; do
    pid=$(find_pid) && break
    pid=
    sleep 1
    waited=$((waited + 1))
done
if [ -z "$pid" ]; then
    log ""
    log "==== ra_probe $(stamp)  binary=$bin: process not found after ${FIND_SECONDS}s (nothing to record) ===="
    flush
    exit 0
fi

context "$pid"

elapsed=0
dwell=0
straced=0
ffdone=0
t0=$(uptime_s) || t0=
[ -f "$SDCARD/System/etc/ra_strace" ] && want_strace=1 || want_strace=0
while [ "$elapsed" -lt "$DURATION" ]; do
    if [ ! -d "$PROC/$pid" ]; then
        log "-- RetroArch exited (about ${elapsed}s after the probe started) $(stamp)"
        flush
        exit 0
    fi
    sample "$pid" "$elapsed"
    if [ "$THREAD_ANY_D" = 1 ]; then dwell=$((dwell + 1)); else dwell=0; fi
    if [ "$straced" = 0 ] && { [ "$dwell" -ge 2 ] || { [ "$want_strace" = 1 ] && [ "$elapsed" -ge 15 ]; }; }; then
        straced=1
        log "   ps (non-kernel processes):"
        ps 2>/dev/null | grep -v '\[' | head -n 40 | sed 's/^/     /' >>"$LOG"
        strace_burst "$pid" 4
    fi
    flush
    nap "$INTERVAL"
    # real elapsed time when /proc/uptime is readable, the nominal one otherwise
    if [ -n "$t0" ] && now=$(uptime_s); then
        elapsed=$((now - t0))
    else
        elapsed=$((elapsed + INTERVAL))
    fi
done
log "-- probe finished after ${elapsed}s; RetroArch still running $(stamp)"
flush
exit 0
