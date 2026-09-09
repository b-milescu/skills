import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
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
  assert.equal(runBuilder().status, 0, "valid builder-owned anchor receipt accepted in pre-post mode");
  assert.notEqual(runBuilder({ document: builderReceipt({ owner: "parent" }) }).status, 0, "wrong owner fails in builder mode");
  assert.notEqual(runBuilder({ document: builderReceipt({ command: undefined }) }).status, 0, "malformed builder receipt missing command fails");
  assert.notEqual(runBuilder({ document: builderReceipt({ checkout_commit: "2".repeat(40) }) }).status, 0, "stale builder receipt commit fails");
  assert.notEqual(runBuilder({ rawBody: "gate_receipt: &gate_receipt\n  kind: gate-receipt\n" }).status, 0, "YAML alias anchor form fails");
  assert.notEqual(runBuilder({ mode: "post-note", extraFlags: ["--review-packet", join(work, "packet.md")] }).status, 0, "post-note Lift validation stays scoped to parent-owned mode");
  console.log("gate-receipt-validator: PASS");
} finally {
  rmSync(work, { recursive: true, force: true });
}
