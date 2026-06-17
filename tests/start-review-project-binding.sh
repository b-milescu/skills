#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-review-project-binding: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

forbid_text() {
  local file="$1" pattern="$2" label="$3"
  if grep -Ein -- "$pattern" "$file"; then
    fail "$file contains forbidden ambiguous bare-ID guidance: $label"
  fi
}

offset_of() {
  local file="$1" pattern="$2" label="$3" offset
  offset="$(LC_ALL=C grep -Eibom1 -- "$pattern" "$file" | head -n1 | cut -d: -f1 || true)"
  [[ -n "$offset" ]] || fail "$file missing ordered text: $label"
  printf '%s' "$offset"
}

FLOW="start-review/REVIEW-FLOW.md"
SKILL="start-review/SKILL.md"
REPORT="start-review/templates/review-report.md"
HANDOFF="start-review/templates/reviewer-final-handoff.md"
GUIDE="start-review/templates/filling-guide.md"

binding_offset="$(offset_of "$FLOW" '^##[[:space:]]+Project binding[[:space:]]*$' 'Project binding section')"
pickup_offset="$(offset_of "$FLOW" '^##[[:space:]]+MR pickup[[:space:]]*$' 'MR pickup section')"
procedure_offset="$(offset_of "$FLOW" '^##[[:space:]]+Procedure[[:space:]]*$' 'Procedure section')"
if (( binding_offset >= pickup_offset || binding_offset >= procedure_offset )); then
  fail 'Project binding section must appear before MR pickup and Procedure'
fi

require_text "$FLOW" 'supplied MR (URL|IID|ID|branch)' 'supplied MR URL/ID/branch binding scope'
require_text "$FLOW" 'before any (MR )?(comment|approval|merge|auto-merge|close)' 'pre-mutation binding requirement'
require_text "$FLOW" 'comments?, approvals?, merge, auto-merge, or close-equivalent actions' 'mutation surface list'
require_text "$FLOW" 'bound_host' 'bound host field'
require_text "$FLOW" 'bound_project_path' 'bound project path field'
require_text "$FLOW" 'bound_repo_url' 'bound repo URL field'
require_text "$FLOW" 'bound_mr_iid' 'bound MR IID field'
require_text "$FLOW" 'bound_source_branch' 'bound source branch field'
require_text "$FLOW" 'bound_target_branch' 'bound target branch field'
require_text "$FLOW" 'bound_current_sha' 'bound current SHA field'
require_text "$FLOW" 'preflight repo' 'local preflight repo comparison'
require_text "$FLOW" 'mismatch[^.]*blocks[^.]*cross-repo review target|cross-repo review target[^.]*mismatch[^.]*blocks' 'mismatch blocks unless explicit cross-repo target'
require_text "$FLOW" 'explicit repo target[^.]*full MR URL|full MR URL[^.]*explicit repo target' 'explicit target or full URL command rule'
require_text "$FLOW" 'bound_mr_ref|bound_mr_iid.*bound_repo_url|bound_mr_url' 'bound MR reference used for commands'

for file in "$SKILL"; do
  require_text "$file" 'project-binding|project binding' 'project-binding prompt guidance'
  require_text "$file" 'host, project path, repo URL, IID, source branch, target branch, and current SHA' 'bound-field prompt list'
  require_text "$file" 'explicit repo target[^.]*full MR URL|full MR URL[^.]*explicit repo target' 'explicit target/full URL prompt rule'
done

for file in "$REPORT" "$HANDOFF" "$GUIDE"; do
  require_text "$file" 'bound MR (URL|target)|bound_url' 'bound MR URL/reporting field'
  require_text "$file" 'bound MR project|project_path' 'bound MR project/reporting field'
done

# Start-review-owned docs must not show ambiguous bare-ID action examples. Use
# bound MR URL or explicit repo target when showing glab commands that decide or
# mutate MR state.
for file in "$FLOW" "$SKILL" "$GUIDE"; do
  forbid_text "$file" 'glab[[:space:]]+mr[[:space:]]+(view|note create|approve|merge|update|close)[[:space:]]+<id>([[:space:]]|`|$)' 'glab mr action/view <id>'
  forbid_text "$file" 'glab[[:space:]]+issue[[:space:]]+(close|note|update)[[:space:]]+<id>([[:space:]]|`|$)' 'glab issue mutation <id>'
done

printf 'start-review-project-binding: PASS\n'
