#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-secret-invariant: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

safety="start-build/SAFETY.md"
builder_prompts=(
  "agents/claude/mr-builder.md"
  "agents/omp/mr-builder.md"
)

# SAFETY.md owns the operational credential detail: never read/print/edit/commit
# /summarize secret stores, and never paste secrets into MR/CI surfaces.
require_text "$safety" 'never paste secrets' 'never-paste-secrets credential token'
require_text "$safety" "don't read, print, edit, commit|don't log api keys" 'credential operational detail token'

# SAFETY.md owns the strip-secrets-from-logs token (anchor: strip-logs -> SAFETY.md).
require_text "$safety" 'strip secrets first|redact tokens, headers, env values' 'strip-secrets-from-logs token'

# Both builder prompts carry the never-touch/print/paste credential token.
for file in "${builder_prompts[@]}"; do
  require_text \
    "$file" \
    'never .*(touch|print|summarize|commit|paste).*(credential|sensitive payload)' \
    "$file never-paste credential token"
done

printf 'start-build-secret-invariant: PASS\n'
