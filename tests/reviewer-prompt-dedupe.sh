#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'reviewer-prompt-dedupe: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  if grep -Eiq -- "$pattern" "$file"; then
    grep -Ein -- "$pattern" "$file" >&2 || true
    fail "$file contains $label"
  fi
}

body_line_count() {
  local file="$1"
  awk '
    NR == 1 && $0 == "---" { in_frontmatter=1; next }
    in_frontmatter && $0 == "---" { in_frontmatter=0; next }
    !in_frontmatter { count++ }
    END { print count + 0 }
  ' "$file"
}

core_step_count() {
  local file="$1"
  awk '
    /^##[[:space:]]+Core procedure[[:space:]]*$/ { in_section=1; next }
    in_section && /^##[[:space:]]+/ { exit }
    in_section && /^[0-9]+\.[[:space:]]/ { count++ }
    END { print count + 0 }
  ' "$file"
}

reviewer_prompts=(
  agents/claude/mr-reviewer.md
  agents/pi/mr-reviewer.md
)

# Reviewer prompts carry runtime/tool rules and critical fail-closed invariants.
# Canonical review workflow policy lives in /start-review; prompt-local procedure
# copies must stay small enough that future policy edits do not drift silently.
max_body_lines=80
max_core_steps=8

for prompt in "${reviewer_prompts[@]}"; do
  lines="$(body_line_count "$prompt")"
  if (( lines > max_body_lines )); then
    fail "$prompt body has $lines line(s); max is $max_body_lines. Point to start-review instead of inlining workflow policy."
  fi

  steps="$(core_step_count "$prompt")"
  if (( steps > max_core_steps )); then
    fail "$prompt Core procedure has $steps step(s); max is $max_core_steps. Keep procedure detail canonical in start-review."
  fi

  require_text "$prompt" 'Canonical development pattern source: `start-review`' 'canonical start-review pointer'
  require_text "$prompt" 'gitlab-local' 'gitlab-local pointer'
  require_text "$prompt" 'tdd' 'tdd pointer'
  require_text "$prompt" 'runtime/tool boundaries|runtime-specific tool rules|tool-boundary' 'runtime/tool boundary purpose'
  require_text "$prompt" 'anti-fabrication' 'anti-fabrication boundary'
  require_text "$prompt" 'Context Firewall' 'Context Firewall invariant'
  require_text "$prompt" 'Merge authority source' 'authority-source invariant'
  require_text "$prompt" 'Approval authority|approval authority' 'approval-authority invariant'
  require_text "$prompt" 'partial-review' 'partial-review fail-closed token'
  require_text "$prompt" 'secret-exposure-suspected' 'secret-exposure fail-closed token'
  require_text "$prompt" 'Snippet: mr-note-create' 'MR note snippet pointer'

  reject_text "$prompt" '^##[[:space:]]+Summary-first Review Report and final handoff[[:space:]]*$' 'duplicated Review Report/final handoff section heading'
  reject_text "$prompt" '^##[[:space:]]+Handoff integrity check[[:space:]]*$' 'duplicated handoff integrity section heading'
  reject_text "$prompt" 'Full command ownership still lives|Reviewers load the small `gitlab-local` review cards before the full command reference' 'copied gitlab-local tooling prose from start-review'
done

shared_adr='templates/adr.md'
review_adr='start-review/templates/adr.md'

[[ -f "$shared_adr" ]] || fail "missing shared ADR template: $shared_adr"

if [[ -e "$review_adr" || -L "$review_adr" ]]; then
  if [[ -L "$review_adr" ]]; then
    target="$(readlink "$review_adr")"
    [[ "$target" == '../../templates/adr.md' || "$target" == "$REPO_ROOT/templates/adr.md" ]] || \
      fail "$review_adr symlink points to $target, expected ../../templates/adr.md"
  else
    require_text "$review_adr" 'GENERATED-COPY|generated-copy' 'generated-copy marker when local ADR copy remains'
    cmp -s "$shared_adr" "$review_adr" || fail "$review_adr generated copy drifted from $shared_adr"
  fi
else
  require_text 'start-review/SKILL.md' '\.\./templates/adr\.md' 'shared ADR template reference'
  reject_text 'start-review/SKILL.md' '`templates/adr\.md`' 'local start-review ADR template reference when local copy is absent'
fi

printf 'reviewer-prompt-dedupe: PASS\n'
