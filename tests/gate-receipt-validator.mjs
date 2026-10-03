import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import yaml from "js-yaml";

const validator = resolve(import.meta.dirname, "../start-build/scripts/validate-gate-receipt.mjs");
const work = mkdtempSync(join(tmpdir(), "gate-receipt-"));
const sha = "1".repeat(40);
const command = "npm run check";
const locator = "verified-system/repository/review-note@opaque-alpha";
const policy = "docs/check-gate.md#ready";
const rationale = `Policy ${policy}; command ${command}; candidate ${sha}; coverage exact-candidate-local; result: PASS — Gate Receipt: ${locator}`;
const rows = {
  "Reviewed SHA": sha, "Finding bindings": "none", "Review gate": "mandatory",
  Transport: "project-confirmed-transport@repository",
  "Gate owner": "parent", "Gate coverage": "exact-candidate-local",
  "Gate coverage rationale": rationale,
  "CI pipeline": `evidence=scoped-ci/run@alpha; status=observed-green; commit=${sha}`,
  "Local gate": `PASS — ${command} — Gate Receipt: ${locator}`,
  RED: "N/A with rationale — mechanical", GREEN: "N/A with rationale — mechanical",
  "Changed paths": "git diff --name-only base...HEAD; validator.mjs", "Touched safety surfaces": "gates",
  "Acceptance surfaces": "gate:test", "Decoupling proof": "co-running repository/branch@alpha; no shared paths or locks",
  "Reviewer Focus": "receipt bindings", "Open Questions": "none", "Approval authority": "default-after-pass",
  "Approval authority source": "project policy#approval", "Finish authority": "none — requires explicit human/parent instruction",
  "Finish authority source": "project policy#finish", "Delta since last ready push": "N/A before ready",
};
const begin = "<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->";
const end = "<!-- REVIEWER-LIFT-SCHEMA:END -->";
function packet(overrides = {}) {
  return `${begin}\n| Field | Value |\n|---|---|\n${Object.entries({ ...rows, ...overrides }).filter(([, value]) => value !== undefined).map(([name, value]) => `| ${name} | ${value} |`).join("\n")}\n${end}`;
}
function receipt(overrides = {}) {
  return { gate_receipt: {
    kind: "gate-receipt", version: "1", owner: "parent", change_id: "repo/change@alpha", issue_id: "tracker/item@beta",
    checkout_path: "/tmp/worktree", checkout_commit: sha, status_before: "draft", status_after: "ready",
    command, result: "PASS", summary: "exact candidate passed",
    preflight_checks: ["clean-status-before", "tracked-files-unchanged-after"].map((name) => ({ name, command: "git status --porcelain", result: "PASS", summary: "empty" })),
    evidence: [{ tier: "tier-1", kind: "local-gate", source: "scoped-evidence@alpha", summary: "original run" }], ...overrides,
  } };
}
function builder(overrides = {}) {
  return { gate_receipt: { kind: "gate-receipt", version: "1", owner: "builder", checkout_commit: sha, command, result: "PASS", ...overrides } };
}
function run({ mode = "post-note", owner = "parent", body = packet(), document = receipt(), receiptLocator = locator, extra = [] } = {}) {
  const receiptPath = join(work, "receipt.yml");
  const packetPath = join(work, "packet.md");
  writeFileSync(receiptPath, typeof document === "string" ? document : yaml.dump(document));
  writeFileSync(packetPath, body);
  const args = ["--mode", mode, "--owner", owner];
  if (mode === "lift-only") args.push("--review-packet", packetPath);
  else {
    args.push("--receipt", receiptPath, "--reviewed-commit", sha, "--gate-command", command);
    if (owner === "parent") {
      args.push("--change-id", "repo/change@alpha", "--issue-id", "tracker/item@beta", "--review-packet", packetPath);
      if (mode === "post-note") args.push("--gate-policy-ref", policy, "--gate-receipt-locator", receiptLocator);
    }
  }
  return spawnSync(process.execPath, [validator, ...args, ...extra], { cwd: tmpdir(), encoding: "utf8" });
}
const pass = (options, label) => { const result = run(options); assert.equal(result.status, 0, `${label}: ${result.stderr}`); };
const reject = (options, label) => { const result = run(options); assert.notEqual(result.status, 0, label); return result; };
try {
  pass({}, "opaque transport/CI/receipt accepted from foreign CWD");
  for (const owner of ["parent", "builder"]) {
    const presence = { mode: "lift-only", owner, document: "not a receipt", body: packet({ "Gate owner": owner, "Local gate": "not-run — parent-owned", "Review gate": "awaiting parent review" }) };
    pass(presence, "presence mode does not validate partial parent values or receipt");
    for (const name of Object.keys(rows)) {
      for (const value of [undefined, "", " \t ", "` \t `", "`` \t ``"]) reject({ ...presence, body: packet({ [name]: value }) }, `${owner} requires nonempty ${name}`);
    }
    for (const body of [packet() + packet(), packet().replace(end, ""), packet().replace(begin, "<!-- REVIEWER-LIFT-SCHEMA:BEGIN -->"), packet().replace("| Gate owner | parent |", "| Gate owner | parent |\n| Gate owner | PRIVATE-SENTINEL |")]) {
      const result = reject({ ...presence, body }, "unique exact markers and rows");
      assert.ok(!result.stderr.includes("PRIVATE-SENTINEL"));
    }
    reject({ ...presence, extra: ["--receipt", join(work, "receipt.yml")] }, "presence refuses receipt flags");
  }
  pass({ owner: "builder", mode: "pre-post", document: builder() }, "builder receipt");
  for (const override of [{ owner: "parent" }, { checkout_commit: "2".repeat(40) }, { command: "other" }, { result: "FAIL" }, { change_id: "extra" }]) reject({ owner: "builder", mode: "pre-post", document: builder(override) }, "builder exact receipt restrictions");
  reject({ owner: "builder", document: builder() }, "builder post-note stays prohibited");
  for (const [flag, value] of [["--change-id", "repo/change@alpha"], ["--issue-id", "tracker/item@beta"], ["--review-packet", join(work, "packet.md")], ["--gate-receipt-locator", locator], ["--gate-policy-ref", policy]]) {
    const result = reject({ owner: "builder", mode: "pre-post", document: builder(), extra: [flag, value] }, "builder refuses parent-only flags");
    assert.match(result.stderr, /parent-owned binding flags are invalid in builder mode/);
  }
  reject({ owner: "builder", mode: "pre-post", document: "gate_receipt: &gate_receipt\n  kind: gate-receipt" }, "alias anchor rejected");
  for (const override of [{ owner: "builder" }, { checkout_commit: "2".repeat(40) }, { change_id: "other" }, { issue_id: "other" }, { command: "other" }, { result: "FAIL" }, { tracked_changes_waiver: "accepted" }, { status_before: "merged" }, { status_after: "draft" }]) reject({ document: receipt(override) }, "parent exact receipt restrictions");
  pass({ document: receipt({ status_before: "ready" }) }, "regate ready");
  for (const path of ["C:\\work\\checkout", "\\\\server\\share\\checkout"]) pass({ document: receipt({ checkout_path: path }), body: packet().replaceAll("\n", "\r\n") }, "portable path and CRLF");
  for (const cmd of ["git status", "git status --porcelain; echo ignored"]) reject({ document: receipt({ preflight_checks: receipt().gate_receipt.preflight_checks.map((r) => ({ ...r, command: cmd })) }) }, "strict preflight");
  pass({ document: receipt({ preflight_checks: receipt().gate_receipt.preflight_checks.map((r) => ({ ...r, command: "git status --porcelain --untracked-files=all" })) }) }, "stronger preflight");
  reject({ document: receipt({ preflight_checks: receipt().gate_receipt.preflight_checks.map((r) => ({ ...r, result: "FAIL" })) }) }, "changed files rejected");
  const log = join(work, "original.log"); writeFileSync(log, "original gate output\n");
  pass({ document: receipt({ evidence: [{ tier: "tier-1", kind: "local-gate", source: log, summary: "original run" }] }) }, "local custody");
  for (const mode of ["pre-post", "post-note"]) reject({ mode, document: receipt({ evidence: [{ tier: "tier-1", kind: "local-gate", source: join(work, "absent.log"), summary: "original run" }] }) }, "missing custody");
  for (const mode of ["pre-post", "post-note"]) {
    const candidate = mode === "pre-post" ? {
      "Local gate": `not-run — parent-owned; ${command}`,
      "Gate coverage rationale": rationale.replace(`PASS — Gate Receipt: ${locator}`, "not-run — parent-owned"),
    } : {};
    pass({ mode, body: packet(candidate) }, `${mode} accepts its documented stage`);
    for (const name of Object.keys(rows)) {
      for (const value of [undefined, "", " \t ", "` \t `", "`` \t ``"]) {
        const result = reject({ mode, body: packet({ ...candidate, [name]: value }) + "\nPRIVATE-SENTINEL" }, `${mode} requires nonempty ${name}`);
        assert.match(result.stderr, new RegExp(`missing Reviewer Lift ${name}`));
        assert.ok(!result.stdout.includes("validation: PASS"));
        assert.ok(!result.stderr.includes("PRIVATE-SENTINEL"));
      }
    }
    for (const body of [packet(candidate) + packet(candidate), packet(candidate).replace(end, ""), packet(candidate).replace(begin, "<!-- REVIEWER-LIFT-SCHEMA:BEGIN -->"), packet(candidate).replace("| Gate owner | parent |", "| Gate owner | parent |\n| Gate owner | PRIVATE-SENTINEL |")]) {
      const result = reject({ mode, body }, `${mode} preserves unique markers and rows`);
      assert.match(result.stderr, /must appear exactly once|row appears more than once/);
      assert.ok(!result.stderr.includes("PRIVATE-SENTINEL"));
    }
    for (const [name, value] of [
      ["Review gate", "optional"], ["Gate owner", "builder"],
      ["Gate coverage", "parent-owned"], ["Transport", "unknown"],
      ["Approval authority", "approved"], ["Finish authority", "merge whenever"],
      ["Touched safety surfaces", "everything"], ["Acceptance surfaces", "gate:unverified"],
    ]) {
      reject({ mode, body: packet({ [name]: value }) }, `${mode} rejects invalid ${name}`);
    }
  }
  for (const [flag, value] of [["--gate-receipt-locator", locator], ["--gate-policy-ref", policy]]) {
    const result = reject({ mode: "pre-post", extra: [flag, value] }, "pre-post refuses future receipt/policy flags");
    assert.match(result.stderr, /post-note flags, invalid in pre-post mode/);
  }
  reject({ mode: "pre-post", document: receipt({ checkout_commit: "2".repeat(40) }) }, "pre-post rejects wrong receipt candidate");
  reject({ body: packet({ "Local gate": "not-run — parent-owned" }) }, "post note requires receipt");
  for (const name of ["Transport", "CI pipeline"]) for (const value of [undefined, "", "pending", "<placeholder>"]) reject({ body: packet({ [name]: value }) }, "absent/placeholder evidence rejected");
  for (const ci of [`evidence=x; status=running`, `status=green; commit=${sha}`, `evidence=<pending>; status=green; commit=${sha}`]) reject({ body: packet({ "CI pipeline": ci }) }, "unbound CI rejected");
  pass({ body: packet({ "CI pipeline": `evidence=scoped-ci/run@alpha; status=pending; commit=${sha}` }) }, "bound pending CI remains advisory");
  pass({ body: packet({ "CI pipeline": "N/A — no configured CI" }) }, "reasoned unavailable CI");
  for (const local of [`PASS — ${command}`, `PASS — ${command} — Gate Receipt: pending`, `PASS — ${command} — Gate Receipt: wrong`, `PASS — ${command} — Gate Receipt: ${locator}; Gate Receipt: other`, `PASS — ${command} — Gate Receipt: ${locator} other`, `FAIL — ${command} — Gate Receipt: ${locator}`, `PASS — not-run — ${command} — Gate Receipt: ${locator}`, `PASS — other — Gate Receipt: ${locator}`]) reject({ body: packet({ "Local gate": local }) }, "sole exact receipt pointer and result/command");
  pass({ body: packet({ "Local gate": `PASS — ${command} — 0 fail — Gate Receipt: \`${locator}\`` }) }, "quoted opaque receipt and fail count");
  for (const value of ["2".repeat(40), `${sha} prose`]) reject({ body: packet({ "Reviewed SHA": value }) }, "exact candidate");
  reject({ body: packet({ "Gate coverage rationale": `${command}; ${sha}; exact-candidate-local` }) }, "policy binding");
  for (const result of [
    "PASS", "not-run — parent-owned", "FAIL", "pending",
    "PASS — Gate Receipt: PRIVATE-SENTINEL", "PASS — Gate Receipt: pending",
    `PASS — Gate Receipt: ${locator} other`,
    `not-run — parent-owned; note: PASS — Gate Receipt: ${locator}`,
    `not-run — parent-owned; result: PASS — Gate Receipt: ${locator}`,
    `FAIL; result: PASS — Gate Receipt: ${locator}`,
    `PASS — Gate Receipt: other; note: ${locator}`,
    `PASS — Gate Receipt: ${locator}; result: not-run — parent-owned`,
    `PASS — Gate Receipt: ${locator}; note: PASS`,
  ]) {
    const refused = reject({ body: packet({ "Gate coverage rationale": rationale.replace(`PASS — Gate Receipt: ${locator}`, result) }) + "\nPRIVATE-SENTINEL" }, "terminal rationale requires actual PASS and exact receipt");
    assert.match(refused.stderr, /Reviewer Lift gate coverage rationale/);
    assert.ok(!refused.stdout.includes("validation: PASS"));
    assert.ok(!refused.stderr.includes("PRIVATE-SENTINEL"));
  }
  reject({ body: packet({ "Gate coverage rationale": `${policy}; exact-candidate-local; ${command}; ${sha}; PASS` }) }, "old terminal shorthand is not a result/receipt binding");
  pass({ body: packet({ "Gate coverage rationale": rationale.replace(locator, `\`${locator}\``) }) }, "terminal rationale accepts quoted opaque receipt");
  pass({ body: packet({ "Gate coverage rationale": `\`${rationale}\`` }) }, "terminal rationale accepts whole-cell code span");
  const opaqueLocator = `${locator}/result:published`;
  pass({ receiptLocator: opaqueLocator, body: packet({
    "Gate coverage rationale": rationale.replace(locator, opaqueLocator),
    "Local gate": `PASS — ${command} — Gate Receipt: ${opaqueLocator}`,
  }) }, "result-like text inside the opaque locator is not a result field");
  for (const delta of ["pending", `${sha}; gate rerun pending`, `${sha}; receipts pending`, `${sha}; pending (parent)`, `${sha.slice(0, 7)} -> files`, `${"2".repeat(40)} -> files`]) reject({ body: packet({ "Delta since last ready push": delta }) }, "stale delta");
  pass({ body: packet({ "Delta since last ready push": `${sha}; bound-or-pending wording fixed; gate rerun PASS` }) }, "pending prose not pointer");
  const unsafe = reject({ body: packet() + "PRIVATE-SENTINEL\u0000" }, "unsafe packet");
  assert.ok(!unsafe.stderr.includes("PRIVATE-SENTINEL"));
  console.log("gate-receipt-validator: PASS");
} finally { rmSync(work, { recursive: true, force: true }); }
