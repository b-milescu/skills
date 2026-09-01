import { readFileSync } from "node:fs";
import yaml from "js-yaml";

const unsafeControl = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/;

// Signature fields whose value proves which gate behaviour the child actually
// took, drawn verbatim from start-build/templates/builder-final-handoff.md.
// The Gate owner line is the sole binding selection; when the echoed
// gate_owner_received disagrees with an observed-behaviour signature the
// handoff is rejected without judgment (issue #398).
const parentOwnedSignatures = [
  { path: "gate_ownership.builder_gate_status.not_run_reason", value: "parent-owned" },
  { path: "delivery.local_gate.not_run_reason", value: "parent-owned" },
  { path: "gate_ownership.local_gate_owner", value: "parent" },
  { path: "gate_ownership.ready_transition_owner", value: "parent" },
  { path: "status", value: "candidate-for-parent-gate" },
  { path: "next_action", value: "parent-run-gate" },
];
const builderOwnedSignatures = [
  { path: "status", value: "ready-for-review" },
  { path: "gate_ownership.ready_transition_owner", value: "builder" },
  { path: "gate_ownership.builder_gate_status.status", value: "pass" },
];
const requiredContractFields = ["phase", "expected_next_actor", "expected_next_action", "blocked"];

function fail(message) {
  console.error(`handoff gate-consistency validation failed: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  if (argv.length !== 2 || argv[0] !== "--handoff" || !argv[1]) fail("usage: --handoff <path>");
  return argv[1];
}

function readSafe(path) {
  let body;
  try {
    body = readFileSync(path, "utf8");
  } catch {
    fail("cannot read handoff");
  }
  if (unsafeControl.test(body)) fail("handoff contains unsafe control characters");
  return body;
}

// Accept either a raw YAML handoff or the markdown template's fenced block.
function extractYaml(body) {
  const begin = "<!-- AGENT-HANDOFF:BUILDER-FINAL:BEGIN -->";
  const end = "<!-- AGENT-HANDOFF:BUILDER-FINAL:END -->";
  const first = body.indexOf(begin);
  if (first < 0) return body;
  const last = body.indexOf(end, first);
  if (last <= first) fail("unterminated AGENT-HANDOFF block");
  const fence = body.slice(first + begin.length, last).match(/```ya?ml\s*\n([\s\S]*?)\n```/);
  if (!fence) fail("missing yaml fence in AGENT-HANDOFF block");
  return fence[1];
}

function get(object, path) {
  return path.split(".").reduce((node, key) => (node !== null && typeof node === "object" ? node[key] : undefined), object);
}

const path = parseArgs(process.argv.slice(2));
let document;
try {
  document = yaml.load(extractYaml(readSafe(path)), { schema: yaml.JSON_SCHEMA });
} catch {
  fail("invalid handoff YAML");
}
if (document === null || typeof document !== "object" || typeof document.agent_handoff !== "object" || document.agent_handoff === null) {
  fail("missing agent_handoff object");
}

const handoff = document.agent_handoff;
const received = get(handoff, "gate_owner_received");
if (received !== "builder" && received !== "parent") {
  fail(`invalid gate_owner_received: ${JSON.stringify(received)} (expected "builder" or "parent")`);
}

const contradicting = (received === "builder" ? parentOwnedSignatures : builderOwnedSignatures).filter(
  (signature) => get(handoff, signature.path) === signature.value,
);

if (contradicting.length > 0) {
  const pairs = contradicting.map((signature) => `gate_owner_received=${received} vs ${signature.path}=${signature.value}`).join("; ");
  const took = received === "builder" ? "parent-owned" : "builder-owned";
  fail(`gate_owner_received=${received} contradicts observed ${took} gate behaviour: ${pairs}`);
}

const contractPath = "agent_handoff.delivery.handoff_contract";
const contract = get(handoff, "delivery.handoff_contract");
if (contract === undefined) {
  if (get(handoff, "handoff_contract") !== undefined) {
    fail(`misplaced agent_handoff.handoff_contract; expected ${contractPath}`);
  }
  fail(`missing ${contractPath}`);
}
for (const field of requiredContractFields) {
  if (get(contract, field) === undefined) fail(`missing ${contractPath}.${field}`);
}

console.log("handoff gate-consistency validation: PASS");
