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

child_builder="start-build/reference/child-builder.md"
builder_agents=(
  agents/claude/mr-builder-trivial.md
  agents/claude/mr-builder-moderate.md
  agents/claude/mr-builder-high-risk.md
  agents/omp/mr-builder-trivial.md
  agents/omp/mr-builder-moderate.md
  agents/omp/mr-builder-high-risk.md
)

# SAFETY.md owns the operational credential detail: never read/print/edit/commit
# /summarize secret stores, never print token-bearing config, and never paste
# secrets into MR/CI surfaces.
require_text "$safety" 'never paste secrets' 'never-paste-secrets credential token'
require_text "$safety" "don't read, print, edit, commit|don't log api keys" 'credential operational detail token'
require_text "$safety" 'token-bearing config' 'token-bearing config no-echo rule'
require_text "$safety" 'read[^.]*variable[^.]*without printing|without printing[^.]*variable' 'read-into-variable-without-printing pattern'

# Child-builder flow must carry the same shell-output discipline in the compact
# implementation path, not only in the global safety reference.
require_text "$child_builder" 'never[^.]*cat[^.]*echo[^.]*token-bearing config' 'child-builder no-print token config rule'
require_text "$child_builder" 'read[^.]*variable[^.]*without printing|read[^.]*shell variable[^.]*without printing' 'child-builder read-into-variable-without-printing pattern'
require_text "$child_builder" 'redact[^.]*\[REDACTED\]' 'child-builder redacted diagnostic rule'

# Routed builder prompts are the launch-time guardrail for every tier/dialect.
for agent in "${builder_agents[@]}"; do
  require_text "$agent" 'Credential handling discipline' 'builder credential discipline section'
  require_text "$agent" 'never[^.]*cat[^.]*echo[^.]*token-bearing config' 'builder no-print token config rule'
  require_text "$agent" 'read[^.]*variable[^.]*without printing|read[^.]*shell variable[^.]*without printing' 'builder read-into-variable-without-printing pattern'
  require_text "$agent" 'redact[^.]*\[REDACTED\]' 'builder redacted diagnostic rule'
done

printf 'start-build-secret-invariant: PASS\n'
