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

run "Agent schema validation" bun run check:agents-schema
run "agent consistency" bash agents/check.sh
run "Markdown lint" bun run check:md
run "Markdown links" bun run check:links

# Pre-loop steps above stay fail-fast; every tests/*.mjs and tests/*.sh script
# runs in its own process and the failing set is reported once at the end.
failed=()
for test_script in tests/*.mjs; do
  # One process per file gated on its exit code: a late throw fails the file and
  # process.exit() ends only it. node:test files run only under `bun test`, which
  # reads a path without ./ as a filter and, given none, discovers *.test.* files
  # repo-wide.
  if grep -Eq "from [\"']node:test[\"']" "$test_script"; then
    run "$test_script" bun test "./$test_script" || failed+=("$test_script")
  else
    run "$test_script" bun "$test_script" || failed+=("$test_script")
  fi
done
for test_script in tests/*.sh; do
  run "$test_script" bash "$test_script" || failed+=("$test_script")
done

if ((${#failed[@]})); then
  printf '\ncheck: FAIL - %d failing test script(s):\n' "${#failed[@]}"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi

printf '\ncheck: PASS\n'
