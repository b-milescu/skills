#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

needle='subagent({ action: "list" })'
parent_file="start-build/reference/parent-orchestrator.md"
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

for phrase in 'issue-implementation specialization' 'change-review specialization'; do
  if ! grep -qF "$phrase" "$parent_file"; then
    echo "parent-subagent-placement: parent reference lacks discovery guidance phrase: $phrase" >&2
    exit 1
  fi
done

for builder_prompt in agents/claude/mr-builder.md agents/omp/mr-builder.md "$child_doc"; do
  if grep -qF "$needle" "$builder_prompt"; then
    echo "parent-subagent-placement: child builder prompt/doc contains runtime-specific subagent list call: $builder_prompt" >&2
    exit 1
  fi
done

# Launch-prompt skill-load invariant (#320, guarded by #322), builder analogue:
# the parent's minimal child-builder launch prompt must carry a
# Skill-tool-invocation `Skills:` line so the spawned child enters through the
# SKILL.md entry procedure rather than raw-Reading a mid-policy reference file.
# Pin to the stable `Skills:` + `via the Skill tool` tokens on the line that
# follows the child-builder `Mode: child mr-builder` marker.
child_builder_skills_line="$(
  awk '
    $0 == "Mode: child mr-builder" { want=1; next }
    want && /^Skills:/ { print; want=0 }
    want && /^```/ { want=0 }
  ' "$parent_file"
)"
if [ -z "$child_builder_skills_line" ]; then
  echo "parent-subagent-placement: child-builder launch-prompt block missing a Skills: line after its Mode: marker" >&2
  exit 1
fi
if ! printf '%s\n' "$child_builder_skills_line" | grep -qiF 'via the Skill tool'; then
  echo "parent-subagent-placement: child-builder launch-prompt Skills: line lacks the 'via the Skill tool' Skill-invocation token" >&2
  exit 1
fi

printf 'parent-subagent-placement: PASS\n'
