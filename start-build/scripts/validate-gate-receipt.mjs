import { readFileSync } from "node:fs";
import yaml from "js-yaml";

const commonFlags = ["--receipt", "--change-id", "--issue-id", "--reviewed-commit", "--gate-command"];
const postFlags = ["--review-packet", "--gate-receipt-locator", "--gate-policy-ref"];
const allowedFlags = ["--mode", "--owner", ...commonFlags, ...postFlags];
const unsafeControl = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/;
// Preflight command allowlist: the canonical form plus the strictly stronger
// untracked-files=all form, which also fails on untracked residue (issue #449).
const cleanStatusCommands = new Set(["git status --porcelain", "git status --porcelain --untracked-files=all"]);

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
    if (!allowedFlags.includes(flag) || !value || args.has(flag)) fail("invalid arguments");
    args.set(flag, value);
  }
  const owner = args.get("--owner") ?? "parent";
  if (!["parent", "builder"].includes(owner)) fail("invalid --owner");
  const mode = args.get("--mode") ?? "post-note";
  if (!["pre-post", "post-note"].includes(mode)) fail("invalid --mode");
  if (owner === "builder" && mode === "post-note") {
    fail("post-note Reviewer Lift validation is scoped to parent-owned mode; validate builder-owned receipts with --owner builder --mode pre-post");
  }
  const required = owner === "builder"
    ? ["--receipt", "--reviewed-commit", "--gate-command"]
    : mode === "pre-post" ? commonFlags : [...commonFlags, ...postFlags];
  for (const flag of required) if (!args.has(flag)) fail(`missing ${flag}`);
  if (owner === "builder" && ["--change-id", "--issue-id", ...postFlags].some((flag) => args.has(flag))) {
    fail("parent-owned binding flags are invalid in builder mode");
  }
  if (owner === "parent" && mode === "pre-post" && postFlags.some((flag) => args.has(flag))) fail("post-note flags are invalid in pre-post mode");
  return { args, mode, owner };
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
    "kind", "version", "owner", "change_id", "issue_id", "checkout_path", "checkout_commit",
    "status_before", "status_after", "command", "result", "summary", "preflight_checks", "evidence",
  ];
  for (const field of required) if (!(field in receipt)) fail(`missing gate_receipt.${field}`);

  const exact = {
    kind: "gate-receipt",
    version: "1",
    owner: "parent",
    change_id: expected.changeId,
    issue_id: expected.issueId,
    checkout_commit: expected.reviewedCommit,
    status_after: "ready",
    command: expected.gateCommand,
    result: "PASS",
  };
  for (const [field, value] of Object.entries(exact)) {
    if (receipt[field] !== value) fail(`invalid gate_receipt.${field}`);
  }
  // A re-gate of an already-ready change request truthfully records "ready" (issue #449).
  if (receipt.status_before !== "draft" && receipt.status_before !== "ready") fail("invalid gate_receipt.status_before");
  if (Object.keys(receipt).some((field) => /waiver/i.test(field))) fail("Gate Receipt cannot waive tracked-file changes");

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
    if (!row || !cleanStatusCommands.has(row.command)) fail(`missing valid ${name} preflight`);
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

