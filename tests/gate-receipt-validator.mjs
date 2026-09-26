// Focus: Cross-platform pure-local Gate Receipt validator: accepts the
// canonical exact-SHA receipt; rejects
// missing/malformed/stale/prose-only/unsafe receipt and Reviewer Lift evidence
// without body leakage; rejects changed tracked files and any tracked-change
// waiver; proves Windows/UNC path plus CRLF handling; enforces pre-ready
// ordering; refuses off-schema values in closed-set Reviewer Lift rows, row by
// row, against frozen live midnight packets (!534 refused, !585 accepted); and
// keeps build/review cards and generated templates pointed at the canonical
// helper.
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import yaml from "js-yaml";

const root = resolve(import.meta.dirname, "..");
const validator = join(root, "start-build/scripts/validate-gate-receipt.mjs");
const work = mkdtempSync(join(tmpdir(), "gate-receipt-"));
const commit = "1".repeat(40);
const locator = "ado://organization/project/repository/pullRequest/42/comment/9001";
const expected = {
  changeId: "PR-42",
  issueId: "WI-381",
  reviewedCommit: commit,
  gateCommand: "npm run check",
  gatePolicy: "docs/agents/check-gate.md#gate-coverage-for-ready-handoff",
  receiptLocator: locator,
};

function receipt(overrides = {}) {
  return { gate_receipt: {
    kind: "gate-receipt", version: "1", owner: "parent",
    change_id: expected.changeId, issue_id: expected.issueId,
    checkout_path: "/tmp/worktree", checkout_commit: commit,
    status_before: "draft", status_after: "ready",
    command: expected.gateCommand, result: "PASS", summary: "gate passed",
    preflight_checks: [
      { name: "clean-status-before", command: "git status --porcelain", result: "PASS", summary: "empty" },
      { name: "tracked-files-unchanged-after", command: "git status --porcelain", result: "PASS", summary: "empty" },
    ],
    evidence: [{ tier: "tier-1", kind: "local-gate", source: "artifact://gate", summary: "exact candidate" }],
    ...overrides,
  } };
}

function preflights(command) {
  return ["clean-status-before", "tracked-files-unchanged-after"].map((name) => ({
    name, command, result: "PASS", summary: "empty",
  }));
}

function builderReceipt(overrides = {}) {
  return { gate_receipt: {
    kind: "gate-receipt", version: "1", owner: "builder",
    checkout_commit: commit,
    command: expected.gateCommand, result: "PASS",
    ...overrides,
  } };
}

function packet(localGate = `PASS — ${expected.gateCommand} — Gate Receipt: ${locator}`, rationale = `${expected.gatePolicy}; exact-candidate-local; command ${expected.gateCommand}; candidate ${commit}; result PASS`) {
  return `<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | \`${commit}\` |
| Finding bindings | \`none\` |
| Review gate | mandatory |
| Change tier | moderate — validator change |
| Transport | mcp |
| Gate owner | parent |
| Gate coverage | exact-candidate-local |
| Gate coverage rationale | ${rationale} |
| CI pipeline | N/A — unavailable |
| Local gate | ${localGate} |
| Touched safety surfaces | gates |
| Acceptance surfaces | none |
| Decoupling proof | single MR |
| Open Questions | none |
| Approval authority | default-after-pass |
| Finish authority | none — requires explicit human/parent instruction |
| Delta since last ready push | N/A before ready |
<!-- REVIEWER-LIFT-SCHEMA:END -->`;
}

function withRow(name, value, body = packet()) {
  const row = new RegExp(`^\\| ${name} \\| .* \\|$`, "m");
  assert.match(body, row, `packet carries a ${name} row`);
  return value === undefined ? body.replace(new RegExp(`${row.source}\\n`, "m"), "") : body.replace(row, `| ${name} | ${value} |`);
}

function liftWithSha(sha) {
  return packet().replace(`| Reviewed SHA | \`${commit}\` |`, `| Reviewed SHA | ${sha} |`);
}

