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

try {
  assert.equal(run().status, 0, "opaque Azure DevOps-style IDs and locator pass");
  assert.notEqual(run({ document: receipt({ checkout_commit: "2".repeat(40) }) }).status, 0, "stale commit fails");
  assert.notEqual(run({ locatorValue: "github://owner/repo/pull/42/comment/9" }).status, 0, "wrong opaque locator fails");
  assert.notEqual(run({ reviewPacket: packet(`PASS — ${expected.gateCommand} — Gate Receipt: ${locator} — https://gitlab.example/x`) }).status, 0, "multiple locators fail");
  assert.notEqual(run({ document: receipt({ change_id: "" }) }).status, 0, "empty opaque ID fails");
  console.log("gate-receipt-validator: PASS");
} finally {
  rmSync(work, { recursive: true, force: true });
}
