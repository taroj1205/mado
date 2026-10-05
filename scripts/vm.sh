#!/usr/bin/env bash
set -euo pipefail

VM=mado-vm
LOCK="$HOME/Library/Caches/mado-vm.lock"
ME=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

lock() {
  for _ in $(seq 600); do
    if mkdir "$LOCK" 2>/dev/null; then echo "$ME" >"$LOCK/owner"; return; fi
    [ "$(cat "$LOCK/owner" 2>/dev/null)" = "$ME" ] && { touch "$LOCK"; return; }
    [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10)" ] && rm -rf "$LOCK" && continue
    sleep 1
  done
  echo "$VM is busy: $(cat "$LOCK/owner" 2>/dev/null)" >&2
  exit 1
}

in_vm() { tart exec "$VM" "$@"; }

vnc_url() {
  local url
  url=$(tmux capture-pane -p -t "$VM" -S - 2>/dev/null | grep -o 'vnc://[^ ]*' | tail -1)
  [ -n "$url" ] || { echo "$VM is not running; run: scripts/vm.sh up" >&2; exit 1; }
  echo "$url"
}

vnc() {
  local url pass port
  url=$(vnc_url)
  pass=${url#vnc://:}
  pass=${pass%@*}
  port=${url##*:}
  PYTHONWARNINGS=ignore vncdo -s "127.0.0.1::$port" -p "$pass" "$@"
}

case "${1:-}" in
  up)
    tmux has-session -t "$VM" 2>/dev/null || tmux new-session -d -s "$VM" "tart run $VM --no-graphics --vnc-experimental"
    for _ in $(seq 180); do in_vm true 2>/dev/null && exit 0; sleep 1; done
    echo "$VM didn't answer tart exec within 3 minutes; see: tmux attach -t $VM" >&2
    exit 1
    ;;
  launch)
    lock
    app=${2:-$ME/build/Build/Products/Debug/Mado.app}
    [ -d "$app" ] || { echo "No app at $app" >&2; exit 1; }
    tar -C "$app" -cf - . | tart exec -i "$VM" sh -c 'pkill -x Mado; while pgrep -x Mado >/dev/null; do sleep 0.1; done; rm -rf ~/Applications/Mado.app ~/Applications/Mado.ready; mkdir -p ~/Applications/Mado.app && tar -xf - -C ~/Applications/Mado.app'
    in_vm sh -c 'open -n ~/Applications/Mado.app --args "$@"; for _ in $(seq 300); do [ -e ~/Applications/Mado.ready ] && exit 0; sleep 0.1; done; echo "Mado did not become ready" >&2; exit 1' sh "${@:3}"
    ;;
  vnc) lock; shift; vnc "$@" ;;
  view) url=$(vnc_url); open "$url" ;;
  done) if [ "$(cat "$LOCK/owner" 2>/dev/null)" = "$ME" ]; then rm -rf "$LOCK"; fi ;;
  down) lock; tart stop "$VM"; rm -rf "$LOCK" ;;
  *)
    echo "usage: scripts/vm.sh up | launch [Mado.app] [app args...] | vnc <vncdo args...> | view | done | down" >&2
    exit 1
    ;;
esac
