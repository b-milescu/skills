#!/usr/bin/env bash
# Canonical local Check Gate for this repository.
# Keep this wrapper read-only: it delegates only to syntax checks and regression
# scripts that use temporary homes/directories for mutation coverage.

set -euo pipefail
shopt -s nullglob

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"
CHECK_HOME="$(mktemp -d "${TMPDIR:-/tmp}/agent-skills-check-home.XXXXXX")"
trap 'rm -rf "$CHECK_HOME"' EXIT
mkdir -p "$CHECK_HOME/.claude/skills/tdd" "$CHECK_HOME/.omp/agent/skills/tdd"
printf '# tdd\n' > "$CHECK_HOME/.claude/skills/tdd/SKILL.md"
printf '# tdd\n' > "$CHECK_HOME/.omp/agent/skills/tdd/SKILL.md"


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
run "agent consistency" env AGENT_SKILLS_CHECK_HOME="$CHECK_HOME" bash agents/check.sh
run "Markdown lint" npm run check:md
run "Markdown links" npm run check:links

# Pre-loop steps above stay fail-fast; every tests/*.sh script runs and the
# failing set is reported once at the end.
failed=()
for test_script in tests/*.sh; do
  run "$test_script" bash "$test_script" || failed+=("$test_script")
done

if ((${#failed[@]})); then
  printf '\ncheck: FAIL - %d failing test script(s):\n' "${#failed[@]}"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi

printf '\ncheck: PASS\n'
