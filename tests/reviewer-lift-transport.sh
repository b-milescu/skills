#!/usr/bin/env bash
# Pins the Reviewer Lift build-side Transport field and its enum, and fails if
# the Reviewer Lift schema and the finish-result schema disagree on the
# transport vocabulary. See issue #397.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

TEST_NAME="reviewer-lift-transport"
# shellcheck source=tests/lib/assertions.sh
source "$REPO_ROOT/tests/lib/assertions.sh"

command -v node >/dev/null 2>&1 || fail "node required to run this test"

schema="start-build/templates/reviewer-lift-schema.md"
finish_schema="gitlab/reference/finish-result-schema.json"
copies=(
  "start-build/templates/review-packet.md"
  "start-build/templates/review-packet-compact.md"
  "start-review/templates/review-report.md"
)

[[ -f "$schema" ]] || fail "missing schema $schema"
[[ -f "$finish_schema" ]] || fail "missing finish-result schema $finish_schema"

# --- The schema declares a build-side Transport field. ---
require_text_case_sensitive "$schema" '^\| Transport \|' 'Transport field row in reviewer-lift-schema'

# --- Cross-schema vocabulary agreement (no drift). ---
# Canonical enum comes from the finish-result schema's transport property.
finish_enum="$(SCHEMA_PATH="$finish_schema" node -e '
  const s = require(require("path").resolve(process.env.SCHEMA_PATH));
  const e = ((s.properties || {}).transport || {}).enum;
  if (!Array.isArray(e)) { process.exit(2); }
  process.stdout.write([...e].map(String).sort().join(","));
')" || fail "could not read transport enum from $finish_schema"

# The Reviewer Lift schema states its enum after the literal "one of ", as a
# comma-separated list of backtick-wrapped tokens ending at the first period.
transport_row="$(grep -E '^\| Transport \|' "$schema" || true)"
[[ -n "$transport_row" ]] || fail "Transport row not found in $schema"

lift_clause="$(printf '%s\n' "$transport_row" | sed -n 's/.*one of \(`[^.]*\)\..*/\1/p')"
[[ -n "$lift_clause" ]] || fail "Transport row does not declare its enum with an 'one of \`...\`' clause"

lift_enum="$(printf '%s\n' "$lift_clause" | grep -oE '`[^`]+`' | tr -d '`' | sort | paste -sd, -)"
[[ -n "$lift_enum" ]] || fail "could not extract enum tokens from Transport row"

[[ "$lift_enum" == "$finish_enum" ]] || \
  fail "Reviewer Lift transport enum ($lift_enum) drifts from finish-result enum ($finish_enum)"

# Each canonical token is individually pinned in the schema row.
IFS=',' read -r -a enum_tokens <<< "$finish_enum"
for token in "${enum_tokens[@]}"; do
  assert_file_contains "$schema" "\`$token\`" "transport token $token in $schema"
done

# --- glab-fallback must force naming the eligible MCP gap. ---
require_text_case_sensitive "$schema" 'glab-fallback' 'glab-fallback value in Transport row'
printf '%s\n' "$transport_row" | grep -Eiq 'gap' || \
  fail "Transport row does not require naming the eligible MCP gap for glab-fallback"

# --- Copies carry the field and the same vocabulary. ---
for copy in "${copies[@]}"; do
  [[ -f "$copy" ]] || fail "missing copy $copy"
  require_text_case_sensitive "$copy" '^\| Transport \|' "Transport field row in $copy"
  copy_transport_row="$(grep -E '^\| Transport \|' "$copy" || true)"
  for token in "${enum_tokens[@]}"; do
    assert_text_contains "$copy_transport_row" "$token" "transport token $token in $copy"
  done
done

echo "reviewer-lift-transport: PASS"
