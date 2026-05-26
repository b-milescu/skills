#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

needle='subagent({ action: "list" })'
flow_file="start-build/BUILD-FLOW.md"
parent_start="$(grep -n '^## Parent-orchestrator recipe$' "$flow_file" | cut -d: -f1)"
parent_end="$(grep -n '^## Check gate discovery$' "$flow_file" | cut -d: -f1)"

if [ -z "$parent_start" ] || [ -z "$parent_end" ]; then
  echo "parent-subagent-placement: missing parent-orchestrator section bounds" >&2
  exit 1
fi

mapfile -t matches < <(
  grep -RInF "$needle" \
    start-build start-review agents docs setup-dev-skills README.md CONTEXT.md \
    2>/dev/null || true
)

if [ "${#matches[@]}" -eq 0 ]; then
  echo "parent-subagent-placement: missing parent-side subagent discovery guidance" >&2
  exit 1
fi

for match in "${matches[@]}"; do
  file="${match%%:*}"
  rest="${match#*:}"
  line="${rest%%:*}"
  if [ "$file" != "$flow_file" ] || [ "$line" -le "$parent_start" ] || [ "$line" -ge "$parent_end" ]; then
    echo "parent-subagent-placement: runtime-specific subagent call outside parent-orchestrator recipe: $match" >&2
    exit 1
  fi
done

if ! sed -n "${parent_start},${parent_end}p" "$flow_file" | grep -q 'MR / code-review specialization'; then
  echo "parent-subagent-placement: parent recipe lacks reviewer discovery guidance" >&2
  exit 1
fi

for builder_prompt in agents/claude/mr-builder.md agents/pi/mr-builder.md; do
  if grep -qF "$needle" "$builder_prompt"; then
    echo "parent-subagent-placement: child builder prompt contains runtime-specific subagent list call: $builder_prompt" >&2
    exit 1
  fi
done

printf 'parent-subagent-placement: PASS\n'
