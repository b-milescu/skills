import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import yaml from "js-yaml";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const validator = join(root, "start-build", "scripts", "validate-gate-receipt.mjs");
const work = mkdtempSync(join(tmpdir(), "gate-receipt-validator-"));
const sha = "1111111111111111111111111111111111111111";
const staleSha = "2222222222222222222222222222222222222222";
const currentReceiptNoteId = "35410";
const staleReceiptNoteIds = ["35395", "35400"];
const expected = {
  mrIid: "42",
  issueIid: "360",
  reviewedSha: sha,
  gateCommand: "npm run check",
  gatePolicy: "docs/agents/check-gate.md#gate-coverage-for-ready-handoff",
  receiptNoteId: currentReceiptNoteId,
};

function receipt(overrides = {}) {
  return {
    gate_receipt: {
      kind: "gate-receipt",
      version: "1",
      owner: "parent",
      mr_iid: expected.mrIid,
      issue_iid: expected.issueIid,
      checkout_path: "/tmp/skills-issue-360",
      checkout_sha: sha,
      status_before: "draft",
      status_after: "ready",
      command: expected.gateCommand,
      result: "PASS",
      summary: "full project Check Gate completed successfully",
      preflight_checks: [
        { name: "clean-status-before", command: "git status --porcelain", result: "PASS", summary: "empty" },
        { name: "tracked-files-unchanged-after", command: "git status --porcelain", result: "PASS", summary: "empty" },
      ],
      evidence: [
        { tier: "tier-1", kind: "local-gate", source: "redacted run artifact", summary: "command, checkout SHA, and result" },
      ],
      ...overrides,
    },
  };
}

function lift(overrides = {}, newline = "\n") {
  const rows = {
    "Reviewed SHA": `\`${sha}\``,
    "Gate coverage rationale": `${expected.gatePolicy}; required CI jobs = check; locally covered jobs = check via ${expected.gateCommand}; unmapped CI-only jobs = none`,
    "CI pipeline": `N/A — pipeline unavailable for candidate ${sha}`,
    "Local gate": `PASS — ${expected.gateCommand} — Gate Receipt: https://gitlab.example/agents/skills/-/merge_requests/${expected.mrIid}#note_${currentReceiptNoteId}`,
    "Delta since last ready push": "N/A before ready",
    ...overrides,
  };
  return [
    "## Reviewer Lift",
    "",
    "<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->",
    "| Field | Value |",
    "| --- | --- |",
    ...Object.entries(rows).map(([field, value]) => `| ${field} | ${value} |`),
    "<!-- REVIEWER-LIFT-SCHEMA:END -->",
    "",
  ].join(newline);
}

function run({ receiptBody = yaml.dump(receipt()), liftBody = lift(), args = {}, name = "case" } = {}) {
  const receiptPath = join(work, `${name}-receipt.yml`);
  const liftPath = join(work, `${name}-packet.md`);
  writeFileSync(receiptPath, receiptBody);
  writeFileSync(liftPath, liftBody);
  const command = [
    validator,
    "--receipt", receiptPath,
    "--review-packet", liftPath,
    "--mr-iid", args.mrIid ?? expected.mrIid,
    "--issue-iid", args.issueIid ?? expected.issueIid,
    "--reviewed-sha", args.reviewedSha ?? expected.reviewedSha,
    "--gate-command", args.gateCommand ?? expected.gateCommand,
    "--gate-policy-ref", args.gatePolicy ?? expected.gatePolicy,
  ];
  if (args.receiptNoteId !== null) command.push("--gate-receipt-note-id", args.receiptNoteId ?? expected.receiptNoteId);
  return spawnSync(process.execPath, command, { encoding: "utf8" });
}

function passes(options, label) {
  const result = run(options);
  assert.equal(result.status, 0, `${label}: expected PASS, got ${result.status}: ${result.stderr}`);
}

function fails(options, label) {
  const result = run(options);
  assert.notEqual(result.status, 0, `${label}: expected fail-closed PASS status was returned`);
  assert.doesNotMatch(result.stderr, /SECRET-FIXTURE-CONTENT/, `${label}: diagnostic echoed input body`);
}

