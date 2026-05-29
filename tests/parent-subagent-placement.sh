#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

needle='subagent({ action: "list" })'
parent_file="start-build/reference/parent-orchestrator.md"
router_file="start-build/BUILD-FLOW.md"
child_doc="start-build/reference/child-builder.md"

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
  if [ "$file" != "$parent_file" ]; then
    echo "parent-subagent-placement: runtime-specific subagent call outside parent-orchestrator reference: $match" >&2
    exit 1
  fi
done

for phrase in 'issue-implementation specialization' 'MR / code-review specialization'; do
  if ! grep -qF "$phrase" "$parent_file"; then
    echo "parent-subagent-placement: parent reference lacks discovery guidance phrase: $phrase" >&2
    exit 1
  fi
done

if grep -qF "$needle" "$router_file"; then
  echo "parent-subagent-placement: BUILD-FLOW router should point to parent reference without runtime-specific subagent call" >&2
  exit 1
fi

for builder_prompt in agents/claude/mr-builder.md agents/pi/mr-builder.md "$child_doc"; do
  if grep -qF "$needle" "$builder_prompt"; then
    echo "parent-subagent-placement: child builder prompt/doc contains runtime-specific subagent list call: $builder_prompt" >&2
    exit 1
  fi
done

printf 'parent-subagent-placement: PASS\n'
