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

run "Agent schema validation" npm run check:agents-schema
run "agent consistency" bash agents/check.sh
run "Markdown lint" npm run check:md
run "Markdown links" npm run check:links

# Pre-loop steps above stay fail-fast; the Node tests and every tests/*.sh
# script run, and the failing set is reported once at the end.
failed=()
# Quoted so Node expands the glob: an empty match runs nothing rather than
# falling back to Node's default repo-wide test patterns.
run "node --test tests/*.mjs" node --test 'tests/*.mjs' || failed+=("tests/*.mjs")
for test_script in tests/*.sh; do
  run "$test_script" bash "$test_script" || failed+=("$test_script")
done

if ((${#failed[@]})); then
  printf '\ncheck: FAIL - %d failing test script(s):\n' "${#failed[@]}"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi

printf '\ncheck: PASS\n'
