import { accessSync, constants, readFileSync } from "node:fs";
import yaml from "./vendor/js-yaml.mjs";

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
  if (!["lift-only", "pre-post", "post-note"].includes(mode)) fail("invalid --mode");
  if (mode === "lift-only") {
    if (!args.has("--review-packet")) fail("missing --review-packet");
    if ([...commonFlags, "--gate-receipt-locator", "--gate-policy-ref"].some((flag) => args.has(flag))) fail("receipt binding flags are invalid in lift-only mode");
    return { args, mode, owner };
  }
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
  // Pre-post may lint the candidate Lift (--review-packet); the receipt pointer
  // and policy binding exist only after the note is posted (issue #503).
  if (owner === "parent" && mode === "pre-post" && ["--gate-receipt-locator", "--gate-policy-ref"].some((flag) => args.has(flag))) {
    fail("--gate-receipt-locator and --gate-policy-ref are post-note flags, invalid in pre-post mode");
  }
  return { args, mode, owner };
}

function readSafe(path, label) {
  let body;
  try {
    body = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(readFileSync(path));
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
    if (!opaque(row.source)) fail("invalid gate_receipt.evidence source");
    if (!/^tier-[12]$/.test(row.tier)) fail("invalid evidence tier");
    if (row.kind === "local-gate") {
      hasLocalGate = true;
      // Issue #490: refuse to publish a receipt claiming a retained local log
      // that is not readable. Native/remote locators (scheme://) keep their
      // documented behavior and are never opened as local paths.
      if (!/[a-z][a-z0-9+.-]*:\/\//i.test(row.source) && isAbsolutePortable(row.source)) {
        try {
          accessSync(row.source, constants.R_OK);
        } catch {
          fail(`gate_receipt.evidence retained local log ${row.source} is not readable; retain and verify the original run's evidence before publication, and if custody failed recover it with explicit original-run provenance — never pass off a replacement run as the historical one`);
        }
      }
    }
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

const liftBegin = "<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->";
const liftEnd = "<!-- REVIEWER-LIFT-SCHEMA:END -->";

function tableRows(body) {
  const first = body.indexOf(liftBegin);
  const last = body.indexOf(liftEnd);
  if (first < 0 || body.indexOf(liftBegin, first + liftBegin.length) >= 0) {
    fail(`Reviewer Lift BEGIN marker must appear exactly once, byte for byte: ${liftBegin}`);
  }
  if (last <= first || body.indexOf(liftEnd, last + liftEnd.length) >= 0) {
    fail(`Reviewer Lift END marker must appear exactly once, after the BEGIN marker: ${liftEnd}`);
  }

  const rows = new Map();
  for (const line of body.slice(first + liftBegin.length, last).split(/\r?\n/)) {
    const match = line.match(/^\|\s*([^|]+?)\s*\|\s*(.*?)\s*\|$/);
    if (!match || match[1] === "Field" || /^-+$/.test(match[1])) continue;
    if (rows.has(match[1])) fail(`Reviewer Lift ${match[1]} row appears more than once`);
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

// Stronger stage validation is separate from presence-only lift validation.
const noteText = String.raw`(?:\s*[—–;(]|\s+-|:)[\s()]*[^\s()].*`;
const naText = new RegExp(`^N/A${noteText}$`, "i");
const safetySurface = /^(?:external-system|credentials|state|migration|gates|locks|deploy|wire-protocol|other(?:\s*\([^()]+\))?)$/;
const acceptanceEntry = new RegExp(String.raw`^[^\s:,\`]+:(?:test|smoke|docs-read|ci|N/A${noteText})$`);
// A commit SHA: a 7-39 hex token with a letter and a digit (so hex-letter words
// like `defaced` are not SHAs), a full 40-hex token, or an all-digit one after
// `sha`/`commit` (a bare all-digit token reads as a pipeline ID).
const ciSha = /\b(?=[0-9a-f]*[a-f])(?=[0-9a-f]*\d)[0-9a-f]{7,39}\b|\b[0-9a-f]{40}\b|\b(?:sha|commit)\s*[:=]?\s*[0-9]{7,40}\b/i;
const identifiedCI = /^evidence=([^;]+);\s*status=([^;]+);\s*commit=([0-9a-f]{40})$/i;
const placeholder = /^(?:pending|unknown|tbd|todo|<[^>]*>|\[[^\]]*\])$/i;
function opaque(value) {
  return isNonEmptyString(value) && !placeholder.test(value.trim());
}
const liftValueForms = [
  ["Review gate", (v) => /^(?:mandatory|bypassed \(human override\))$/.test(v), "`mandatory` or `bypassed (human override)`"],
  ["Transport", opaque, "identified transport evidence (required; no default)"],
  // Post-note mode validates a parent-owned Lift, so the row leads with `parent` (#502 C-1).
  ["Gate owner", (v) => /^parent(?:$|[\s.,;:(—–])/.test(v), "`parent`, optionally followed by the ownership-contract annotation"],
  ["Gate coverage", (v) => v === "exact-candidate-local", "`exact-candidate-local`"],
  ["CI pipeline", (v) => {
    if (naText.test(v)) return true;
    const match = v.match(identifiedCI);
    return !!match && opaque(match[1]) && isNonEmptyString(match[2]);
  }, "`evidence=<opaque>; status=<opaque>; commit=<40-hex SHA>`, or `N/A — <why>`"],
  ["Touched safety surfaces", (v) => /^(?:none|\[\])$/.test(v) || v.split(/,(?![^(]*\))/).every((item) => safetySurface.test(item.trim())),
    "`none`, `[]`, or comma-separated bare tokens from external-system, credentials, state, migration, gates, locks, deploy, wire-protocol, other (optional parenthetical)"],
  // Entries split only at a comma that starts a new `surface:evidence` entry
  // (no space after the colon; a backticked one is split off and refused), so
  // an `N/A — <reason>` may itself contain commas and `, word: text` (#502 C-2).
  ["Acceptance surfaces", (v) => /^(?:none|\[\])$/.test(v) || v.split(/,(?=\s*`?[^\s:,`]+:\S)/).every((entry) => acceptanceEntry.test(entry.trim())),
    "`none`, `[]`, or comma-separated bare `surface:evidence` entries with evidence test, smoke, docs-read, ci, or `N/A — <reason>`"],
  ["Decoupling proof", (v) => /^single (?:MR|PR|change request)$/.test(v) || /^co-running [^;]+;\s*\S.+$/.test(v) && opaque(v.slice(11).split(";")[0]),
    "`single change request`, or `co-running <opaque identifiers>; <Decoupling Contract summary>`"],
  ["Open Questions", (v) => v === "none" || /\bOQ-\d+\b/.test(v), "`none` or a count/list of `OQ-N` IDs"],
  ["Approval authority", (v) => /^(?:default-after-pass|restricted:\s*\S.*)$/.test(v), "`default-after-pass` or `restricted: <source/reason>`"],
  ["Finish authority", (v) => /^(?:none — requires explicit human\/parent instruction|approval-only|reviewer may merge|queue auto-merge|human release|project default:\s*\S.*)$/.test(v.replace(/^"(.*)"$/, "$1")),
    "`none — requires explicit human/parent instruction`, `approval-only`, `reviewer may merge`, `queue auto-merge`, `human release`, or `project default: <policy>`"],
];

function offSchemaLiftRows(rows) {
  const refused = [];
  for (const [name, accepts, forms, optional] of liftValueForms) {
    const cell = rows.get(name);
    if (cell === undefined && optional) continue;
    const value = (cell ?? "").trim().replace(/^`([^`]*)`$/, "$1").trim();
    if (!accepts(value)) refused.push(`- Reviewer Lift ${name} is off-schema; accepted: ${forms}`);
  }
  return refused;
}

const fullLiftRows = [
  "Reviewed SHA", "Finding bindings", "Review gate", "Transport",
  "Gate owner", "Gate coverage", "Gate coverage rationale", "CI pipeline", "Local gate",
  "RED", "GREEN", "Changed paths", "Touched safety surfaces", "Acceptance surfaces",
  "Decoupling proof", "Reviewer Focus", "Open Questions", "Approval authority",
  "Approval authority source", "Finish authority", "Finish authority source",
  "Delta since last ready push",
];

function liftPresence(body) {
  const rows = tableRows(body);
  for (const name of fullLiftRows) {
    const value = (rows.get(name) ?? "").trim().replace(/^(`+)([^`]*)\1$/, "$2").trim();
    if (!isNonEmptyString(value)) fail(`missing Reviewer Lift ${name}`);
  }
  return rows;
}

// Receipt-independent Lift checks, shared by pre-post (before the receipt note
// is posted) and post-note: markers, unique rows, required rows, closed sets.
function liftStructure(body) {
  const rows = liftPresence(body);
  const refused = offSchemaLiftRows(rows);
  if (refused.length > 0) fail(`Reviewer Lift values are off-schema per start-build/templates/reviewer-lift-schema.md:\n${refused.join("\n")}`);
  return rows;
}

// `pending` makes the Delta stale only inside a `;`/`<br>` clause that starts
// with it (a bare or annotated slot such as `pending — parent-owned`), or names
// the gate, its command, a rerun, a receipt, a head, a rebind, a SHA/commit
// (word or token), or an arrow; prose such as "the bound-or-pending wording"
// is not a pointer (issues #503, #505).
const deltaPointer = /\bgate\b|\bre-?run(?:s|n?ing)?\b|\breceipts?\b|\bshas?\b|\bcommits?\b|\bheads?\b|\bre-?bind(?:ing)?\b|\bre-?bound\b|→|->/i;

function pendingPointer(clause, gateCommand) {
  if (!/pending/i.test(clause)) return false;
  return /^\W*pending\b/i.test(clause) || deltaPointer.test(clause) || ciSha.test(clause) || clause.includes(gateCommand);
}

function validateLift(body, expected) {
  const rows = liftStructure(body);
  const reviewedSha = rows.get("Reviewed SHA").trim();
  if (reviewedSha !== expected.reviewedCommit && reviewedSha !== `\`${expected.reviewedCommit}\``) fail("Reviewer Lift Reviewed SHA is stale");

  const rationale = rows.get("Gate coverage rationale");
  for (const value of [expected.gatePolicy, expected.gateCommand, expected.reviewedCommit, "exact-candidate-local"]) {
    if (!rationale.includes(value)) fail("Reviewer Lift gate coverage rationale is incomplete");
  }
  // Bind the sole terminal result field, not PASS/receipt mentions elsewhere.
  const result = rationale.trim().replace(/^`([^`]*)`$/, "$1")
    .match(/(?:^|;)\s*result:\s*PASS — Gate Receipt:\s*(`[^`]+`|[^;`]+)$/);
  const rationaleLocator = result?.[1].trim().replace(/^`([^`]*)`$/, "$1") ?? "";
  if ((rationale.match(/\bresult:/g) ?? []).length !== 1 || !opaque(rationaleLocator) || rationaleLocator !== expected.receiptLocator) {
    fail("Reviewer Lift gate coverage rationale needs one terminal PASS result with the exact Gate Receipt pointer");
  }

  const localGate = rows.get("Local gate");
  const pointers = [...localGate.matchAll(/Gate Receipt:\s*(`[^`]+`|[^;]+)(?=;|$)/g)];
  const locator = pointers.length === 1 ? pointers[0][1].trim().replace(/^`([^`]*)`$/, "$1") : "";
  if (!/\bPASS\b/.test(localGate)) fail("Reviewer Lift local gate does not record PASS");
  if (/(?<!\d\s)\b(?:FAIL|pending|not-run|N\/A)\b/i.test(localGate)) fail("Reviewer Lift local gate carries a contradictory FAIL/pending/not-run/N/A token");
  if ((localGate.match(/Gate Receipt/gi) ?? []).length !== 1) fail("Reviewer Lift local gate needs exactly one Gate Receipt pointer");
  if (!localGate.includes(expected.gateCommand)) fail(`Reviewer Lift local gate does not name the gate command ${expected.gateCommand}`);
  if (!opaque(locator) || locator !== expected.receiptLocator) fail("Gate Receipt pointer mismatch: expected one exact identified receipt locator");

  const delta = rows.get("Delta since last ready push");
  if (!/^(?:N\/A before ready|`N\/A before ready`)$/i.test(delta.trim())) {
    if (delta.split(/;|<br\s*\/?>/i).some((clause) => pendingPointer(clause, expected.gateCommand))) {
      fail("Reviewer Lift delta is stale: Delta since last ready push leaves a gate rerun, Gate Receipt, or commit pending");
    }
    const hasFull = containsCommit(delta, expected.reviewedCommit);
    if (!hasFull && !namesShortReviewedCommit(delta, expected.reviewedCommit)) {
      fail("Reviewer Lift delta is stale: Delta since last ready push does not name the reviewed commit");
    }
    if (!hasFull) fail("Reviewer Lift delta names the reviewed commit in short form; the full 40-hex form is required");
  }
}

const { args, mode, owner } = parseArgs(process.argv.slice(2));
if (mode === "lift-only") {
  liftPresence(readSafe(args.get("--review-packet"), "review packet"));
  console.log("gate-receipt lift-only validation: PASS (presence only; no receipt or native verification)");
  process.exit(0);
}
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
  else if (args.has("--review-packet")) liftStructure(readSafe(args.get("--review-packet"), "review packet"));
  console.log(`gate-receipt ${mode} validation: PASS`);
}
