#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

builder_template="$REPO_ROOT/start-build/templates/builder-final-handoff.md"
reviewer_template="$REPO_ROOT/start-review/templates/reviewer-final-handoff.md"

builder_expected=(
  kind
  version
  status
  issue
  mr
  head_sha
  reviewed_sha
  pipeline
  local_gate
  tdd
  changed_files
  safety_surfaces
  decoupling
  reviewer_focus
  open_questions
  merge_authority
  next_action
  artifacts
  blockers
  extra
)

reviewer_expected=(
  kind
  version
  decision
  mr
  reviewed_sha
  pipeline
  local_checks
  findings
  open_questions_addressed
  merge
  next_action
  report_url
  extra
)

extract_top_level_fields() {
  local file="$1"
  awk '
    /^```yaml$/ { in_yaml=1; next }
    in_yaml && /^```$/ { in_yaml=0; in_agent=0; next }
    in_yaml && /^agent_handoff:/ { in_agent=1; next }
    in_agent && /^  [a-z_]+:/ {
      field=$1
      sub(/:$/, "", field)
      print field
    }
  ' "$file"
}

assert_template() {
  local name="$1"
  local file="$2"
  local begin_marker="$3"
  local end_marker="$4"
  shift 4
  local expected=("$@")
  local expected_file="$TMPDIR/$name.expected"
  local actual_file="$TMPDIR/$name.actual"

  [[ -f "$file" ]] || { echo "missing $name template: $file" >&2; exit 1; }
  grep -qF "$begin_marker" "$file" || { echo "$name template missing begin marker" >&2; exit 1; }
  grep -qF "$end_marker" "$file" || { echo "$name template missing end marker" >&2; exit 1; }
  grep -q 'https://gitlab.example/' "$file" || { echo "$name template must use synthetic gitlab.example URLs" >&2; exit 1; }
  if grep -q 'gitlab.example.com' "$file"; then
    echo "$name template must not use live project URLs" >&2
    exit 1
  fi

  printf '%s\n' "${expected[@]}" > "$expected_file"
  extract_top_level_fields "$file" > "$actual_file"
  if ! diff -u "$expected_file" "$actual_file"; then
    echo "$name handoff field order drift" >&2
    exit 1
  fi
}

assert_template \
  builder \
  "$builder_template" \
  '<!-- AGENT-HANDOFF:BUILDER-FINAL:BEGIN -->' \
  '<!-- AGENT-HANDOFF:BUILDER-FINAL:END -->' \
  "${builder_expected[@]}"

assert_template \
  reviewer \
  "$reviewer_template" \
  '<!-- AGENT-HANDOFF:REVIEWER-FINAL:BEGIN -->' \
  '<!-- AGENT-HANDOFF:REVIEWER-FINAL:END -->' \
  "${reviewer_expected[@]}"

node --input-type=module - "$builder_template" "$reviewer_template" <<'NODE'
import fs from 'node:fs';
import yaml from 'js-yaml';

for (const file of process.argv.slice(2)) {
  const content = fs.readFileSync(file, 'utf8');
  const matches = [...content.matchAll(/```yaml\n([\s\S]*?)\n```/g)];
  if (matches.length !== 1) {
    throw new Error(`${file}: expected exactly one YAML fence, found ${matches.length}`);
  }
  const parsed = yaml.load(matches[0][1]);
  if (!parsed?.agent_handoff || typeof parsed.agent_handoff !== 'object') {
    throw new Error(`${file}: missing agent_handoff object`);
  }

  if (file.endsWith('builder-final-handoff.md')) {
    const handoff = parsed.agent_handoff;
    if (!('head_sha' in handoff) || !('reviewed_sha' in handoff)) {
      throw new Error(`${file}: builder handoff must expose both head_sha and reviewed_sha`);
    }
    if (handoff.head_sha !== handoff.reviewed_sha) {
      throw new Error(`${file}: builder example head_sha and reviewed_sha must match`);
    }
    if (!content.includes('`reviewed_sha` is the same commit as `head_sha`')) {
      throw new Error(`${file}: missing explicit reviewed_sha/head_sha equality semantics`);
    }
  }
}
NODE

echo "agent-handoff-templates: PASS"
