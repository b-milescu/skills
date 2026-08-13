#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

fail() {
  printf 'start-build-context-routing: FAIL: %s\n' "$*" >&2
  exit 1
}

require() {
  local file="$1" pattern="$2" label="$3"
  grep -Eiq -- "$pattern" "$file" || fail "$file missing $label"
}

skill="start-build/SKILL.md"
context="start-build/reference/context-and-planning.md"
pickup="start-build/reference/issue-pickup.md"
child="start-build/reference/child-builder.md"

require "$skill" '^## Invocation modes$' 'invocation modes'
require "$skill" '\*\*Standalone:\*\*' 'standalone mode'
require "$skill" '\*\*Child `mr-builder`:\*\*' 'child mode'
require "$skill" '\*\*Revision:\*\*' 'revision mode'
require "$skill" 'active mode reference' 'active-mode routing'
require "$skill" 'skill://start-build/reference/child-builder.md' 'explicit child-builder URI'

require "$context" 'Read the issue and project rulebook index first' 'issue/rulebook-first discovery'
require "$context" 'expand only from evidence' 'evidence-triggered expansion'
require "$context" 'Stop expanding once those facts are evidence-backed' 'bounded discovery stop'
require "$context" 'instead of guessing requirements or starting edits' 'stop instead of guessing'
require "$context" 'active mode-specific flow' 'mode-specific flow ownership'
require "$context" 'child-builder.md' 'child flow pointer'
require "$context" 'standalone-gate.md' 'standalone flow pointer'
require "$context" 'parent-orchestrator.md' 'parent flow pointer'
require "$context" 'compact invocation-mode procedure' 'current compact router wording'

require "$pickup" 'read its description and all current discussion before planning or editing' 'canonical work-item pickup'
require "$pickup" 'source precedence' 'work-item source precedence'
require "$pickup" 'human escalation' 'work-item escalation'
require "$child" 'parent orchestrator owns the mandatory review gate' 'parent-owned review gate boundary'
require "$child" 'must not start a reviewer' 'child no-reviewer boundary'

printf 'start-build-context-routing: PASS\n'
