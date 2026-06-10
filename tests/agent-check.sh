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

assert_not_contains() {
  local file="$1" unexpected="$2"
  if grep -Fq "$unexpected" "$file"; then
    echo "expected output NOT to contain: $unexpected" >&2
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
    "$home_dir/.omp/agent/agents" \
    "$home_dir/.omp/agent/skills"

  for agent in mr-builder mr-reviewer; do
    ln -s "$repo/agents/claude/$agent.md" "$home_dir/.claude/agents/$agent.md"
    ln -s "$repo/agents/omp/$agent.md" "$home_dir/.omp/agent/agents/$agent.md"
  done

  if [[ "$with_tdd" == yes ]]; then
    for runtime in "$home_dir/.claude/skills" "$home_dir/.omp/agent/skills"; do
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
# The OMP-only GPT routes have no Claude counterpart by design; the documented
# allowlist in agents/check.sh must exempt them from the parity error.
assert_not_contains "$clean_output" "agents/omp/mr-reviewer-gpt55-xhigh.md has no agents/claude/mr-reviewer-gpt55-xhigh.md"
assert_not_contains "$clean_output" "agents/omp/mr-review-scout-gpt54-low.md has no agents/claude/mr-review-scout-gpt54-low.md"

git_noise_repo="$TMP_ROOT/git-noise-repo"
git_noise_home="$TMP_ROOT/git-noise-home"
git_noise_output="$TMP_ROOT/git-noise.out"
git_noise_scan="$TMP_ROOT/git-noise-scan.list"
git_noise_schema_output="$TMP_ROOT/git-noise-schema.out"
copy_repo "$git_noise_repo"
git -C "$git_noise_repo" init -q
git -C "$git_noise_repo" add .
tracked_markdown_count="$(git -C "$git_noise_repo" ls-files '*.md' | wc -l | tr -d '[:space:]')"
mkdir -p \
  "$git_noise_repo/node_modules/noise" \
  "$git_noise_repo/.npm/cache" \
  "$git_noise_repo/cleanup-discovery" \
  "$git_noise_repo/graphify-out" \
  "$git_noise_repo/.graphify-cache"
cat > "$git_noise_repo/node_modules/noise/reviewer-lift-drift.md" <<'DRIFT'
| Field | Value |
|---|---|
| Reviewed SHA | stale |
| Review gate | stale |
| CI pipeline | stale |
| Local gate | stale |
DRIFT
cat > "$git_noise_repo/.npm/cache/reviewer-lift-drift.md" <<'DRIFT'
| Field | Value |
|---|---|
| Reviewed SHA | stale |
| Review gate | stale |
| CI pipeline | stale |
| Local gate | stale |
DRIFT
cat > "$git_noise_repo/cleanup-discovery/report.md" <<'DRIFT'
## Summary

## Decision

## Must Fix

## Should Fix
DRIFT
cat > "$git_noise_repo/graphify-out/GRAPH_REPORT.md" <<'DRIFT'
## Graph Report

| Field | Value |
|---|---|
| Reviewed SHA | graph-noise |
DRIFT
cat > "$git_noise_repo/.graphify-cache/report.md" <<'DRIFT'
## Graph Cache

| Field | Value |
|---|---|
| Reviewed SHA | graph-cache-noise |
DRIFT
cat > "$git_noise_repo/.graphify-report.md" <<'DRIFT'
## Graph File

| Field | Value |
|---|---|
| Reviewed SHA | graph-file-noise |
DRIFT
cat > "$git_noise_repo/progress.md" <<'DRIFT'
| Field | Value |
|---|---|
| Reviewed SHA | local |
| Review gate | local |
| CI pipeline | local |
| Local gate | local |
DRIFT
bash "$git_noise_repo/scripts/list-prompt-drift-markdown.sh" "$git_noise_repo" |
  tr '\0' '\n' |
  sed '/^$/d' > "$git_noise_scan"
scan_count="$(wc -l < "$git_noise_scan" | tr -d '[:space:]')"
if [[ "$scan_count" != "$tracked_markdown_count" ]]; then
  echo "expected prompt-drift Markdown scan count ($scan_count) to equal tracked Markdown count ($tracked_markdown_count)" >&2
  echo "--- scan list ---" >&2
  cat "$git_noise_scan" >&2
  exit 1
fi
if grep -E '/(node_modules|cleanup-discovery|graphify-out|\.npm|\.graphify[^/]*)/|/progress\.md$|/\.graphify[^/]*\.md$' "$git_noise_scan"; then
  echo "expected prompt-drift Markdown scan to ignore local artifacts" >&2
  echo "--- scan list ---" >&2
  cat "$git_noise_scan" >&2
  exit 1
fi

fallback_noise_repo="$TMP_ROOT/fallback-noise-repo"
fallback_noise_scan="$TMP_ROOT/fallback-noise-scan.list"
copy_repo "$fallback_noise_repo"
mkdir -p \
  "$fallback_noise_repo/graphify-out" \
  "$fallback_noise_repo/.graphify-cache"
printf '# graph report\n' > "$fallback_noise_repo/graphify-out/GRAPH_REPORT.md"
printf '# graph cache\n' > "$fallback_noise_repo/.graphify-cache/report.md"
printf '# graph file\n' > "$fallback_noise_repo/.graphify-report.md"
bash "$fallback_noise_repo/scripts/list-prompt-drift-markdown.sh" "$fallback_noise_repo" |
  tr '\0' '\n' |
  sed '/^$/d' > "$fallback_noise_scan"
if grep -E '/(graphify-out|\.graphify[^/]*)/|/\.graphify[^/]*\.md$' "$fallback_noise_scan"; then
  echo "expected fallback prompt-drift Markdown scan to ignore graphify artifacts" >&2
  echo "--- scan list ---" >&2
  cat "$fallback_noise_scan" >&2
  exit 1
fi
run_check_ok "$git_noise_repo" "$git_noise_home" "$git_noise_output"
assert_contains "$git_noise_output" "agent-check: PASS"
if ! (cd "$git_noise_repo" && bash tests/reviewer-lift-schema.sh) >"$git_noise_schema_output" 2>&1; then
  echo "expected tests/reviewer-lift-schema.sh to ignore local artifact Markdown in a Git worktree" >&2
  echo "--- output ---" >&2
  cat "$git_noise_schema_output" >&2
  exit 1
fi
assert_contains "$git_noise_schema_output" "Reviewer Lift schema check passed"

nomutate_home="$TMP_ROOT/nomutate-home"
nomutate_output="$TMP_ROOT/nomutate.out"
mkdir -p \
  "$nomutate_home/.claude/skills/tdd" \
  "$nomutate_home/.omp/agent/skills/tdd"
printf '# tdd\n' > "$nomutate_home/.claude/skills/tdd/SKILL.md"
printf '# tdd\n' > "$nomutate_home/.omp/agent/skills/tdd/SKILL.md"
if ! AGENT_SKILLS_CHECK_HOME="$nomutate_home" HOME="$nomutate_home" "$clean_repo/install.sh" --check >"$nomutate_output" 2>&1; then
  echo "expected install.sh --check to pass" >&2
  echo "--- output ---" >&2
  cat "$nomutate_output" >&2
  exit 1
fi
assert_contains "$nomutate_output" "agent-check: PASS"
assert_not_exists "$nomutate_home/.claude/agents"
assert_not_exists "$nomutate_home/.omp/agent/agents"

omp_only_repo="$TMP_ROOT/omp-only-repo"
omp_only_home="$TMP_ROOT/omp-only-home"
omp_only_output="$TMP_ROOT/omp-only.out"
copy_repo "$omp_only_repo"
cat > "$omp_only_repo/agents/omp/omp-only.md" <<'AGENT'
---
name: omp-only
description: should be paired with a Claude variant
tools: read
---
AGENT
prepare_installed_agents "$omp_only_repo" "$omp_only_home" yes
run_check_fail "$omp_only_repo" "$omp_only_home" "$omp_only_output"
assert_contains "$omp_only_output" "agents/omp/omp-only.md has no agents/claude/omp-only.md"

missing_omp_repo="$TMP_ROOT/missing-omp-repo"
missing_omp_home="$TMP_ROOT/missing-omp-home"
missing_omp_output="$TMP_ROOT/missing-omp.out"
copy_repo "$missing_omp_repo"
rm "$missing_omp_repo/agents/omp/mr-reviewer.md"
prepare_installed_agents "$missing_omp_repo" "$missing_omp_home" yes
run_check_fail "$missing_omp_repo" "$missing_omp_home" "$missing_omp_output"
assert_contains "$missing_omp_output" "agents/claude/mr-reviewer.md has no agents/omp/mr-reviewer.md"

prompt_strategy_repo="$TMP_ROOT/prompt-strategy-repo"
prompt_strategy_home="$TMP_ROOT/prompt-strategy-home"
prompt_strategy_output="$TMP_ROOT/prompt-strategy.out"
copy_repo "$prompt_strategy_repo"
perl -0pi -e 's/Canonical development pattern source: `start-build`/Canonical development pattern source: `local-copy`/' "$prompt_strategy_repo/agents/omp/mr-builder.md"
prepare_installed_agents "$prompt_strategy_repo" "$prompt_strategy_home" yes
run_check_fail "$prompt_strategy_repo" "$prompt_strategy_home" "$prompt_strategy_output"
assert_contains "$prompt_strategy_output" "agent prompt strategy: agents/omp/mr-builder.md must point to canonical workflow skill start-build"


routed_prompt_strategy_repo="$TMP_ROOT/routed-prompt-strategy-repo"
routed_prompt_strategy_home="$TMP_ROOT/routed-prompt-strategy-home"
routed_prompt_strategy_output="$TMP_ROOT/routed-prompt-strategy.out"
copy_repo "$routed_prompt_strategy_repo"
perl -0pi -e 's/Canonical development pattern source: `start-review`/Canonical development pattern source: `local-copy`/' "$routed_prompt_strategy_repo/agents/claude/mr-reviewer-opus48-xhigh.md"
prepare_installed_agents "$routed_prompt_strategy_repo" "$routed_prompt_strategy_home" yes
run_check_fail "$routed_prompt_strategy_repo" "$routed_prompt_strategy_home" "$routed_prompt_strategy_output"
assert_contains "$routed_prompt_strategy_output" "agent prompt strategy: agents/claude/mr-reviewer-opus48-xhigh.md must point to canonical workflow skill start-review"

lift_drift_repo="$TMP_ROOT/lift-drift-repo"
lift_drift_home="$TMP_ROOT/lift-drift-home"
lift_drift_output="$TMP_ROOT/lift-drift.out"
copy_repo "$lift_drift_repo"
cat >> "$lift_drift_repo/agents/omp/mr-builder.md" <<'DRIFT'

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

## Decision Summary

## Context / Snapshot

## Reviewer Lift (builder handoff)

## Review Context Capsule
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
