#!/usr/bin/env bash
# Regression coverage for the read-only agent/install check surface.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skills-agent-check.XXXXXX")"
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

assert_not_exists() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    echo "expected path not to exist: $path" >&2
    exit 1
  fi
}

copy_repo() {
  local dest="$1"
  mkdir -p "$dest"
  (cd "$REPO_ROOT" && tar --exclude .git -cf - .) | (cd "$dest" && tar -xf -)
}

prepare_installed_agents() {
  local repo="$1" home_dir="$2" with_tdd="${3:-yes}"

  mkdir -p \
    "$home_dir/.claude/agents" \
    "$home_dir/.claude/skills" \
    "$home_dir/.pi/agent/agents" \
    "$home_dir/.pi/agent/skills"

  for agent in mr-builder mr-reviewer; do
    ln -s "$repo/agents/claude/$agent.md" "$home_dir/.claude/agents/$agent.md"
    ln -s "$repo/agents/pi/$agent.md" "$home_dir/.pi/agent/agents/$agent.md"
  done

  if [[ "$with_tdd" == yes ]]; then
    for runtime in "$home_dir/.claude/skills" "$home_dir/.pi/agent/skills"; do
      mkdir -p "$runtime/tdd"
      printf '# tdd\n' > "$runtime/tdd/SKILL.md"
    done
  fi
}

run_check_ok() {
  local repo="$1" home_dir="$2" output="$3"
  if ! AGENT_SKILLS_CHECK_HOME="$home_dir" bash "$repo/agents/check.sh" >"$output" 2>&1; then
    echo "expected agents/check.sh to pass" >&2
    echo "--- output ---" >&2
    cat "$output" >&2
    exit 1
  fi
}

run_check_fail() {
  local repo="$1" home_dir="$2" output="$3"
  if AGENT_SKILLS_CHECK_HOME="$home_dir" bash "$repo/agents/check.sh" >"$output" 2>&1; then
    echo "expected agents/check.sh to fail" >&2
    echo "--- output ---" >&2
    cat "$output" >&2
    exit 1
  fi
}

clean_repo="$TMP_ROOT/clean-repo"
clean_home="$TMP_ROOT/clean-home"
clean_output="$TMP_ROOT/clean.out"
copy_repo "$clean_repo"
prepare_installed_agents "$clean_repo" "$clean_home" yes
run_check_ok "$clean_repo" "$clean_home" "$clean_output"
assert_contains "$clean_output" "agent-check: PASS"

nomutate_home="$TMP_ROOT/nomutate-home"
nomutate_output="$TMP_ROOT/nomutate.out"
mkdir -p \
  "$nomutate_home/.claude/skills/tdd" \
  "$nomutate_home/.pi/agent/skills/tdd"
printf '# tdd\n' > "$nomutate_home/.claude/skills/tdd/SKILL.md"
printf '# tdd\n' > "$nomutate_home/.pi/agent/skills/tdd/SKILL.md"
if ! AGENT_SKILLS_CHECK_HOME="$nomutate_home" HOME="$nomutate_home" "$clean_repo/install.sh" --check >"$nomutate_output" 2>&1; then
  echo "expected install.sh --check to pass" >&2
  echo "--- output ---" >&2
  cat "$nomutate_output" >&2
  exit 1
fi
assert_contains "$nomutate_output" "agent-check: PASS"
assert_not_exists "$nomutate_home/.claude/agents"
assert_not_exists "$nomutate_home/.pi/agent/agents"

pi_only_repo="$TMP_ROOT/pi-only-repo"
pi_only_home="$TMP_ROOT/pi-only-home"
pi_only_output="$TMP_ROOT/pi-only.out"
copy_repo "$pi_only_repo"
cat > "$pi_only_repo/agents/pi/pi-only.md" <<'AGENT'
---
name: pi-only
description: should be paired with a Claude variant
tools: read
---
AGENT
prepare_installed_agents "$pi_only_repo" "$pi_only_home" yes
run_check_fail "$pi_only_repo" "$pi_only_home" "$pi_only_output"
assert_contains "$pi_only_output" "agents/pi/pi-only.md has no agents/claude/pi-only.md"

missing_pi_repo="$TMP_ROOT/missing-pi-repo"
missing_pi_home="$TMP_ROOT/missing-pi-home"
missing_pi_output="$TMP_ROOT/missing-pi.out"
copy_repo "$missing_pi_repo"
rm "$missing_pi_repo/agents/pi/mr-reviewer.md"
prepare_installed_agents "$missing_pi_repo" "$missing_pi_home" yes
run_check_fail "$missing_pi_repo" "$missing_pi_home" "$missing_pi_output"
assert_contains "$missing_pi_output" "agents/claude/mr-reviewer.md has no agents/pi/mr-reviewer.md"

lift_drift_repo="$TMP_ROOT/lift-drift-repo"
lift_drift_home="$TMP_ROOT/lift-drift-home"
lift_drift_output="$TMP_ROOT/lift-drift.out"
copy_repo "$lift_drift_repo"
cat >> "$lift_drift_repo/agents/pi/mr-builder.md" <<'DRIFT'

| Field | Value |
|---|---|
| Reviewed SHA | stale |
| Review gate | stale |
| CI pipeline | stale |
| Local gate | stale |
DRIFT
prepare_installed_agents "$lift_drift_repo" "$lift_drift_home" yes
run_check_fail "$lift_drift_repo" "$lift_drift_home" "$lift_drift_output"
assert_contains "$lift_drift_output" "Reviewer Lift stale duplicate table"

report_drift_repo="$TMP_ROOT/report-drift-repo"
report_drift_home="$TMP_ROOT/report-drift-home"
report_drift_output="$TMP_ROOT/report-drift.out"
copy_repo "$report_drift_repo"
cat >> "$report_drift_repo/agents/claude/mr-reviewer.md" <<'DRIFT'

## Summary

## Decision

## Must Fix

## Should Fix
DRIFT
prepare_installed_agents "$report_drift_repo" "$report_drift_home" yes
run_check_fail "$report_drift_repo" "$report_drift_home" "$report_drift_output"
assert_contains "$report_drift_output" "Review Report stale structure"

missing_tdd_repo="$TMP_ROOT/missing-tdd-repo"
missing_tdd_home="$TMP_ROOT/missing-tdd-home"
missing_tdd_output="$TMP_ROOT/missing-tdd.out"
copy_repo "$missing_tdd_repo"
prepare_installed_agents "$missing_tdd_repo" "$missing_tdd_home" no
run_check_fail "$missing_tdd_repo" "$missing_tdd_home" "$missing_tdd_output"
assert_contains "$missing_tdd_output" "missing required external skill tdd"
assert_contains "$missing_tdd_output" "Install external skill 'tdd' into"

echo "agent-check: PASS"
