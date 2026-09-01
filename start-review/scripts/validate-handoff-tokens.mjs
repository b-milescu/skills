import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import yaml from "js-yaml";

const unsafeControl = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/;

function fail(message) {
  console.error(`handoff token validation failed: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  if (argv.length !== 2 || argv[0] !== "--handoff" || !argv[1]) fail("usage: --handoff <path>");
  return argv[1];
}

function readSafe(path, label) {
  let body;
  try {
    body = readFileSync(path, "utf8");
  } catch {
    fail(`cannot read ${label}`);
  }
  if (unsafeControl.test(body)) fail(`${label} contains unsafe control characters`);
  return body;
}

// Match the existing gate-consistency validator's raw-YAML/marked-fence input contract.
function extractYaml(body) {
  const marker = body.match(/<!-- AGENT-HANDOFF:(BUILDER|REVIEWER)-FINAL:BEGIN -->/);
  if (!marker) return body;
  const end = `<!-- AGENT-HANDOFF:${marker[1]}-FINAL:END -->`;
  const last = body.indexOf(end, marker.index + marker[0].length);
  if (last < 0) fail("unterminated AGENT-HANDOFF block");
  const fence = body.slice(marker.index + marker[0].length, last).match(/```ya?ml\s*\n([\s\S]*?)\n```/);
  if (!fence) fail("missing yaml fence in AGENT-HANDOFF block");
  return fence[1];
}

function get(object, path) {
  return path.split(".").reduce((node, key) => (node !== null && typeof node === "object" ? node[key] : undefined), object);
}

const root = dirname(fileURLToPath(import.meta.url));
let tokens;
try {
  tokens = JSON.parse(readSafe(join(root, "../reference/handoff-tokens.schema.json"), "token schema"));
} catch {
  fail("invalid token schema JSON");
}
if (tokens === null || typeof tokens !== "object") fail("invalid token schema object");

const path = parseArgs(process.argv.slice(2));
let document;
try {
  document = yaml.load(extractYaml(readSafe(path, "handoff")), { schema: yaml.JSON_SCHEMA });
} catch {
  fail("invalid handoff YAML");
}
if (document === null || typeof document !== "object" || document.agent_handoff === null || typeof document.agent_handoff !== "object") {
  fail("missing agent_handoff object");
}

const handoff = document.agent_handoff;
if (handoff.kind !== "builder-final" && handoff.kind !== "reviewer-final") {
  fail(`invalid agent_handoff.kind: ${JSON.stringify(handoff.kind)}`);
}

const fields = [["delivery.handoff_contract.blocker_token", "blocker_token"]];
if (handoff.kind === "reviewer-final") {
  fields.push(["review_verdict", "review_verdict"], ["action_blocker", "action_blocker"], ["next_action", "next_action"]);
}

for (const [field, schemaField] of fields) {
  const allowed = tokens[schemaField];
  if (!Array.isArray(allowed) || allowed.some((value) => typeof value !== "string")) fail(`invalid token schema field: ${schemaField}`);
  const value = get(handoff, field);
  if (typeof value !== "string" || !allowed.includes(value)) {
    fail(`invalid agent_handoff.${field}: ${JSON.stringify(value)}`);
  }
}

if (
  (get(handoff, "delivery.handoff_contract.blocker_token") === "other" || get(handoff, "action_blocker") === "other") &&
  (typeof handoff.blocker_detail !== "string" || handoff.blocker_detail.trim() === "")
) {
  fail("agent_handoff.blocker_detail must be a non-empty string when a blocker token is other");
}

console.log("handoff token validation: PASS");
