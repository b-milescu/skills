#!/usr/bin/env bash
# Shared agent prompt role map for regression tests. Keep routed variants in one
# place so prompt-drift, authority, handoff, and transport checks cover the same
# files without duplicating path inventories across scripts.
#
# Routed-only inventory (#300): MR builder/reviewer routes are runtime-specific.
# OMP routes pin openai-codex/* (GPT) models; Claude Code routes pin anthropic/*
# (Opus/Sonnet) models. No route name is shared across dialects, and no generic
# fallback builder/reviewer or review scout remains.

agent_prompt_dialects=(claude omp)

claude_builder_prompt_names=(
  mr-builder-sonnet-low
  mr-builder-opus48
  mr-builder-opus48-high
)

omp_builder_prompt_names=(
  mr-builder-gpt54-low
  mr-builder-gpt55
  mr-builder-gpt55-high
)

# Every builder route is a routed pin now; the routed list equals the full list.
builder_prompt_names=(
  "${claude_builder_prompt_names[@]}"
  "${omp_builder_prompt_names[@]}"
)
routed_builder_prompt_names=( "${builder_prompt_names[@]}" )

claude_final_reviewer_prompt_names=(
  mr-reviewer-opus48-xhigh
)

omp_final_reviewer_prompt_names=(
  mr-reviewer-gpt55-xhigh
)

# Every final reviewer route is a routed pin now; there is no generic reviewer
# and no review scout.
final_reviewer_prompt_names=(
  "${claude_final_reviewer_prompt_names[@]}"
  "${omp_final_reviewer_prompt_names[@]}"
)
routed_final_reviewer_prompt_names=( "${final_reviewer_prompt_names[@]}" )
reviewer_prompt_names=( "${final_reviewer_prompt_names[@]}" )

# Each routed name lives in exactly one dialect: OMP routes pin openai-codex/*
# and Claude routes pin anthropic/*, so no name resolves to both dialects.
agent_prompt_dialects_for() {
  local name="$1" candidate
  for candidate in "${omp_builder_prompt_names[@]}" "${omp_final_reviewer_prompt_names[@]}"; do
    [[ "$candidate" == "$name" ]] && { printf 'omp\n'; return 0; }
  done
  for candidate in "${claude_builder_prompt_names[@]}" "${claude_final_reviewer_prompt_names[@]}"; do
    [[ "$candidate" == "$name" ]] && { printf 'claude\n'; return 0; }
  done
  # Unknown names (non-routed callers) fall back to both dialects so the path
  # helpers stay total.
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
