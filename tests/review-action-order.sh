#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'review-action-order: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

offset_of() {
  local file="$1" pattern="$2" label="$3" offset
  offset="$(LC_ALL=C grep -Eibom1 -- "$pattern" "$file" | head -n1 | cut -d: -f1 || true)"
  [[ -n "$offset" ]] || fail "$file missing ordered step: $label"
  printf '%s' "$offset"
}

assert_increasing() {
  local previous=-1
  local file="$1"
  shift
  while (( "$#" )); do
    local label="$1" pattern="$2" offset
    shift 2
    offset="$(offset_of "$file" "$pattern" "$label")"
    if (( offset <= previous )); then
      fail "$file step out of order: $label at byte $offset after $previous"
    fi
    previous="$offset"
  done
}

procedure="$(mktemp)"
trap 'rm -f "$procedure"' EXIT
awk '
  /^##[[:space:]]+Procedure[[:space:]]*$/ { in_section=1; next }
  in_section && /^##[[:space:]]+/ { exit }
  in_section { print }
' start-review/REVIEW-FLOW.md > "$procedure"

[[ -s "$procedure" ]] || fail 'start-review/REVIEW-FLOW.md Procedure section is empty'

assert_increasing "$procedure" \
  'draft Review Report before final guards' 'draft[^.]*Review Report|Review Report[^.]*draft' \
  'final MR/CI/authority snapshot' 'final MR/CI/authority snapshot|MR/CI/authority snapshot' \
  'convert guard failure to blocked before posting' 'convert[^.]*blocked|blocked[^.]*guard[^.]*fails' \
  'post Review Report after final snapshot' 'post[^.]*Review Report|Review Report[^.]*comment' \
  'SHA guard immediately before approval' 'sha-guard[^.]*before approving|before approving[^.]*sha-guard|SHA guard[^.]*before approval' \
  'authorized action after post-time SHA guard' 'authorized[^.]*action|approval/merge/auto-merge action' \
  'action-result note or final handoff after action' 'action-result note|final reviewer handoff|final handoff'

require_text \
  start-review/REVIEW-FLOW.md \
  'head SHA changes after[^.]*report[^.]*(posted|posting)[^.]*skip[^.]*(approval|merge|auto-merge)' \
  'stale-head-after-report skip guidance'
require_text \
  start-review/REVIEW-FLOW.md \
  '(final handoff|action-result note)[^.]*(stale SHA|changed-head-sha)|stale SHA[^.]*(final handoff|action-result note)' \
  'stale SHA final handoff/action-result reporting'
require_text \
  start-review/REVIEW-FLOW.md \
  'direct merge[^.]*(fresh|re-run)[^.]*SHA guard[^.]*immediately before[^.]*direct merge|fresh SHA guard[^.]*immediately before[^.]*direct merge' \
  'fresh SHA guard immediately before direct merge'
require_text \
  start-review/REVIEW-FLOW.md \
  '(auto-merge|queue)[^.]*(fresh|re-run)[^.]*SHA guard[^.]*immediately before[^.]*(auto-merge|queue)|fresh SHA guard[^.]*immediately before[^.]*(auto-merge|queue)' \
  'fresh SHA guard immediately before auto-merge queue'

for file in start-review/SKILL.md; do
  require_text "$file" 'draft[^.]*Review Report|Review Report[^.]*draft' 'draft Review Report before final guards prompt guidance'
  require_text "$file" 'final MR/CI/authority snapshot|MR/CI/authority snapshot' 'final MR/CI/authority snapshot prompt guidance'
  require_text "$file" 'head SHA changes after[^.]*report[^.]*(posted|posting)[^.]*skip' 'stale head after report skip prompt guidance'
done

require_text \
  start-review/templates/review-report.md \
  'intended action[^.]*completed action|completed action[^.]*intended action' \
  'intended-vs-completed action wording'
require_text \
  start-review/templates/filling-guide.md \
  'intended action[^.]*completed action|completed action[^.]*intended action' \
  'intended-vs-completed action filling guidance'
require_text \
  start-review/templates/filling-guide.md \
  'action failure[^.]*pass verdict|pass verdict[^.]*action failure' \
  'action failure after pass verdict guidance'

require_text   start-review/REVIEW-FLOW.md   'Finish owner: parent[^.]*not approve|do not approve[^.]*Finish owner: parent'   'parent-managed reviewer does not approve'
require_text   start-review/REVIEW-FLOW.md   'approval_action: "not-approved"[^.]*finish_action: "none"|finish_action: "none"[^.]*approval_action: "not-approved"'   'parent-managed enum-safe pass action values'

if grep -Fq 'otherwise take the authorized reviewer approval action' start-review/SKILL.md; then
  fail 'start-review/SKILL.md still contains the obsolete standalone approval clause'
fi

printf 'review-action-order: PASS\n'
