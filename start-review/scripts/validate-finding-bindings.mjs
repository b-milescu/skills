import { readFileSync } from "node:fs";

const BEGIN = "<!-- FINDING-IDENTITY-SCHEMA:BEGIN -->";
const END = "<!-- FINDING-IDENTITY-SCHEMA:END -->";
const ID = /\b(?:MF|SF|C)-\d+\b/g;
const SHA = /^[0-9a-f]{40}$/i;
const LOCATOR = /^(?:review-report:[^;\s]+|https?:\/\/[^;\s]+)$/;

function fail(message, status = 2) {
  console.error(`finding-bindings: FAIL: ${message}`);
  process.exit(status);
}

function parseArgs(argv) {
  const values = { report: [], packet: [], lift: [] };
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index]?.replace(/^--/, "");
    const value = argv[index + 1];
    if (!Object.hasOwn(values, key) || !value) fail("usage: --report <file> [--report <file> ...] [--packet <file> ...] [--lift <file> ...]", 64);
    values[key].push(value);
  }
  if (values.report.length + values.packet.length + values.lift.length === 0) fail("at least one input is required", 64);
  return values;
}

function read(file) {
  try {
    return readFileSync(file, "utf8").replace(/\r\n?/g, "\n");
  } catch {
    fail(`cannot read ${file}`, 64);
  }
}

function clean(value) {
  return value.trim().replace(/^`|`$/g, "").trim();
}

function table(body, file) {
  const first = body.indexOf(BEGIN);
  const last = body.indexOf(END);
  if (first < 0 || last <= first || body.indexOf(BEGIN, first + BEGIN.length) >= 0 || body.indexOf(END, last + END.length) >= 0) {
    return null;
  }
  const rows = body.slice(first + BEGIN.length, last).split("\n").map((line) => line.trim()).filter((line) => line.startsWith("|")).map((line) => line.slice(1, -1).split("|").map(clean));
  if (rows.length < 2 || rows[0].length !== 3 || rows[0].join("|") !== "Report locator|Reviewed SHA|Finding ID") fail(`${file}: invalid finding identity table header`);
  if (rows[1].length !== 3 || rows[1].join("|") !== "---|---|---") fail(`${file}: identity table delimiter must have exactly three cells`);
  const data = rows.slice(2).filter((row) => row.some(Boolean));
  if (data.some((row) => row.length !== 3)) fail(`${file}: identity table rows must have exactly three cells`);
  return data.map(([report, sha, id]) => ({ report, sha, id }));
}

function fields(body, name) {
  return body.split("\n").flatMap((line) => {
    const cells = line.trim().startsWith("|") ? line.trim().slice(1, -1).split("|").map(clean) : [];
    return cells.length === 2 && cells[0] === name ? [cells[1] ?? ""] : [];
  });
}

function ids(body) {
  return new Set(body.match(ID) ?? []);
}

function rejectDuplicateBindings(bindings, file) {
  const seen = new Set();
  for (const binding of bindings) {
    const key = `${binding.report}\u0000${binding.sha.toLowerCase()}\u0000${binding.id}`;
    if (seen.has(key)) fail(`${file}: duplicate finding identity ${binding.id}`);
    seen.add(key);
  }
}

const args = parseArgs(process.argv.slice(2));
const registry = new Map();
const byId = new Map();
const locatorShas = new Map();
const shaLocators = new Map();

