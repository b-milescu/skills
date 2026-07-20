import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const validator = path.join(root, "start-review", "scripts", "validate-finding-bindings.mjs");
const fixtures = path.join(root, "tests", "fixtures", "finding-identities");
const reports = ["report-round-1.md", "report-round-2.md"].map((name) => path.join(fixtures, name));

function run(args, expectedStatus, expectedText) {
  const result = spawnSync(process.execPath, [validator, ...args], { cwd: root, encoding: "utf8" });
  assert.equal(result.status, expectedStatus, result.stderr || result.stdout);
  assert.match(`${result.stdout}${result.stderr}`, expectedText);
  return result.stdout;
}

const reportArgs = reports.flatMap((file) => ["--report", file]);
run(reportArgs, 0, /reports=2 identities=2 artifacts=0/);

const validOutput = run(
  [...reportArgs, "--packet", path.join(fixtures, "revision-valid.md")],
  0,
  /reports=2 identities=2 artifacts=1/,
);
run([...reportArgs, "--packet", path.join(fixtures, "revision-bare-id.md")], 2, /ambiguous finding ID MF-5/);
run([...reportArgs, "--packet", path.join(fixtures, "revision-missing-sha.md")], 2, /missing reviewed SHA for MF-5/);
run([...reportArgs, "--packet", path.join(fixtures, "revision-stale-sha.md")], 2, /stale finding binding for MF-5/);
run([...reportArgs, "--packet", path.join(fixtures, "revision-contradictory.md")], 2, /contradictory finding binding for MF-5/);
run([...reportArgs, "--lift", path.join(fixtures, "reviewer-lift-valid.md")], 0, /artifacts=1/);

const temp = mkdtempSync(path.join(tmpdir(), "finding-identities-"));
try {
  const emptyLift = path.join(temp, "lift-none.md");
  writeFileSync(emptyLift, "| Field | Value |\n|---|---|\n| Finding bindings | `none` |\n");
  run(["--lift", emptyLift], 0, /reports=0 identities=0 artifacts=1/);
  const roundTwoPacket = path.join(temp, "revision-round-2.md");
  writeFileSync(
    roundTwoPacket,
    readFileSync(path.join(fixtures, "revision-valid.md"), "utf8")
      .replaceAll("review-report:agents/skills!340:1", "review-report:agents/skills!340:2")
      .replaceAll("a".repeat(40), "b".repeat(40)),
  );
  run([...reportArgs, "--packet", roundTwoPacket], 0, /reports=2 identities=2 artifacts=1/);
  const unstableReport = path.join(temp, "report-pending.md");
  writeFileSync(
    unstableReport,
    readFileSync(reports[0], "utf8").replaceAll("review-report:agents/skills!340:1", "pending"),
  );
  run(["--report", unstableReport], 2, /invalid stable Report locator/);
  const crlf = (source, name) => {
    const target = path.join(temp, name);
    writeFileSync(target, readFileSync(source, "utf8").replace(/\r?\n/g, "\r\n"));
    return target;
  };
  const crlfReports = reports.map((file, index) => crlf(file, `report-${index + 1}.md`));
  const crlfOutput = run(
    [...crlfReports.flatMap((file) => ["--report", file]), "--packet", crlf(path.join(fixtures, "revision-valid.md"), "revision.md")],
    0,
    /reports=2 identities=2 artifacts=1/,
  );
  assert.equal(crlfOutput, validOutput, "LF and CRLF validation results differ");

  const lift = readFileSync(path.join(fixtures, "reviewer-lift-valid.md"), "utf8");
  const bareLift = path.join(temp, "lift-bare.md");
  writeFileSync(bareLift, lift.replace(/report=[^`]+/, "MF-5"));
  run([...reportArgs, "--lift", bareLift], 2, /ambiguous finding ID MF-5/);

  const staleLift = path.join(temp, "lift-stale.md");
  writeFileSync(staleLift, lift.replace(/a{40}/, "c".repeat(40)));
  run([...reportArgs, "--lift", staleLift], 2, /stale finding binding for MF-5/);
} finally {
  rmSync(temp, { recursive: true, force: true });
}

console.log("finding-identity-bindings: PASS");
