#!/usr/bin/env bash
# Shared agent prompt role map for regression tests. Keep routed agents in one
# place so prompt-drift, authority, handoff, and transport checks cover the same
# files without duplicating path inventories across scripts.
#
# Route basenames are shared and model-free. Claude/OMP dialects use the same
# names; model/provider pins live only in frontmatter/body pin prose. No generic
# fallback builder/reviewer or review scout remains.

agent_prompt_dialects=(claude omp)

builder_prompt_names=(
  mr-builder
)
claude_builder_prompt_names=( "${builder_prompt_names[@]}" )
omp_builder_prompt_names=( "${builder_prompt_names[@]}" )
routed_builder_prompt_names=( "${builder_prompt_names[@]}" )

final_reviewer_prompt_names=(
  mr-reviewer-final
)
claude_final_reviewer_prompt_names=( "${final_reviewer_prompt_names[@]}" )
omp_final_reviewer_prompt_names=( "${final_reviewer_prompt_names[@]}" )
routed_final_reviewer_prompt_names=( "${final_reviewer_prompt_names[@]}" )
reviewer_prompt_names=( "${final_reviewer_prompt_names[@]}" )

agent_prompt_dialects_for() {
  printf '%s\n' "${agent_prompt_dialects[@]}"
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
