#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

schema="start-build/templates/gitlab-delivery-schema.md"
copies=(
  "start-build/templates/builder-final-handoff.md"
  "start-review/templates/reviewer-final-handoff.md"
)

TEST_NAME="gitlab-delivery-schema"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# shellcheck source=tests/lib/schema-sync.sh
source "$REPO_ROOT/tests/lib/schema-sync.sh"

require_text() {
  require_text_case_sensitive "$@"
}

extract_schema_fields() {
  extract_markdown_table_fields "$schema" 'GITLAB-DELIVERY-FIELDS:BEGIN' 'GITLAB-DELIVERY-FIELDS:END'
}

extract_copy_fields() {
  local file="$1"
  extract_yaml_keys_from_marked_block "$file" 'GITLAB-DELIVERY-SCHEMA:BEGIN' 'GITLAB-DELIVERY-SCHEMA:END'
}

extract_schema_fields > "$tmpdir/schema.fields"

if [ ! -s "$tmpdir/schema.fields" ]; then
  echo "GitLab Delivery schema drift: canonical field list is empty" >&2
  exit 1
fi

for copy in "${copies[@]}"; do
  extract_copy_fields "$copy" > "$tmpdir/$(basename "$copy").fields"
  if [ ! -s "$tmpdir/$(basename "$copy").fields" ]; then
    echo "GitLab Delivery schema drift: $copy has no generated-copy block" >&2
    exit 1
  fi
  assert_files_match "$tmpdir/schema.fields" "$tmpdir/$(basename "$copy").fields" "GitLab Delivery schema drift: $copy does not match $schema"
done

for copy in "${copies[@]}"; do
  require_text "$copy" 'source_branch' 'GitLab source_branch noun in delivery copy'
  require_text "$copy" 'target_branch' 'GitLab target_branch noun in delivery copy'
done
for file in "$schema" "${copies[@]}"; do
  require_text "$file" 'handoff_contract' 'shared handoff contract field'
done

for token in \
  'phase' \
  'expected_next_actor' \
  'expected_next_action' \
  'blocked' \
  'blocker_token' \
  'required_parent_decision' \
  'safe_to_continue_without_parent' \
  'changed_since_last_handoff' \
  'evidence_ready_for_next_actor'; do
  require_text "$schema" "$token" "handoff contract token $token"
done

require_text "$schema" 'use `none` or a concise decision' 'required_parent_decision guidance'
require_text "$schema" '`blocking_question`' 'optional blocking_question guidance'
require_text "$schema" 'specific actionable question' 'blocking_question specificity guidance'

for copy in "${copies[@]}"; do
  for token in \
    'phase:' \
    'expected_next_actor:' \
    'expected_next_action:' \
    'blocked:' \
    'blocker_token:' \
    'required_parent_decision:' \
    'safe_to_continue_without_parent:' \
    'changed_since_last_handoff:' \
    'evidence_ready_for_next_actor:'; do
    require_text "$copy" "$token" "delivery copy routing token $token"
  done
done

require_text "$schema" 'kind: "gitlab-delivery"' 'fixed delivery kind example'
require_text "$schema" '`not_run_reason` enum' 'not_run_reason taxonomy'
require_text "$schema" 'parent-owned' 'parent-owned gate not-run reason'
require_text "$schema" '`tier-1`' 'tier-1 evidence taxonomy'
require_text "$schema" '`tier-2`' 'tier-2 evidence taxonomy'
require_text "$schema" '`tier-3`' 'tier-3 index taxonomy'
require_text "$schema" '`issue-metadata`' 'evidence kind enum'
require_text "$schema" '`gate-receipt`' 'evidence kind enum'
require_text "$schema" '`mr-metadata`' 'evidence kind enum'
require_text "$schema" '`default-after-pass`' 'approval authority enum'
require_text "$schema" '`approval-only`' 'authority enum'
require_text "$schema" '`queue auto-merge`' 'authority enum'
require_text "$schema" '`auto-merge queued`' 'finish action enum'
require_text "$schema" '`secret-exposure-suspected`' 'action blocker enum'
require_text "$schema" '`spawn-reviewer`' 'builder next-action token'
require_text "$schema" '`parent-run-gate`' 'builder parent-owned gate next-action token'
require_text "$schema" '`finish-by-authorized-actor`' 'reviewer/parent next-action token'
require_text "$schema" '`post-merge-verify`' 'parent next-action token'
require_text "$schema" '`done`' 'verifier next-action token'
require_text "$schema" 'post_merge_snapshot' 'post-merge snapshot schema anchor'
require_text "$schema" 'post-merge-snapshot' 'post-merge snapshot fixed kind'
require_text "$schema" 'contains_reviewed_sha' 'post-merge reviewed containment field'
require_text "$schema" 'contains_merge_commit_sha' 'post-merge merge containment field'
require_text "$schema" 'contains_squash_commit_sha' 'post-merge squash containment field'

# Acceptance surfaces: schema declares taxonomy, copies carry field, workflow docs require verification
require_text "$schema" 'acceptance_surfaces' 'acceptance_surfaces field in delivery schema'
require_text "$schema" 'Acceptance surfaces taxonomy' 'acceptance_surfaces taxonomy section heading'
for surface in 'docs' 'prompt' 'agent_inventory' 'install_surface' 'transport' 'authority' 'ci_finish' 'mutation_guard'; do
  require_text "$schema" "$surface" "acceptance_surfaces taxonomy surface: $surface"
done
for ev in 'test' 'smoke' 'docs-read' 'ci'; do
  require_text "$schema" "$ev" "acceptance_surfaces evidence value: $ev"
done
require_text "start-review/REVIEW-FLOW.md" 'Acceptance surfaces' 'reviewer flow acceptance surface verification requirement'
require_text "start-build/reference/parent-owned-gate.md" 'Acceptance surfaces' 'parent gate acceptance surface verification requirement'

if grep -Eq '\bpull_request\b|\bpull_request_url\b|\bpr_url\b' "$schema"; then
  echo "gitlab-delivery-schema: FAIL: provider-neutral pull-request aliases are not allowed" >&2
  exit 1
fi

echo "gitlab-delivery-schema: PASS"