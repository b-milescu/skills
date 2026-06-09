#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
REPORT="$REPO_ROOT/start-review/templates/review-report.md"
# shellcheck source=tests/lib/agent-prompt-sets.sh
source "$REPO_ROOT/tests/lib/agent-prompt-sets.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
  printf 'review-report-summary-first: FAIL: %s\n' "$*" >&2
  exit 1
}

first_heading="$(awk '/^##[[:space:]]+/ { sub(/^##[[:space:]]+/, ""); print; exit }' "$REPORT")"
[[ "$first_heading" == "Decision Summary" ]] || {
  fail "first Review Report section must be 'Decision Summary', got '${first_heading:-<none>}'"
}

summary="$TMPDIR/decision-summary.md"
awk '
  /^##[[:space:]]+Decision Summary[[:space:]]*$/ { in_summary=1; next }
  in_summary && /^##[[:space:]]+/ { exit }
  in_summary { print }
' "$REPORT" > "$summary"

[[ -s "$summary" ]] || fail "Decision Summary section is empty"

require_summary_text() {
  local pattern="$1"
  local label="$2"
  grep -Eiq "$pattern" "$summary" || fail "Decision Summary missing $label"
}

require_summary_text 'Review verdict' 'review verdict field'
require_summary_text 'pass[[:space:]]*/[[:space:]]*request-changes[[:space:]]*/[[:space:]]*reject[[:space:]]*/[[:space:]]*blocked' 'blocked-capable verdict enum'
require_summary_text 'Reviewed SHA' 'reviewed SHA field'
require_summary_text 'CI status[[:space:]]*/[[:space:]]*SHA|CI .*status.*SHA' 'CI status/SHA field'
require_summary_text 'Findings summary' 'findings summary field'
require_summary_text 'MF' 'Must Fix (MF) summary'
require_summary_text 'SF' 'Should Fix (SF) summary'
require_summary_text 'C' 'Consider (C) summary'
require_summary_text 'Local checks' 'local checks field'
require_summary_text 'Approval action' 'approval action field'
require_summary_text 'Finish action' 'finish action field'
require_summary_text 'Action blocker' 'action blocker field'
require_summary_text 'Next action' 'next action field'
require_summary_text 'Report link' 'report link placeholder'

require_template_heading() {
  local heading="$1"
  local label="$2"
  grep -Eq "^##[[:space:]]+${heading}[[:space:]]*$" "$REPORT" || fail "Review Report missing $label"
}

require_template_heading 'Context / Snapshot' 'core context/snapshot section'
require_template_heading 'Findings' 'core findings section'
require_template_heading 'Open Questions Addressed' 'core Open Questions section'
require_template_heading 'Evidence' 'core evidence section'
require_template_heading 'Action / Blocker' 'core action/blocker section'
require_template_heading 'Optional Annex: Checklists' 'optional checklist annex'

if grep -En 'None\.' "$REPORT"; then
  fail "Review Report template contains hardcoded 'None.' placeholder"
fi

extract_section() {
  local file="$1" heading="$2"
  awk -v heading="$heading" '
    $0 == "## " heading { in_section=1; next }
    in_section && /^##[[:space:]]+/ { exit }
    in_section { print }
  ' "$file"
}

assert_required_sections_placeholder_clean() {
  local file="$1" section content
  for section in 'Findings' 'Open Questions Addressed' 'Evidence' 'Action / Blocker'; do
    content="$(extract_section "$file" "$section")"
    [[ -n "$content" ]] || return 1
    if grep -En '^[[:space:]]*None\.?[[:space:]]*$|None\.' <<<"$content"; then
      return 1
    fi
  done
}

bad_placeholders="$TMPDIR/bad-required-placeholders.md"
cat > "$bad_placeholders" <<'BAD'
# Review Report

## Decision Summary

| Field | Value |
|---|---|
| Review verdict | `<pass / request-changes / reject / blocked>` |
| Reviewed SHA | `<sha>` |
| CI status / SHA | `<status / sha>` |
| Findings summary | `MF: 0; SF: 0; C: 0` |
| Local checks | `<checks>` |
| Approval action | `<action>` |
| Finish action | `<action>` |
| Action blocker | `<none / missing-authority / stale-or-missing-ci / changed-head-sha / sha-bound-action-unsupported / preflight-failure / permission-failure / human-decision-needed / partial-review / secret-exposure-suspected / other>` |
| Next action | `<next>` |
| Report link | `<link>` |

