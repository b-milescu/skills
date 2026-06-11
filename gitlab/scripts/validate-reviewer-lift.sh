#!/usr/bin/env bash
# Pure-local presence linter for a Reviewer Lift block.
#
# Reads a Reviewer Lift block (the markdown `| Field | Value |` table, optionally
# embedded in surrounding prose/markers) from a file argument or stdin, and exits
# 0 only when EVERY required row named in the Reviewer Lift schema is present AND
# every CLOSED-SET row carries a value drawn from its allowed set. A missing
# required row, or a closed-set row with an out-of-set value, fails closed.
#
# This is a presence/shape + closed-set MEMBERSHIP check. It validates that each
# required row name appears as a table row, and that the closed-set rows below
# hold an allowed value:
#   - Merge authority  ∈ {approval-only, reviewer may merge, queue auto-merge,
#                         human release, project default: <...>}
#   - Review gate      ∈ {mandatory, bypassed (human override)}
#   - Gate owner       ∈ {child, parent}
#   - Gate coverage    ∈ {full-local, hybrid, ci-only}
#   - Acceptance surfaces: each `surface[:evidence]` token's surface is drawn
#     from the project acceptance_surfaces_ref vocabulary (read at runtime), or
#     the whole value is `none`/`[]`.
# It does NOT judge SEMANTIC correctness (e.g. whether a declared acceptance
# surface actually matches the diff) — that stays parent/reviewer judgment.
#
# Makes NO network call: it only reads local files (schema, acceptance-surface
# vocabulary) and the input text. The schema markdown is the single source of
# truth for the required-row list, and the vocabulary doc is the source of truth
# for allowed acceptance-surface tokens; this script extracts both at runtime
# instead of re-listing them, so it cannot invent or drop a row, and it
# auto-tracks vocabulary additions. The fixed enums above are owned by
# start-build/templates/reviewer-lift-schema.md field definitions.
#
# Canonical schema: start-build/templates/reviewer-lift-schema.md (## Required fields)
# Acceptance-surface vocabulary: docs/agents/dev-workflows.md
#   (### Acceptance-surface vocabulary)
#
# Exit codes:
#   0   valid: every required row is present and every closed-set value is allowed
#   3   reason=missing_row     one or more required rows absent from the block
#   4   reason=invalid_value   a closed-set row holds an out-of-set value
#   5   reason=no_table        input has no parseable Reviewer Lift table / is empty
#   64  usage / argument error (bad flag, missing/unreadable input/schema/vocab)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_SCHEMA="$SCRIPT_DIR/../../start-build/templates/reviewer-lift-schema.md"
DEFAULT_VOCAB="$SCRIPT_DIR/../../docs/agents/dev-workflows.md"

usage() {
  cat <<'USAGE'
Usage: validate-reviewer-lift.sh [--schema <path>] [--vocab <path>] [<lift-block.md>]

Reads a Reviewer Lift block from <lift-block.md> or, when no file is given, from
stdin. The block is the markdown `| Field | Value |` table (it may be embedded in
surrounding prose). Validates that every required row named in the Reviewer Lift
schema (default: start-build/templates/reviewer-lift-schema.md, ## Required
fields) is present, and that every closed-set row holds an allowed value. The
acceptance-surface vocabulary is read at runtime from the project doc (default:
docs/agents/dev-workflows.md, ### Acceptance-surface vocabulary). Checks row
presence and closed-set membership only, never semantic correctness.

Options:
  --schema <path>   Override the schema path (testing/local use).
  --vocab <path>    Override the acceptance-surface vocabulary doc path
                    (testing/local use).
  -h, --help        Show this help.

Exit codes:
  0   valid: every required row is present and every closed-set value is allowed
  3   reason=missing_row     one or more required rows absent
  4   reason=invalid_value   a closed-set row holds an out-of-set value
  5   reason=no_table        input has no Reviewer Lift table / is empty
  64  usage / argument error
USAGE
}

schema_path="$DEFAULT_SCHEMA"
vocab_path="$DEFAULT_VOCAB"
input_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema) schema_path="${2:-}"; shift 2 ;;
    --vocab) vocab_path="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*)
      echo "REVIEWER_LIFT result=invalid reason=unknown_arg arg=$1" >&2
      usage >&2
      exit 64 ;;
    *)
      if [[ -n "$input_path" ]]; then
        echo "REVIEWER_LIFT result=invalid reason=too_many_args arg=$1" >&2
        exit 64
      fi
      input_path="$1"; shift ;;
  esac
done