// Builder-owned receipt (start-build/reference/parent-owned-gate.md#builder-owned-gate-receipt):
// anchor-form gate_receipt block with kind/version/owner/checkout_commit/command/result only.
function validateBuilderReceipt(body, expected) {
  if (/^\s*gate_receipt:\s*&\S/m.test(body)) {
    fail("gate_receipt must be a standalone mapping anchor, not a YAML alias anchor (&gate_receipt)");
  }
  let document;
  try {
    document = yaml.load(body, { schema: yaml.JSON_SCHEMA });
  } catch {
    fail("invalid receipt YAML");
  }
  if (!isObject(document) || !isObject(document.gate_receipt)) fail("missing gate_receipt object");

  const receipt = document.gate_receipt;
  for (const field of ["kind", "version", "owner", "checkout_commit", "command", "result"]) {
    if (!isNonEmptyString(receipt[field])) fail(`invalid gate_receipt.${field}`);
  }
  const exact = {
    kind: "gate-receipt",
    version: "1",
    owner: "builder",
    checkout_commit: expected.reviewedCommit,
    command: expected.gateCommand,
    result: "PASS",
  };
  for (const [field, value] of Object.entries(exact)) {
    if (receipt[field] !== value) fail(`invalid gate_receipt.${field}`);
  }
  const allowed = new Set(["kind", "version", "owner", "checkout_commit", "command", "result"]);
  for (const field of Object.keys(receipt)) {
    if (!allowed.has(field)) fail(`unexpected gate_receipt.${field}`);
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

function containsCommit(value, commit) {
  return new RegExp(`(?:^|[^0-9a-f])${commit}(?:$|[^0-9a-f])`, "i").test(value);
}

function namesShortReviewedCommit(value, commit) {
  return [...value.matchAll(/(?:^|[^0-9a-f])([0-9a-f]{7,39})(?=$|[^0-9a-f])/gi)]
    .some((match) => commit.startsWith(match[1].toLowerCase()));
}

function validateLift(body, expected) {
  const rows = tableRows(body);
  const names = ["Reviewed SHA", "Gate coverage rationale", "CI pipeline", "Local gate", "Delta since last ready push"];
  for (const name of names) if (!isNonEmptyString(rows.get(name))) fail(`missing Reviewer Lift ${name}`);

  const reviewedSha = rows.get("Reviewed SHA").trim();
  if (reviewedSha !== expected.reviewedCommit && reviewedSha !== `\`${expected.reviewedCommit}\``) fail("Reviewer Lift Reviewed SHA is stale");

  const rationale = rows.get("Gate coverage rationale");
  for (const value of [expected.gatePolicy, expected.gateCommand, expected.reviewedCommit, "exact-candidate-local"]) {
    if (!rationale.includes(value)) fail("Reviewer Lift gate coverage rationale is incomplete");
  }

  const localGate = rows.get("Local gate");
  const locatorTokens = localGate.match(/\b(?:https?:\/\/|[a-z][a-z0-9+.-]*:\/\/)[^\s|)>,;`]+/gi) ?? [];
  // The pointer binding is the row's SOLE locator token: zero or several tokens
  // collapse to "" and never match the expected argument (issue #458).
  const locator = locatorTokens.length === 1 ? locatorTokens[0] : "";
  if (!/\bPASS\b/.test(localGate)) fail("Reviewer Lift local gate does not record PASS");
  if (/(?<!\d\s)\b(?:FAIL|pending|not-run|N\/A)\b/i.test(localGate)) fail("Reviewer Lift local gate carries a contradictory FAIL/pending/not-run/N/A token");
  if ((localGate.match(/Gate Receipt/gi) ?? []).length !== 1) fail("Reviewer Lift local gate needs exactly one Gate Receipt pointer");
  if (!localGate.includes(expected.gateCommand)) fail(`Reviewer Lift local gate does not name the gate command ${expected.gateCommand}`);
  if (locator !== expected.receiptLocator) {
    const observed = locator || `none — the row carries ${locatorTokens.length} locator tokens: ${locatorTokens.join(", ") || "(none)"}`;
    fail(`Gate Receipt pointer mismatch: --gate-receipt-locator ${expected.receiptLocator} vs Local gate sole locator token ${observed}`);
  }

  const delta = rows.get("Delta since last ready push");
  if (!/^(?:N\/A before ready|`N\/A before ready`)$/i.test(delta.trim())) {
    const hasFull = containsCommit(delta, expected.reviewedCommit);
    if (/pending/i.test(delta) || (!hasFull && !namesShortReviewedCommit(delta, expected.reviewedCommit))) {
      fail("Reviewer Lift delta is stale");
    }
    if (!hasFull) fail("Reviewer Lift delta names the reviewed commit in short form; the full 40-hex form is required");
  }
}

const { args, mode, owner } = parseArgs(process.argv.slice(2));
const expected = {
  changeId: args.get("--change-id"),
  issueId: args.get("--issue-id"),
  reviewedCommit: args.get("--reviewed-commit").toLowerCase(),
  gateCommand: args.get("--gate-command"),
  gatePolicy: args.get("--gate-policy-ref"),
  receiptLocator: args.get("--gate-receipt-locator"),
};

if (owner === "builder") {
  if (!/^[0-9a-f]{40}$/.test(expected.reviewedCommit) || !isNonEmptyString(expected.gateCommand)) {
    fail("invalid expected binding");
  }
  for (const value of [expected.reviewedCommit, expected.gateCommand]) {
    if (unsafeControl.test(value)) fail("expected binding contains unsafe control characters");
  }
  validateBuilderReceipt(readSafe(args.get("--receipt"), "receipt"), expected);
  console.log(`gate-receipt ${mode} (owner: builder) validation: PASS`);
} else {
  if (![expected.changeId, expected.issueId].every(isNonEmptyString) || !/^[0-9a-f]{40}$/.test(expected.reviewedCommit)) {
    fail("invalid expected binding");
  }
  if (mode === "post-note" && !isNonEmptyString(expected.receiptLocator)) fail("invalid expected binding");
  for (const value of Object.values(expected)) if (value && unsafeControl.test(value)) fail("expected binding contains unsafe control characters");

  validateReceipt(readSafe(args.get("--receipt"), "receipt"), expected);
  if (mode === "post-note") validateLift(readSafe(args.get("--review-packet"), "review packet"), expected);
  console.log(`gate-receipt ${mode} validation: PASS`);
}
