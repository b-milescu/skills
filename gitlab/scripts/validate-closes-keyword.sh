#!/usr/bin/env bash
# Pure-local shape linter for the GitLab auto-close keyword in an MR description.
#
# Reads an MR description from a file argument or stdin, plus a target issue iid,
# and exits 0 only when the description contains at least one closing reference
# that GitLab's DEFAULT closing pattern (default_issue_closing_pattern) would
# actually match for that iid — i.e. a plain closing keyword immediately followed
# by `#<iid>` that is NOT inside an inline code span or a fenced code block, and
# is NOT present only in a bolded / markdown-wrapped form. Otherwise it fails
# closed with an explicit, body-free diagnostic.
#
# Why this exists (issue #295, a #293 recurrence): documentation-only guidance
# asking builders to write a plain, unbolded `Closes #N` did not prevent
# `**Closes:** #N` (bolded) and `` `Closes #N` `` (inline code span) recurrences,
# which GitLab does NOT auto-close. The closing-pattern rationale (the *why*) is
# owned by start-build/templates/review-packet.md (issue #293); this helper
# mechanically enforces it so a builder cannot mark ready, and a parent cannot
# finish, with a formatting-defeated or missing close keyword.
#
# Closing keywords mirror GitLab's default_issue_closing_pattern keyword set:
#   close, closes, closed, closing, fix, fixes, fixed, fixing,
#   resolve, resolves, resolved, resolving,
#   implement, implements, implemented, implementing   (case-insensitive)
#
# Makes NO network call: it reads only the local input text. Presence/shape only;
# it does not contact GitLab and does not judge whether the iid is the "right"
# issue — the caller supplies the iid the MR is meant to close.
#
# Exit codes:
#   0   valid: at least one plain `<keyword> #<iid>` matches outside code/bold
#   3   reason=no_plain_close   no GitLab-auto-close-eligible plain reference for <iid>
#   64  usage / argument error (bad/missing --issue-iid, unreadable input, etc.)

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: validate-closes-keyword.sh --issue-iid <iid> [<description.md>]

Reads an MR description from <description.md> or, when no file is given, from
stdin. Exits 0 only when the description contains at least one plain
`<closing-keyword> #<iid>` reference that GitLab's default closing pattern would
auto-close — a closing keyword (close/closes/closed/closing, fix/fixes/...,
resolve/..., implement/...; case-insensitive) immediately followed by `#<iid>`,
that is NOT inside an inline code span (`` `...` ``) or a fenced code block
(``` ``` ```), and NOT present only in a bolded / wrapped form (`**Closes:** #N`).

The closing-pattern rationale (the *why*) is owned by
start-build/templates/review-packet.md (issue #293); this helper enforces it.

Options:
  --issue-iid <iid>   Target issue iid the MR is meant to close (required, digits).
  -h, --help          Show this help.

Exit codes:
  0   valid: a plain `<keyword> #<iid>` matches outside code spans/blocks and bold
  3   reason=no_plain_close   no auto-close-eligible plain reference for <iid>
  64  usage / argument error
USAGE
}

issue_iid=""
input_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue-iid) issue_iid="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*)
      echo "CLOSES_KEYWORD result=invalid reason=unknown_arg arg=$1" >&2
      usage >&2
      exit 64 ;;
    *)
      if [[ -n "$input_path" ]]; then
        echo "CLOSES_KEYWORD result=invalid reason=too_many_args arg=$1" >&2
        exit 64
      fi
      input_path="$1"; shift ;;
  esac
done

