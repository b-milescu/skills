#!/usr/bin/env bash
# Shared agent prompt role map for regression tests. Keep routed variants in one
# place so prompt-drift, authority, handoff, and transport checks cover the same
# files without duplicating path inventories across scripts.

agent_prompt_dialects=(claude omp)

routed_builder_prompt_names=(
  mr-builder-sonnet-low
  mr-builder-opus48
  mr-builder-opus48-high
)

builder_prompt_names=(
  mr-builder
  "${routed_builder_prompt_names[@]}"
)

routed_final_reviewer_prompt_names=(
  mr-reviewer-gpt55-xhigh
  mr-reviewer-opus48-xhigh
)

final_reviewer_prompt_names=(
  mr-reviewer
  "${routed_final_reviewer_prompt_names[@]}"
)

scout_prompt_names=(
  mr-review-scout-gpt54-low
)

reviewer_prompt_names=(
  "${final_reviewer_prompt_names[@]}"
  "${scout_prompt_names[@]}"
)

# GPT-routed reviewer/scout agents exist only in the OMP dialect: Claude Code has
# no openai-codex/* route, so these names must not generate agents/claude paths.
omp_only_prompt_names=(
  mr-reviewer-gpt55-xhigh
  mr-review-scout-gpt54-low
)

agent_prompt_is_omp_only() {
  local candidate="$1" name
  for name in "${omp_only_prompt_names[@]}"; do
    [[ "$name" == "$candidate" ]] && return 0
  done
  return 1
}

agent_prompt_dialects_for() {
  local name="$1"
  if agent_prompt_is_omp_only "$name"; then
    printf 'omp\n'
  else
    printf '%s\n' "${agent_prompt_dialects[@]}"
  fi
}

agent_prompt_paths() {
  local name dialect

  for name in "$@"; do
    while IFS= read -r dialect; do
      printf 'agents/%s/%s.md\n' "$dialect" "$name"
    done < <(agent_prompt_dialects_for "$name")
  done
}

agent_prompt_paths_under() {
  local root="$1" name dialect
  shift

  for name in "$@"; do
    while IFS= read -r dialect; do
      printf '%s/agents/%s/%s.md\n' "$root" "$dialect" "$name"
    done < <(agent_prompt_dialects_for "$name")
  done
}