## Findings

None.

## Open Questions Addressed

None.

## Evidence

None.

## Action / Blocker

None.
BAD

if assert_required_sections_placeholder_clean "$bad_placeholders" >/dev/null 2>&1; then
  fail "negative fixture with hardcoded None placeholders was not rejected"
fi

assert_required_sections_placeholder_clean "$REPORT" || fail "Review Report required sections contain hardcoded None placeholders"

for old_heading in \
  'Safety Checklist' \
  'State / Migration / Persistence Checklist' \
  'External-System and Credential Checklist' \
  'Praise'; do
  if grep -Eq "^##[[:space:]]+${old_heading}[[:space:]]*$" "$REPORT"; then
    fail "Review Report keeps old required top-level ${old_heading}; move it under optional annex/compact sections"
  fi
done

require_prompt_text() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  grep -Eiq "$pattern" "$file" || fail "$file missing $label"
}

prompt_files=(
  "$REPO_ROOT/start-review/templates/filling-guide.md"
  "$REPO_ROOT/start-review/SKILL.md"
  $(agent_prompt_paths_under "$REPO_ROOT" mr-reviewer)
)
routed_final_reviewer_prompts=( $(agent_prompt_paths_under "$REPO_ROOT" "${routed_final_reviewer_prompt_names[@]}") )

for file in "${prompt_files[@]}"; do
  require_prompt_text "$file" 'Decision Summary' 'Decision Summary reference'
  require_prompt_text "$file" 'Review verdict' 'review verdict summary field reference'
  require_prompt_text "$file" 'pass[[:space:]]*/[[:space:]]*request-changes[[:space:]]*/[[:space:]]*reject[[:space:]]*/[[:space:]]*blocked' 'blocked-capable verdict enum reference'
  require_prompt_text "$file" 'reviewed SHA' 'reviewed SHA summary field reference'
  require_prompt_text "$file" 'CI[^\n]*(status[[:space:]]*/[[:space:]]*SHA|status[^\n]*SHA)' 'CI status/SHA summary field reference'
  require_prompt_text "$file" 'MF-N[^\n]*SF-N[^\n]*C-N|MF[^\n]*SF[^\n]*C' 'MF/SF/C summary field reference'
  require_prompt_text "$file" 'local checks' 'local checks summary field reference'
  require_prompt_text "$file" 'Approval action' 'approval action summary field reference'
  require_prompt_text "$file" 'Finish action' 'finish action summary field reference'
  require_prompt_text "$file" 'Action blocker' 'action blocker summary field reference'
  require_prompt_text "$file" 'Next action' 'next action summary field reference'
  require_prompt_text "$file" 'Report link|report link' 'report link summary field reference'
done

for file in "${routed_final_reviewer_prompts[@]}"; do
  require_prompt_text "$file" 'Review Report' 'routed reviewer Review Report reference'
  require_prompt_text "$file" 'final handoff' 'routed reviewer final handoff reference'
  require_prompt_text "$file" 'MR, SHA, CI/gate, authority, finding, action, and blocker evidence' 'routed reviewer report/handoff evidence fields'
  require_prompt_text "$file" 'verdict, approval action, finish action, action blocker, and next action separate' 'routed reviewer action separation'
done

require_prompt_text "$REPO_ROOT/start-review/templates/filling-guide.md" 'Context / Snapshot' 'Context / Snapshot filling guidance'
require_prompt_text "$REPO_ROOT/start-review/templates/filling-guide.md" 'Findings' 'Findings filling guidance'
require_prompt_text "$REPO_ROOT/start-review/templates/filling-guide.md" 'Open Questions Addressed' 'Open Questions filling guidance'
require_prompt_text "$REPO_ROOT/start-review/templates/filling-guide.md" 'Evidence' 'Evidence filling guidance'
require_prompt_text "$REPO_ROOT/start-review/templates/filling-guide.md" 'Action / Blocker' 'Action / Blocker filling guidance'
require_prompt_text "$REPO_ROOT/start-review/templates/filling-guide.md" 'Optional Annex: Checklists' 'optional checklist annex filling guidance'

printf 'review-report-summary-first: PASS\n'
