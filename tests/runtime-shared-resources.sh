#!/usr/bin/env bash
# Regression coverage for shared skill resources when workflows run from another project.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_NAME="runtime-shared-resources"

# shellcheck source=tests/lib/assertions.sh
source "$REPO_ROOT/tests/lib/assertions.sh"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skills-runtime-resources.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

home_dir="$TMP_ROOT/home"
foreign_project="$TMP_ROOT/foreign-project"
output_file="$TMP_ROOT/install.out"
bad_refs="$TMP_ROOT/bad-refs.out"
workflow_bad_refs="$TMP_ROOT/workflow-bad-refs.out"
bad_shared_resource_ref_pattern='(^|[^A-Za-z0-9_:/.-])((\./)|(\.\./))*docs/(decoupling-contract|effort-scaling)\.md'
mkdir -p \
  "$home_dir/.claude" \
  "$home_dir/.pi/agent" \
  "$foreign_project"

HOME="$home_dir" "$REPO_ROOT/install.sh" >"$output_file" 2>&1

for runtime in \
  "$home_dir/.claude/skills" \
  "$home_dir/.pi/agent/skills"; do
  assert_path_absent "$runtime/docs" "runtime skill-root resource entry"
  assert_path_absent "$runtime/templates" "runtime skill-root resource entry"
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
      assert_path_readable "$runtime/$skill_name/docs/decoupling-contract.md" "shared runtime resource"
      assert_path_readable "$runtime/$skill_name/docs/effort-scaling.md" "shared runtime resource"
      assert_path_readable "$runtime/$skill_name/shared-templates/filling-guide.md" "shared runtime resource"
    done
  done
)

# Agent prompts run with the target project as cwd. A prompt-level instruction
# such as `read docs/decoupling-contract.md` or `read docs/effort-scaling.md`
# therefore resolves to the target project and fails. Agents should load the
# workflow skill and follow explicit skill:// URIs instead.
: > "$bad_refs"
find -L \
  "$home_dir/.claude/agents" \
  "$home_dir/.pi/agent/agents" \
  -type f -name '*.md' -print0 |
  xargs -0 grep -nE "$bad_shared_resource_ref_pattern" >"$bad_refs" || true
if [[ -s "$bad_refs" ]]; then
  echo "agent prompt(s) contain cwd-relative shared resource path(s):" >&2
  cat "$bad_refs" >&2
  echo "Use explicit skill://... URIs for Decoupling Contract and Effort Scaling shared resources." >&2
  exit 1
fi

# Workflow skill docs can also be read while cwd is a target project. Shared
# resource pointers there must be explicit skill:// URIs; repo-local docs/agents
# links stay local and are intentionally outside this shared-resource pattern.
: > "$workflow_bad_refs"
find \
  "$REPO_ROOT/gitlab-to-issues" \
  "$REPO_ROOT/issue-delivery-loop" \
  "$REPO_ROOT/start-build" \
  "$REPO_ROOT/start-review" \
  -path '*/docs' -prune -o \
  -type f -name '*.md' -print0 |
  xargs -0 grep -nE "$bad_shared_resource_ref_pattern" >"$workflow_bad_refs" || true

if [[ -s "$workflow_bad_refs" ]]; then
  echo "workflow doc(s) contain cwd-relative shared resource path(s):" >&2
  cat "$workflow_bad_refs" >&2
  echo "Use explicit skill://<skill>/docs/... URIs for shared Decoupling Contract and Effort Scaling reads." >&2
  exit 1
fi

echo "runtime-shared-resources: PASS"
