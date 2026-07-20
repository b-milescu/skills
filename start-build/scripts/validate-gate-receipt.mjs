import { readFileSync } from "node:fs";
import yaml from "js-yaml";

const requiredFlags = [
  "--receipt",
  "--review-packet",
  "--mr-iid",
  "--issue-iid",
  "--reviewed-sha",
  "--gate-receipt-note-id",
  "--gate-command",
  "--gate-policy-ref",
];
const unsafeControl = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/;

function fail(message) {
  console.error(`gate-receipt validation failed: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  if (argv.length % 2 !== 0) fail("expected flag/value pairs");
  const args = new Map();
  for (let index = 0; index < argv.length; index += 2) {
    const flag = argv[index];
    const value = argv[index + 1];
    if (!requiredFlags.includes(flag) || !value || args.has(flag)) fail("invalid arguments");
    args.set(flag, value);
  }
  for (const flag of requiredFlags) if (!args.has(flag)) fail(`missing ${flag}`);
  return args;
}

function readSafe(path, label) {
  let body;
  try {
    body = readFileSync(path, "utf8");
  } catch {
    fail(`cannot read ${label}`);
  }
  if (unsafeControl.test(body)) fail(`${label} contains unsafe control characters`);
  return body;
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim() !== "";
}

function requireString(object, field) {
  if (!isNonEmptyString(object[field])) fail(`invalid gate_receipt.${field}`);
  return object[field];
}

function isAbsolutePortable(path) {
  return path.startsWith("/") || /^[A-Za-z]:[\\/]/.test(path) || /^(?:\\\\|\/\/)[^\\/]+[\\/][^\\/]+/.test(path);
}

function validateReceipt(body, expected) {
  let document;
  try {
    document = yaml.load(body, { schema: yaml.JSON_SCHEMA });
  } catch {
    fail("invalid receipt YAML");
  }
  if (!isObject(document) || !isObject(document.gate_receipt)) fail("missing gate_receipt object");

  const receipt = document.gate_receipt;
  const required = [
    "kind", "version", "owner", "mr_iid", "issue_iid", "checkout_path", "checkout_sha",
    "status_before", "status_after", "command", "result", "summary", "preflight_checks", "evidence",
  ];
  for (const field of required) if (!(field in receipt)) fail(`missing gate_receipt.${field}`);

  const exact = {
    kind: "gate-receipt",
    version: "1",
    owner: "parent",
    mr_iid: expected.mrIid,
    issue_iid: expected.issueIid,
    checkout_sha: expected.reviewedSha,
    status_before: "draft",
    status_after: "ready",
    command: expected.gateCommand,
    result: "PASS",
  };
  for (const [field, value] of Object.entries(exact)) {
    if (receipt[field] !== value) fail(`invalid gate_receipt.${field}`);
  }

  if (!isAbsolutePortable(requireString(receipt, "checkout_path"))) fail("gate_receipt.checkout_path must be absolute");
  requireString(receipt, "summary");

  if (!Array.isArray(receipt.preflight_checks) || receipt.preflight_checks.length < 2) fail("invalid gate_receipt.preflight_checks");
  const preflight = new Map();
  for (const row of receipt.preflight_checks) {
    if (!isObject(row)) fail("invalid preflight row");
    for (const field of ["name", "command", "result", "summary"]) requireString(row, field);
    if (row.result !== "PASS" || preflight.has(row.name)) fail("invalid preflight result");
    preflight.set(row.name, row);
  }
  for (const name of ["clean-status-before", "tracked-files-unchanged-after"]) {
    const row = preflight.get(name);
    if (!row || row.command !== "git status --porcelain") fail(`missing valid ${name} preflight`);
  }

  if (!Array.isArray(receipt.evidence) || receipt.evidence.length === 0) fail("invalid gate_receipt.evidence");
  let hasLocalGate = false;
  for (const row of receipt.evidence) {
    if (!isObject(row)) fail("invalid evidence row");
    for (const field of ["tier", "kind", "source", "summary"]) requireString(row, field);
    if (!/^tier-[12]$/.test(row.tier)) fail("invalid evidence tier");
    if (row.kind === "local-gate") hasLocalGate = true;
  }
  if (!hasLocalGate) fail("missing local-gate evidence");

  if ("observed_at" in receipt) {
    const observed = requireString(receipt, "observed_at");
    if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(observed) || Number.isNaN(Date.parse(observed))) {
      fail("invalid gate_receipt.observed_at");
    }
  }
}

function tableRows(body) {
  const begin = "<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->";
  const end = "<!-- REVIEWER-LIFT-SCHEMA:END -->";
  const first = body.indexOf(begin);
  const last = body.indexOf(end);
  if (first < 0 || last <= first || body.indexOf(begin, first + begin.length) >= 0 || body.indexOf(end, last + end.length) >= 0) {
    fail("invalid Reviewer Lift block");
  }

  const rows = new Map();
  for (const line of body.slice(first + begin.length, last).split(/\r?\n/)) {
    const match = line.match(/^\|\s*([^|]+?)\s*\|\s*(.*?)\s*\|$/);
    if (!match || match[1] === "Field" || /^-+$/.test(match[1])) continue;
    if (rows.has(match[1])) fail("duplicate Reviewer Lift row");
    rows.set(match[1], match[2]);
  }
  return rows;
}

function containsSha(value, sha) {
  return new RegExp(`(?:^|[^0-9a-f])${sha}(?:$|[^0-9a-f])`, "i").test(value);
}

function validateLift(body, expected) {
  const rows = tableRows(body);
  const names = ["Reviewed SHA", "Gate coverage rationale", "CI pipeline", "Local gate", "Delta since last ready push"];
  for (const name of names) if (!isNonEmptyString(rows.get(name))) fail(`missing Reviewer Lift ${name}`);

  if (rows.get("Reviewed SHA").trim() !== `\`${expected.reviewedSha}\``) fail("Reviewer Lift Reviewed SHA is stale");

  const rationale = rows.get("Gate coverage rationale");
  for (const value of [expected.gatePolicy, expected.gateCommand, "required CI jobs", "locally covered jobs", "unmapped CI-only jobs"]) {
    if (!rationale.includes(value)) fail("Reviewer Lift gate coverage rationale is incomplete");
  }

  if (!containsSha(rows.get("CI pipeline"), expected.reviewedSha)) fail("Reviewer Lift CI pointer is stale");

  const localGate = rows.get("Local gate");
  const pointerTokens = localGate.match(/\/merge_requests\/[^\s|)>,.;`]+/g) ?? [];
  const pointer = pointerTokens.length === 1 && pointerTokens[0].match(/^\/merge_requests\/(\d+)#note_(\d+)$/);
  const contradictory = /\b(?:FAIL|pending|not-run|N\/A)\b/i.test(localGate) || (localGate.match(/Gate Receipt/gi) ?? []).length !== 1;
  if (!/\bPASS\b/.test(localGate) || contradictory || !localGate.includes(expected.gateCommand) || !pointer || pointer[1] !== expected.mrIid || pointer[2] !== expected.receiptNoteId) {
    fail("Reviewer Lift local gate or Gate Receipt pointer is stale");
  }

  const delta = rows.get("Delta since last ready push");
  if (!/^N\/A before ready$/i.test(delta.trim()) && (!containsSha(delta, expected.reviewedSha) || /pending/i.test(delta))) {
    fail("Reviewer Lift delta is stale");
  }
}

const args = parseArgs(process.argv.slice(2));
const expected = {
  mrIid: args.get("--mr-iid"),
  issueIid: args.get("--issue-iid"),
  reviewedSha: args.get("--reviewed-sha").toLowerCase(),
  receiptNoteId: args.get("--gate-receipt-note-id"),
  gateCommand: args.get("--gate-command"),
  gatePolicy: args.get("--gate-policy-ref"),
};
if (!/^\d+$/.test(expected.mrIid) || !/^\d+$/.test(expected.issueIid) || !/^[0-9a-f]{40}$/.test(expected.reviewedSha) || !/^\d+$/.test(expected.receiptNoteId)) fail("invalid expected binding");
for (const value of Object.values(expected)) if (unsafeControl.test(value)) fail("expected binding contains unsafe control characters");

validateReceipt(readSafe(args.get("--receipt"), "receipt"), expected);
validateLift(readSafe(args.get("--review-packet"), "review packet"), expected);
console.log("gate-receipt validation: PASS");
