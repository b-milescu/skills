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

# Builder prompts carry runtime/tool rules plus critical anti-fabrication and
# child-mode authority invariants. Canonical implementation policy lives in
# /start-build; routed builder variants must preserve the same workflow pointer,
# GitLab transport, authority, parent-owned gate, and handoff/report guardrails.
# Routed builder pins point Issue-pickup / Decoupling / Multiple-issue-worktree
# procedures back to start-build instead of inlining copies that drift silently.
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

  # Cross-dialect verb parity (#321, guarded by #322): the
  # canonical-development-pattern-source line must use the dialect-approved
  # activation verb, and never the bare `Load it` form, so one dialect cannot be
  # fixed while the other drifts back to raw-Read-biasing wording. Pin to the
  # stable activation tokens per dialect, not the surrounding prose.
  case "$prompt" in
    agents/claude/*)
      require_text "$prompt" 'Canonical development pattern source: `start-build`\. Invoke it via' 'Claude builder Skill-tool activation verb'
      ;;
    agents/omp/*)
      require_text "$prompt" 'Canonical development pattern source: `start-build`\. Invoke it through the OMP skill-load mechanism' 'OMP builder autoload-skills activation verb'
      require_text "$prompt" 'autoload-skills' 'OMP builder autoload-skills frontmatter'
      ;;
  esac
  reject_text "$prompt" 'Canonical development pattern source: `start-build`\. Load it' 'bare "Load it" activation verb on the canonical-pattern-source line'
  require_text "$prompt" 'gitlab' 'gitlab pointer'
  require_text "$prompt" 'tdd' 'tdd pointer'
  require_text "$prompt" 'anti-fabrication' 'anti-fabrication boundary'
  require_text "$prompt" 'Child mode authority boundary|child-builder authority boundary' 'child-mode authority boundary invariant'
  require_text "$prompt" 'approve[^.]*merge[^.]*queue auto-merge|queue auto-merge[^.]*approve[^.]*merge' 'approval/merge/auto-merge authority boundary'
  require_text "$prompt" 'parent-owned gate mode' 'parent-owned gate invariant'
  # The launch-prompt `Gate owner` line is the sole binding gate-mode selector;
  # builders must not infer gate ownership from finish-authority prose (#285).
  require_text "$prompt" '`Gate owner`' 'Gate owner field binding reference'
  require_text "$prompt" 'sole|binding|only' 'Gate owner sole/binding selection wording'
  require_text "$prompt" 'not infer[^.]*finish[ -]authority|finish[ -]authority[^.]*not[^.]*(infer|influence|select)' 'forbid inferring gate ownership from finish-authority prose'
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

printf 'builder-prompt-dedupe: PASS\n'
