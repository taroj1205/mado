#!/bin/sh
set -eu
"$1/Contents/MacOS/Mado" &
pid=$!
sleep 3
kill -0 "$pid"
lsappinfo info -only ApplicationType -app "$pid" | grep -q UIElement
kill "$pid"
