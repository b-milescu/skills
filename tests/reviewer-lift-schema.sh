#!/usr/bin/env bash
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

# The CI pipeline row must frame the recorded status as an as-of-ready-marking
# snapshot while the pipeline identity/bound commit are authoritative, and it must
# name the finisher's re-derivation of terminal CI as a required step. This pins
# the row against silently regressing to an unqualified status claim (#401).
require_text_case_sensitive "$schema" 'as[ -]of[ -]ready-marking snapshot' 'CI pipeline as-of-ready-marking snapshot framing'
require_text_case_sensitive "$schema" 'authoritative' 'CI pipeline authoritative pipeline identity framing'
require_text_case_sensitive "$schema" 're-derive' 'CI pipeline finisher re-derivation as a required step'

# Byte-identity guard for the Local gate row's safety floor: the as-of framing
# sits beside this blocking rule, never in place of it (#401 AC).
local_gate_row='| Local gate | `PASS`, `FAIL`, `N/A`, or `not-run` plus the exact command. A completed local gate or parent-owned Gate Receipt permits review launch for every coverage class; `hybrid`/`ci-only` review may start while exact-SHA CI is pending. Failed, canceled, skipped, missing, stale, or wrong-SHA required CI blocks pass eligibility and every finish action unless an authorized CI waiver is recorded. In parent-owned gate mode use the ownership contract and Gate Receipt pointer from `start-build/reference/parent-owned-gate.md`; child builders must not claim gate pass/fail. |'
require_exact_line "$schema" "$local_gate_row" 'Local gate safety-floor row byte-identity'

require_text_case_sensitive "start-review/templates/review-report.md" 'Finish owner' 'Review Report Finish owner row'
require_text_case_sensitive "start-review/templates/reviewer-final-handoff.md" 'Finish owner: parent' 'reviewer final handoff Finish owner guidance'
echo "Reviewer Lift schema check passed: ${#copies[@]} generated copies match $schema and no stale duplicate field-list tables found."
