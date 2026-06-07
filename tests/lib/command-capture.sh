# Shared command-output capture/assertions for shell regression tests.
# Source from tests after setting REPO_ROOT or from any tests/lib sibling.

_TEST_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=tests/lib/assertions.sh
source "$_TEST_LIB_DIR/assertions.sh"
unset _TEST_LIB_DIR

CAPTURE_STATUS=0
CAPTURE_OUTPUT=""

run_capture() {
  set +e
  CAPTURE_OUTPUT="$({ "$@"; } 2>&1)"
  CAPTURE_STATUS=$?
  set -e
}

assert_capture_status() {
  local expected="$1"
  [[ "$CAPTURE_STATUS" -eq "$expected" ]] || fail "expected status $expected, got $CAPTURE_STATUS; output: $CAPTURE_OUTPUT"
}

assert_status() {
  assert_capture_status "$@"
}

assert_capture_contains() {
  local needle="$1" label="${2:-$1}"
  assert_text_contains "$CAPTURE_OUTPUT" "$needle" "$label"
}

assert_capture_not_contains() {
  local needle="$1" label="${2:-$1}"
  assert_text_not_contains "$CAPTURE_OUTPUT" "$needle" "$label"
}

assert_yaml_field() {
  local field="$1" expected="$2"
  YAML_PAYLOAD="$CAPTURE_OUTPUT" node - "$field" "$expected" <<'NODE'
const yaml = require('js-yaml');
const data = yaml.load(process.env.YAML_PAYLOAD || '');
const field = process.argv[2];
const expected = process.argv[3];
const actual = data?.[field];
if (String(actual) !== expected) {
  console.error(`expected YAML ${field}=${expected}, got ${actual}`);
  process.exit(1);
}
NODE
}

assert_json_field() {
  local field="$1" expected="$2"
  JSON_PAYLOAD="$CAPTURE_OUTPUT" node - "$field" "$expected" <<'NODE'
const data = JSON.parse(process.env.JSON_PAYLOAD || '{}');
const path = process.argv[2].split('.').filter(Boolean);
let value = data;
for (const key of path) value = value?.[key];
const actual = value === undefined || value === null ? '' : String(value);
if (actual !== process.argv[3]) {
  console.error(`expected JSON ${process.argv[2]}=${process.argv[3]}, got ${actual}`);
  process.exit(1);
}
NODE
}

assert_json_array_contains() {
  local field="$1" expected="$2"
  JSON_PAYLOAD="$CAPTURE_OUTPUT" node - "$field" "$expected" <<'NODE'
const data = JSON.parse(process.env.JSON_PAYLOAD || '{}');
const path = process.argv[2].split('.').filter(Boolean);
let value = data;
for (const key of path) value = value?.[key];
if (!Array.isArray(value) || !value.includes(process.argv[3])) {
  console.error(`expected JSON array ${process.argv[2]} to contain ${process.argv[3]}, got ${JSON.stringify(value)}`);
  process.exit(1);
}
NODE
}
