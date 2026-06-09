#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"
# shellcheck source=tests/lib/agent-prompt-sets.sh
source "$REPO_ROOT/tests/lib/agent-prompt-sets.sh"


fail() {
  printf 'builder-prompt-dedupe: FAIL: %s\n' "$*" >&2
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

builder_prompts=( $(agent_prompt_paths "${builder_prompt_names[@]}") )
generic_builder_prompts=( $(agent_prompt_paths mr-builder) )

# Builder prompts carry runtime/tool rules plus critical anti-fabrication and
# child-mode authority invariants. Canonical implementation policy lives in
# /start-build; routed builder variants must preserve the same workflow pointer,
# GitLab transport, authority, parent-owned gate, and handoff/report guardrails.
# The generic compatibility prompts also keep Issue-pickup / Decoupling /
# Multiple-issue-worktree procedures as pointers, not inlined copies that drift
# silently.
# This cap sits above the current pointer-first builder bodies and below legacy
# inlined copies, so it ratchets future drift without pinning the test to exact
# historical body counts. It is intentionally larger
# than the reviewer dedupe cap (80): builder prompts keep more inline safety
# and handoff contract surface.
max_body_lines=135

for prompt in "${builder_prompts[@]}"; do
  lines="$(body_line_count "$prompt")"
  if (( lines > max_body_lines )); then
    fail "$prompt body has $lines line(s); max is $max_body_lines. Point to start-build instead of inlining Issue-pickup / Decoupling / Multiple-issue-worktree policy."
  fi

  require_text "$prompt" 'Canonical development pattern source: `start-build`' 'canonical start-build pointer'
  require_text "$prompt" 'gitlab-local' 'gitlab-local pointer'
  require_text "$prompt" 'tdd' 'tdd pointer'
  require_text "$prompt" 'anti-fabrication' 'anti-fabrication boundary'
  require_text "$prompt" 'Child mode authority boundary|child-builder authority boundary' 'child-mode authority boundary invariant'
  require_text "$prompt" 'approve[^.]*merge[^.]*queue auto-merge|queue auto-merge[^.]*approve[^.]*merge' 'approval/merge/auto-merge authority boundary'
  require_text "$prompt" 'parent-owned gate mode' 'parent-owned gate invariant'
  require_text "$prompt" 'Review Packet' 'Review Packet handoff invariant'
  require_text "$prompt" 'final handoff' 'final handoff invariant'
  require_text "$prompt" 'authority' 'authority evidence invariant'

  # Reject re-inlining the canonical procedure bodies as their own headings.
  reject_text "$prompt" '^##[[:space:]]+Issue pickup[[:space:]]*$' 'inlined Issue pickup procedure heading'
  reject_text "$prompt" '^##[[:space:]]+Decoupling[[:space:]]*' 'inlined Decoupling procedure heading'
  reject_text "$prompt" '^##[[:space:]]+Multiple issue worktree mode[[:space:]]*$' 'inlined Multiple issue worktree mode procedure heading'
  # The worktree creation command is canonical to start-build; a copied
  # `git worktree add` invocation is the tell-tale inlined procedure body.
  reject_text "$prompt" 'git worktree add' 'copied git worktree add command from start-build'
done

for prompt in "${generic_builder_prompts[@]}"; do
  require_text "$prompt" 'Child mode authority boundary' 'child-mode authority boundary invariant'
  require_text "$prompt" 'Merge authority source' 'authority-source invariant'
  require_text "$prompt" 'Approval authority' 'approval-authority invariant'
  require_text "$prompt" 'start-build/templates/reviewer-lift-schema\.md' 'canonical Reviewer Lift schema ownership pointer'
  require_text "$prompt" 'Do not inline a Reviewer Lift field table in this prompt' 'Reviewer Lift anti-inline guard'

  require_text "$prompt" 'start-build/reference/stuck-protocol\.md' 'canonical Stuck protocol pointer'
  require_text "$prompt" 'Every child-builder final response MUST start' 'unconditional builder-final handoff schema requirement'
  require_text "$prompt" 'Parent-owned gate is one status/mode inside that schema, not the trigger for using it' 'parent-owned gate is a mode, not schema trigger'

  # The Issue-pickup / Decoupling / Multiple-issue-worktree procedures are owned
  # by start-build. The builder prompts keep only a pointer block to them.
  # The section-reference glyph differs by dialect (Claude inserts a
  # non-breaking space after `§`, pi does not), so match the quoted canonical
  # section name rather than the exact `§"` punctuation.
  require_text "$prompt" 'owned by the `start-build` skill' 'start-build ownership pointer for Issue-pickup/Decoupling/Multi-issue procedures'
  require_text "$prompt" 'start-build`.*"Issue pickup"' 'Issue pickup pointer'
  require_text "$prompt" 'start-build`.*"Multiple issue worktree mode"' 'Multiple issue worktree mode pointer'
done

printf 'builder-prompt-dedupe: PASS\n'
