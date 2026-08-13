#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME=review-authority-provenance
source tests/lib/assertions.sh
source tests/lib/agent-prompt-sets.sh

schema=start-build/templates/reviewer-lift-schema.md
for row in 'Approval authority' 'Approval authority source' 'Finish authority' 'Finish authority source'; do
  assert_file_contains "$schema" "| $row |" "canonical row $row"
done
for copy in start-build/templates/review-packet.md start-build/templates/review-packet-compact.md start-review/templates/review-report.md; do
  for row in 'Approval authority' 'Approval authority source' 'Finish authority' 'Finish authority source'; do
    assert_file_contains "$copy" "| $row |" "$copy row $row"
  done
  assert_file_not_contains "$copy" '| Merge authority' "$copy retired merge row"
done

for file in start-review/REVIEW-FLOW.md start-review/SKILL.md start-review/templates/filling-guide.md; do
  assert_file_contains "$file" 'Approval authority' "$file approval guidance"
  assert_file_contains "$file" 'Finish authority' "$file finish guidance"
  assert_file_contains "$file" 'source' "$file source verification"
  assert_file_not_contains "$file" 'Merge authority' "$file retired merge guidance"
done
assert_file_contains start-review/REVIEW-FLOW.md 'Explicit human/provider restrictions precede defaults' "source precedence"
assert_file_contains start-review/REVIEW-FLOW.md 'Missing Finish authority blocks only' "finish-only blocker"
assert_file_contains forge/reference/common-guard.md 'Authority Verification' "shared verification owner"
assert_file_contains forge/reference/common-guard.md 'take precedence' "common source precedence"

for file in start-build/reference/child-builder.md start-build/reference/context-and-planning.md start-build/templates/filling-guide.md; do
  assert_file_contains "$file" 'Finish authority' "$file builder finish claim"
  assert_file_contains "$file" 'source' "$file builder source"
  assert_file_not_contains "$file" 'Merge authority' "$file retired builder merge guidance"
done
assert_file_contains start-build/reference/child-builder.md 'builders cannot grant authority' "child builder cannot grant"
assert_file_contains start-build/reference/context-and-planning.md 'not a builder grant' "planning treats finish as claim"
assert_file_contains start-build/templates/filling-guide.md 'Do not write builder-local interpretation as authority' "filling guide forbids builder grant"

for file in $(agent_prompt_paths "${routed_final_reviewer_prompt_names[@]}"); do
  assert_file_contains "$file" 'start-review` plus `forge` common-guard authority verification' "$file reviewer authority seam"
  assert_file_contains "$file" 'Reviewer Lift' "$file Lift claims"
  assert_file_not_contains "$file" 'start-review` plus `gitlab`' "$file retired GitLab seam"
done
for file in $(agent_prompt_paths "${routed_builder_prompt_names[@]}"); do
  assert_file_contains "$file" 'approve, merge, queue auto-merge' "$file no self finish"
  assert_file_contains "$file" 'forge' "$file provider seam"
done

for handoff in start-build/templates/builder-final-handoff.md start-review/templates/reviewer-final-handoff.md; do
  assert_file_contains "$handoff" '    authority:' "$handoff authority object"
  assert_file_contains "$handoff" '      approval:' "$handoff approval object"
  assert_file_contains "$handoff" '      finish:' "$handoff finish object"
  assert_file_not_contains "$handoff" '^  merge_authority' "$handoff retired flat alias"
  assert_file_not_contains "$handoff" '^  approval_authority' "$handoff retired flat alias"
done

printf '%s\n' "review-authority-provenance: PASS"
