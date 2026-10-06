import assert from "node:assert/strict";
import { existsSync, lstatSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const extractor = resolve(import.meta.dirname, "../start-build/scripts/extract-gate-receipt.mjs");
const validator = resolve(import.meta.dirname, "../start-build/scripts/validate-gate-receipt.mjs");
const work = mkdtempSync(join(tmpdir(), "gate-extractor-"));
const sentinel = "PRIVATE-BODY-AND-ARGUMENT-SENTINEL";
const input = join(work, `${sentinel} input.md`);
const sha = "1".repeat(40);
// Synthetic compatibility fixtures are not published receipts or gate execution proof.
const builder = `gate_receipt:
  kind: "gate-receipt"
  version: "1"
  owner: "builder"
  checkout_commit: "${sha}"
  command: "bun run check"
  result: "PASS"
`;
const parent = `gate_receipt:
  kind: "gate-receipt"
  version: "1"
  owner: "parent"
  change_id: "repository/change@synthetic"
  issue_id: "tracker/item@synthetic"
  checkout_path: ${JSON.stringify(work)}
  checkout_commit: "${sha}"
  status_before: "draft"
  status_after: "ready"
  command: "bun run check"
  result: "PASS"
  summary: "synthetic compatibility only"
  preflight_checks:
    - name: "clean-status-before"
      command: "git status --porcelain --untracked-files=all"
      result: "PASS"
      summary: "synthetic"
    - name: "tracked-files-unchanged-after"
      command: "git status --porcelain --untracked-files=all"
      result: "PASS"
      summary: "synthetic"
  evidence:
    - tier: "tier-1"
      kind: "local-gate"
      source: "synthetic-evidence@fixture"
      summary: "not execution proof"
`;
const fence = (document, newline = "\n") => `\`\`\`yaml${newline}${document}\`\`\``;
let sequence = 0;
const freshOutput = () => join(work, `${sentinel} receipt-${sequence++}.yaml`);
const cli = (...args) => spawnSync(process.execPath, [extractor, ...args], { cwd: work, encoding: "utf8" });
function diagnostic(result, label) {
  assert.equal(result.status, 1, label);
  assert.equal(result.stdout, "", `${label}: no stdout body`);
  for (const flag of ["--input", "--output", "--help"]) assert.ok(result.stderr.includes(flag), `${label}: static CLI guidance names ${flag}`);
  assert.ok(!result.stderr.includes(work), `${label}: no supplied path echo`);
  assert.ok(!result.stderr.includes("gate_receipt:"), `${label}: no receipt body echo`);
  assert.ok(!result.stderr.includes(sentinel), `${label}: no body or argument echo`);
}
function extract(note, expected, label) {
  const output = freshOutput();
  writeFileSync(input, note);
  const result = cli("--input", input, "--output", output);
  assert.equal(result.status, 0, `${label}: ${result.stderr}`);
  assert.equal(result.stdout, "", `${label}: no success banner or body`);
  assert.equal(result.stderr, "", label);
  assert.deepEqual(readFileSync(output), Buffer.from(expected), label);
  assert.deepEqual(readFileSync(input), Buffer.from(note), `${label}: input unchanged`);
  return output;
}
function reject(note, label) {
  const output = freshOutput();
  writeFileSync(input, note);
  diagnostic(cli("--input", input, "--output", output), label);
  assert.equal(existsSync(output), false, `${label}: no output created`);
  assert.deepEqual(readFileSync(input), Buffer.from(note), `${label}: input unchanged`);
}
try {
  const builderPath = extract(`# Builder Gate Receipt\n\n${fence(builder)}\n\n- Synthetic evidence only.\n`, builder, "fenced builder receipt preserves original bytes from foreign CWD");
  const crlfParent = parent.replaceAll("\n", "\r\n");
  const parentPath = extract(`# Parent Gate Receipt\r\n${fence(crlfParent, "\r\n")}\r\n- Synthetic evidence.`, crlfParent, "fenced parent CRLF bytes");
  const spelling = "gate_receipt:\n  quoted: 'café 日本語 😀 �'\n  spelling: 0xCAFE\n  scalar: |+\n    first line  \n\n    second line\n  # indented comment\n\n";
  extract(`${fence(spelling)}\n`, spelling, "LF scalar spelling Unicode comments and blank bytes");
  extract(spelling.slice(0, -2), spelling.slice(0, -2), "raw parent form without final newline");
  extract(crlfParent, crlfParent, "raw parent form with final CRLF");
  const rootPath = extract(fence("gate_receipt:\n"), "gate_receipt:\n", "root-only extraction leaves semantics downstream");
  extract("gate_receipt:", "gate_receipt:", "raw root-only without final newline");
  extract(`\`\`\`yaml\nunrelated: true\n\`\`\`\n${fence(builder)}`, builder, "unrelated preceding YAML is not first-match selection");
  extract(`\`\`\`\`markdown\n${fence(builder)}\n\`\`\`\`\n~~~text\n${fence("gate_receipt: &example\n")}\n~~~\n\`\`\`json\ngate_receipt: &ignored\n\`\`\`\n${fence(builder)}`, builder, "nested examples and non-YAML fences are ignored");

  for (const [note, label] of [
    [`# ${sentinel}\n\`\`\`yaml\nother: true\n\`\`\``, "missing receipt"],
    [`${fence(builder)}\n${fence(parent)}`, "duplicate across fences"],
    [fence(builder + builder), "duplicate in one fence"],
    [`${fence("gate_receipt: &alias\n  kind: ignored\n")}\n${fence(builder)}`, "malformed candidate plus valid receipt is ambiguous"],
    [fence("gate_receipt: *alias\n"), "alias-style root"],
    [fence("gate_receipt: {kind: receipt}\n"), "nonplain root"],
    [`\`\`\`yaml\n${builder}${sentinel}`, "unterminated receipt fence"],
    [`${fence(builder)}\n\`\`\`yaml\ngate_receipt: &alias\n`, "unterminated candidate after a valid receipt"],
    [fence(`other: true\n${builder}`), "receipt document does not start with root"],
    [fence(`${builder}second: ${sentinel}\n`), "second top-level mapping"],
    [fence(`${builder}# ${sentinel}\n`), "unindented comment is outside child form"],
    [`${builder}# ${sentinel}\n`, "mixed raw document and Markdown"],
    ["gate_receipt: &alias\n  kind: receipt\n", "raw nonplain root"],
    [`\`\`\`yml\n${builder}\`\`\``, "alternate YAML fence spelling"],
    [`\`\`\`yaml \n${builder}\`\`\``, "receipt opener must be exact"],
    [`\`\`\`\`yaml\n${builder}\`\`\`\``, "longer receipt fence is unsupported"],
    [`\`\`\`yaml\n${builder}\`\`\` `, "receipt closer must be exact"],
    [builder.replaceAll("\n", "\r"), "CR-only is unsupported"],
    [Buffer.concat([Buffer.from(`\`\`\`yaml\n${builder}\`\`\`\n${sentinel}`), Buffer.from([0xff])]), "strict UTF-8 applies to complete note"],
  ]) reject(note, label);

  const help = cli("--help");
  assert.equal(help.status, 0);
  for (const flag of ["--input", "--output", "--help"]) assert.ok(help.stdout.includes(flag), `help names ${flag}`);
  assert.ok(!help.stdout.includes(sentinel));
  assert.ok(!help.stdout.includes(work));
  assert.equal(help.stderr, "");
  const unused = freshOutput();
  for (const args of [[], ["--input"], ["--input", input], ["--input", input, "--output"], ["--input", input, "--input", sentinel], ["--input", input, "--output", unused, "--output", sentinel], ["--input", input, "--output", unused, "--owner", sentinel], ["--help", sentinel], ["--input", "", "--output", unused], ["--input", "--output", "--output", unused]]) {
    diagnostic(cli(...args), "invalid CLI option set");
    assert.equal(existsSync(unused), false);
  }
  diagnostic(cli("--input", join(work, sentinel), "--output", unused), "unreadable input");
  assert.equal(existsSync(unused), false);
  writeFileSync(input, builder);
  diagnostic(cli("--input", input, "--output", join(work, sentinel, "receipt.yaml")), "unwritable output");
  const existing = freshOutput();
  writeFileSync(existing, `${sentinel}\n`);
  diagnostic(cli("--input", input, "--output", existing), "existing output refuses overwrite");
  assert.equal(readFileSync(existing, "utf8"), `${sentinel}\n`);
  diagnostic(cli("--input", input, "--output", input), "input/output collision");
  assert.equal(readFileSync(input, "utf8"), builder);
  const link = freshOutput();
  symlinkSync(existing, link);
  diagnostic(cli("--input", input, "--output", link), "symlink output");
  assert.ok(lstatSync(link).isSymbolicLink());
  assert.equal(readFileSync(existing, "utf8"), `${sentinel}\n`);
  const dangling = freshOutput();
  const target = freshOutput();
  symlinkSync(target, dangling);
  diagnostic(cli("--input", input, "--output", dangling), "dangling symlink output");
  assert.ok(lstatSync(dangling).isSymbolicLink());
  assert.equal(existsSync(target), false);

  const validate = (owner, receipt) => spawnSync(process.execPath, [validator, "--owner", owner, "--mode", "pre-post", "--receipt", receipt, "--reviewed-commit", sha, "--gate-command", "bun run check", ...(owner === "parent" ? ["--change-id", "repository/change@synthetic", "--issue-id", "tracker/item@synthetic"] : [])], { cwd: work, encoding: "utf8" });
  for (const [owner, receipt] of [["builder", builderPath], ["parent", parentPath]]) {
    const result = validate(owner, receipt);
    assert.equal(result.status, 0, `unchanged real ${owner} validator accepts extracted synthetic bytes: ${result.stderr}`);
  }
  const insufficient = validate("builder", rootPath);
  assert.equal(insufficient.status, 1, "root-only extraction is not semantic validation");
  assert.match(insufficient.stderr, /gate-receipt validation failed:/);
  console.log("gate-receipt-extractor: PASS");
} finally { rmSync(work, { recursive: true, force: true }); }