try {
  passes({}, "complete exact-SHA receipt");
  passes({ receiptBody: yaml.dump(receipt({ checkout_path: "C:\\worktrees\\skills-issue-360" })).replaceAll("\n", "\r\n"), liftBody: lift({}, "\r\n"), name: "windows-crlf" }, "Windows path and CRLF");
  passes({ receiptBody: yaml.dump(receipt({ checkout_path: "//server/share/skills-issue-360", observed_at: "2026-07-20T10:30:00Z" })), name: "unc-observed" }, "UNC path and observation time");
  fails({ args: { receiptNoteId: null }, name: "missing-receipt-note-input" }, "missing expected Gate Receipt note input");
  fails({ args: { receiptNoteId: "note_35400" }, name: "malformed-receipt-note-input" }, "malformed expected Gate Receipt note input");

  const required = ["kind", "version", "owner", "mr_iid", "issue_iid", "checkout_path", "checkout_sha", "status_before", "status_after", "command", "result", "summary", "preflight_checks", "evidence"];
  for (const field of required) {
    const value = receipt().gate_receipt;
    delete value[field];
    fails({ receiptBody: yaml.dump({ gate_receipt: value }), name: `missing-${field}` }, `missing ${field}`);
  }

  for (const [field, value] of Object.entries({ kind: "note", version: "2", owner: "builder", mr_iid: "99", issue_iid: "99", checkout_path: "relative/path", checkout_sha: staleSha, status_before: "ready", status_after: "draft", command: "npm test", result: "FAIL" })) {
    fails({ receiptBody: yaml.dump(receipt({ [field]: value })), name: `wrong-${field}` }, `wrong ${field}`);
  }

  for (const name of ["clean-status-before", "tracked-files-unchanged-after"]) {
    const checks = receipt().gate_receipt.preflight_checks.filter((row) => row.name !== name);
    fails({ receiptBody: yaml.dump(receipt({ preflight_checks: checks })), name: `missing-preflight-${name}` }, `missing ${name}`);
  }
  const failedPreflight = structuredClone(receipt().gate_receipt.preflight_checks);
  failedPreflight[0].result = "FAIL";
  fails({ receiptBody: yaml.dump(receipt({ preflight_checks: failedPreflight })), name: "failed-preflight" }, "failed preflight");
  const malformedEvidence = [{ tier: "tier-1", kind: "local-gate", source: "", summary: "SECRET-FIXTURE-CONTENT" }];
  fails({ receiptBody: yaml.dump(receipt({ evidence: malformedEvidence })), name: "malformed-evidence" }, "malformed evidence");
  fails({ receiptBody: yaml.dump(receipt({ observed_at: "2026-07-20 10:30" })), name: "bad-time" }, "timezone-free observation time");
  fails({ receiptBody: "Gate Receipt: PASS for current head", name: "prose-only" }, "prose-only receipt");
  fails({ receiptBody: "gate_receipt: [SECRET-FIXTURE-CONTENT", name: "malformed-yaml" }, "malformed YAML");
  fails({ receiptBody: `${yaml.dump(receipt())}\u0000SECRET-FIXTURE-CONTENT`, name: "unsafe-receipt" }, "unsafe receipt control byte");
  fails({ liftBody: `${lift()}\u007fSECRET-FIXTURE-CONTENT`, name: "unsafe-lift" }, "unsafe Lift control byte");

  const liftCases = [
    [{ "Reviewed SHA": `\`${staleSha}\`` }, "stale Reviewed SHA"],
    [{ "Reviewed SHA": sha }, "unwrapped Reviewed SHA"],
    [{ "Reviewed SHA": `\`${sha}\` extra` }, "malformed Reviewed SHA"],
    [{ "Gate coverage rationale": `required CI jobs = check; ${expected.gateCommand}` }, "missing gate policy"],
    [{ "Gate coverage rationale": expected.gatePolicy }, "missing gate command in rationale"],
    [{ "CI pipeline": `https://gitlab.example/pipelines/7 success ${staleSha}` }, "stale CI SHA"],
    [{ "Local gate": `not-run — parent-owned — ${expected.gateCommand} — Gate Receipt pending` }, "pending receipt"],
    [{ "Local gate": `PASS — ${expected.gateCommand}` }, "missing receipt pointer"],
    [{ "Local gate": `PASS — npm test — Gate Receipt: https://gitlab.example/agents/skills/-/merge_requests/${expected.mrIid}#note_${currentReceiptNoteId}` }, "wrong local command"],
    [{ "Local gate": `PASS — ${expected.gateCommand} — Gate Receipt: https://gitlab.example/agents/skills/-/merge_requests/99#note_${currentReceiptNoteId}` }, "wrong receipt MR"],
    ...staleReceiptNoteIds.map((noteId) => [
      { "Local gate": `PASS — ${expected.gateCommand} — Gate Receipt: https://gitlab.example/agents/skills/-/merge_requests/${expected.mrIid}#note_${noteId}` },
      `stale same-MR Gate Receipt note ${noteId} instead of current note ${currentReceiptNoteId}`,
    ]),
    [{ "Local gate": `PASS — ${expected.gateCommand} — Gate Receipt: https://gitlab.example/agents/skills/-/merge_requests/${expected.mrIid}#note_${currentReceiptNoteId} — https://gitlab.example/agents/skills/-/merge_requests/${expected.mrIid}#note_35400 — SECRET-FIXTURE-CONTENT` }, "current Gate Receipt note plus stale same-MR note"],
    [{ "Local gate": `PASS — ${expected.gateCommand} — Gate Receipt: https://gitlab.example/agents/skills/-/merge_requests/${expected.mrIid}#note_${currentReceiptNoteId} — https://gitlab.example/agents/skills/-/merge_requests/${expected.mrIid}#note_${currentReceiptNoteId}` }, "duplicate current Gate Receipt pointer"],
    [{ "Local gate": `PASS — ${expected.gateCommand} — Gate Receipt: https://gitlab.example/agents/skills/-/merge_requests/${expected.mrIid}#note_${currentReceiptNoteId} — https://gitlab.example/agents/skills/-/merge_requests/${expected.mrIid}#note_bad` }, "current Gate Receipt pointer plus malformed pointer"],
    [{ "Local gate": `PASS FAIL — ${expected.gateCommand} — Gate Receipt: https://gitlab.example/agents/skills/-/merge_requests/${expected.mrIid}#note_${currentReceiptNoteId}` }, "contradictory Gate Receipt result"],
    [{ "Local gate": `PASS — ${expected.gateCommand} — Gate Receipt: https://gitlab.example/agents/skills/-/merge_requests/${expected.mrIid}#note_${currentReceiptNoteId}-extra` }, "malformed receipt pointer"],
    [{ "Delta since last ready push": `${staleSha} -> ${staleSha}; Gate Receipt pending` }, "stale delta"],
  ];
  for (const [overrides, label] of liftCases) fails({ liftBody: lift(overrides), name: label.replaceAll(" ", "-") }, label);

  const missingRowPacket = lift().split(/\r?\n/).filter((line) => !line.startsWith("| CI pipeline |")).join("\n");
  fails({ liftBody: missingRowPacket, name: "missing-ci-row" }, "missing synchronized Lift row");

  const pointerFiles = [
    "start-build/reference/parent-owned-gate.md",
    "start-build/reference/parent-owned-gate-card.md",
    "start-review/reference/single-mr-review-card.md",
    "start-build/templates/review-packet.md",
    "start-build/templates/review-packet-compact.md",
    "start-review/templates/review-report.md",
  ];
  for (const relative of pointerFiles) {
    const body = readFileSync(join(root, relative), "utf8");
    assert.match(body, /validate-gate-receipt\.mjs/, `${relative} must point to the canonical validator`);
    assert.match(body, /--gate-receipt-note-id/, `${relative} must supply the current Gate Receipt identity`);
  }
  const parentGate = readFileSync(join(root, "start-build/reference/parent-owned-gate.md"), "utf8");
  const preReady = parentGate.match(/^## Pre-ready validation\r?\n([\s\S]*?)(?=^## )/m);
  assert.ok(preReady, "parent ready guidance must keep the canonical Pre-ready validation section");
  assert.match(
    preReady[1],
    /Before the GitLab Mutation Guard's ready mutation,[\s\S]*?```text\r?\nnode skill:\/\/start-build\/scripts\/validate-gate-receipt\.mjs [^\r\n]*--gate-receipt-note-id "<current Gate Receipt note ID>"[^\r\n]*\r?\n```/,
    "canonical Pre-ready validation command must include the receipt note flag before the Mutation Guard ready mutation",
  );

  console.log("gate-receipt-validator: PASS");
} finally {
  rmSync(work, { recursive: true, force: true });
}
