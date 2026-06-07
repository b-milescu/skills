# Shared extraction helpers for Markdown headings and generated-copy markers.
# Source from tests; do not execute directly.

extract_marked_block() {
  local file="$1" begin_marker="$2" end_marker="$3"
  awk -v begin="$begin_marker" -v end="$end_marker" '
    index($0, begin) { in_block=1; next }
    index($0, end) { in_block=0; next }
    in_block { print }
  ' "$file"
}

extract_markdown_section() {
  local file="$1" heading="$2" next_heading_pattern="${3:-^#}"
  awk -v heading="$heading" -v next_heading_pattern="$next_heading_pattern" '
    $0 == heading { in_section=1; next }
    in_section && $0 ~ next_heading_pattern { exit }
    in_section { print }
  ' "$file"
}
