#!/usr/bin/env bash
# Prints the xcodebuild flags for shard INDEX of COUNT over every test target.
# Suites are dealt out round-robin by name. The last shard also takes everything
# the scan can't see (it runs each target and skips the other shards' suites), so
# a test outside an @Suite still runs.
# Usage: scripts/shard-args.sh INDEX COUNT
set -euo pipefail

index=$1 count=$2

cd "$(dirname "$0")/.."

targets=()
suites=()
for dir in Packages/*/Tests/* Tests/*; do
  target=$(basename "$dir")
  targets+=("$target")
  while read -r suite; do
    suites+=("$target/$suite")
  done < <(
    sed -nE 's/^(@[A-Za-z]+(\([^)]*\))? +)*@Suite(\([^)]*\))? +(@[A-Za-z]+ +)*(final +)?(struct|class|enum|actor) +([A-Za-z0-9_]+).*/\7/p' "$dir"/*.swift |
      LC_ALL=C sort
  )
done

if ((index < count)); then
  for ((i = index - 1; i < ${#suites[@]}; i += count)); do
    echo "-only-testing:${suites[i]}"
  done
else
  printf -- '-only-testing:%s\n' "${targets[@]}"
  for ((i = 0; i < ${#suites[@]}; i++)); do
    if (((i % count) + 1 != index)); then
      echo "-skip-testing:${suites[i]}"
    fi
  done
fi
