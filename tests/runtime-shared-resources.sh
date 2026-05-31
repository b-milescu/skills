#!/usr/bin/env bash
# Regression coverage for shared skill resources when workflows run from another project.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skills-runtime-resources.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

assert_readable() {
  local path="$1"
  if [[ ! -r "$path" ]]; then
    echo "expected readable shared runtime resource: $path" >&2
    exit 1
  fi
}

assert_not_exists() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    echo "unexpected runtime skill-root resource entry: $path" >&2
    exit 1
  fi
}

home_dir="$TMP_ROOT/home"
foreign_project="$TMP_ROOT/foreign-project"
output_file="$TMP_ROOT/install.out"
bad_refs="$TMP_ROOT/bad-refs.out"

mkdir -p \
  "$home_dir/.claude" \
  "$home_dir/.pi/agent" \
  "$foreign_project"

HOME="$home_dir" "$REPO_ROOT/install.sh" >"$output_file" 2>&1

for runtime in \
  "$home_dir/.claude/skills" \
  "$home_dir/.pi/agent/skills"; do
  assert_not_exists "$runtime/docs"
  assert_not_exists "$runtime/templates"
done

if [[ -e "$foreign_project/docs/decoupling-contract.md" ]]; then
  echo "test setup error: foreign project unexpectedly has docs/decoupling-contract.md" >&2
  exit 1
fi

# Shared docs/templates must be available through skill-local resource symlinks,
# independent of the current project checkout, without placing non-skill
# resource directories in the runtime skill root. These paths mirror
# skill://<skill>/docs/... and skill://<skill>/shared-templates/... reads.
(
  cd "$foreign_project"
  for runtime in \
    "$home_dir/.claude/skills" \
    "$home_dir/.pi/agent/skills"; do
    for skill_file in "$REPO_ROOT"/*/SKILL.md; do
      skill_name="$(basename "$(dirname "$skill_file")")"
      assert_readable "$runtime/$skill_name/docs/decoupling-contract.md"
      assert_readable "$runtime/$skill_name/docs/effort-scaling.md"
      assert_readable "$runtime/$skill_name/shared-templates/filling-guide.md"
    done
  done
)

# Agent prompts run with the target project as cwd. A prompt-level instruction such
# as `read docs/decoupling-contract.md` therefore resolves to the target project
# and fails. Agents should load the workflow skill and follow its skill-relative
# Decoupling Contract links instead of naming this cwd-relative path directly.
: > "$bad_refs"
find -L \
  "$home_dir/.claude/agents" \
  "$home_dir/.pi/agent/agents" \
  -type f -name '*.md' -print0 |
  xargs -0 grep -nF 'docs/decoupling-contract.md' >"$bad_refs" || true

if [[ -s "$bad_refs" ]]; then
  echo "agent prompt(s) contain cwd-relative Decoupling Contract path(s):" >&2
  cat "$bad_refs" >&2
  echo "Use the start-build/start-review skill-relative Decoupling Contract links instead." >&2
  exit 1
fi

echo "runtime-shared-resources: PASS"
