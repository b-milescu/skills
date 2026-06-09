#!/usr/bin/env bash
# Shared agent prompt role map for regression tests. Keep routed variants in one
# place so prompt-drift, authority, handoff, and transport checks cover the same
# files without duplicating path inventories across scripts.

agent_prompt_dialects=(claude pi)

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

agent_prompt_paths() {
  local name dialect

  for name in "$@"; do
    for dialect in "${agent_prompt_dialects[@]}"; do
      printf 'agents/%s/%s.md\n' "$dialect" "$name"
    done
  done
}

agent_prompt_paths_under() {
  local root="$1" name dialect
  shift

  for name in "$@"; do
    for dialect in "${agent_prompt_dialects[@]}"; do
      printf '%s/agents/%s/%s.md\n' "$root" "$dialect" "$name"
    done
  done
}
