#!/usr/bin/env bash
# Focus: agent inventory/parity and read-only disposable-HOME checks.

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
empty_repo="$TMP_ROOT/empty-repo"
mkdir -p "$empty_repo/agents"
cp "$REPO_ROOT/agents/check.sh" "$empty_repo/agents/check.sh"
run_check_fail "$empty_repo" "$TMP_ROOT/empty-home" "$TMP_ROOT/empty.out"
assert_contains "$TMP_ROOT/empty.out" "validation collected no agent files"


nomutate_home="$TMP_ROOT/nomutate-home"
nomutate_output="$TMP_ROOT/nomutate.out"
mkdir -p "$nomutate_home/.claude" "$nomutate_home/.omp/agent"
snapshot_home() {
  (cd "$nomutate_home" && find . -printf '%P %y %l %m %T@\n' | LC_ALL=C sort)
}
snapshot_home >"$TMP_ROOT/home-before"
if ! HOME="$nomutate_home" bash "$clean_repo/agents/check.sh" >"$nomutate_output" 2>&1; then
  echo "expected agents/check.sh to pass" >&2
  echo "--- output ---" >&2
  cat "$nomutate_output" >&2
  exit 1
fi
assert_contains "$nomutate_output" "agent-check: PASS"
snapshot_home >"$TMP_ROOT/home-after"
if ! cmp -s "$TMP_ROOT/home-before" "$TMP_ROOT/home-after"; then
  echo "agents/check.sh changed HOME" >&2
  exit 1
fi

omp_only_repo="$TMP_ROOT/omp-only-repo"
omp_only_home="$TMP_ROOT/omp-only-home"
omp_only_output="$TMP_ROOT/omp-only.out"
copy_repo "$omp_only_repo"
cat > "$omp_only_repo/agents/omp-only.md" <<'AGENT'
---
name: omp-only
description: should be paired with a Claude variant
tools: read
---
AGENT
run_check_fail "$omp_only_repo" "$omp_only_home" "$omp_only_output"
assert_contains "$omp_only_output" "agents/omp-only.md has no agents/claude/omp-only.md"

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
assert_contains "$claude_only_output" "agents/claude/unpaired-only.md has no agents/unpaired-only.md"

route_token_repo="$TMP_ROOT/route-token-repo"
route_token_home="$TMP_ROOT/route-token-home"
route_token_output="$TMP_ROOT/route-token.out"
copy_repo "$route_token_repo"
for agent_dir in agents/claude agents; do
  mkdir -p "$route_token_repo/$agent_dir"
  cat > "$route_token_repo/$agent_dir/forbidden-gpt-55.md" <<'AGENT'
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




echo "agent-check: PASS"
