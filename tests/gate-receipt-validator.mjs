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
| Gate coverage rationale | ${rationale} |
| CI pipeline | advisory — unavailable |
| Local gate | ${localGate} |
| Delta since last ready push | N/A before ready |
<!-- REVIEWER-LIFT-SCHEMA:END -->`;
}

function liftWithSha(sha) {
  return packet().replace(`| Reviewed SHA | \`${commit}\` |`, `| Reviewed SHA | ${sha} |`);
}

function run({ document = receipt(), reviewPacket = packet(), locatorValue = locator } = {}) {
  const receiptPath = join(work, "receipt.yml");
  const packetPath = join(work, "packet.md");
  writeFileSync(receiptPath, yaml.dump(document));
  writeFileSync(packetPath, reviewPacket);
  return spawnSync(process.execPath, [validator,
    "--receipt", receiptPath, "--review-packet", packetPath,
    "--change-id", expected.changeId, "--issue-id", expected.issueId,
    "--reviewed-commit", commit, "--gate-command", expected.gateCommand,
    "--gate-policy-ref", expected.gatePolicy,
    "--gate-receipt-locator", locatorValue,
  ], { encoding: "utf8" });
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

  console.log("gate-receipt-validator: PASS");
} finally {
  rmSync(work, { recursive: true, force: true });
}
