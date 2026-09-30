#!/bin/sh
set -eu

app="$1"
bin="$app/Contents/MacOS/$(basename "$app" .app)"

"$bin" &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT

sleep 3
if ! kill -0 "$pid" 2>/dev/null; then
  wait "$pid" || status=$?
  echo "smoke-launch: $app exited during startup (status ${status:-0})" >&2
  exit 1
fi

type=$(lsappinfo info -only ApplicationType -app "$pid" 2>/dev/null || true)
case "$type" in
  *UIElement*) echo "smoke-launch: ok ($type)" ;;
  *) echo "smoke-launch: expected an agent app, got: $type" >&2; exit 1 ;;
esac
