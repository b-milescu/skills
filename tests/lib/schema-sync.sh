# Shared schema/generated-copy sync helpers for shell regression tests.
# Source from tests; do not execute directly.

_SCHEMA_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=tests/lib/assertions.sh
source "$_SCHEMA_LIB_DIR/assertions.sh"
# shellcheck source=tests/lib/marked-sections.sh
source "$_SCHEMA_LIB_DIR/marked-sections.sh"
unset _SCHEMA_LIB_DIR

extract_markdown_table_fields() {
  local file="$1" begin_marker="${2:-}" end_marker="${3:-}"
  awk -F'|' -v begin="$begin_marker" -v end="$end_marker" '
    BEGIN { in_block = (begin == "") }
    begin != "" && index($0, begin) { in_block=1; next }
    end != "" && index($0, end) { in_block=0; next }
    in_block && /^\|/ {
      field=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      if (field != "Field" && field !~ /^-+$/ && field != "") print field
    }
  ' "$file"
}

extract_yaml_keys_from_marked_block() {
  local file="$1" begin_marker="$2" end_marker="$3" indent_regex="${4:-    }"
  awk -v begin="$begin_marker" -v end="$end_marker" -v indent="$indent_regex" '
    index($0, begin) { in_block=1; next }
    index($0, end) { in_block=0; next }
    in_block && $0 ~ "^" indent "[a-z_]+:" {
      field=$1
      sub(/:$/, "", field)
      print field
    }
  ' "$file"
}

assert_files_match() {
  local expected_file="$1" actual_file="$2" label="$3"
  if ! diff -u "$expected_file" "$actual_file" >/dev/null; then
    printf '%s: FAIL: %s\n' "$TEST_NAME" "$label" >&2
    diff -u "$expected_file" "$actual_file" >&2 || true
    exit 1
  fi
}
