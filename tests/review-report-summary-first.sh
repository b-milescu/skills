#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
REPORT="$REPO_ROOT/start-review/templates/review-report.md"
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

require_summary_text 'Decision' 'decision field'
require_summary_text 'Reviewed SHA' 'reviewed SHA field'
require_summary_text 'CI status[[:space:]]*/[[:space:]]*SHA|CI .*status.*SHA' 'CI status/SHA field'
require_summary_text 'Findings summary' 'findings summary field'
require_summary_text 'MF' 'Must Fix (MF) summary'
require_summary_text 'SF' 'Should Fix (SF) summary'
require_summary_text 'C' 'Consider (C) summary'
require_summary_text 'Local checks' 'local checks field'
require_summary_text 'Report link' 'report link placeholder'

require_prompt_text() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  grep -Eiq "$pattern" "$file" || fail "$file missing $label"
}

prompt_files=(
  "$REPO_ROOT/start-review/templates/filling-guide.md"
  "$REPO_ROOT/start-review/SKILL.md"
  "$REPO_ROOT/agents/claude/mr-reviewer.md"
  "$REPO_ROOT/agents/pi/mr-reviewer.md"
)

for file in "${prompt_files[@]}"; do
  require_prompt_text "$file" 'Decision Summary' 'Decision Summary reference'
  require_prompt_text "$file" 'decision' 'decision summary field reference'
  require_prompt_text "$file" 'reviewed SHA' 'reviewed SHA summary field reference'
  require_prompt_text "$file" 'CI[^\n]*(status[[:space:]]*/[[:space:]]*SHA|status[^\n]*SHA)' 'CI status/SHA summary field reference'
  require_prompt_text "$file" 'MF-N[^\n]*SF-N[^\n]*C-N|MF[^\n]*SF[^\n]*C' 'MF/SF/C summary field reference'
  require_prompt_text "$file" 'local checks' 'local checks summary field reference'
  require_prompt_text "$file" 'Report link|report link' 'report link summary field reference'
done

printf 'review-report-summary-first: PASS\n'