function run({ document = receipt(), reviewPacket = packet(), locatorValue = locator, mode = "post-note", bind = {} } = {}) {
  const { reviewedCommit = commit, gateCommand = expected.gateCommand, gatePolicy = expected.gatePolicy } = bind;
  const receiptPath = join(work, "receipt.yml");
  const packetPath = join(work, "packet.md");
  writeFileSync(receiptPath, yaml.dump(document));
  writeFileSync(packetPath, reviewPacket);
  const argv = ["--receipt", receiptPath,
    "--change-id", expected.changeId, "--issue-id", expected.issueId,
    "--reviewed-commit", reviewedCommit, "--gate-command", gateCommand];
  if (mode === "post-note") {
    argv.push("--review-packet", packetPath,
      "--gate-policy-ref", gatePolicy,
      "--gate-receipt-locator", locatorValue);
  } else {
    argv.unshift("--mode", mode);
  }
  return spawnSync(process.execPath, [validator, ...argv], { encoding: "utf8" });
}

// A frozen live midnight Review Packet, validated against a receipt bound to
// the packet's own candidate, command, policy, and Local gate locator.
function runMidnight(fixture, { reviewedCommit, note }) {
  const gateCommand = "bun tools/isolated-gate/index.ts";
  return run({
    document: receipt({ checkout_commit: reviewedCommit, command: gateCommand }),
    reviewPacket: readFileSync(join(root, "tests/fixtures/reviewer-lift-values", fixture), "utf8"),
    locatorValue: `https://gitlab.example.com/group/project/-/merge_requests/${note}`,
    bind: { reviewedCommit, gateCommand, gatePolicy: "docs/agents/check-gate.md" },
  });
}

function offSchemaRows(stderr) {
  return [...stderr.matchAll(/^- Reviewer Lift (.+?) is off-schema; accepted: /gm)].map((match) => match[1]);
}

function runBuilder({ document = builderReceipt(), rawBody, mode = "pre-post", extraFlags = [] } = {}) {
  const receiptPath = join(work, "builder-receipt.yml");
  writeFileSync(receiptPath, rawBody ?? yaml.dump(document));
  const argv = ["--owner", "builder", "--mode", mode, "--receipt", receiptPath,
    "--reviewed-commit", commit, "--gate-command", expected.gateCommand, ...extraFlags];
  return spawnSync(process.execPath, [validator, ...argv], { encoding: "utf8" });
}

