#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

schema="start-build/templates/gitlab-delivery-schema.md"
copies=(
  "start-build/templates/builder-final-handoff.md"
  "start-review/templates/reviewer-final-handoff.md"
)

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

extract_schema_fields() {
  awk -F'|' '
    /GITLAB-DELIVERY-FIELDS:BEGIN/ { in_block=1; next }
    /GITLAB-DELIVERY-FIELDS:END/ { in_block=0; next }
    in_block && /^\|/ {
      field=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      if (field != "Field" && field !~ /^-+$/ && field != "") print field
    }
  ' "$schema"
}

extract_copy_fields() {
  local file="$1"
  awk '
    /GITLAB-DELIVERY-SCHEMA:BEGIN/ { in_block=1; next }
    /GITLAB-DELIVERY-SCHEMA:END/ { in_block=0; next }
    in_block && /^    [a-z_]+:/ {
      field=$1
      sub(/:$/, "", field)
      print field
    }
  ' "$file"
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eq -- "$pattern" "$file" || {
    echo "gitlab-delivery-schema: FAIL: $file missing $label" >&2
    exit 1
  }
}

extract_schema_fields > "$tmpdir/schema.fields"

if [ ! -s "$tmpdir/schema.fields" ]; then
  echo "GitLab Delivery schema drift: canonical field list is empty" >&2
  exit 1
fi

for copy in "${copies[@]}"; do
  extract_copy_fields "$copy" > "$tmpdir/$(basename "$copy").fields"
  if [ ! -s "$tmpdir/$(basename "$copy").fields" ]; then
    echo "GitLab Delivery schema drift: $copy has no generated-copy block" >&2
    exit 1
  fi
  diff -u "$tmpdir/schema.fields" "$tmpdir/$(basename "$copy").fields" >/dev/null || {
    echo "GitLab Delivery schema drift: $copy does not match $schema" >&2
    diff -u "$tmpdir/schema.fields" "$tmpdir/$(basename "$copy").fields" >&2 || true
    exit 1
  }
done

for copy in "${copies[@]}"; do
  require_text "$copy" 'source_branch' 'GitLab source_branch noun in delivery copy'
  require_text "$copy" 'target_branch' 'GitLab target_branch noun in delivery copy'
done

require_text "$schema" 'kind: "gitlab-delivery"' 'fixed delivery kind example'
require_text "$schema" '`not_run_reason` enum' 'not_run_reason taxonomy'
require_text "$schema" 'parent-owned-final-gate' 'parent-owned final gate not-run reason'
require_text "$schema" '`tier-1`' 'tier-1 evidence taxonomy'
require_text "$schema" '`tier-2`' 'tier-2 evidence taxonomy'
require_text "$schema" '`tier-3`' 'tier-3 index taxonomy'
require_text "$schema" '`issue-metadata`' 'evidence kind enum'
require_text "$schema" '`mr-metadata`' 'evidence kind enum'
require_text "$schema" '`approval-only`' 'authority enum'
require_text "$schema" '`queue auto-merge`' 'authority enum'
require_text "$schema" '`auto-merge queued`' 'finish action enum'
require_text "$schema" '`secret-exposure-suspected`' 'action blocker enum'
require_text "$schema" '`spawn-reviewer`' 'builder next-action token'
require_text "$schema" '`finish-by-authorized-actor`' 'reviewer/parent next-action token'
require_text "$schema" '`post-merge-verify`' 'parent next-action token'
require_text "$schema" '`done`' 'verifier next-action token'

if grep -Eq '\bpull_request\b|\bpull_request_url\b|\bpr_url\b' "$schema"; then
  echo "gitlab-delivery-schema: FAIL: provider-neutral pull-request aliases are not allowed" >&2
  exit 1
fi

echo "gitlab-delivery-schema: PASS"
