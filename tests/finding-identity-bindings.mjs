// Focus: Pure-local canonical finding identity validator: two Review Reports
// may both define `MF-5` while `(Report locator, Reviewed SHA, Finding ID)`
// tuples remain distinct; valid Revision Packet and Reviewer Lift bindings
// pass; bare/missing/stale/contradictory bindings fail before
// publication/ready; LF and CRLF inputs produce the same result through
// platform-neutral `node:path` handling and no network calls.
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

function rejectWithoutEcho(label, args, protectedValue, expectedText) {
  const result = spawnSync(process.execPath, [validator, ...args], { cwd: root, encoding: "utf8" });
  assert.equal(result.status, 2, "validator must reject the malformed artifact");
  const output = `${result.stdout}${result.stderr}`;
  assert.match(output, expectedText);
  if (output.includes(protectedValue)) acceptedInvalid.push(label);
}

const reportArgs = reports.flatMap((file) => ["--report", file]);
run(reportArgs, 0, /reports=2 identities=2 artifacts=0/);
const durableReport = path.join(fixtures, "report-round-4-decision-locator.txt");
run(["--report", durableReport], 0, /reports=1 identities=2 artifacts=0/);

const validOutput = run(
  [...reportArgs, "--packet", path.join(fixtures, "revision-valid.md")],
  0,
  /reports=2 identities=2 artifacts=1/,
);
run([...reportArgs, "--packet", path.join(fixtures, "revision-bare-id.md")], 2, /ambiguous finding ID MF-5/);
run([...reportArgs, "--packet", path.join(fixtures, "revision-missing-sha.md")], 2, /missing reviewed SHA for MF-5/);
run([...reportArgs, "--packet", path.join(fixtures, "revision-stale-sha.md")], 2, /stale finding binding for MF-5/);
run([...reportArgs, "--packet", path.join(fixtures, "revision-contradictory.md")], 2, /contradictory finding binding for MF-5/);
run(
  [...reportArgs, "--packet", path.join(fixtures, "revision-comment-url.md")],
  2,
  /unknown report locator for MF-5/,
);
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
      .replaceAll("review-report:b-milescu/skills#340:1", "review-report:b-milescu/skills#340:2")
      .replaceAll("a".repeat(40), "b".repeat(40)),
  );
  run([...reportArgs, "--packet", roundTwoPacket], 0, /reports=2 identities=2 artifacts=1/);
  const packet = readFileSync(path.join(fixtures, "revision-valid.md"), "utf8");
  const packetRow = "| `review-report:b-milescu/skills#340:1` | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` | `MF-5` |";
  const secondPacketRow = "| `review-report:b-milescu/skills#340:2` | `bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb` | `MF-5` |";
  const distinctPacket = path.join(temp, "revision-distinct-reused-id.md");
  writeFileSync(distinctPacket, packet.replace(packetRow, `${packetRow}\n${secondPacketRow}`));
  run([...reportArgs, "--packet", distinctPacket], 0, /reports=2 identities=2 artifacts=1/);

  const firstReport = readFileSync(reports[0], "utf8");
  const opaqueLocator = "confirmed-system/repository/Report@Alpha";
  const opaqueSha = "A".repeat(40);
  const opaqueReport = path.join(temp, "opaque-report.md");
  const opaquePacket = path.join(temp, "opaque-packet.md");
  const opaqueLift = path.join(temp, "opaque-lift.md");
  const opaque = (body) => body.replaceAll("review-report:b-milescu/skills#340:1", opaqueLocator).replaceAll("a".repeat(40), opaqueSha);
  writeFileSync(opaqueReport, opaque(firstReport));
  writeFileSync(opaquePacket, opaque(packet));
  writeFileSync(opaqueLift, opaque(readFileSync(path.join(fixtures, "reviewer-lift-valid.md"), "utf8")));
  run(["--report", opaqueReport, "--packet", opaquePacket, "--lift", opaqueLift], 0, /identities=1 artifacts=2/);
  writeFileSync(opaquePacket, opaque(packet).replaceAll(opaqueSha, opaqueSha.toLowerCase()));
  reject("commit identity normalization", ["--report", opaqueReport, "--packet", opaquePacket], /stale finding binding/);
  writeFileSync(opaquePacket, opaque(packet).replaceAll(opaqueLocator, opaqueLocator.toLowerCase()));
  reject("report identity normalization", ["--report", opaqueReport, "--packet", opaquePacket], /unknown report locator/);
  writeFileSync(opaquePacket, opaque(packet).replaceAll("MF-5", "MF-6"));
  reject("finding identity change", ["--report", opaqueReport, "--packet", opaquePacket], /stale finding binding/);
  const duplicateLocatorReport = path.join(temp, "report-duplicate-locator.md");
  writeFileSync(
    duplicateLocatorReport,
    firstReport.replace(
      "| Reviewed commit |",
      "| Report locator | `review-report:b-milescu/skills#340:99` |\n| Reviewed commit |",
    ),
  );
  reject("conflicting duplicate Report locator", ["--report", duplicateLocatorReport], /exactly one Report locator/);

  const duplicateShaReport = path.join(temp, "report-duplicate-sha.md");
  writeFileSync(
    duplicateShaReport,
    firstReport.replace(
      "| Reviewed commit | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |",
      "| Reviewed commit | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |\n| Reviewed commit | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |",
    ),
  );
  reject("duplicate Reviewed commit", ["--report", duplicateShaReport], /exactly one Reviewed commit/);
  const missingCommitReport = path.join(temp, "report-missing-commit.md");
  writeFileSync(missingCommitReport, firstReport.replace(/\| Reviewed commit \|.*\n/, ""));
  reject("missing Reviewed commit", ["--report", missingCommitReport], /exactly one Reviewed commit/);

  const invalidCommitReport = path.join(temp, "report-invalid-commit.md");
  writeFileSync(invalidCommitReport, firstReport.replace("a".repeat(40), "not-a-commit"));
  reject("invalid Reviewed commit", ["--report", invalidCommitReport], /invalid exact Reviewed commit/);
  const durable = readFileSync(durableReport, "utf8");
  const duplicateDecisionLocator = path.join(temp, "report-decision-duplicate-locator.md");
  writeFileSync(duplicateDecisionLocator, durable.replace(
    "| Report locator | `review-report:b-milescu/skills#361:4` |",
    "| Report locator | `review-report:b-milescu/skills#361:4` |\n| Report locator | `review-report:b-milescu/skills#361:4` |",
  ));
  reject("duplicate Decision Summary locator", ["--report", duplicateDecisionLocator], /exactly one Report locator/);

  const conflictingDecisionLocator = path.join(temp, "report-decision-conflicting-locator.md");
  writeFileSync(conflictingDecisionLocator, durable.replace(
    "| Report locator | `review-report:b-milescu/skills#361:4` |",
    "| Report locator | `review-report:b-milescu/skills#361:99` |",
  ));
  reject("conflicting Decision Summary locator", ["--report", conflictingDecisionLocator], /contradicts finding identities/);

  const mismatchedDecisionTuple = path.join(temp, "report-decision-tuple-mismatch.md");
  writeFileSync(mismatchedDecisionTuple, durable.replace(
    "| `review-report:b-milescu/skills#361:4` | `1ab7ad068c2c71c4ac9d68d59fa083936c930e9d` | `MF-1` |",
    "| `review-report:b-milescu/skills#361:99` | `1ab7ad068c2c71c4ac9d68d59fa083936c930e9d` | `MF-1` |",
  ));
  reject("Decision Summary tuple mismatch", ["--report", mismatchedDecisionTuple], /contradicts finding identities/);

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
      "id=MF-5<br>report=review-report:b-milescu/skills#340:1; sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; id=MF-5` |",
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

  const fourCellDelimiterReport = path.join(temp, "report-four-cell-delimiter.md");
  writeFileSync(fourCellDelimiterReport, firstReport.replace("|---|---|---|", "|---|---|---|---|"));
  reject(
    "four-cell finding identity delimiter",
    ["--report", fourCellDelimiterReport],
    /identity table delimiter must have exactly three cells/,
  );

  const protectedValue = "PROTECTED-ARTIFACT-BODY-SENTINEL";
  const protectedValueReport = path.join(temp, "report-protected-invalid-id.md");
  writeFileSync(protectedValueReport, firstReport.replace("| `MF-5` |", `| \`${protectedValue}\` |`));
  rejectWithoutEcho(
    "invalid identity value echoed artifact body",
    ["--report", protectedValueReport],
    protectedValue,
    /invalid finding ID/,
  );

  const missingCanonicalIdentityReport = path.join(temp, "report-missing-canonical-identity.md");
  writeFileSync(
    missingCanonicalIdentityReport,
    firstReport.replace("The first report's finding.", "The first report's finding.\n\n#### SF-9: Unregistered report finding"),
  );
  reject(
    "report finding without canonical identity",
    ["--report", missingCanonicalIdentityReport],
    /finding SF-9 lacks its canonical identity tuple/,
  );

  const phantomReport = path.join(temp, "report-phantom-identity.md");
  const phantomRow = "| `review-report:b-milescu/skills#340:1` | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` | `SF-9` |";
  writeFileSync(phantomReport, firstReport.replace(packetRow, `${packetRow}\n${phantomRow}`));
  const phantomPacket = path.join(temp, "revision-phantom-identity.md");
  writeFileSync(phantomPacket, packet.replaceAll("MF-5", "SF-9"));
  reject(
    "identity absent from report findings",
    ["--report", phantomReport, "--packet", phantomPacket],
    /registered identity SF-9 is not a report finding/,
  );

  // Machine-read Decision Summary / Context-Snapshot cells must hold one bare value: trailing prose
  // inside the value slot makes provider-side reviewed-SHA and finding extraction drop the claims.
  const prose = " (equals provider head at decision time)";
  const decisionProseCommit = path.join(temp, "report-decision-prose-commit.md");
  writeFileSync(
    decisionProseCommit,
    durable.replace(
      "| Reviewed commit | `1ab7ad068c2c71c4ac9d68d59fa083936c930e9d` |\n| Report locator |",
      `| Reviewed commit | \`1ab7ad068c2c71c4ac9d68d59fa083936c930e9d\`${prose} |\n| Report locator |`,
    ),
  );
  reject(
    "prose after the Decision Summary Reviewed commit value",
    ["--report", decisionProseCommit],
    /Decision Summary Reviewed commit cell must be a bare commit/,
  );

  const snapshotProseCommit = path.join(temp, "report-snapshot-prose-commit.md");
  writeFileSync(
    snapshotProseCommit,
    firstReport.replace(
      "| Reviewed commit | `aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |",
      `| Reviewed commit | \`aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\`${prose} |`,
    ),
  );
  reject(
    "prose after the Context / Snapshot Reviewed commit value",
    ["--report", snapshotProseCommit],
    /Context \/ Snapshot Reviewed commit cell must be a bare commit/,
  );

  const summaryRow = "| Findings summary | `MF: MF-1, MF-2; SF: 0; C: 0` |";
  const withSummary = (body) => body.replace("| Report locator | `review-report:b-milescu/skills#361:4` |", `${summaryRow}\n| Report locator | \`review-report:b-milescu/skills#361:4\` |`);
  const bareSummaryReport = path.join(temp, "report-bare-findings-summary.md");
  writeFileSync(bareSummaryReport, withSummary(durable));
  run(["--report", bareSummaryReport], 0, /reports=1 identities=2 artifacts=0/);

  const proseSummaryReport = path.join(temp, "report-prose-findings-summary.md");
  writeFileSync(proseSummaryReport, withSummary(durable).replace(summaryRow, `| Findings summary | \`MF: MF-1, MF-2; SF: 0; C: 0\` — both block the candidate |`));
  reject(
    "prose after the Findings summary value",
    ["--report", proseSummaryReport],
    /Findings summary cell must be a bare MF\/SF\/C list/,
  );

  const droppedSummaryReport = path.join(temp, "report-dropped-findings-summary.md");
  writeFileSync(droppedSummaryReport, withSummary(durable).replace(summaryRow, "| Findings summary | `MF: MF-1; SF: 0; C: 0` |"));
  reject(
    "Findings summary omitting a registered finding",
    ["--report", droppedSummaryReport],
    /Findings summary IDs do not match the finding identity table/,
  );

  const proseSentinel = "PROTECTED-PROSE-SENTINEL";
  const echoedProseReport = path.join(temp, "report-prose-echo.md");
  writeFileSync(
    echoedProseReport,
    durable.replace(
      "| Reviewed commit | `1ab7ad068c2c71c4ac9d68d59fa083936c930e9d` |\n| Report locator |",
      `| Reviewed commit | \`1ab7ad068c2c71c4ac9d68d59fa083936c930e9d\` ${proseSentinel} |\n| Report locator |`,
    ),
  );
  rejectWithoutEcho(
    "bare-cell rejection echoed artifact body",
    ["--report", echoedProseReport],
    proseSentinel,
    /Decision Summary Reviewed commit cell must be a bare commit/,
  );

  assert.deepEqual(acceptedInvalid, [], `validator accepted invalid artifacts: ${acceptedInvalid.join(", ")}`);

  const unstableReport = path.join(temp, "report-pending.md");
  writeFileSync(
    unstableReport,
    readFileSync(reports[0], "utf8").replaceAll("review-report:b-milescu/skills#340:1", "pending"),
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
