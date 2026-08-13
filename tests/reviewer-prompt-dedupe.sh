#!/usr/bin/env bash
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

final_reviewer_prompts=( $(agent_prompt_paths "${final_reviewer_prompt_names[@]}") )
# Shared final-review route resolves in both Claude and OMP dialects; it carries
# no provider-failure fallback wording, no generic reviewer review scout to
# check.
claude_final_reviewer_prompt='agents/claude/mr-reviewer-final.md'

# Final reviewer prompts carry runtime/tool rules and critical fail-closed
# invariants. Canonical review workflow policy lives in /start-review; routed
# final reviewers must preserve the same workflow pointer, GitLab transport,
# authority, anti-fabrication, Review Report, and final-handoff guardrails.
# Prompt-local procedure copies must stay small enough that future policy edits
# do not drift silently.
max_body_lines=80
max_core_steps=8

for prompt in "${final_reviewer_prompts[@]}"; do
  lines="$(body_line_count "$prompt")"
  if (( lines > max_body_lines )); then
    fail "$prompt body has $lines line(s); max is $max_body_lines. Point to start-review instead of inlining workflow policy."
  fi

  steps="$(core_step_count "$prompt")"
  if (( steps > max_core_steps )); then
    fail "$prompt Core procedure has $steps step(s); max is $max_core_steps. Keep procedure detail canonical in start-review."
  fi

  require_text "$prompt" 'Canonical development pattern source: `start-review`' 'canonical start-review pointer'

  # Cross-dialect verb parity (#321, guarded by #322): the
  # canonical-development-pattern-source line must use the dialect-approved
  # activation verb, and never the bare `Load it` form, so one dialect cannot be
  # fixed while the other drifts back to raw-Read-biasing wording. Pin to the
  # stable activation tokens per dialect, not the surrounding prose.
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
  require_text "$prompt" 'gitlab' 'gitlab pointer'
  require_text "$prompt" 'anti-fabrication' 'anti-fabrication boundary'
  require_text "$prompt" 'Review Report' 'Review Report handoff invariant'
  require_text "$prompt" 'final handoff|reviewer-final-handoff\.md' 'final handoff invariant'
  require_text "$prompt" 'reviewed-commit[^.]*CI|CI[^.]*reviewed-commit' 'reviewed-commit/CI evidence invariant'
  require_text "$prompt" 'authority' 'authority invariant'
  require_text "$prompt" 'verdict[^.]*approval action[^.]*finish action|approval action[^.]*finish action[^.]*next action' 'verdict/action separation invariant'
  require_text "$prompt" 'merge/?auto-merge|queue auto-merge' 'merge/auto-merge authority boundary'

  reject_text "$prompt" '^##[[:space:]]+Summary-first Review Report and final handoff[[:space:]]*$' 'duplicated Review Report/final handoff section heading'
  reject_text "$prompt" '^##[[:space:]]+Handoff integrity check[[:space:]]*$' 'duplicated handoff integrity section heading'
  reject_text "$prompt" 'Full command ownership still lives|Reviewers load the small `gitlab` review cards before the full command reference' 'copied gitlab tooling prose from start-review'
done

require_text "$claude_final_reviewer_prompt" 'Final-review route: mandatory independent reviewer' 'Claude final-review routing contract'
reject_text "$claude_final_reviewer_prompt" 'Provider-failure fallback only' 'Claude final reviewer labeled provider-failure fallback only'

# #230 reviewer launch prompt must carry route-resolution evidence field, and
# orchestrator docs must not present old provider/model route names as launch
# targets.
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
