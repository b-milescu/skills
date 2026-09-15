#!/usr/bin/env bash
# Focus: Builder/reviewer final-handoff locator fields, explicit builder
# pre-gate `not-created`, no YAML fence, and no live locators.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME=agent-handoff-templates
source tests/lib/assertions.sh

builder=start-build/templates/builder-final-handoff.md
reviewer=start-review/templates/reviewer-final-handoff.md
for file in "$builder" "$reviewer"; do
  assert_file_contains "$file" "Change-request locator:" "$file locator line"
  assert_file_contains "$file" "Durable note id:" "$file note-id line"
  assert_file_not_contains "$file" '```yaml' "$file has no YAML fence"
  assert_file_not_contains "$file" "AGENT-HANDOFF:" "$file has no YAML marker"
  assert_file_not_contains "$file" gitlab.example.com "$file contains no live locator"
done
assert_file_contains "$builder" 'not-created' "builder permits explicit pre-gate absence"
printf '%s\n' "agent-handoff-templates: PASS"
