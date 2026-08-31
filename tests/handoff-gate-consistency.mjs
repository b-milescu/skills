import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import yaml from "js-yaml";

const root = resolve(import.meta.dirname, "..");
const validator = join(root, "start-build/scripts/validate-handoff-gate-consistency.mjs");
const template = join(root, "start-build/templates/builder-final-handoff.md");
const work = mkdtempSync(join(tmpdir(), "handoff-gate-"));

function run(source) {
  const path = join(work, "handoff.md");
  writeFileSync(path, source);
  return spawnSync(process.execPath, [validator, "--handoff", path], { encoding: "utf8" });
}

function handoff(agent_handoff) {
  return yaml.dump({ agent_handoff });
}

// Valid builder-owned handoff: gate_owner_received builder plus a builder-owned signature.
const validBuilderOwned = handoff({
  gate_owner_received: "builder",
  status: "ready-for-review",
  gate_ownership: {
    local_gate_owner: "builder",
    ready_transition_owner: "builder",
    builder_gate_status: { status: "pass" },
  },
  delivery: { local_gate: { status: "pass" } },
  next_action: "await-review",
});

// Observed real case: builder selection carrying the parent-owned signature.
const observedContradiction = handoff({
  gate_owner_received: "builder",
  status: "candidate-for-parent-gate",
  delivery: { local_gate: { not_run_reason: "parent-owned" } },
  next_action: "parent-run-gate",
});

// Inverse: parent selection carrying a builder-owned signature.
const inverseContradiction = handoff({
  gate_owner_received: "parent",
  status: "ready-for-review",
  gate_ownership: {
    ready_transition_owner: "builder",
    builder_gate_status: { status: "pass" },
  },
});

try {
  // Both real template example blocks (parent-owned) must still pass.
  assert.equal(run(readTemplate()).status, 0, "shipped template example passes");
  assert.equal(run(validBuilderOwned).status, 0, "valid builder-owned handoff passes");

  const observed = run(observedContradiction);
  assert.notEqual(observed.status, 0, "observed builder-owned contradiction fails closed");
  // Diagnostic names the contradicting field pair.
  assert.match(observed.stderr, /gate_owner_received/, "diagnostic names gate_owner_received");
  assert.match(observed.stderr, /next_action=parent-run-gate/, "diagnostic names the contradicting field pair");

  const inverse = run(inverseContradiction);
  assert.notEqual(inverse.status, 0, "inverse parent-owned contradiction fails closed");
  assert.match(inverse.stderr, /ready_transition_owner=builder/, "inverse diagnostic names the contradicting field pair");

  // A missing/invalid gate_owner_received fails closed rather than silently passing.
  assert.notEqual(run(handoff({ status: "ready-for-review" })).status, 0, "missing gate_owner_received fails");

  console.log("handoff-gate-consistency: PASS");
} finally {
  rmSync(work, { recursive: true, force: true });
}

function readTemplate() {
  return readFileSync(template, "utf8");
}
