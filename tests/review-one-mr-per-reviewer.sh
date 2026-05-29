#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'review-one-mr-per-reviewer: FAIL: %s\n' "$*" >&2
  exit 1
}

require_text() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

reject_text() {
  local file="$1" pattern="$2" label="$3"
  if grep -Eiq -- "$pattern" "$file"; then
    fail "$file contains unsafe $label"
  fi
}

flow="start-review/REVIEW-FLOW.md"
skill="start-review/SKILL.md"
claude_prompt="agents/claude/mr-reviewer.md"
pi_prompt="agents/pi/mr-reviewer.md"

for file in "$skill" "$flow"; do
  require_text "$file" 'single-MR[^.]*default[^.]*preferred|default[^.]*preferred[^.]*single-MR|one MR per fresh reviewer session[^.]*default[^.]*preferred' 'single-MR default/preferred policy'
  require_text "$file" 'one MR per fresh reviewer session|one fresh reviewer session[^.]*one MR' 'one MR per fresh reviewer session wording'
done

require_text "$flow" 'single reviewer session[^.]*cannot[^.]*separate LLM contexts|cannot[^.]*separate LLM contexts[^.]*single reviewer session' 'single-session cannot emulate separate LLM contexts'
require_text "$flow" 'parent/harness[^.]*separate sessions[^.]*worktrees|separate sessions[^.]*worktrees[^.]*parent/harness' 'parent/harness isolated sessions/worktrees requirement'
require_text "$flow" 'explicit serialized mode[^.]*does not batch[^.]*decisions[^.]*comments[^.]*actions' 'serialized mode no-batch constraint'
require_text "$flow" 'Decoupling Contract' 'Decoupling Contract retained'
require_text "$flow" 'one Review Report[^.]*one `Review verdict`[^.]*one reviewed SHA per MR|one Review Report[^.]*one reviewed SHA per MR' 'separate report/verdict/SHA per MR'
require_text "$flow" 'approval[^.]*merge[^.]*sequence per MR|per MR[^.]*approval[^.]*merge' 'per-MR action result path'

for file in "$claude_prompt" "$pi_prompt"; do
  require_text "$file" 'review only[^.]*assigned MR[^.]*worktree|assigned MR[^.]*worktree[^.]*review only' 'child reviewer assigned MR/worktree boundary'
  require_text "$file" 'never launch sibling reviewers|do not launch sibling reviewers' 'child reviewer no sibling launch rule'
  require_text "$file" 'single-MR[^.]*default[^.]*preferred|one MR per fresh reviewer session[^.]*default[^.]*preferred' 'prompt single-MR default/preferred policy'
done

for file in "$skill" "$flow" "$claude_prompt" "$pi_prompt"; do
  reject_text "$file" 'batch-approve|batch approve|batch-approval|batch approval' 'batch approval wording'
  reject_text "$file" 'approve[^.]*multiple MRs|multiple MRs[^.]*approve' 'multi-MR approval wording without per-MR guard'
done

printf 'review-one-mr-per-reviewer: PASS\n'
