#!/usr/bin/env bash
# Pure-local presence linter for a Reviewer Lift block.
#
# Reads a Reviewer Lift block (the markdown `| Field | Value |` table, optionally
# embedded in surrounding prose/markers) from a file argument or stdin, and exits
# 0 only when EVERY required row named in the Reviewer Lift schema is present.
# A missing required row fails closed.
#
# This is a presence/shape check only: it verifies that each required row name
# appears as a table row. It does NOT judge row VALUES (e.g. whether declared
# acceptance surfaces match the diff) — that stays parent/reviewer judgment.
#
# Makes NO network call: it only reads the local schema file and the input text.
# The schema markdown is the single source of truth for the required-row list;
# this script extracts that list from the schema instead of re-listing it, so it
# cannot invent or drop a row.
#
# Canonical schema: start-build/templates/reviewer-lift-schema.md (## Required fields)
#
# Exit codes:
#   0   valid: every required Reviewer Lift row is present
#   3   reason=missing_row     one or more required rows absent from the block
#   5   reason=no_table        input has no parseable Reviewer Lift table / is empty
#   64  usage / argument error (bad flag, missing/unreadable input or schema)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_SCHEMA="$SCRIPT_DIR/../../start-build/templates/reviewer-lift-schema.md"

usage() {
  cat <<'USAGE'
Usage: validate-reviewer-lift.sh [--schema <path>] [<lift-block.md>]

Reads a Reviewer Lift block from <lift-block.md> or, when no file is given, from
stdin. The block is the markdown `| Field | Value |` table (it may be embedded in
surrounding prose). Validates that every required row named in the Reviewer Lift
schema (default: start-build/templates/reviewer-lift-schema.md, ## Required
fields) is present. Checks row PRESENCE only, never row values.

Options:
  --schema <path>   Override the schema path (testing/local use).
  -h, --help        Show this help.

Exit codes:
  0   valid: every required Reviewer Lift row is present
  3   reason=missing_row    one or more required rows absent
  5   reason=no_table       input has no Reviewer Lift table / is empty
  64  usage / argument error
USAGE
}

schema_path="$DEFAULT_SCHEMA"
input_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema) schema_path="${2:-}"; shift 2 ;;
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
SCHEMA_PATH="$schema_path" INPUT_TEXT="$input_text" node <<'NODE'
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
  present.add(field.toLowerCase());
}

if (!sawTableRow) {
  failNoTable('detail=no_lift_table_rows');
}

const missing = required.filter((r) => !present.has(r.toLowerCase()));
if (missing.length > 0) {
  failMissing(missing);
}

process.exit(0);
NODE
