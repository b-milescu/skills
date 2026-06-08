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
portable_resource_bad_refs="$TMP_ROOT/portable-resource-bad-refs.out"
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
# The readiness scorecard lives under shared docs/agents and must also be
# reachable as a skill-owned resource for cross-project issue creation.
(
  cd "$foreign_project"
  for runtime in \
    "$home_dir/.claude/skills" \
    "$home_dir/.pi/agent/skills"; do
    for skill_file in "$REPO_ROOT"/*/SKILL.md; do
      skill_name="$(basename "$(dirname "$skill_file")")"
      assert_path_readable "$runtime/$skill_name/docs/decoupling-contract.md" "shared runtime resource"
      assert_path_readable "$runtime/$skill_name/docs/effort-scaling.md" "shared runtime resource"
      assert_path_readable "$runtime/$skill_name/docs/agents/agent-readiness-scorecard.md" "shared runtime resource"
      assert_path_readable "$runtime/$skill_name/shared-templates/filling-guide.md" "shared runtime resource"
    done
  done
)

# Agent prompts and invoked workflow skill entrypoints run with the target
# project as cwd. Prompt-level instructions such as `read
# docs/decoupling-contract.md`, `read templates/issue-body.md`, or `read
# start-build/templates/reviewer-lift-schema.md` therefore resolve against the
# target project and fail. Skill-owned resources must use explicit
# skill://<skill>/... URIs. Target-repo policy docs such as
# <repo-root>/docs/agents/... or documented repo-relative docs/agents/... stay
# target-rooted and are intentionally allowed.
: > "$portable_resource_bad_refs"
python3 - "$REPO_ROOT" >"$portable_resource_bad_refs" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
skill_names = {
    "gitlab-local",
    "gitlab-to-issues",
    "issue-delivery-loop",
    "setup-dev-skills",
    "start-build",
    "start-review",
}
skill_name_pattern = "|".join(re.escape(name) for name in sorted(skill_names))
cross_skill_ref = re.compile(
    rf"(?<!skill://)(?:\.\./)*(?:{skill_name_pattern})/"
    r"(?:SKILL\.md|BUILD-FLOW\.md|REVIEW-FLOW\.md|SAFETY\.md|"
    r"reference/[A-Za-z0-9_./#-]+|templates/[A-Za-z0-9_./#-]+|"
    r"scripts/[A-Za-z0-9_./#-]+|shared-templates/[A-Za-z0-9_./#-]+|"
    r"docs/(?:decoupling-contract|effort-scaling|agents/agent-readiness-scorecard)\.md(?:#[A-Za-z0-9_-]+)?)"
)
current_skill_ref_template = (
    r"(?<!skill://{skill}/)(?<![A-Za-z0-9_:/<.-])"
    r"(?:(?:reference|templates|scripts|shared-templates)/[A-Za-z0-9_./#-]+\.(?:md|json|sh)(?:#[A-Za-z0-9_-]+)?|"
    r"(?:BUILD-FLOW|REVIEW-FLOW|SAFETY)\.md(?:#[A-Za-z0-9_-]+)?)"
)
shared_doc_ref = re.compile(
    r"(?<!skill://[A-Za-z0-9_-]/)(?<![A-Za-z0-9_:/<.-])"
    r"(?:\./|\.\./)*docs/(?:decoupling-contract|effort-scaling)\.md"
)

surfaces = sorted(root.glob("*/SKILL.md")) + sorted(root.glob("agents/*/*.md"))
violations = []
for path in surfaces:
    rel = path.relative_to(root)
    text = path.read_text(encoding="utf-8")
    current_skill = path.parent.name if path.name == "SKILL.md" else None
    current_skill_ref = (
        re.compile(current_skill_ref_template.format(skill=re.escape(current_skill)))
        if current_skill in skill_names
        else None
    )
    for line_number, line in enumerate(text.splitlines(), 1):
        reasons = []
        if cross_skill_ref.search(line):
            reasons.append("cross-skill resource path")
        if current_skill_ref and current_skill_ref.search(line):
            reasons.append("current-skill resource path")
        if shared_doc_ref.search(line):
            reasons.append("shared docs path")
        if (
            "docs/agents/agent-readiness-scorecard.md#scorecard" in line
            and "skill://gitlab-to-issues/docs/agents/agent-readiness-scorecard.md#scorecard" not in line
            and "<repo-root>/docs/agents/agent-readiness-scorecard.md" not in line
        ):
            reasons.append("readiness scorecard path")
        if (
            "templates/issue-body.md" in line
            and "skill://gitlab-to-issues/templates/issue-body.md" not in line
        ):
            reasons.append("issue body template path")
        if reasons:
            violations.append(f"{rel}:{line_number}: {', '.join(reasons)}: {line}")

if violations:
    print("\n".join(violations))
PY

if [[ -s "$portable_resource_bad_refs" ]]; then
  echo "invoked surface(s) contain cwd-relative skill-owned resource path(s):" >&2
  cat "$portable_resource_bad_refs" >&2
  echo "Use explicit skill://<skill>/... URIs for reusable skill-owned docs/templates/scripts." >&2
  exit 1
fi

assert_file_contains "$REPO_ROOT/gitlab-to-issues/SKILL.md" "skill://gitlab-to-issues/docs/agents/agent-readiness-scorecard.md#scorecard" "portable Agent Readiness scorecard resource"
assert_file_contains "$REPO_ROOT/gitlab-to-issues/SKILL.md" "skill://gitlab-to-issues/templates/issue-body.md#agent-readiness" "portable issue body template resource"
assert_file_contains "$REPO_ROOT/gitlab-to-issues/SKILL.md" "<repo-root>/docs/agents/agent-readiness-scorecard.md" "target-rooted readiness policy reference"
assert_file_contains "$REPO_ROOT/setup-dev-skills/SKILL.md" "skill://setup-dev-skills/dev-workflows-gitlab.md" "portable GitLab setup seed resource"
assert_file_contains "$REPO_ROOT/setup-dev-skills/dev-workflows-gitlab.md" "skill://gitlab-to-issues/docs/agents/agent-readiness-scorecard.md" "portable setup readiness scorecard resource"

echo "runtime-shared-resources: PASS"
