#!/usr/bin/env bash
# Regression coverage for install.sh symlink ownership checks.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skills-install-ownership.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

if realpath --relative-to=/ / >/dev/null 2>&1; then
  REALPATH=realpath
elif command -v grealpath >/dev/null 2>&1; then
  REALPATH=grealpath
else
  echo "install-symlink-ownership: GNU realpath required" >&2
  exit 1
fi

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
    echo "expected path to be removed: $path" >&2
    exit 1
  fi
}

assert_symlink_target() {
  local link_path="$1" expected_target="$2"
  if [[ ! -L "$link_path" ]]; then
    echo "expected symlink: $link_path" >&2
    exit 1
  fi

  local actual_target
  actual_target="$(readlink "$link_path")"
  if [[ "$actual_target" != "$expected_target" ]]; then
    echo "expected $link_path -> $expected_target" >&2
    echo "actual: $actual_target" >&2
    exit 1
  fi
}

assert_symlink_resolves_to() {
  local link_path="$1" expected_abs="$2"
  if [[ ! -L "$link_path" ]]; then
    echo "expected symlink: $link_path" >&2
    exit 1
  fi

  local actual_target actual_abs
  actual_target="$(readlink "$link_path")"
  if [[ "$actual_target" == /* ]]; then
    actual_abs="$("$REALPATH" -m "$actual_target")"
  else
    actual_abs="$("$REALPATH" -m "$(dirname "$link_path")/$actual_target")"
  fi

  if [[ "$actual_abs" != "$expected_abs" ]]; then
    echo "expected $link_path to resolve to $expected_abs" >&2
    echo "actual: $actual_abs" >&2
    exit 1
  fi
}

assert_skill_resolves_to_source() {
  local link_path="$1" expected_abs="$2" actual_target actual_abs

  if [[ ! -L "$link_path" ]]; then
    echo "expected symlink: $link_path" >&2
    exit 1
  fi
  actual_target="$(readlink "$link_path")"
  actual_abs="$("$REALPATH" -m "$(dirname "$link_path")/$actual_target")"
  [[ "$actual_abs" == "$expected_abs" ]] && return
  assert_symlink_resolves_to "$actual_abs/.source" "$expected_abs"
}

home_dir="$TMP_ROOT/home"
output_file="$TMP_ROOT/install.out"
external_dir="$TMP_ROOT/external"
mkdir -p \
  "$home_dir/.claude/skills" \
  "$home_dir/.claude/agents" \
  "$home_dir/.omp/agent/skills" \
  "$home_dir/.omp/agent/agents" \
  "$external_dir"

touch \
  "$external_dir/custom-skill" \
  "$external_dir/custom-agent.md" \
  "$external_dir/omp-custom-skill" \
  "$external_dir/omp-custom-agent.md"

ln -s "$external_dir/custom-skill" "$home_dir/.claude/skills/start-build"
ln -s "$external_dir/custom-agent.md" "$home_dir/.claude/agents/custom-agent.md"
ln -s "$external_dir/omp-custom-skill" "$home_dir/.omp/agent/skills/start-build"
ln -s "$external_dir/omp-custom-agent.md" "$home_dir/.omp/agent/agents/custom-agent.md"

custom_skill_abs="$("$REALPATH" -m "$external_dir/custom-skill")"
omp_custom_skill_abs="$("$REALPATH" -m "$external_dir/omp-custom-skill")"

ln -s "$REPO_ROOT/gitlab" "$home_dir/.claude/skills/start-review"
ln -s "$REPO_ROOT/agents/claude/mr-builder.md" "$home_dir/.claude/agents/mr-reviewer.md"
ln -s "$REPO_ROOT/start-build" "$home_dir/.claude/skills/old-repo-skill"
ln -s "$REPO_ROOT/agents/claude/mr-builder.md" "$home_dir/.claude/agents/old-repo-agent.md"
ln -s "$REPO_ROOT/agents/omp/mr-reviewer-final.md" "$home_dir/.claude/agents/mr-reviewer-final.md"
ln -s "$REPO_ROOT/agents/omp/mr-builder.md" "$home_dir/.claude/agents/mr-builder.md"

# Older installers linked shared resource dirs into runtime skill roots. They are
# repo-owned but not skills, so a rerun must prune them instead of preserving the
# bogus skill entries.
ln -s "$REPO_ROOT/docs" "$home_dir/.claude/skills/docs"
ln -s "$REPO_ROOT/templates" "$home_dir/.claude/skills/templates"
ln -s "$REPO_ROOT/docs" "$home_dir/.omp/agent/skills/docs"
ln -s "$REPO_ROOT/templates" "$home_dir/.omp/agent/skills/templates"

HOME="$home_dir" "$REPO_ROOT/install.sh" >"$output_file" 2>&1

assert_symlink_target "$home_dir/.claude/skills/start-build" "$external_dir/custom-skill"
assert_symlink_target "$home_dir/.claude/agents/custom-agent.md" "$external_dir/custom-agent.md"
assert_symlink_target "$home_dir/.omp/agent/skills/start-build" "$external_dir/omp-custom-skill"
assert_symlink_target "$home_dir/.omp/agent/agents/custom-agent.md" "$external_dir/omp-custom-agent.md"

assert_contains "$output_file" "$home_dir/.claude/skills/start-build (existing symlink points outside repo: $custom_skill_abs)"
assert_contains "$output_file" "$home_dir/.omp/agent/skills/start-build (existing symlink points outside repo: $omp_custom_skill_abs)"

assert_skill_resolves_to_source "$home_dir/.claude/skills/start-review" "$REPO_ROOT/start-review"
assert_not_exists "$home_dir/.claude/agents/mr-reviewer.md"
assert_symlink_resolves_to "$home_dir/.omp/agent/agents/mr-reviewer-final.md" "$REPO_ROOT/agents/omp/mr-reviewer-final.md"
assert_symlink_resolves_to "$home_dir/.omp/agent/agents/mr-builder.md" "$REPO_ROOT/agents/omp/mr-builder.md"
assert_symlink_resolves_to "$home_dir/.claude/agents/mr-reviewer-final.md" "$REPO_ROOT/agents/claude/mr-reviewer-final.md"
assert_symlink_resolves_to "$home_dir/.claude/agents/mr-builder.md" "$REPO_ROOT/agents/claude/mr-builder.md"
for runtime in \
  "$home_dir/.claude/skills" \
  "$home_dir/.omp/agent/skills"; do
  assert_not_exists "$runtime/docs"
  assert_not_exists "$runtime/templates"
done
assert_not_exists "$home_dir/.claude/skills/old-repo-skill"
assert_not_exists "$home_dir/.claude/agents/old-repo-agent.md"

# A user-managed route-name collision exercises link(), unlike custom-agent.md,
# which is intentionally outside the repository's managed agent inventory.
collision_home="$TMP_ROOT/collision-home"
collision_output="$TMP_ROOT/collision-install.out"
mkdir -p \
  "$collision_home/.claude/agents" \
  "$collision_home/.omp/agent/agents"
ln -s "$external_dir/custom-agent.md" "$collision_home/.claude/agents/mr-builder.md"
ln -s "$external_dir/omp-custom-agent.md" "$collision_home/.omp/agent/agents/mr-builder.md"

HOME="$collision_home" "$REPO_ROOT/install.sh" >"$collision_output" 2>&1

assert_symlink_target "$collision_home/.claude/agents/mr-builder.md" "$external_dir/custom-agent.md"
assert_symlink_target "$collision_home/.omp/agent/agents/mr-builder.md" "$external_dir/omp-custom-agent.md"
custom_agent_abs="$("$REALPATH" -m "$external_dir/custom-agent.md")"
omp_custom_agent_abs="$("$REALPATH" -m "$external_dir/omp-custom-agent.md")"
assert_contains "$collision_output" "$collision_home/.claude/agents/mr-builder.md (existing symlink points outside repo: $custom_agent_abs)"
assert_contains "$collision_output" "$collision_home/.omp/agent/agents/mr-builder.md (existing symlink points outside repo: $omp_custom_agent_abs)"

echo "install-symlink-ownership: PASS"
