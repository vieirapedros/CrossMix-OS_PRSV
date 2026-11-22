#!/bin/sh
# mock do infoscreen.sh: registra a mensagem; com -k devolve a tecla (fila info.q, ou prog.q se -k B)
. "$(dirname "$0")/mocklib.sh"
D=$MOCK_DIR
msg=""; keys=""
while [ $# -gt 0 ]; do
  case "$1" in -m) msg=$2; shift 2 ;; -k) keys=$2; shift 2 ;; -t | -fs | -i | -c | -ff) shift 2 ;; *) shift ;; esac
done
printf '%s\n----\n' "$msg" >>"$D/info.log"
[ -n "$keys" ] || exit 0
if [ "$keys" = B ]; then
  sleep 0.3
  act=$(pop "$D/prog.q")
  case "$act" in key:*) echo "${act#key:}" ;; *) echo timeout ;; esac
else
  act=$(pop "$D/info.q")
  case "$act" in key:*) echo "${act#key:}" ;; *) echo A ;; esac
fi
exit 0
