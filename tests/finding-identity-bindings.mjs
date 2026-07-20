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

const acceptedInvalid = [];
function reject(label, args, expectedText) {
  const result = spawnSync(process.execPath, [validator, ...args], { cwd: root, encoding: "utf8" });
  if (result.status === 0) {
    acceptedInvalid.push(label);
    return;
  }
  assert.equal(result.status, 2, result.stderr || result.stdout);
  assert.match(`${result.stdout}${result.stderr}`, expectedText);
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
  const packet = readFileSync(path.join(fixtures, "revision-valid.md"), "utf8");
  const packetRow = "| `review-report:agents/skills!340:1` | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` | `MF-5` |";
  const secondPacketRow = "| `review-report:agents/skills!340:2` | `bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb` | `MF-5` |";
  const distinctPacket = path.join(temp, "revision-distinct-reused-id.md");
  writeFileSync(distinctPacket, packet.replace(packetRow, `${packetRow}\n${secondPacketRow}`));
  run([...reportArgs, "--packet", distinctPacket], 0, /reports=2 identities=2 artifacts=1/);

  const firstReport = readFileSync(reports[0], "utf8");
  const duplicateLocatorReport = path.join(temp, "report-duplicate-locator.md");
  writeFileSync(
    duplicateLocatorReport,
    firstReport.replace(
      "| Reviewed SHA |",
      "| Report locator | `review-report:agents/skills!340:99` |\n| Reviewed SHA |",
    ),
  );
  reject("conflicting duplicate Report locator", ["--report", duplicateLocatorReport], /exactly one Report locator/);

  const duplicateShaReport = path.join(temp, "report-duplicate-sha.md");
  writeFileSync(
    duplicateShaReport,
    firstReport.replace(
      "| Reviewed SHA | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |",
      "| Reviewed SHA | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |\n| Reviewed SHA | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |",
    ),
  );
  reject("duplicate Reviewed SHA", ["--report", duplicateShaReport], /exactly one Reviewed SHA/);

  const lift = readFileSync(path.join(fixtures, "reviewer-lift-valid.md"), "utf8");
  const conflictingLiftRows = path.join(temp, "lift-conflicting-rows.md");
  writeFileSync(
    conflictingLiftRows,
    lift.replace("| Finding bindings |", "| Finding bindings | `none` |\n| Finding bindings |"),
  );
  reject(
    "conflicting Reviewer Lift Finding bindings rows",
    [...reportArgs, "--lift", conflictingLiftRows],
    /exactly one Reviewer Lift Finding bindings row/,
  );

  const liftRow = lift.split("\n").find((line) => line.startsWith("| Finding bindings |"));
  const duplicateLiftRows = path.join(temp, "lift-duplicate-rows.md");
  writeFileSync(duplicateLiftRows, lift.replace(liftRow, `${liftRow}\n${liftRow}`));
  reject(
    "duplicate Reviewer Lift Finding bindings rows",
    [...reportArgs, "--lift", duplicateLiftRows],
    /exactly one Reviewer Lift Finding bindings row/,
  );

  const duplicatePacket = path.join(temp, "revision-duplicate-identity.md");
  writeFileSync(duplicatePacket, packet.replace(packetRow, `${packetRow}\n${packetRow}`));
  reject(
    "duplicate Revision Packet identity",
    [...reportArgs, "--packet", duplicatePacket],
    /duplicate finding identity MF-5/,
  );

  const duplicateLiftBinding = path.join(temp, "lift-duplicate-identity.md");
  writeFileSync(
    duplicateLiftBinding,
    lift.replace(
      "id=MF-5` |",
      "id=MF-5<br>report=review-report:agents/skills!340:1; sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; id=MF-5` |",
    ),
  );
  reject(
    "duplicate Reviewer Lift identity",
    [...reportArgs, "--lift", duplicateLiftBinding],
    /duplicate finding identity MF-5/,
  );

  const malformedPacket = path.join(temp, "revision-four-cells.md");
  writeFileSync(malformedPacket, packet.replace(" | `MF-5` |", " | `MF-5` | `extra` |"));
  reject(
    "four-cell Revision Packet identity",
    [...reportArgs, "--packet", malformedPacket],
    /identity table rows must have exactly three cells/,
  );

  const phantomReport = path.join(temp, "report-phantom-identity.md");
  const phantomRow = "| `review-report:agents/skills!340:1` | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` | `SF-9` |";
  writeFileSync(phantomReport, firstReport.replace(packetRow, `${packetRow}\n${phantomRow}`));
  const phantomPacket = path.join(temp, "revision-phantom-identity.md");
  writeFileSync(phantomPacket, packet.replaceAll("MF-5", "SF-9"));
  reject(
    "identity absent from report findings",
    ["--report", phantomReport, "--packet", phantomPacket],
    /registered identity SF-9 is not a report finding/,
  );

  assert.deepEqual(acceptedInvalid, [], `validator accepted invalid artifacts: ${acceptedInvalid.join(", ")}`);

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