for (const file of args.report) {
  const body = read(file);
  const snapshot = body.split(/^## Context \/ Snapshot\s*$/m)[1]?.split(/^## /m)[0] ?? "";
  const decision = body.split(/^## Decision Summary\s*$/m)[1]?.split(/^## /m)[0] ?? "";
  const bindings = table(body, file);
  if (!bindings) fail(`${file}: missing finding identity table`);

  const snapshotLocators = fields(snapshot, "Report locator");
  const decisionLocators = fields(decision, "Report locator");
  if (snapshotLocators.length > 1) fail(`${file}: report must contain exactly one Report locator`);
  let report = snapshotLocators[0];
  if (!report) {
    if (decisionLocators.length !== 1) fail(`${file}: report must contain exactly one Report locator`);
    report = decisionLocators[0];
    if (bindings.some((binding) => binding.report !== report)) {
      fail(`${file}: Decision Summary Report locator contradicts finding identities`);
    }
  } else if (decisionLocators.some((locator) => locator !== report)) {
    fail(`${file}: report contains contradictory Report locators`);
  }

  const shaFields = fields(snapshot, "Reviewed commit");
  if (shaFields.length !== 1) fail(`${file}: report must contain exactly one Reviewed commit`);
  const decisionShas = fields(decision, "Reviewed commit");
  const sha = shaFields[0].toLowerCase();
  if (decisionShas.some((value) => value.toLowerCase() !== sha)) {
    fail(`${file}: report contains contradictory Reviewed commits`);
  }
  if (!report || !LOCATOR.test(report)) fail(`${file}: missing or invalid stable Report locator`);
  if (!SHA.test(sha)) fail(`${file}: missing or invalid exact Reviewed commit`);
  if (locatorShas.has(report) && locatorShas.get(report) !== sha) fail(`${file}: report locator has contradictory reviewed SHAs`);
  locatorShas.set(report, sha);
  if (!shaLocators.has(sha)) shaLocators.set(sha, new Set());
  shaLocators.get(sha).add(report);

  rejectDuplicateBindings(bindings, file);
  for (const binding of bindings) {
    if (binding.report !== report || binding.sha.toLowerCase() !== sha) fail(`${file}: finding identity contradicts report locator or reviewed SHA`);
    if (!/^(?:MF|SF|C)-\d+$/.test(binding.id)) fail(`${file}: invalid finding ID`);
    const key = `${report}\u0000${sha}\u0000${binding.id}`;
    if (registry.has(key)) fail(`${file}: duplicate finding identity ${binding.id}`);
    registry.set(key, { report, sha, id: binding.id });
    if (!byId.has(binding.id)) byId.set(binding.id, []);
    byId.get(binding.id).push({ report, sha, id: binding.id });
  }

  const findingIds = ids(body.split(/^## Findings\s*$/m)[1]?.split(/^## /m)[0] ?? "");
  for (const binding of bindings) {
    if (!findingIds.has(binding.id)) fail(`${file}: registered identity ${binding.id} is not a report finding`);
  }
  for (const id of findingIds) {
    if (![...registry.values()].some((binding) => binding.report === report && binding.sha === sha && binding.id === id)) {
      fail(`${file}: finding ${id} lacks its canonical identity tuple`);
    }
  }
}

function classify(binding, file) {
  const matches = byId.get(binding.id) ?? [];
  if (!binding.report) {
    if (matches.length > 1) fail(`${file}: ambiguous finding ID ${binding.id}; add report locator and reviewed SHA`);
    fail(`${file}: missing report locator for ${binding.id}`);
  }
  if (!binding.sha) fail(`${file}: missing reviewed SHA for ${binding.id}`);
  if (!SHA.test(binding.sha)) fail(`${file}: invalid reviewed SHA for ${binding.id}`);
  binding.sha = binding.sha.toLowerCase();
  if (registry.has(`${binding.report}\u0000${binding.sha}\u0000${binding.id}`)) return;
  if (locatorShas.has(binding.report) && shaLocators.has(binding.sha) && !shaLocators.get(binding.sha).has(binding.report)) {
    fail(`${file}: contradictory finding binding for ${binding.id}`);
  }
  if (locatorShas.has(binding.report)) fail(`${file}: stale finding binding for ${binding.id}`);
  fail(`${file}: unknown report locator for ${binding.id}`);
}

let artifacts = 0;
for (const file of args.packet) {
  artifacts += 1;
  const body = read(file);
  const referenced = ids(body.split(/^## Response to /m).slice(1).join("\n"));
  const bindings = table(body, file);
  if (!bindings) {
    for (const id of referenced) classify({ report: "", sha: "", id }, file);
    fail(`${file}: missing finding identity table`);
  }
  rejectDuplicateBindings(bindings, file);
  for (const binding of bindings) classify(binding, file);
  for (const id of referenced) {
    if (!bindings.some((binding) => binding.id === id)) classify({ report: "", sha: "", id }, file);
  }
}

for (const file of args.lift) {
  artifacts += 1;
  const body = read(file);
  const values = fields(body, "Finding bindings");
  if (values.length !== 1) fail(`${file}: expected exactly one Reviewer Lift Finding bindings row`);
  const value = values[0];
  if (!value) fail(`${file}: missing Reviewer Lift Finding bindings row`);
  if (/^none$/i.test(value)) continue;
  const bindings = value.split(/<br\s*\/?\s*>/i).map((entry) => {
    const match = entry.match(/^report=([^;]+);\s*sha=([^;]*);\s*id=((?:MF|SF|C)-\d+)$/);
    if (match) return { report: match[1].trim(), sha: match[2].trim(), id: match[3] };
    const [id] = entry.match(ID) ?? [];
    if (id) return { report: "", sha: "", id };
    fail(`${file}: invalid Reviewer Lift Finding bindings value`);
  });
  rejectDuplicateBindings(bindings, file);
  for (const binding of bindings) classify(binding, file);
}

console.log(`finding-bindings: PASS reports=${args.report.length} identities=${registry.size} artifacts=${artifacts}`);
