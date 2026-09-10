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

function packet(localGate = `PASS — ${expected.gateCommand} — Gate Receipt: ${locator}`) {
  return `<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | \`${commit}\` |
| Gate coverage rationale | ${expected.gatePolicy}; exact-candidate-local; command ${expected.gateCommand}; candidate ${commit}; result PASS |
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
  assert.notEqual(run({ locatorValue: "github://owner/repo/pull/42/comment/9" }).status, 0, "wrong opaque locator fails");
  assert.notEqual(run({ reviewPacket: packet(`PASS — ${expected.gateCommand} — Gate Receipt: ${locator} — https://gitlab.example/x`) }).status, 0, "multiple locators fail");
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
  console.log("gate-receipt-validator: PASS");
} finally {
  rmSync(work, { recursive: true, force: true });
}