if [[ $# -gt 0 ]]; then
  if [[ -n "$input_path" ]]; then
    echo "CLOSES_KEYWORD result=invalid reason=too_many_args arg=$1" >&2
    exit 64
  fi
  input_path="$1"
fi

if [[ -z "$issue_iid" ]]; then
  echo "CLOSES_KEYWORD result=invalid reason=missing_issue_iid" >&2
  usage >&2
  exit 64
fi

if [[ ! "$issue_iid" =~ ^[0-9]+$ ]]; then
  echo "CLOSES_KEYWORD result=invalid reason=non_numeric_issue_iid value=$issue_iid" >&2
  exit 64
fi

command -v node >/dev/null 2>&1 || {
  echo "CLOSES_KEYWORD result=invalid reason=node_missing" >&2
  exit 64
}

if [[ -n "$input_path" ]]; then
  [[ -f "$input_path" ]] || {
    echo "CLOSES_KEYWORD result=invalid reason=input_not_found path=$input_path" >&2
    exit 64
  }
  input_text="$(cat -- "$input_path")"
else
  input_text="$(cat)"
fi

# All parsing lives in node for robust, deterministic text handling. node reads
# the target iid and the description text, neutralises markdown code (fenced
# blocks and inline code spans) and bold-wrapped keywords, then checks for a
# plain `<keyword> #<iid>` with proper word/number boundaries.
ISSUE_IID="$issue_iid" INPUT_TEXT="$input_text" node <<'NODE'
'use strict';

const iid = process.env.ISSUE_IID;
const original = process.env.INPUT_TEXT || '';

// 1. Remove fenced code blocks (```...``` or ~~~...~~~). A fence opens on a line
//    whose first non-space content is >=3 backticks or tildes and closes on the
//    next matching fence line. Everything between (inclusive) is dropped so a
//    `Closes #N` that lives only inside a fence cannot satisfy the check.
function stripFencedBlocks(text) {
  const lines = text.split(/\r?\n/);
  const out = [];
  let fence = null; // the fence marker char run that opened the current block
  for (const line of lines) {
    const m = line.match(/^\s*(`{3,}|~{3,})/);
    if (fence === null) {
      if (m) {
        fence = m[1][0]; // '`' or '~'
        continue;        // drop the opening fence line
      }
      out.push(line);
    } else {
      // inside a fenced block: look for a closing fence of the same char.
      if (m && m[1][0] === fence) {
        fence = null;    // drop the closing fence line
      }
      // else: drop the in-fence content line
    }
  }
  return out.join('\n');
}

// 2. Remove inline code spans (`...`, ``...``). Replace each span with a space so
//    a `Closes #N` that lives only inside a code span cannot satisfy the check,
//    while unrelated prose backticks (`config.yaml`) simply vanish harmlessly.
function stripInlineCode(text) {
  // Match the longest run of backticks as a delimiter, then the shortest content
  // up to the same run. Process line by line so an unterminated backtick does not
  // swallow the rest of the document.
  return text
    .split(/\r?\n/)
    .map((line) => line.replace(/(`+)(.+?)\1/g, ' '))
    .join('\n');
}

// 3. Neutralise bold/wrapped keyword forms. The issue requires a PLAIN, unbolded
//    keyword: `**Closes:** #N` and `**Closes** #N` (and `__...__`) must fail so a
//    formatting-wrapped reference can never be mistaken for an auto-close-eligible
//    one. We blank the entire bold-delimited span (markers AND content) to a space
//    so a wrapped keyword disappears and cannot read as a plain keyword token.
//    Unrelated bold prose (e.g. **Summary**) harmlessly vanishes too. A bare
//    colon directly after a non-bold keyword (`Closes: #N`) also breaks the plain
//    `<keyword> #N` adjacency below, matching GitLab's keyword+reference shape.
function stripBoldSpans(text) {
  return text
    .split(/\r?\n/)
    .map((line) =>
      line.replace(/\*\*(.+?)\*\*/g, ' ').replace(/__(.+?)__/g, ' ')
    )
    .join('\n');
}

let text = stripFencedBlocks(original);
text = stripInlineCode(text);
text = stripBoldSpans(text);

// 4. Plain auto-close match: a closing keyword as a whole word, optional spaces,
//    then `#<iid>` where the iid is bounded so #2950 does not satisfy #295. This
//    mirrors GitLab's default_issue_closing_pattern shape (keyword + reference)
//    for the single-iid case the caller asks about.
const keywords = [
  'close', 'closes', 'closed', 'closing',
  'fix', 'fixes', 'fixed', 'fixing',
  'resolve', 'resolves', 'resolved', 'resolving',
  'implement', 'implements', 'implemented', 'implementing',
];
const kwAlt = keywords.join('|');
// (?<![A-Za-z]) / (?![A-Za-z]) keep the keyword a standalone word (so `closesomething`
// or `unclosed` never count). After `#<iid>` we forbid a trailing digit so a
// longer issue number cannot substring-match the target.
const re = new RegExp(
  `(?<![A-Za-z])(?:${kwAlt})\\s+#${iid}(?![0-9])`,
  'i'
);

if (re.test(text)) {
  process.exit(0);
}

process.stderr.write(
  `CLOSES_KEYWORD result=invalid reason=no_plain_close issue_iid=${iid} ` +
  `detail=no_plain_auto_close_eligible_reference\n`
);
process.exit(3);
NODE
