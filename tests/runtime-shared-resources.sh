#!/usr/bin/env bash
# Focus: disposable temp-HOME installs prove Windows, Linux, and macOS
# shared-resource behavior for both native symlink-preserving checkouts and
# symlink-disabled checkouts where Git materializes links as relative-target
# files. Installed Claude and OMP skills expose the canonical shared
# docs/templates through skill-local `docs/` and `shared-templates/` paths
# from a foreign project cwd, including the Agent Readiness scorecard; runtime
# skill roots do not expose `docs`/`templates` as bogus skills; invoked agent
# prompts and workflow skill entrypoints use explicit `skill://<skill>/...`
# URIs for reusable skill-owned docs/templates/scripts while preserving
# target-rooted `docs/agents/...` policy references.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_NAME="runtime-shared-resources"

# shellcheck source=tests/lib/assertions.sh
source "$REPO_ROOT/tests/lib/assertions.sh"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/skills-runtime-resources.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

foreign_project="$TMP_ROOT/foreign-project"
portable_resource_bad_refs="$TMP_ROOT/portable-resource-bad-refs.out"
mkdir -p "$foreign_project"

create_checkout_fixture() {
  local checkout="$1" resource_kind="$2" skill_file skill_name

  mkdir -p \
    "$checkout/docs/agents" \
    "$checkout/templates"
  cp "$REPO_ROOT/install.sh" "$checkout/install.sh"
  cp "$REPO_ROOT/docs/decoupling-contract.md" "$checkout/docs/decoupling-contract.md"
  cp "$REPO_ROOT/docs/effort-scaling.md" "$checkout/docs/effort-scaling.md"
  cp "$REPO_ROOT/docs/agents/agent-readiness-scorecard.md" "$checkout/docs/agents/agent-readiness-scorecard.md"
  cp "$REPO_ROOT/templates/filling-guide.md" "$checkout/templates/filling-guide.md"

  for skill_file in "$REPO_ROOT"/*/SKILL.md; do
    skill_name="$(basename "$(dirname "$skill_file")")"
    mkdir -p "$checkout/$skill_name"
    cp "$skill_file" "$checkout/$skill_name/SKILL.md"
    if [[ "$resource_kind" == symlink ]]; then
      ln -s ../docs "$checkout/$skill_name/docs"
      ln -s ../templates "$checkout/$skill_name/shared-templates"
    else
      printf '%s\n' ../docs >"$checkout/$skill_name/docs"
      printf '%s\n' ../templates >"$checkout/$skill_name/shared-templates"
    fi
  done
}

assert_fixture_install() {
  local checkout="$1" home_dir="$2" fixture_label="$3" runtime skill_file skill_name

  mkdir -p \
    "$home_dir/.claude" \
    "$home_dir/.omp/agent"
  HOME="$home_dir" bash "$checkout/install.sh" >"$TMP_ROOT/$fixture_label-install.out" 2>&1
  HOME="$home_dir" bash "$checkout/install.sh" >>"$TMP_ROOT/$fixture_label-install.out" 2>&1

  (
    cd "$foreign_project"
    for runtime in \
      "$home_dir/.claude/skills" \
      "$home_dir/.omp/agent/skills"; do
      assert_path_absent "$runtime/docs" "$fixture_label runtime skill-root resource entry"
      assert_path_absent "$runtime/templates" "$fixture_label runtime skill-root resource entry"
      for skill_file in "$checkout"/*/SKILL.md; do
        skill_name="$(basename "$(dirname "$skill_file")")"
        assert_path_readable "$runtime/$skill_name/docs/decoupling-contract.md" "$fixture_label shared runtime resource"
        assert_path_readable "$runtime/$skill_name/docs/effort-scaling.md" "$fixture_label shared runtime resource"
        assert_path_readable "$runtime/$skill_name/docs/agents/agent-readiness-scorecard.md" "$fixture_label shared runtime resource"
        assert_path_readable "$runtime/$skill_name/shared-templates/filling-guide.md" "$fixture_label shared runtime resource"
      done
    done
  )
}

native_checkout="$TMP_ROOT/native-symlink-checkout"
regular_checkout="$TMP_ROOT/regular-file-checkout"
create_checkout_fixture "$native_checkout" symlink
create_checkout_fixture "$regular_checkout" regular
assert_fixture_install "$native_checkout" "$TMP_ROOT/native-home" native-symlink
assert_fixture_install "$regular_checkout" "$TMP_ROOT/regular-home" regular-file

if [[ -e "$foreign_project/docs/decoupling-contract.md" ]]; then
  echo "test setup error: foreign project unexpectedly has docs/decoupling-contract.md" >&2
  exit 1
fi

# Agent prompts and invoked workflow skill entrypoints run with the target
# project as cwd. Prompt-level instructions such as `read
# docs/decoupling-contract.md`, `read templates/issue-body.md`, or `read
# start-build/templates/reviewer-lift-schema.md` therefore resolve against the
# target project and fail. Skill-owned resources must use explicit
# skill://<skill>/... URIs. Target-repo policy docs such as
# <repo-root>/docs/agents/... or documented repo-relative docs/agents/... stay
# target-rooted and are intentionally allowed.
PYTHON=python3
command -v "$PYTHON" >/dev/null 2>&1 && "$PYTHON" --version >/dev/null 2>&1 || PYTHON=python

: > "$portable_resource_bad_refs"
"$PYTHON" - "$REPO_ROOT" >"$portable_resource_bad_refs" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
skill_names = {
    "gitlab",
    "plan-to-issues",
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

link_pattern = re.compile(r"\[[^\]]+\]\(skill://[A-Za-z0-9_-]+/[^)]+\)")
probe_ref = re.compile(current_skill_ref_template.format(skill="start-review"))
assert not probe_ref.search(link_pattern.sub("", "[REVIEW-FLOW.md](skill://start-review/REVIEW-FLOW.md)"))
assert probe_ref.search("REVIEW-FLOW.md")
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
        portable_line = link_pattern.sub("", line)
        reasons = []
        if cross_skill_ref.search(portable_line):
            reasons.append("cross-skill resource path")
        if current_skill_ref and current_skill_ref.search(portable_line):
            reasons.append("current-skill resource path")
        if shared_doc_ref.search(portable_line):
            reasons.append("shared docs path")
        if (
            "docs/agents/agent-readiness-scorecard.md#scorecard" in line
            and "skill://plan-to-issues/docs/agents/agent-readiness-scorecard.md#scorecard" not in line
        ):
            reasons.append("readiness scorecard path")
        if (
            "templates/issue-body.md" in line
            and "skill://plan-to-issues/templates/issue-body.md" not in line
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

assert_file_contains "$REPO_ROOT/plan-to-issues/SKILL.md" "skill://plan-to-issues/docs/agents/agent-readiness-scorecard.md#scorecard" "portable Agent Readiness scorecard resource"
assert_file_contains "$REPO_ROOT/plan-to-issues/SKILL.md" "skill://plan-to-issues/templates/issue-body.md#agent-readiness" "portable issue body template resource"
assert_file_contains "$REPO_ROOT/setup-dev-skills/SKILL.md" "skill://setup-dev-skills/dev-workflows-generic.md" "portable neutral setup seed resource"

echo "runtime-shared-resources: PASS"
