#!/usr/bin/env bash
# Canonical local Check Gate for this repository.
# Keep this wrapper read-only: it delegates only to syntax checks and regression
# scripts that use temporary homes/directories for mutation coverage.

set -euo pipefail
shopt -s nullglob

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

run() {
  local label="$1"
  shift
  local arg

  printf '\n==> %s\n' "$label"
  printf '+'
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
  "$@"
}

run "install.sh syntax" bash -n install.sh
run "Agent schema validation" npm run check:agents-schema
run "agent consistency" bash agents/check.sh
run "Markdown lint" npm run check:md
run "Markdown links" npm run check:links

for test_script in tests/*.sh; do
  run "$test_script" bash "$test_script"
done

printf '\ncheck: PASS\n'
