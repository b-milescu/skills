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

# Require acceptance_surfaces field and taxonomy in schema
require_text_case_sensitive "$schema" 'Acceptance surfaces' 'acceptance_surfaces field in reviewer-lift-schema'
require_text_case_sensitive "$schema" 'docs' 'acceptance_surfaces docs taxonomy value'
require_text_case_sensitive "$schema" 'install_surface' 'acceptance_surfaces install_surface taxonomy value'
require_text_case_sensitive "$schema" 'mutation_guard' 'acceptance_surfaces mutation_guard taxonomy value'

echo "Reviewer Lift schema check passed: ${#copies[@]} generated copies match $schema and no stale duplicate field-list tables found."
