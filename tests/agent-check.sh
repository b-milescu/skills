#!/usr/bin/env bash
# Focus: agent inventory/parity, Markdown input inventory, installed exposure and
# read-only disposable-HOME checks.

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
  (cd "$REPO_ROOT" && tar --exclude .git --exclude node_modules -cf - .) | (cd "$dest" && tar -xf -)
}

run_check_ok() {
  local repo="$1" home_dir="$2" output="$3"
  if ! HOME="$home_dir" bash "$repo/agents/check.sh" >"$output" 2>&1; then
    echo "expected agents/check.sh to pass" >&2
    echo "--- output ---" >&2
    cat "$output" >&2
    exit 1
  fi
}

run_check_fail() {
  local repo="$1" home_dir="$2" output="$3"
  if HOME="$home_dir" bash "$repo/agents/check.sh" >"$output" 2>&1; then
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
run_check_ok "$clean_repo" "$clean_home" "$clean_output"
assert_contains "$clean_output" "agent-check: PASS"
# Shared routed inventory has identical model-free basenames in both dialects;
# agents/check.sh must treat any missing counterpart as a parity error.
for agent in mr-builder mr-reviewer-final; do
  assert_not_contains "$clean_output" "agents/claude/$agent.md has no agents/omp/$agent.md"
  assert_not_contains "$clean_output" "agents/omp/$agent.md has no agents/claude/$agent.md"
done
empty_repo="$TMP_ROOT/empty-repo"
mkdir -p "$empty_repo/agents"
cp "$REPO_ROOT/agents/check.sh" "$empty_repo/agents/check.sh"
run_check_fail "$empty_repo" "$TMP_ROOT/empty-home" "$TMP_ROOT/empty.out"
assert_contains "$TMP_ROOT/empty.out" "validation collected no agent files"

git_noise_repo="$TMP_ROOT/git-noise-repo"
git_noise_home="$TMP_ROOT/git-noise-home"
git_noise_output="$TMP_ROOT/git-noise.out"
git_noise_scan="$TMP_ROOT/git-noise-scan.list"
git_noise_schema_output="$TMP_ROOT/git-noise-schema.out"
copy_repo "$git_noise_repo"
git -C "$git_noise_repo" init -q
git -C "$git_noise_repo" add .
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

# Leftover builder worktrees can be copied under a non-Git fixture checkout
# (tar copy preserves `.claude/worktrees/<name>/` once `.git` is excluded). The
# find fallback must prune those worktree copies so stale tracked-Markdown copies
# do not trip the prompt-drift checks on main (issue #246).
worktree_noise_repo="$TMP_ROOT/worktree-noise-repo"
worktree_noise_scan="$TMP_ROOT/worktree-noise-scan.list"
copy_repo "$worktree_noise_repo"
mkdir -p "$worktree_noise_repo/.claude/worktrees/stale-builder/start-build/templates"
cp "$worktree_noise_repo/start-build/templates/reviewer-lift-schema.md" \
  "$worktree_noise_repo/.claude/worktrees/stale-builder/start-build/templates/reviewer-lift-schema.md"
bash "$worktree_noise_repo/scripts/list-prompt-drift-markdown.sh" "$worktree_noise_repo" |
  tr '\0' '\n' |
  sed '/^$/d' > "$worktree_noise_scan"
if grep -E '/\.claude/worktrees/' "$worktree_noise_scan"; then
  echo "expected fallback prompt-drift Markdown scan to ignore .claude/worktrees copies" >&2
  echo "--- scan list ---" >&2
  cat "$worktree_noise_scan" >&2
  exit 1
fi

# Issue #272 (find fallback path): a NON-Git fixture checkout forces the `find`
# fallback enumeration, not the `git ls-files` index path. A NON-worktree
# `.claude/<x>/...` copy of a canonical template (i.e. NOT under
# `.claude/worktrees/`, which has its own `-path` prune) must still be excluded:
# the find prune group must drop EVERY `.claude/` path, mirroring the git-index
# path's `.claude/` exclusion. Without the fix the find fallback only prunes
# `.claude/worktrees/`, so this non-worktree copy leaks and trips prompt-drift —
# the exact false-FAIL class issue #272 removes.
fallback_claude_repo="$TMP_ROOT/fallback-claude-repo"
fallback_claude_scan="$TMP_ROOT/fallback-claude-scan.list"
fallback_claude_home="$TMP_ROOT/fallback-claude-home"
fallback_claude_output="$TMP_ROOT/fallback-claude.out"
copy_repo "$fallback_claude_repo"
# No `git init`: force the non-git / find-fallback enumeration code path.
if git -C "$fallback_claude_repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "expected fallback-claude fixture to NOT be a Git work tree (find fallback path)" >&2
  exit 1
fi
mkdir -p \
  "$fallback_claude_repo/.claude/agent-stray/start-build/templates" \
  "$fallback_claude_repo/.claude/agent-stray/start-review/templates"
cp "$fallback_claude_repo/start-build/templates/reviewer-lift-schema.md" \
  "$fallback_claude_repo/.claude/agent-stray/start-build/templates/reviewer-lift-schema.md"
cp "$fallback_claude_repo/start-review/templates/review-report.md" \
  "$fallback_claude_repo/.claude/agent-stray/start-review/templates/review-report.md"
# The enumerator resolves symlinks via `pwd -P`, so compare against the
# resolved repo root (e.g. /var -> /private/var on macOS).
fallback_claude_real="$(cd "$fallback_claude_repo" && pwd -P)"
fallback_canonical_md="$fallback_claude_real/start-build/templates/reviewer-lift-schema.md"
bash "$fallback_claude_repo/scripts/list-prompt-drift-markdown.sh" "$fallback_claude_repo" |
  tr '\0' '\n' |
  sed '/^$/d' > "$fallback_claude_scan"
# No `.claude/` path (worktree or not) may leak through the find fallback.
if grep -E '/\.claude/' "$fallback_claude_scan"; then
  echo "expected find fallback to ignore every .claude/ path (non-worktree copy leaked)" >&2
  echo "--- scan list ---" >&2
  cat "$fallback_claude_scan" >&2
  exit 1
fi
# No over-pruning: a NON-`.claude` canonical Markdown file is still enumerated.
if ! grep -Fq "$fallback_canonical_md" "$fallback_claude_scan"; then
  echo "expected find fallback to still list non-.claude canonical Markdown (over-pruned)" >&2
  echo "--- scan list ---" >&2
  cat "$fallback_claude_scan" >&2
  exit 1
fi
# End-to-end: agent-check must PASS via the find fallback with no .claude leak.
run_check_ok "$fallback_claude_repo" "$fallback_claude_home" "$fallback_claude_output"
assert_contains "$fallback_claude_output" "agent-check: PASS"
assert_not_contains "$fallback_claude_output" ".claude/agent-stray"

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
mkdir -p "$nomutate_home/.claude" "$nomutate_home/.omp/agent"
HOME="$nomutate_home" "$clean_repo/install.sh" >"$TMP_ROOT/nomutate-install.out" 2>&1
for runtime in "$nomutate_home/.claude/skills" "$nomutate_home/.omp/agent/skills"; do
  assert_not_exists "$runtime/tdd"
  for skill in start-build start-review issue-delivery-loop forge; do
    [[ -L "$runtime/$skill" && -f "$runtime/$skill/SKILL.md" ]] || {
      echo "missing installed workflow entry: $runtime/$skill" >&2
      exit 1
    }
  done
done
for runtime in "$nomutate_home/.claude/agents" "$nomutate_home/.omp/agent/agents"; do
  for agent in mr-builder mr-reviewer-final; do
    [[ -L "$runtime/$agent.md" && -f "$runtime/$agent.md" ]] || {
      echo "missing installed agent: $runtime/$agent.md" >&2
      exit 1
    }
  done
done
snapshot_home() {
  (cd "$nomutate_home" && find . -printf '%P %y %l %m %T@\n' | LC_ALL=C sort)
}
snapshot_home >"$TMP_ROOT/home-before"
if ! HOME="$nomutate_home" "$clean_repo/install.sh" --check >"$nomutate_output" 2>&1; then
  echo "expected install.sh --check to pass" >&2
  echo "--- output ---" >&2
  cat "$nomutate_output" >&2
  exit 1
fi
assert_contains "$nomutate_output" "agent-check: PASS"
snapshot_home >"$TMP_ROOT/home-after"
if ! cmp -s "$TMP_ROOT/home-before" "$TMP_ROOT/home-after"; then
  echo "install.sh --check changed installed HOME" >&2
  exit 1
fi

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
run_check_fail "$omp_only_repo" "$omp_only_home" "$omp_only_output"
assert_contains "$omp_only_output" "agents/omp/omp-only.md has no agents/claude/omp-only.md"

claude_only_repo="$TMP_ROOT/claude-only-repo"
claude_only_home="$TMP_ROOT/claude-only-home"
claude_only_output="$TMP_ROOT/claude-only.out"
copy_repo "$claude_only_repo"
cat > "$claude_only_repo/agents/claude/unpaired-only.md" <<'AGENT'
---
name: unpaired-only
description: should be paired with an OMP variant
tools: Read
---
AGENT
run_check_fail "$claude_only_repo" "$claude_only_home" "$claude_only_output"
assert_contains "$claude_only_output" "agents/claude/unpaired-only.md has no agents/omp/unpaired-only.md"

route_token_repo="$TMP_ROOT/route-token-repo"
route_token_home="$TMP_ROOT/route-token-home"
route_token_output="$TMP_ROOT/route-token.out"
copy_repo "$route_token_repo"
for dialect in claude omp; do
  mkdir -p "$route_token_repo/agents/$dialect"
  cat > "$route_token_repo/agents/$dialect/forbidden-gpt-55.md" <<'AGENT'
---
name: forbidden-gpt-55
description: should reject provider/model route-name token
tools: Read
---
AGENT
done
run_check_fail "$route_token_repo" "$route_token_home" "$route_token_output"
assert_contains "$route_token_output" "agent route naming: agents/claude/forbidden-gpt-55.md file name 'forbidden-gpt-55' must not include provider/model token 'gpt-55'"
assert_contains "$route_token_output" "agent route naming: agents/claude/forbidden-gpt-55.md frontmatter name 'forbidden-gpt-55' must not include provider/model token 'gpt-55'"


# Issue #272: in a real Git checkout, parallel agent worktrees leave copies of
# canonical templates under .claude/worktrees/<id>/. Because `.claude/` is not in
# `.gitignore`, a `git add .` in the parent worktree can accidentally STAGE those
# copies, which then leak into `git ls-files` and produce spurious "stale
# duplicate table" / "stale structure" FAILs unrelated to the change under test.
# agent-check must enumerate its inputs from tracked files but exclude
# `.claude/` paths so untracked/ignored or accidentally-tracked worktree copies
# cannot inject findings, while every real check on genuine tracked files stays
# intact.
untracked_worktree_repo="$TMP_ROOT/untracked-worktree-repo"
untracked_worktree_home="$TMP_ROOT/untracked-worktree-home"
untracked_worktree_output="$TMP_ROOT/untracked-worktree.out"
copy_repo "$untracked_worktree_repo"
git -C "$untracked_worktree_repo" init -q
git -C "$untracked_worktree_repo" add .
git -C "$untracked_worktree_repo" -c user.email=check@example.com -c user.name=check \
  commit -qm "baseline"
# Stray agent-worktree copies of canonical templates under .claude/worktrees/.
mkdir -p \
  "$untracked_worktree_repo/.claude/worktrees/agent-stray/start-build/templates" \
  "$untracked_worktree_repo/.claude/worktrees/agent-stray/start-review/templates"
cp "$untracked_worktree_repo/start-build/templates/reviewer-lift-schema.md" \
  "$untracked_worktree_repo/.claude/worktrees/agent-stray/start-build/templates/reviewer-lift-schema.md"
cp "$untracked_worktree_repo/start-review/templates/review-report.md" \
  "$untracked_worktree_repo/.claude/worktrees/agent-stray/start-review/templates/review-report.md"
# Even if a stray copy is force-staged, it must not inject a stale-structure FAIL.
git -C "$untracked_worktree_repo" add -f \
  ".claude/worktrees/agent-stray/start-build/templates/reviewer-lift-schema.md" \
  ".claude/worktrees/agent-stray/start-review/templates/review-report.md"
run_check_ok "$untracked_worktree_repo" "$untracked_worktree_home" "$untracked_worktree_output"
assert_contains "$untracked_worktree_output" "agent-check: PASS"
assert_not_contains "$untracked_worktree_output" ".claude/worktrees"


echo "agent-check: PASS"
