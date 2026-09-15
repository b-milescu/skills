#!/usr/bin/env bash
# Focus: Claude/OMP reviewer prompts stay frontmatter plus invoke
# `start-review` below the tiny route-pin body cap, and shared ADR template
# ownership/drift stays enforced.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"
# shellcheck source=tests/lib/agent-prompt-sets.sh
source "$REPO_ROOT/tests/lib/agent-prompt-sets.sh"


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

final_reviewer_prompts=( $(agent_prompt_paths "${final_reviewer_prompt_names[@]}") )
claude_final_reviewer_prompt='agents/claude/mr-reviewer-final.md'

# Dialect reviewers are route pins: frontmatter plus invoke start-review.
max_body_lines=8

for prompt in "${final_reviewer_prompts[@]}"; do
  lines="$(body_line_count "$prompt")"
  if (( lines > max_body_lines )); then
    fail "$prompt body has $lines line(s); max is $max_body_lines. Keep frontmatter + invoke start-review only."
  fi

  require_text "$prompt" 'Canonical development pattern source: `start-review`' 'canonical start-review pointer'
  require_text "$prompt" 'exists only to pin the runtime route' 'route-pin contract'

  case "$prompt" in
    agents/claude/*)
      require_text "$prompt" 'Canonical development pattern source: `start-review`\. Invoke it via' 'Claude reviewer Skill-tool activation verb'
      ;;
    agents/omp/*)
      require_text "$prompt" 'Canonical development pattern source: `start-review`\. Invoke it through the OMP skill-load mechanism' 'OMP reviewer autoload-skills activation verb'
      require_text "$prompt" 'autoload-skills' 'OMP reviewer autoload-skills frontmatter'
      ;;
  esac
  reject_text "$prompt" 'Canonical development pattern source: `start-review`\. Load it' 'bare "Load it" activation verb on the canonical-pattern-source line'
  reject_text "$prompt" '^##[[:space:]]+' 'inlined policy heading'
done

reject_text "$claude_final_reviewer_prompt" 'Provider-failure fallback only' 'Claude final reviewer labeled provider-failure fallback only'

parent_doc='start-build/reference/parent-orchestrator.md'
require_text "$parent_doc" 'Route-resolved-at-launch' 'route-resolution evidence field in minimal reviewer launch prompt'
require_text "$parent_doc" 'current runtime inventory' 'runtime inventory evidence in reviewer launch prompt'
reject_text "$parent_doc" 'mr-(builder|reviewer)-[^[:space:]`|]*(gpt|opus|sonnet)[^[:space:]`|]*' 'provider/model route target'

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
