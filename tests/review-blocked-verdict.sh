#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
  printf 'review-blocked-verdict: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

require_absent() {
  local file="$1" pattern="$2" label="$3"
  if grep -Eiq -- "$pattern" "$file"; then
    grep -Ein -- "$pattern" "$file" >&2 || true
    fail "$file still has $label"
  fi
}

normalize_enum() {
  tr '/|' '\n' |
    sed -E 's/[`"<>]//g; s/^[[:space:]]+//; s/[[:space:]]+$//' |
    sed '/^$/d'
}

assert_exact_values() {
  local label="$1" actual="$2"
  shift 2
  local expected=("$@")
  local expected_file="$TMPDIR/${label//[^A-Za-z0-9_]/_}.expected"
  local actual_file="$TMPDIR/${label//[^A-Za-z0-9_]/_}.actual"

  printf '%s\n' "${expected[@]}" > "$expected_file"
  printf '%s\n' "$actual" | normalize_enum > "$actual_file"
  if ! diff -u "$expected_file" "$actual_file" >/dev/null; then
    diff -u "$expected_file" "$actual_file" >&2 || true
    return 1
  fi
}

report_row_value() {
  local file="$1" row="$2"
  awk -F'|' -v row="$row" '
    $0 ~ /^\|/ {
      field=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      if (field == row) {
        value=$3
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

yaml_field_value() {
  local file="$1" field="$2"
  sed -nE "s/^[[:space:]]+${field}:[[:space:]]*\"([^\"]+)\".*/\1/p" "$file" | head -n1
}

expected_verdicts=(pass request-changes reject blocked)
expected_blockers=(
  none
  missing-authority
  stale-or-missing-ci
  changed-head-sha
  merge-conflict
  sha-bound-action-unsupported
  preflight-failure
  permission-failure
  human-decision-needed
  partial-review
  secret-exposure-suspected
  other
)

bad_verdict='pass | request-changes | reject'
if assert_exact_values 'bad verdict fixture' "$bad_verdict" "${expected_verdicts[@]}" 2>/dev/null; then
  fail 'negative verdict fixture without blocked was not rejected'
fi

bad_blockers='none / missing-authority / stale-or-missing-ci'
if assert_exact_values 'bad blocker fixture' "$bad_blockers" "${expected_blockers[@]}" 2>/dev/null; then
  fail 'negative action-blocker fixture missing stable tokens was not rejected'
fi

report_verdict="$(report_row_value start-review/templates/review-report.md 'Review verdict')"
handoff_verdict="$(yaml_field_value start-review/templates/reviewer-final-handoff.md review_verdict)"
assert_exact_values 'review report verdict enum' "$report_verdict" "${expected_verdicts[@]}" || fail 'Review Report verdict enum drifted'
assert_exact_values 'reviewer final handoff verdict enum' "$handoff_verdict" "${expected_verdicts[@]}" || fail 'reviewer final handoff verdict enum drifted'

report_blockers="$(report_row_value start-review/templates/review-report.md 'Action blocker')"
handoff_blockers="$(yaml_field_value start-review/templates/reviewer-final-handoff.md action_blocker)"
assert_exact_values 'review report action blockers' "$report_blockers" "${expected_blockers[@]}" || fail 'Review Report action blocker tokens drifted'
assert_exact_values 'reviewer final handoff action blockers' "$handoff_blockers" "${expected_blockers[@]}" || fail 'reviewer final handoff action blocker tokens drifted'

review_docs=(
  "start-review/SKILL.md"
  "start-review/REVIEW-FLOW.md"
  "start-review/templates/review-report.md"
  "start-review/templates/reviewer-final-handoff.md"
  "start-review/templates/filling-guide.md"
  "agents/claude/mr-reviewer.md"
  "agents/omp/mr-reviewer.md"
)

for file in "${review_docs[@]}"; do
  require_text "$file" 'pass[[:space:]]*/[[:space:]]*request-changes[[:space:]]*/[[:space:]]*reject[[:space:]]*/[[:space:]]*blocked|pass[[:space:]]*\|[[:space:]]*request-changes[[:space:]]*\|[[:space:]]*reject[[:space:]]*\|[[:space:]]*blocked' 'review verdict enum with blocked'
  require_absent "$file" 'approve[[:space:]]*/[[:space:]]*request-changes[[:space:]]*/[[:space:]]*reject|approve[[:space:]]*\|[[:space:]]*request-changes[[:space:]]*\|[[:space:]]*reject' 'approve-based review verdict enum'
done

revision_ready_docs=(
  "start-review/SKILL.md"
  "start-review/REVIEW-FLOW.md"
  "start-review/templates/review-report.md"
  "start-review/templates/filling-guide.md"
  "agents/claude/mr-reviewer.md"
  "agents/omp/mr-reviewer.md"
)

for file in "${revision_ready_docs[@]}"; do
  require_text "$file" 'revision-ready|bounded remedy direction' 'revision-ready MF guidance'
done

blocked_vs_revision_docs=(
  "start-review/SKILL.md"
  "start-review/REVIEW-FLOW.md"
  "start-review/templates/review-report.md"
  "start-review/templates/filling-guide.md"
)

for file in "${blocked_vs_revision_docs[@]}"; do
  require_text "$file" 'human-decision-needed' 'human decision blocked token'
  require_text "$file" 'builder revision work|builder work' 'blocked-vs-revision wording'
done

for field in 'Approval action' 'Finish action' 'Action blocker' 'Next action'; do
  require_text "start-review/templates/review-report.md" "$field" "Review Report $field field"
done

for field in 'review_verdict' 'approval_action' 'finish_action' 'action_blocker' 'next_action'; do
  require_text "start-review/templates/reviewer-final-handoff.md" "^[[:space:]]+$field:" "reviewer final handoff $field field"
done

routing_docs=(
  "start-review/SKILL.md"
  "start-review/REVIEW-FLOW.md"
  "start-review/templates/filling-guide.md"
  "agents/claude/mr-reviewer.md"
  "agents/omp/mr-reviewer.md"
)

for file in "${routing_docs[@]}"; do
  for blocker in \
    'missing-authority' \
    'stale-or-missing-ci' \
    'changed-head-sha' \
    'merge-conflict' \
    'sha-bound-action-unsupported' \
    'preflight-failure' \
    'permission-failure' \
    'human-decision-needed' \
    'partial-review' \
    'secret-exposure-suspected'; do
    require_text "$file" "$blocker" "$blocker blocked routing"
  done
  require_text "$file" 'Approval action' 'approval action routing'
  require_text "$file" 'Finish action' 'finish action routing'
  require_text "$file" 'Action blocker' 'action blocker routing'
done

# The four sibling Action-blocker vocabularies must carry `merge-conflict`
# immediately after `changed-head-sha`, matching the canonical enum order in
# start-build/templates/gitlab-delivery-schema.md. Guards future token additions
# from silently skipping these sites again (issue #255).
sibling_vocab_docs=(
  "agents/claude/mr-reviewer.md"
  "agents/omp/mr-reviewer.md"
  "start-review/reference/blocked-review-routing-card.md"
  "start-review/templates/filling-guide.md"
)

for file in "${sibling_vocab_docs[@]}"; do
  require_text "$file" 'changed-head-sha`,[[:space:]]*`merge-conflict`' \
    'merge-conflict immediately after changed-head-sha in canonical enum order'
done

printf 'review-blocked-verdict: PASS\n'
