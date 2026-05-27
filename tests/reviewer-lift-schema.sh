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

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

extract_schema_fields() {
  awk -F'|' '
    /^\|/ {
      field=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      if (field != "Field" && field !~ /^-+$/ && field != "") print field
    }
  ' "$schema"
}

extract_copy_fields() {
  local file="$1"
  awk -F'|' '
    /REVIEWER-LIFT-SCHEMA:BEGIN/ { in_block=1; next }
    /REVIEWER-LIFT-SCHEMA:END/ { in_block=0; next }
    in_block && /^\|/ {
      field=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      if (field != "Field" && field !~ /^-+$/ && field != "") print field
    }
  ' "$file"
}

extract_schema_fields > "$tmpdir/schema.fields"

for copy in "${copies[@]}"; do
  extract_copy_fields "$copy" > "$tmpdir/$(basename "$copy").fields"
  diff -u "$tmpdir/schema.fields" "$tmpdir/$(basename "$copy").fields" >/dev/null || {
    echo "Reviewer Lift schema drift: $copy does not match $schema" >&2
    diff -u "$tmpdir/schema.fields" "$tmpdir/$(basename "$copy").fields" >&2 || true
    exit 1
  }
  if [ ! -s "$tmpdir/$(basename "$copy").fields" ]; then
    echo "Reviewer Lift schema drift: $copy has no generated-copy block" >&2
    exit 1
  fi
done

# Detect stale duplicate field-list tables outside approved generated-copy blocks.
# A run of 4+ canonical fields in a markdown table is treated as an unapproved copy.
find . -type f -name '*.md' \
  ! -path './.git/*' \
  ! -path "./$schema" \
  -print0 |
while IFS= read -r -d '' file; do
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

echo "Reviewer Lift schema check passed: ${#copies[@]} generated copies match $schema and no stale duplicate field-list tables found."
