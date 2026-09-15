#!/usr/bin/env bash
# Focus: Claude/OMP builder prompts stay frontmatter plus invoke `start-build`,
# reject inlined policy headings, and stay below the tiny route-pin body cap.
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
    fail "$file unexpectedly contains $label"
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

# Dialect builders are route pins: frontmatter plus invoke start-build.
# Policy lives in start-build; keep bodies tiny so they cannot drift.
max_body_lines=8

for prompt in "${builder_prompts[@]}"; do
  lines="$(body_line_count "$prompt")"
  if (( lines > max_body_lines )); then
    fail "$prompt body has $lines line(s); max is $max_body_lines. Keep frontmatter + invoke start-build only."
  fi

  require_text "$prompt" 'Canonical development pattern source: `start-build`' 'canonical start-build pointer'
  require_text "$prompt" 'exists only to pin the runtime route' 'route-pin contract'

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
  reject_text "$prompt" '^##[[:space:]]+' 'inlined policy heading'
  reject_text "$prompt" 'git worktree add' 'copied git worktree add command from start-build'
done

printf 'builder-prompt-dedupe: PASS\n'
