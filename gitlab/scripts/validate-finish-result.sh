#!/usr/bin/env bash
# Pure-local validator for a finish_result object.
#
# Reads a finish_result JSON from a file argument or stdin, validates it against
# gitlab/reference/finish-result-schema.json, and exits 0 only when every
# required field is present with a correctly enumerated/typed value. Otherwise it
# prints a FINISH_RESULT result=invalid reason=... line to stderr and exits
# non-zero.
#
# Makes NO network call: it only reads the local schema file and the input JSON.
# The schema file is the single source of truth for required fields and enums;
# this script loads them from the schema instead of re-listing them.
#
# Canonical schema: gitlab/reference/finish-result-schema.json
#
# Exit codes:
#   0   valid finish_result
#   3   reason=invalid          input JSON failed required-field / enum / type check
#   5   reason=bad_json         input was not parseable JSON / not a JSON object
#   64  usage / argument error (bad flag, missing/unreadable input or schema)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_SCHEMA="$SCRIPT_DIR/../reference/finish-result-schema.json"

usage() {
  cat <<'USAGE'
Usage: validate-finish-result.sh [--schema <path>] [<finish-result.json>]

Reads a finish_result JSON object from <finish-result.json> or, when no file is
given, from stdin. Validates it against the finish-result schema (default:
gitlab/reference/finish-result-schema.json).

Options:
  --schema <path>   Override the schema path (testing/local use).
  -h, --help        Show this help.

Exit codes:
  0   valid finish_result
  3   reason=invalid    required field missing or enum/type mismatch
  5   reason=bad_json    input is not parseable JSON / not a JSON object
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
      echo "FINISH_RESULT result=invalid reason=unknown_arg arg=$1" >&2
      usage >&2
      exit 64 ;;
    *)
      if [[ -n "$input_path" ]]; then
        echo "FINISH_RESULT result=invalid reason=too_many_args arg=$1" >&2
        exit 64
      fi
      input_path="$1"; shift ;;
  esac
done

if [[ $# -gt 0 ]]; then
  if [[ -n "$input_path" ]]; then
    echo "FINISH_RESULT result=invalid reason=too_many_args arg=$1" >&2
    exit 64
  fi
  input_path="$1"
fi

command -v node >/dev/null 2>&1 || {
  echo "FINISH_RESULT result=invalid reason=node_missing" >&2
  exit 64
}

[[ -f "$schema_path" ]] || {
  echo "FINISH_RESULT result=invalid reason=schema_not_found path=$schema_path" >&2
  exit 64
}

if [[ -n "$input_path" ]]; then
  [[ -f "$input_path" ]] || {
    echo "FINISH_RESULT result=invalid reason=input_not_found path=$input_path" >&2
    exit 64
  }
  input_json="$(cat -- "$input_path")"
else
  input_json="$(cat)"
fi

# All validation logic lives in node for robust JSON parsing and exact
# enum/type comparison. node reads the schema (source of truth) and the input,
# and exits 0 / 3 / 5 with a single diagnostic line on stderr for failures.
SCHEMA_PATH="$schema_path" INPUT_JSON="$input_json" node <<'NODE'
'use strict';

const fs = require('fs');

function failInvalid(reason, extra) {
  const tail = extra ? ' ' + extra : '';
  process.stderr.write(`FINISH_RESULT result=invalid reason=${reason}${tail}\n`);
  process.exit(3);
}

function failBadJson(extra) {
  const tail = extra ? ' ' + extra : '';
  process.stderr.write(`FINISH_RESULT result=invalid reason=bad_json${tail}\n`);
  process.exit(5);
}

let schema;
try {
  schema = JSON.parse(fs.readFileSync(process.env.SCHEMA_PATH, 'utf8'));
} catch (e) {
  process.stderr.write('FINISH_RESULT result=invalid reason=schema_unreadable\n');
  process.exit(64);
}

const raw = process.env.INPUT_JSON;
if (raw === undefined || raw.trim() === '') {
  failBadJson('detail=empty_input');
}

let obj;
try {
  obj = JSON.parse(raw);
} catch (e) {
  failBadJson('detail=parse_error');
}

if (obj === null || typeof obj !== 'object' || Array.isArray(obj)) {
  failBadJson('detail=not_an_object');
}

const required = Array.isArray(schema.required) ? schema.required : [];
const props = schema.properties || {};

// 1. additionalProperties: reject unknown fields when the schema forbids them.
if (schema.additionalProperties === false) {
  for (const key of Object.keys(obj)) {
    if (!Object.prototype.hasOwnProperty.call(props, key)) {
      failInvalid('unknown_field', `field=${key}`);
    }
  }
}

// 2. required fields must be present.
for (const field of required) {
  if (!Object.prototype.hasOwnProperty.call(obj, field)) {
    failInvalid('missing_field', `field=${field}`);
  }
}

function typeMatches(value, type) {
  switch (type) {
    case 'string': return typeof value === 'string';
    case 'integer': return typeof value === 'number' && Number.isInteger(value);
    case 'number': return typeof value === 'number';
    case 'boolean': return typeof value === 'boolean';
    case 'object': return value !== null && typeof value === 'object' && !Array.isArray(value);
    case 'array': return Array.isArray(value);
    case 'null': return value === null;
    default: return false;
  }
}

// 3. per-field type, enum, pattern, and integer-minimum validation.
for (const [field, spec] of Object.entries(props)) {
  if (!Object.prototype.hasOwnProperty.call(obj, field)) continue; // optional & absent
  const value = obj[field];

  if (spec.type !== undefined) {
    const types = Array.isArray(spec.type) ? spec.type : [spec.type];
    if (!types.some((t) => typeMatches(value, t))) {
      failInvalid('type_mismatch', `field=${field} expected=${types.join('|')}`);
    }
  }

  if (Array.isArray(spec.enum)) {
    const ok = spec.enum.some((allowed) => allowed === value);
    if (!ok) {
      const shown = typeof value === 'string' ? value : JSON.stringify(value);
      failInvalid('enum_mismatch', `field=${field} value=${shown}`);
    }
  }

  if (typeof spec.pattern === 'string' && typeof value === 'string') {
    const re = new RegExp(spec.pattern);
    if (!re.test(value)) {
      failInvalid('pattern_mismatch', `field=${field}`);
    }
  }

  if (spec.type === 'integer' && typeof spec.minimum === 'number') {
    if (typeof value === 'number' && value < spec.minimum) {
      failInvalid('below_minimum', `field=${field} minimum=${spec.minimum}`);
    }
  }
}

process.exit(0);
NODE
