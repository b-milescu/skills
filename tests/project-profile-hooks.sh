#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

require_text() {
  local file="$1" pattern="$2" label="$3"
  if grep -Eq -- "$pattern" "$file"; then
    return
  fi
  if tr '\n' ' ' < "$file" | grep -Eq -- "$pattern"; then
    return
  fi
  echo "project-profile-hooks: FAIL: $file missing $label" >&2
  exit 1
}

schema="start-build/templates/gitlab-delivery-schema.md"
builder_copy="start-build/templates/builder-final-handoff.md"
reviewer_copy="start-review/templates/reviewer-final-handoff.md"

profile_fields=(
  profile_id
  profile_path
  gate_policy_ref
  label_profile_ref
  language_families
  auxiliary_index_policy
  branch_naming
  ci_jobs
  domain_docs
  release_deploy_policy
  manual_validation_rules
)

for field in "${profile_fields[@]}"; do
  require_text "$schema" "\\b${field}\\b" "project_profile field ${field}"
  require_text "$builder_copy" "\\b${field}\\b" "builder handoff project_profile field ${field}"
  require_text "$reviewer_copy" "\\b${field}\\b" "reviewer handoff project_profile field ${field}"
done

require_text "$schema" 'global delivery field names remain GitLab-specific' 'GitLab-specific schema-name rule'
require_text "$schema" '`issue`, `mr`, `pipeline`' 'GitLab issue/MR/pipeline field names'
require_text "$schema" '`source_branch`, `target_branch`, and `sha`' 'GitLab branch/SHA field names'
require_text "$schema" 'Do not add provider-neutral aliases' 'provider-neutral alias ban'

if grep -Eq '\b(pull_request|pull_request_url|pr_url|change_request|source_ref|target_ref|commit_hash)\b' "$schema"; then
  echo "project-profile-hooks: FAIL: provider-neutral aliases are not allowed in $schema" >&2
  exit 1
fi

invariant_docs=(
  "start-build/BUILD-FLOW.md"
  "start-build/reference/child-builder.md"
  "start-build/reference/context-and-planning.md"
  "start-review/REVIEW-FLOW.md"
  "gitlab/SKILL.md"
  "docs/agents/dev-workflows.md"
  "setup-dev-skills/dev-workflows-gitlab.md"
)

for file in "${invariant_docs[@]}"; do
  require_text "$file" 'Project-profile hooks|project_profile|project-profile' 'project-profile hook guidance'
  require_text "$file" 'reviewed-SHA binding' 'reviewed-SHA invariant'
  require_text "$file" 'exact-SHA CI' 'exact-SHA CI invariant'
  require_text "$file" 'explicit authority source' 'authority-source invariant'
  require_text "$file" 'independent review' 'independent review invariant'
  require_text "$file" 'child-builder' 'child-builder boundary invariant'
  require_text "$file" 'verifier read-only' 'verifier read-only invariant'
  require_text "$file" 'MCP-first transport correctness plus help-first `glab` fallback correctness|fallback help-first rule' 'MCP-first plus help-first fallback invariant'
done

setup_docs=(
  "setup-dev-skills/SKILL.md"
  "setup-dev-skills/dev-workflows-gitlab.md"
  "setup-dev-skills/check-gate.md"
  "setup-dev-skills/triage-labels.md"
  "setup-dev-skills/domain.md"
  "setup-dev-skills/issue-tracker-gitlab.md"
  "docs/agents/dev-workflows.md"
  "docs/agents/check-gate.md"
  "docs/agents/triage-labels.md"
  "docs/agents/domain.md"
  "docs/agents/issue-tracker.md"
)

for file in "${setup_docs[@]}"; do
  require_text "$file" 'project_profile|project-profile' 'project-profile setup hook'
done

removed_skill_surface='post-merge-verifier/SKILL'".md"
copy_brittle_seed_links=(
  '](../issue-delivery-loop/'
  "$removed_skill_surface"
  '](../start-build/'
)

for pattern in "${copy_brittle_seed_links[@]}"; do
  if grep -Fq -- "$pattern" "setup-dev-skills/dev-workflows-gitlab.md"; then
    echo "project-profile-hooks: FAIL: setup-dev-skills/dev-workflows-gitlab.md contains copy-brittle or removed-skill pattern: $pattern" >&2
    exit 1
  fi
done

for file in "setup-dev-skills/dev-workflows-gitlab.md" "docs/agents/dev-workflows.md"; do
  require_text "$file" 'gate_policy_ref' 'gate policy declaration hook'
  require_text "$file" 'label_profile_ref' 'label vocabulary declaration hook'
  require_text "$file" 'acceptance_surfaces_ref' 'acceptance-surface vocabulary declaration hook'
  require_text "$file" 'branch_naming' 'branch naming declaration hook'
  require_text "$file" 'ci_jobs' 'CI jobs declaration hook'
  require_text "$file" 'domain_docs' 'domain docs declaration hook'
  require_text "$file" 'manual_validation_rules' 'manual validation declaration hook'
  require_text "$file" 'auxiliary_index_policy' 'auxiliary index declaration hook'
  require_text "$file" 'release_deploy_policy' 'release/deploy declaration hook'
  require_text "$file" 'language_families' 'language family declaration hook'
  require_text "$file" 'Parent/coordinator checkouts own generated auxiliary project-index updates' 'parent-owned auxiliary index default'
  require_text "$file" 'Child worktrees treat index reports as read-only' 'child read-only index rule'
  require_text "$file" 'must not[[:space:]]+copy index artifacts between worktrees' 'no index artifact copying rule'
done

for file in "issue-delivery-loop/SKILL.md" "start-build/reference/parent-orchestrator.md" "start-build/reference/child-builder.md"; do
  require_text "$file" 'parent/coordinator' 'parent/coordinator auxiliary index owner'
  require_text "$file" 'Child worktrees treat index reports as read-only|child worktrees treat index reports as read-only' 'child index read-only rule'
  require_text "$file" 'must not copy index artifacts between worktrees' 'no index artifact copying rule'
done

echo "project-profile-hooks: PASS"