if [[ $# -gt 0 ]]; then
  if [[ -n "$input_path" ]]; then
    echo "REVIEWER_LIFT result=invalid reason=too_many_args arg=$1" >&2
    exit 64
  fi
  input_path="$1"
fi

command -v node >/dev/null 2>&1 || {
  echo "REVIEWER_LIFT result=invalid reason=node_missing" >&2
  exit 64
}

[[ -f "$schema_path" ]] || {
  echo "REVIEWER_LIFT result=invalid reason=schema_not_found path=$schema_path" >&2
  exit 64
}

[[ -f "$vocab_path" ]] || {
  echo "REVIEWER_LIFT result=invalid reason=vocab_not_found path=$vocab_path" >&2
  exit 64
}

if [[ -n "$input_path" ]]; then
  [[ -f "$input_path" ]] || {
    echo "REVIEWER_LIFT result=invalid reason=input_not_found path=$input_path" >&2
    exit 64
  }
  input_text="$(cat -- "$input_path")"
else
  input_text="$(cat)"
fi

# All parsing lives in node for robust, deterministic text handling. node reads
# the schema (source of truth for required rows) and the input block, then exits
# 0 / 3 / 5 with a single diagnostic line on stderr for failures.
SCHEMA_PATH="$schema_path" VOCAB_PATH="$vocab_path" INPUT_TEXT="$input_text" node <<'NODE'
'use strict';

const fs = require('fs');

function failMissing(rows) {
  process.stderr.write(
    `REVIEWER_LIFT result=invalid reason=missing_row rows=${rows.join(',')}\n`
  );
  // Also emit one line per missing row so callers/tests can match a single name.
  for (const r of rows) {
    process.stderr.write(`REVIEWER_LIFT missing_row row=${r}\n`);
  }
  process.exit(3);
}

function failNoTable(detail) {
  const tail = detail ? ' ' + detail : '';
  process.stderr.write(`REVIEWER_LIFT result=invalid reason=no_table${tail}\n`);
  process.exit(5);
}

function failInvalidValue(row, value, detail) {
  // Diagnostic names the offending row so callers/tests can match it directly.
  const tail = detail ? ' ' + detail : '';
  process.stderr.write(
    `REVIEWER_LIFT result=invalid reason=invalid_value row=${row} value=${value}${tail}\n`
  );
  process.exit(4);
}

// --- Extract required rows from the schema's "## Required fields" table. ---
let schemaText;
try {
  schemaText = fs.readFileSync(process.env.SCHEMA_PATH, 'utf8');
} catch (e) {
  process.stderr.write('REVIEWER_LIFT result=invalid reason=schema_unreadable\n');
  process.exit(64);
}

function extractFieldColumn(text, headingRe) {
  const lines = text.split(/\r?\n/);
  let state = '';
  const rows = [];
  for (const l of lines) {
    if (headingRe.test(l)) { state = 'pre'; continue; }
    if (state === 'pre' && /^\|\s*Field\s*\|/.test(l)) { state = 'head'; continue; }
    if (state === 'head' && /^\|\s*-+\s*\|/.test(l)) { state = 'rows'; continue; }
    if (state === 'rows') {
      if (/^\|/.test(l)) {
        const field = l.split('|')[1].trim();
        if (field) rows.push(field);
      } else if (l.trim() === '') {
        break;
      }
    }
  }
  return rows;
}

const required = extractFieldColumn(schemaText, /^## Required fields/);
if (required.length === 0) {
  process.stderr.write('REVIEWER_LIFT result=invalid reason=schema_no_rows\n');
  process.exit(64);
}

// --- Extract the field names present in the input Lift block. ---
// A Lift block row is any markdown table row "| <field> | <value> |". We accept
// the block embedded in surrounding prose, and skip the header row ("Field") and
// the separator row ("---"). Field names are matched case-insensitively after
// trimming, mirroring how the names appear verbatim in the generated-copy block.
const inputText = process.env.INPUT_TEXT || '';
const present = new Set();
const values = new Map(); // lowercase field -> first-seen trimmed value cell
let sawTableRow = false;
for (const l of inputText.split(/\r?\n/)) {
  if (!/^\s*\|/.test(l)) continue;
  const cells = l.split('|');
  if (cells.length < 3) continue; // not a "| a | b |" row
  const field = cells[1].trim();
  if (field === '') continue;
  if (/^-+$/.test(field)) continue;          // separator row
  if (field.toLowerCase() === 'field') continue; // header row
  sawTableRow = true;
  const key = field.toLowerCase();
  present.add(key);
  if (!values.has(key)) values.set(key, cells[2].trim());
}

if (!sawTableRow) {
  failNoTable('detail=no_lift_table_rows');
}

const missing = required.filter((r) => !present.has(r.toLowerCase()));
if (missing.length > 0) {
  failMissing(missing);
}

// --- Closed-set ROW VALUE validation (membership only). ---------------------
// Fixed enums are owned by the schema field definitions; the acceptance-surface
// vocabulary is read at runtime from the project doc so it auto-tracks additions.

// Lift values are commonly wrapped in a markdown code span (`value`), as in the
// generated-copy template. Strip a single surrounding backtick pair (and outer
// whitespace) so membership is checked against the literal value, not its
// markdown presentation. This does not alter inner text.
function unwrap(v) {
  if (v === undefined) return undefined;
  let s = v.trim();
  if (s.length >= 2 && s.startsWith('`') && s.endsWith('`')) {
    s = s.slice(1, -1).trim();
  }
  return s;
}

function valueOf(rowName) {
  return unwrap(values.get(rowName.toLowerCase()));
}

// Merge authority accepts a fixed enum plus the open `project default: <...>`
// form, so it is checked with a predicate rather than a flat set.
const mergeAuthorityFixed = new Set([
  'approval-only',
  'reviewer may merge',
  'queue auto-merge',
  'human release',
]);
function mergeAuthorityOk(v) {
  if (mergeAuthorityFixed.has(v)) return true;
  return /^project default:\s*\S/.test(v);
}

const enumRows = [
  { row: 'Merge authority', ok: mergeAuthorityOk },
  { row: 'Review gate', ok: (v) => v === 'mandatory' || v === 'bypassed (human override)' },
  { row: 'Gate owner', ok: (v) => v === 'child' || v === 'parent' },
  { row: 'Gate coverage', ok: (v) => v === 'full-local' || v === 'hybrid' || v === 'ci-only' },
];

for (const { row, ok } of enumRows) {
  const v = valueOf(row);
  if (v === undefined) continue; // presence already enforced for required rows
  if (!ok(v)) {
    failInvalidValue(row, v, `detail=not_in_allowed_set`);
  }
}

// Acceptance surfaces: read the allowed surface vocabulary at runtime from the
// project acceptance_surfaces_ref doc's "### Acceptance-surface vocabulary"
// table (first column, backticks stripped). Each value token is
// `surface[:evidence]`; the surface part must be in the vocabulary. `none`/`[]`
// means no surface is declared.
let vocabText;
try {
  vocabText = fs.readFileSync(process.env.VOCAB_PATH, 'utf8');
} catch (e) {
  process.stderr.write('REVIEWER_LIFT result=invalid reason=vocab_unreadable\n');
  process.exit(64);
}

function extractVocabColumn(text, headingRe) {
  const lines = text.split(/\r?\n/);
  let state = '';
  const rows = [];
  for (const l of lines) {
    if (headingRe.test(l)) { state = 'pre'; continue; }
    if (state === 'pre' && /^\|\s*Surface value\s*\|/.test(l)) { state = 'head'; continue; }
    if (state === 'head' && /^\|\s*-+\s*\|/.test(l)) { state = 'rows'; continue; }
    if (state === 'rows') {
      if (/^\|/.test(l)) {
        const cell = l.split('|')[1].trim().replace(/`/g, '');
        if (cell) rows.push(cell);
      } else if (l.trim() === '') {
        break;
      }
    }
  }
  return rows;
}

const acceptanceRow = 'Acceptance surfaces';
const acceptanceValue = valueOf(acceptanceRow);
if (acceptanceValue !== undefined) {
  const vocab = new Set(
    extractVocabColumn(vocabText, /^### Acceptance-surface vocabulary/)
  );
  if (vocab.size === 0) {
    process.stderr.write('REVIEWER_LIFT result=invalid reason=vocab_no_rows\n');
    process.exit(64);
  }
  const normalized = acceptanceValue.trim();
  // `none` / `[]` means no surface declared and is always allowed.
  if (normalized !== 'none' && normalized !== '[]' && normalized !== '') {
    const tokens = normalized.split(',').map((t) => t.trim()).filter((t) => t !== '');
    for (const tok of tokens) {
      // token is `surface` or `surface:evidence`; validate the surface part.
      const surface = tok.split(':')[0].trim();
      if (!vocab.has(surface)) {
        failInvalidValue(acceptanceRow, acceptanceValue, `detail=surface_not_in_vocabulary surface=${surface}`);
      }
    }
  }
}

process.exit(0);
NODE
