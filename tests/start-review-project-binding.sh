#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() { printf 'start-review-project-binding: FAIL: %s\n' "$*" >&2; exit 1; }
require() { grep -Eiq -- "$2" "$1" || fail "$1 missing $3"; }
reject() { ! grep -Eiq -- "$2" "$1" || fail "$1 contains $3"; }

flow="start-review/REVIEW-FLOW.md"
skill="start-review/SKILL.md"
report="start-review/templates/review-report.md"
handoff="start-review/templates/reviewer-final-handoff.md"
guide="start-review/templates/filling-guide.md"

for file in "$flow" "$skill"; do
  require "$file" 'forge preflight' 'forge preflight'
  require "$file" 'provider' 'provider binding'
  require "$file" 'canonical repository' 'canonical repository'
  require "$file" 'default' 'default branch prefix'
  require "$file" 'branch, opaque change-request' 'default branch binding'
  require "$file" 'opaque change-request' 'opaque change-request locator'
  require "$file" 'identifier/locator' 'change-request identifier/locator'
  require "$file" 'source/target' 'source/target binding'
  require "$file" 'current commit' 'current commit'
  require "$file" 'caller identity' 'caller identity'
  require "$file" 'before snapshot, publication, or' 'pre-operation binding prefix'
  require "$file" 'action' 'pre-operation action binding'
  require "$file" 'Ambiguity, profile mismatch, or a bare cross-repository identifier' 'fail-closed ambiguity/profile/cross-repository rule'
  require "$file" 'fail(s|ed) closed|blocks' 'fail-closed outcome'
done

require "$flow" 'Local checkout, remote source, Reviewer Lift reviewed commit, and current' 'four-way commit agreement prefix'
require "$flow" 'provider commit must agree' 'four-way commit agreement outcome'
require "$flow" 'wrong-commit CI' 'wrong-commit CI guard'
require "$flow" 'missing readback' 'missing-readback guard'

require "$report" '^\| Change request \|' 'neutral change-request field'
require "$report" '^\| Repository \|' 'neutral repository field'
require "$report" '^\| Reviewed commit \|' 'neutral reviewed-commit field'
require "$handoff" 'repository:' 'repository handoff object'
require "$handoff" 'change_request:' 'change-request handoff object'
require "$handoff" 'locator:' 'opaque locator field'
require "$handoff" 'current:' 'current commit field'
require "$handoff" 'reviewed:' 'reviewed commit field'
require "$guide" 'change-request locator, canonical repository, reviewed commit' 'neutral summary fields'
require "$guide" 'delivery.repository.locator' 'repository locator guidance'
require "$guide" 'delivery.change_request.locator' 'change-request locator guidance'
require "$guide" 'delivery.commit.current/reviewed' 'current/reviewed commit guidance'

for file in "$flow" "$skill" "$guide"; do
  reject "$file" '(glab|gh)[[:space:]]+(mr|pr|issue)[[:space:]]+(view|comment|approve|merge|close)[[:space:]]+<id>([[:space:]`]|$)' 'provider CLI action with ambiguous bare ID'
  reject "$file" 'az[[:space:]]+repos[[:space:]]+pr[[:space:]]+(show|update)[^\n]*--id[[:space:]]+<id>' 'Azure DevOps CLI action with ambiguous bare ID'
done

printf 'start-review-project-binding: PASS\n'