try {
  assert.equal(run().status, 0, "opaque Azure DevOps-style IDs and locator pass");
  assert.equal(run({ reviewPacket: liftWithSha(commit) }).status, 0, "bare 40-hex Reviewed SHA passes");
  assert.equal(run({ reviewPacket: packet() }).status, 0, "code-span Reviewed SHA passes");
  assert.notEqual(run({ reviewPacket: liftWithSha("2".repeat(40)) }).status, 0, "wrong Reviewed SHA fails");
  assert.notEqual(run({ reviewPacket: liftWithSha(`${commit} extra`) }).status, 0, "mixed extra text around Reviewed SHA fails");
  assert.notEqual(run({ reviewPacket: liftWithSha(`\`${commit}\` extra`) }).status, 0, "code-span plus extra text fails");
  assert.notEqual(run({ reviewPacket: liftWithSha("") }).status, 0, "empty Reviewed SHA fails");
  assert.notEqual(run({ reviewPacket: packet().replace(`| Reviewed SHA | \`${commit}\` |\n`, "") }).status, 0, "missing Reviewed SHA fails");
  const schema = readFileSync(join(root, "start-build/templates/reviewer-lift-schema.md"), "utf8");
  assert.match(schema, /\| Reviewed SHA \| MR head SHA at ready-marking; update on every post-ready push before asking for review\. \|/, "schema does not require a fenced Reviewed SHA");
  assert.notEqual(run({ document: receipt({ checkout_commit: "2".repeat(40) }) }).status, 0, "stale commit fails");
  assert.notEqual(run({ document: receipt({ change_id: "" }) }).status, 0, "empty opaque ID fails");
  assert.notEqual(run({ document: receipt({
    preflight_checks: [
      { name: "clean-status-before", command: "git status --porcelain", result: "PASS", summary: "empty" },
      { name: "tracked-files-unchanged-after", command: "git status --porcelain", result: "FAIL", summary: "tracked files changed" },
    ],
  }) }).status, 0, "tracked file changes fail the Receipt");
  assert.notEqual(run({ document: receipt({ tracked_changes_waiver: "accepted" }) }).status, 0, "tracked file changes cannot be waived");
  assert.equal(run({ document: receipt({ status_before: "ready" }) }).status, 0, "re-gate of an already-ready change request may record status_before: ready");
  assert.notEqual(run({ document: receipt({ status_before: "merged" }) }).status, 0, "genuinely wrong status_before still fails");
  assert.equal(run({ document: receipt({ preflight_checks: preflights("git status --porcelain --untracked-files=all") }) }).status, 0, "stronger --untracked-files=all preflight accepted");
  assert.notEqual(run({ document: receipt({ preflight_checks: preflights("git status") }) }).status, 0, "weaker preflight without --porcelain fails");
  assert.notEqual(run({ document: receipt({ preflight_checks: preflights("git status --porcelain --untracked-files=all; echo anything") }) }).status, 0, "preflight command is not widened to any string");
  assert.equal(runBuilder().status, 0, "valid builder-owned anchor receipt accepted in pre-post mode");
  assert.notEqual(runBuilder({ document: builderReceipt({ owner: "parent" }) }).status, 0, "wrong owner fails in builder mode");
  assert.notEqual(runBuilder({ document: builderReceipt({ command: undefined }) }).status, 0, "malformed builder receipt missing command fails");
  assert.notEqual(runBuilder({ document: builderReceipt({ checkout_commit: "2".repeat(40) }) }).status, 0, "stale builder receipt commit fails");
  assert.notEqual(runBuilder({ rawBody: "gate_receipt: &gate_receipt\n  kind: gate-receipt\n" }).status, 0, "YAML alias anchor form fails");
  assert.notEqual(runBuilder({ document: builderReceipt({ change_id: expected.changeId }) }).status, 0, "builder receipt with parent-only extra field fails");
  assert.notEqual(runBuilder({ mode: "post-note", extraFlags: ["--review-packet", join(work, "packet.md")] }).status, 0, "post-note Lift validation stays scoped to parent-owned mode");

  // Issue #453: parent-owned rationale form is documented and validateLift
  // accepts a row written exactly to that example.
  const parentOwnedForm = "Policy <ref>; command <cmd>; candidate <sha>; coverage exact-candidate-local; result: <not-run — parent-owned \\| PASS — Gate Receipt <locator>>";
  const schemaForRationale = readFileSync(join(root, "start-build/templates/reviewer-lift-schema.md"), "utf8");
  assert.ok(schemaForRationale.includes(parentOwnedForm), "schema documents parent-owned Gate coverage rationale form");
  for (const copy of [
    "start-build/templates/review-packet.md",
    "start-build/templates/review-packet-compact.md",
  ]) {
    assert.ok(readFileSync(join(root, copy), "utf8").includes(parentOwnedForm), `${copy} pastes the documented parent-owned rationale form`);
  }
  const filledForm = `Policy ${expected.gatePolicy}; command ${expected.gateCommand}; candidate ${commit}; coverage exact-candidate-local; result: PASS — Gate Receipt ${locator}`;
  assert.equal(run({ reviewPacket: packet(undefined, filledForm) }).status, 0, "documented parent-owned rationale example passes validateLift");
  assert.notEqual(
    run({ reviewPacket: packet(undefined, `Policy ${expected.gatePolicy}; command ${expected.gateCommand}; candidate ${commit}; result: PASS — Gate Receipt ${locator}`) }).status,
    0,
    "policy/command/commit without exact-candidate-local fail",
  );
  const parentOwnedGuide = readFileSync(join(root, "start-build/reference/parent-owned-gate.md"), "utf8");
  assert.ok(parentOwnedGuide.includes("rebind both `Local gate` and `Gate coverage rationale`"), "parent-owned-gate rebinds both Local gate and Gate coverage rationale");
  assert.ok(parentOwnedGuide.includes("replace only the `result:` token"), "parent-owned-gate names the single result: token to replace");

  // Issue #455: numeric fail counts and one surrounding code span on N/A before ready.
  const countGate = `PASS — ${expected.gateCommand} — bun test 1913 pass, 1 skip, 0 fail — Gate Receipt: ${locator}`;
  assert.equal(run({ reviewPacket: packet(countGate) }).status, 0, "0 fail count in Local gate passes");
  assert.equal(
    run({ reviewPacket: packet(`PASS — ${expected.gateCommand} — 1 fail — Gate Receipt: ${locator}`) }).status,
    0,
    "1 fail count in Local gate passes",
  );
  assert.notEqual(
    run({ reviewPacket: packet(`PASS — ${expected.gateCommand} —  FAIL  — Gate Receipt: ${locator}`) }).status,
    0,
    "standalone FAIL in Local gate still fails",
  );
  const withDelta = (delta) => packet().replace("| Delta since last ready push | N/A before ready |", `| Delta since last ready push | ${delta} |`);
  assert.equal(run({ reviewPacket: withDelta("`N/A before ready`") }).status, 0, "backticked N/A before ready passes");
  assert.notEqual(
    run({ reviewPacket: withDelta("`" + "2".repeat(40) + " -> " + "3".repeat(40) + ", files, gate, no`") }).status,
    0,
    "backticked delta naming a different commit still fails",
  );
  // Issue #489: short-form reviewed SHA is a form error, not stale.
  const shortSha = commit.slice(0, 7);
  const shortDelta = run({ reviewPacket: withDelta(`${shortSha} -> files, gate, no`) });
  assert.notEqual(shortDelta.status, 0, "short-form delta fails");
  assert.match(shortDelta.stderr, /full 40-hex form is required/, "short-form names the 40-hex requirement");
  assert.doesNotMatch(shortDelta.stderr, /delta is stale/, "short-form is not reported as stale");
  const staleDelta = run({ reviewPacket: withDelta("2".repeat(40) + " -> files, gate, no") });
  assert.notEqual(staleDelta.status, 0, "different-commit delta fails");
  assert.match(staleDelta.stderr, /Reviewer Lift delta is stale/, "different commit keeps the stale message");
  assert.doesNotMatch(staleDelta.stderr, /full 40-hex form is required/, "stale is not the short-form message");
  const pendingDelta = run({ reviewPacket: withDelta("pending") });
  assert.notEqual(pendingDelta.status, 0, "pending delta fails");
  assert.match(pendingDelta.stderr, /Reviewer Lift delta is stale/, "pending keeps the stale message");
  const fullDelta = run({ reviewPacket: withDelta(`${commit} -> files, gate, no`) });
  assert.equal(fullDelta.status, 0, "full 40-hex delta still passes");

  // Doc/validator agreement (issue #450): the example a parent copies must teach
  // exactly the accepted status_before values and preflight commands.
  const validatorSource = readFileSync(validator, "utf8");
  const guide = readFileSync(join(root, "start-build/reference/parent-owned-gate.md"), "utf8");
  const acceptedStatuses = [...validatorSource.matchAll(/receipt\.status_before !== "(\w+)"/g)].map((match) => match[1]);
  const acceptedCommands = [...validatorSource.matchAll(/"(git status --porcelain[^"]*)"/g)].map((match) => match[1]);
  assert.deepEqual(acceptedStatuses.slice().sort(), ["draft", "ready"], "validator accepts exactly draft and ready");
  assert.deepEqual(acceptedCommands.slice().sort(), ["git status --porcelain", "git status --porcelain --untracked-files=all"], "validator accepts exactly the two preflight forms");
  for (const status of acceptedStatuses) {
    assert.ok(guide.includes(`\`${status}\``), `parent-owned-gate.md documents status_before: ${status}`);
  }
  for (const command of acceptedCommands) {
    assert.ok(guide.includes(command), `parent-owned-gate.md documents preflight command: ${command}`);
  }
  for (const [, status] of guide.matchAll(/^\s*status_before: "(\w+)"/gm)) {
    assert.ok(acceptedStatuses.includes(status), `documented status_before is accepted: ${status}`);
  }
  for (const [, command] of guide.matchAll(/^\s*command: "(git status[^"]*)"/gm)) {
    assert.ok(acceptedCommands.includes(command), `documented preflight command is accepted: ${command}`);
  }
  // Issue #458: the locator argument must equal the Local gate row's sole
  // scheme:// token, and that mismatch is distinguishable from the other three
  // Local gate conditions, naming both compared values.
  const twoUrls = run({ reviewPacket: packet(`PASS — ${expected.gateCommand} — Gate Receipt: ${locator} — https://gitlab.example/x`) });
  assert.notEqual(twoUrls.status, 0, "two locator tokens in Local gate fail: the mechanism is the sole token, not the first");
  assert.match(twoUrls.stderr, /Gate Receipt pointer mismatch/, "two-URL row reports a pointer mismatch, not the shared stale message");
  assert.match(twoUrls.stderr, /2 locator tokens/, "two-URL row reports that no sole token could be extracted");
  const wrongLocator = run({ locatorValue: "github://owner/repo/pull/42/comment/9" });
  assert.notEqual(wrongLocator.status, 0, "wrong locator fails");
  assert.match(wrongLocator.stderr, /github:\/\/owner\/repo\/pull\/42\/comment\/9/, "mismatch names the expected argument");
  assert.ok(wrongLocator.stderr.includes(locator), "mismatch names the token extracted from the row");
  const localGateFailures = {
    noPass: run({ reviewPacket: packet(`done — ${expected.gateCommand} — Gate Receipt: ${locator}`) }),
    contradictory: run({ reviewPacket: packet(`PASS — not-run — ${expected.gateCommand} — Gate Receipt: ${locator}`) }),
    noCommand: run({ reviewPacket: packet(`PASS — npm run other — Gate Receipt: ${locator}`) }),
  };
  for (const [name, result] of Object.entries(localGateFailures)) {
    assert.notEqual(result.status, 0, `${name} Local gate fails`);
    assert.doesNotMatch(result.stderr, /Gate Receipt pointer mismatch/, `${name} is not reported as a pointer mismatch`);
  }
  assert.equal(
    new Set(Object.values(localGateFailures).map((result) => result.stderr)).size,
    3,
    "the three non-locator Local gate conditions no longer share one message",
  );
  assert.ok(
    guide.includes("--gate-receipt-locator <the sole URL in the Reviewer Lift `Local gate` row>"),
    "parent-owned-gate.md documents the locator argument as the row's sole URL",
  );
  assert.ok(!/opaque provider locator/.test(guide), "parent-owned-gate.md no longer calls the locator opaque");

  // Issue #490: a parent receipt naming a retained local log must point at a
  // readable file at the pre-publication step; remote/native evidence
  // locators keep their documented behavior and are never opened as local
  // paths.
  const retainedLog = join(work, "gate-run.log");
  writeFileSync(retainedLog, "gate output\n");
  const retainedEvidence = [{ tier: "tier-1", kind: "local-gate", source: retainedLog, summary: "exact candidate" }];
  assert.equal(run({ document: receipt({ evidence: retainedEvidence }), mode: "pre-post" }).status, 0, "readable retained local log passes pre-publication validation");
  assert.equal(run({ document: receipt({ evidence: retainedEvidence }) }).status, 0, "readable retained local log passes post-note validation");
  const missingEvidence = [{ tier: "tier-1", kind: "local-gate", source: join(work, "absent-gate-run.log"), summary: "exact candidate" }];
  const missingPre = run({ document: receipt({ evidence: missingEvidence }), mode: "pre-post" });
  assert.notEqual(missingPre.status, 0, "missing retained local log is refused before publication");
  assert.match(missingPre.stderr, /retained local log .*absent-gate-run\.log.* is not readable/, "refusal names the unreadable evidence source");
  assert.match(missingPre.stderr, /original-run provenance/, "refusal names the recovery action");
  assert.notEqual(run({ document: receipt({ evidence: missingEvidence }) }).status, 0, "missing retained local log also fails post-note validation");
  assert.equal(run({ document: receipt({ evidence: [{ tier: "tier-1", kind: "local-gate", source: "https://gitlab.example/-/notes/53817", summary: "exact candidate" }] }) }).status, 0, "remote evidence locator is not opened as a local file");

  // Issue #501 (midnight #557 owner decision): Lift rows with a closed value
  // set in reviewer-lift-schema.md refuse off-schema values, each by name.
  const live534 = runMidnight("mr-534-description.txt", { reviewedCommit: "871f82381ba3e5d97ff4e51c72388a42bd500efb", note: "534#note_54548" });
  assert.notEqual(live534.status, 0, "live !534 Lift is refused");
  assert.deepEqual(
    offSchemaRows(live534.stderr),
    ["Review gate", "CI pipeline", "Touched safety surfaces", "Acceptance surfaces", "Decoupling proof"],
    "live !534 Lift is refused once per offending row, and only those rows",
  );
  assert.doesNotMatch(live534.stderr, /parent-owned independent review|not observed by the builder|only one test file/, "refusal does not echo Lift body values");
  const live585 = runMidnight("mr-585-description.txt", { reviewedCommit: "1126607b886bfc0eb9060c2e355e16ebeaa1f30e", note: "585#note_56387" });
  assert.equal(live585.status, 0, `current real midnight !585 Lift is accepted: ${live585.stderr}`);

  const conforming = {
    "Review gate": ["mandatory", "bypassed (human override)"],
    "Change tier": ["trivial — docs only", "moderate: one validator", "high-risk - gate semantics", "`trivial — docs only`"],
    Transport: ["mcp", "n/a", "glab-fallback (gap: approvals endpoint)", undefined],
    "Gate owner": ["builder", "parent", "`parent`"],
    "Gate coverage": ["exact-candidate-local", "`exact-candidate-local`"],
    "CI pipeline": [
      "N/A — no CI configured",
      "N/A: no pipeline observed for 1126607b by the builder; advisory only",
      "advisory: pipeline 8053 (https://gitlab.example.com/group/project/-/pipelines/8053), status running at publication, sha 6081f11337676723a591037f82a4e03c38a82089",
      `pipeline #412 success at ${"a".repeat(40)}`,
    ],
    "Touched safety surfaces": ["none", "[]", "`none`", "gates, locks", "other (one new read-only query, LAN panel)", "`state, other (x)`"],
    "Acceptance surfaces": ["none", "[]", "`none`", "gate-receipt:test, docs:docs-read", "panel:smoke, deploy:N/A — no deploy surface", "ci-parity:ci"],
    "Decoupling proof": ["single MR", "`single MR`", "co-running !583 (issue-621-panel-build) and !585; no shared paths, locks, or migrations"],
    "Open Questions": ["none", "1: OQ-1", "OQ-1, OQ-2"],
    "Approval authority": ["default-after-pass", "restricted: release freeze until 2026-10-01"],
    "Finish authority": [
      "none — requires explicit human/parent instruction", "approval-only", "reviewer may merge",
      "queue auto-merge", "human release", "project default: merge train", "\"queue auto-merge\"",
    ],
  };
  assert.equal(run().status, 0, "conforming packet is accepted");
  for (const [name, values] of Object.entries(conforming)) {
    for (const value of values) {
      const result = run({ reviewPacket: withRow(name, value) });
      assert.equal(result.status, 0, `${name} accepts ${value ?? "(absent)"}: ${result.stderr}`);
    }
  }
  const offSchema = {
    "Review gate": ["pending — parent-owned independent review after Gate Receipt", "mandatory — pending", "bypassed", undefined],
    "Change tier": ["trivial", "small — docs", "moderate-ish change", undefined],
    Transport: ["MCP", "glab", "glab-fallback", "mcp via glab"],
    "Gate owner": ["parent-owned", "both", undefined],
    "Gate coverage": ["parent-owned", "exact-candidate-local; plus CI", undefined],
    "CI pipeline": ["advisory; not observed by the builder", "advisory — unavailable", "N/A", "pipeline 8053 running", "sha 6081f11337676723a591037f82a4e03c38a82089 running", "success"],
    "Touched safety surfaces": ["none — test only", "`gates`, `locks`", "gates; locks", "database", "other: x", undefined],
    "Acceptance surfaces": ["AC1 test; AC2 test (mutant run); AC3 docs-read (diff name-only); AC4 N/A — parent-owned gate", "gate:tested", "`gate:test`, `docs:docs-read`", "gate: test", "gate:N/A", undefined],
    "Decoupling proof": ["single issue; only one test file touched; #555 still open and not asserted", "single MR; one file", "N/A", "independent", undefined],
    "Open Questions": ["maybe the timeout", "0", undefined],
    "Approval authority": ["approve after pass", "restricted", undefined],
    "Finish authority": ["merge when green", "none", "project default", undefined],
  };
  for (const [name, values] of Object.entries(offSchema)) {
    for (const value of values) {
      const result = run({ reviewPacket: withRow(name, value) });
      assert.notEqual(result.status, 0, `${name} refuses ${value ?? "(absent)"}`);
      assert.deepEqual(offSchemaRows(result.stderr), [name], `${name} refusal names only that row for ${value ?? "(absent)"}`);
    }
  }
  const reviewGate = run({ reviewPacket: withRow("Review gate", "pending") });
  assert.match(reviewGate.stderr, /Review gate is off-schema; accepted: `mandatory` or `bypassed \(human override\)`/, "refusal names the accepted forms");

  console.log("gate-receipt-validator: PASS");
} finally {
  rmSync(work, { recursive: true, force: true });
}
