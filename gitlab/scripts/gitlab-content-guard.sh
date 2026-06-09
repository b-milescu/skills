#!/usr/bin/env bash
# Pure-local content-byte guard for text submitted to GitLab over any transport.
#
# Reads a body string from a file (--file <path>) or, when no file is given, from
# stdin. Exits 0 when the body is safe, non-zero when it contains a NUL byte, a
# non-whitespace C0 control character, or DEL (0x7f). Tab (0x09), newline (0x0a),
# and carriage return (0x0d) remain valid because Markdown bodies use them.
#
# Diagnostics name the failing role and the offending byte offset and NEVER print
# the body, so a malformed or secret-bearing payload is not echoed back.
# gitlab/scripts/gitlab-wrappers.sh delegates file-backed fallback bodies
# here, so this script owns the shared Safe GitLab Text byte rule.
#
# Makes NO network call: it only reads the local input body.
#
# Exit codes:
#   0   safe body
#   65  reason=invalid_control_character   body contains NUL / non-whitespace C0 / DEL
#   66  reason=unreadable_body             --file path missing or unreadable
#   64  usage / argument error (bad flag, missing path)

set -euo pipefail

PREFIX="GITLAB_CONTENT_GUARD"

usage() {
  cat <<'USAGE'
Usage: gitlab-content-guard.sh [--file <path>] [--role <name>]

Reads a body from <path> (with --file) or stdin (default) and validates that it
contains no NUL byte, no non-whitespace C0 control character, and no DEL. Tab,
newline, and carriage return stay valid. Diagnostics name the failing role and
byte offset and never print the body.

Options:
  --file <path>   Read the body from <path> instead of stdin.
  --role <name>   Role label used in diagnostics (default: body).
  -h, --help      Show this help.

Exit codes:
  0   safe body
  65  reason=invalid_control_character
  66  reason=unreadable_body
  64  usage / argument error
USAGE
}

fail() {
  local code="$1" reason="$2"
  # Never include the body here — only the role and offset travel in $reason.
  echo "$PREFIX result=blocked reason=$reason" >&2
  exit "$code"
}

require_node() {
  command -v node >/dev/null || fail 64 dependency_missing_node
}

file=""
role="body"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) file="${2:-}"; shift 2 ;;
    --role) role="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail 64 "unknown_arg:$1" ;;
  esac
done

[[ -n "$role" ]] || fail 64 missing_role

if [[ -n "$file" ]]; then
  [[ -f "$file" && -r "$file" ]] || fail 66 "unreadable_${role}"
fi

require_node

# The Node reader inspects raw bytes only. It reports a role + byte offset on the
# first violating byte and never writes the body to any stream. The script is
# passed via -e so the process stdin (fd 0) stays free for the piped body.
guard_js='
const fs = require("fs");
const file = process.env.GUARD_FILE || "";
const role = process.argv[1] || "body";
let bytes;
try {
  bytes = file ? fs.readFileSync(file) : fs.readFileSync(0);
} catch (_) {
  process.stdout.write(`unreadable_${role}`);
  process.exit(2);
}
for (let i = 0; i < bytes.length; i += 1) {
  const byte = bytes[i];
  // Reject NUL + non-whitespace C0 controls + DEL; keep tab/newline/CR valid.
  if ((byte < 0x20 && byte !== 0x09 && byte !== 0x0a && byte !== 0x0d) || byte === 0x7f) {
    process.stdout.write(`invalid_control_character:${role}:byte_${i}`);
    process.exit(3);
  }
}
'
set +e
result="$(GUARD_FILE="$file" node -e "$guard_js" "$role")"
status=$?
set -e

case "$status" in
  0) exit 0 ;;
  2) fail 66 "${result:-unreadable_${role}}" ;;
  *) fail 65 "${result:-invalid_control_character:$role}" ;;
esac
