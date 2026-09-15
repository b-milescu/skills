#!/usr/bin/env bash
# Focus: Shared regression harness self-check for shell assertion primitives,
# command-output capture, marked-section extraction, and schema-sync field
# extraction.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO_ROOT"

TEST_NAME="regression-harness"
TEST_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/regression-harness.XXXXXX")"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# shellcheck source=tests/lib/command-capture.sh
source "$REPO_ROOT/tests/lib/command-capture.sh"
# shellcheck source=tests/lib/marked-sections.sh
source "$REPO_ROOT/tests/lib/marked-sections.sh"
# shellcheck source=tests/lib/schema-sync.sh
source "$REPO_ROOT/tests/lib/schema-sync.sh"

fixture_doc="$TEST_TMPDIR/fixture.md"
cat > "$fixture_doc" <<'MARKDOWN'
# Fixture

Alpha invariant line.

### Snippet: one
first snippet body
<!-- GENERATED-FIELDS:BEGIN -->
| Field | Value |
| --- | --- |
| Reviewed SHA | abc123 |
| Local gate | not-run |
<!-- GENERATED-FIELDS:END -->
### Snippet: two
second snippet body

<!-- DELIVERY:BEGIN -->
    delivery:
    issue:
    mr:
<!-- DELIVERY:END -->
MARKDOWN

require_text "$fixture_doc" 'alpha invariant' 'case-insensitive text assertion'
reject_text "$fixture_doc" 'missing invariant' 'unexpected text assertion'
assert_text_contains 'command output: ok' 'output: ok' 'literal output assertion'
assert_text_not_contains 'command output: ok' 'secret-token' 'negative output assertion'

run_capture bash -c 'printf "captured output"; exit 7'
assert_status 7
assert_capture_contains 'captured output'
assert_capture_not_contains 'not captured'

snippet_body="$(extract_markdown_section "$fixture_doc" '### Snippet: one')"
assert_contains "$snippet_body" 'first snippet body' 'snippet body'
assert_not_contains "$snippet_body" 'second snippet body' 'next snippet body'

extract_markdown_table_fields "$fixture_doc" 'GENERATED-FIELDS:BEGIN' 'GENERATED-FIELDS:END' > "$TEST_TMPDIR/fields.actual"
printf 'Reviewed SHA\nLocal gate\n' > "$TEST_TMPDIR/fields.expected"
assert_files_match "$TEST_TMPDIR/fields.expected" "$TEST_TMPDIR/fields.actual" 'marked table field extraction drifted'

extract_yaml_keys_from_marked_block "$fixture_doc" 'DELIVERY:BEGIN' 'DELIVERY:END' > "$TEST_TMPDIR/yaml.actual"
printf 'delivery\nissue\nmr\n' > "$TEST_TMPDIR/yaml.expected"
assert_files_match "$TEST_TMPDIR/yaml.expected" "$TEST_TMPDIR/yaml.actual" 'marked YAML key extraction drifted'


echo "regression-harness: PASS"
