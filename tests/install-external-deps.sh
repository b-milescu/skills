#!/usr/bin/env bash
# Focus: `install.sh` warnings for missing required external skills and
# silence when they exist under a temporary `HOME`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skills-install-deps.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_contains() {
  local file="$1" expected="$2"
  if ! grep -Fq "$expected" "$file"; then
    echo "expected output to contain: $expected" >&2
    echo "--- output ---" >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1" unexpected="$2"
  if grep -Fq "$unexpected" "$file"; then
    echo "expected output not to contain: $unexpected" >&2
    echo "--- output ---" >&2
    cat "$file" >&2
    exit 1
  fi
}

run_install() {
  local home_dir="$1" output_file="$2"
  mkdir -p "$home_dir/.claude" "$home_dir/.omp/agent"
  HOME="$home_dir" "$REPO_ROOT/install.sh" >"$output_file" 2>&1
}

missing_home="$TMP_ROOT/missing"
missing_output="$TMP_ROOT/missing.out"
run_install "$missing_home" "$missing_output"

for runtime in \
  "$missing_home/.claude/skills" \
  "$missing_home/.omp/agent/skills"; do
  assert_contains "$missing_output" "warn: missing required external skill tdd in $runtime"
done

present_home="$TMP_ROOT/present"
for runtime in \
  "$present_home/.claude/skills" \
  "$present_home/.omp/agent/skills"; do
  for skill in tdd; do
    mkdir -p "$runtime/$skill"
    printf '# %s\n' "$skill" >"$runtime/$skill/SKILL.md"
  done
done
present_output="$TMP_ROOT/present.out"
run_install "$present_home" "$present_output"

assert_not_contains "$present_output" "warn: missing required external skill"
assert_not_contains "$present_output" "warn: missing optional external skill"

echo "install-external-deps: PASS"
