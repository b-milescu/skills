#!/usr/bin/env bash
# Focus: Reviewer Lift generated-copy blocks match the canonical schema and
# stale duplicate field-list tables are rejected.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

schema="start-build/templates/reviewer-lift-schema.md"
copies=(
  "start-build/templates/review-packet.md"
  "start-build/templates/review-packet-compact.md"
  "start-review/templates/review-report.md"
)

TEST_NAME="reviewer-lift-schema"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# shellcheck source=tests/lib/schema-sync.sh
source "$REPO_ROOT/tests/lib/schema-sync.sh"

list_prompt_drift_markdown_files() {
  bash "$REPO_ROOT/scripts/list-prompt-drift-markdown.sh" "$REPO_ROOT"
}

extract_schema_fields() {
  extract_markdown_table_fields "$schema"
}

extract_copy_fields() {
  local file="$1"
  extract_markdown_table_fields "$file" 'REVIEWER-LIFT-SCHEMA:BEGIN' 'REVIEWER-LIFT-SCHEMA:END'
}

extract_schema_fields > "$tmpdir/schema.fields"

for copy in "${copies[@]}"; do
  extract_copy_fields "$copy" > "$tmpdir/$(basename "$copy").fields"
  assert_files_match "$tmpdir/schema.fields" "$tmpdir/$(basename "$copy").fields" "Reviewer Lift schema drift: $copy does not match $schema"
  if [ ! -s "$tmpdir/$(basename "$copy").fields" ]; then
    echo "Reviewer Lift schema drift: $copy has no generated-copy block" >&2
    exit 1
  fi
done

# Detect stale duplicate field-list tables outside approved generated-copy blocks.
# A run of 4+ canonical fields in a markdown table is treated as an unapproved copy.
list_prompt_drift_markdown_files |
while IFS= read -r -d '' file; do
  case "$file" in
    "$REPO_ROOT/$schema") continue ;;
  esac
  awk -v fields_file="$tmpdir/schema.fields" -v file="$file" -F'|' '
    BEGIN {
      while ((getline line < fields_file) > 0) wanted[line]=1
      close(fields_file)
      run=0
      start=0
    }
    /REVIEWER-LIFT-SCHEMA:BEGIN/ { in_block=1; run=0; next }
    /REVIEWER-LIFT-SCHEMA:END/ { in_block=0; run=0; next }
    in_block { next }
    /^\|/ {
      field=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      gsub(/`|\*\*/, "", field)
      if (wanted[field]) {
        if (run == 0) start=FNR
        run++
        if (run >= 4) {
          printf "Reviewer Lift stale duplicate table: %s:%d (canonical field run starts at line %d)\n", file, FNR, start > "/dev/stderr"
          bad=1
        }
      } else if (field !~ /^-+$/) {
        run=0
      }
      next
    }
    { run=0 }
    END { exit bad ? 1 : 0 }
  ' "$file" || exit 1
done

# Require acceptance_surfaces field in schema; vocabulary now lives behind
# project_profile.acceptance_surfaces_ref, so the row must reference the ref and
# the fail-closed no-ref default rather than hardcode this repo's surface values.
require_text_case_sensitive "$schema" 'Acceptance surfaces' 'acceptance_surfaces field in reviewer-lift-schema'
require_text_case_sensitive "$schema" 'acceptance_surfaces_ref' 'reviewer-lift acceptance_surfaces_ref reference'
require_text_case_sensitive "$schema" 'fail-closed' 'reviewer-lift acceptance_surfaces fail-closed no-ref default'

# Changed paths is measured from the merge base, not reconstructed from
# per-commit figures. Fixed-string checks keep the literal `...` separator safe.
command='git diff --name-only <base>...HEAD'
assert_file_contains "$schema" "$command" 'Changed paths measurement command'
require_text_case_sensitive "$schema" 'per-commit' 'Changed paths merge-base semantics in reviewer-lift-schema'
require_text_case_sensitive "$schema" 'measured, not estimated' 'MR body numeric measurement guidance in reviewer-lift-schema'
for copy in "${copies[@]}"; do
  assert_file_contains "$copy" "$command" 'Changed paths measurement command'
  require_text_case_sensitive "$copy" 'measured output' "Changed paths measured output in $copy"
done

malformed="$tmpdir/malformed-separator.md"
sed 's/<base>\.\.\.HEAD/<base>abcHEAD/g' "$schema" > "$malformed"
if grep -Fq -- "$command" "$malformed"; then
  fail "malformed separator fixture retained literal Changed paths command"
fi

# The CI row is explicitly advisory and commit-attributed; every provider state
# is non-blocking. The local gate row owns the singular quality predicate.
require_text_case_sensitive "$schema" 'Advisory pipeline' 'CI pipeline advisory framing'
require_text_case_sensitive "$schema" 'matches `Reviewed SHA`' 'CI pipeline exact-commit attribution'
require_text_case_sensitive "$schema" 'never changes verdict or action eligibility' 'CI pipeline non-blocking policy'

local_gate_row='| Local gate | `PASS`, `FAIL`, `N/A`, or `not-run` plus the exact command. `PASS` on the exact candidate is the required quality gate. `N/A` requires a rationale that no local gate can run. In parent-owned mode use the ownership contract and exact-candidate Gate Receipt pointer from `start-build/reference/parent-owned-gate.md`; after the receipt the row carries exactly one literal `Gate Receipt` pointer (the label once, with one locator); child builders must not claim gate pass/fail. |'
require_exact_line "$schema" "$local_gate_row" 'Local gate safety-floor row byte-identity'

require_text_case_sensitive "start-review/templates/review-report.md" 'Finish owner' 'Review Report Finish owner row'
require_text_case_sensitive "start-review/templates/reviewer-final-handoff.md" 'Finish owner: parent' 'reviewer final handoff Finish owner guidance'
echo "Reviewer Lift schema check passed: ${#copies[@]} generated copies match $schema and no stale duplicate field-list tables found."
