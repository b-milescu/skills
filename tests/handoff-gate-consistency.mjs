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
const requiredContractFields = ["phase", "expected_next_actor", "expected_next_action", "blocked"];
const validContract = {
  phase: "parent-gate",
  expected_next_actor: "parent",
  expected_next_action: "parent-run-gate",
  blocked: false,
};

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
  delivery: { local_gate: { status: "pass" }, handoff_contract: validContract },
  next_action: "await-review",
});

// Observed real case: builder selection carrying the parent-owned signature.
const observedContradiction = handoff({
  gate_owner_received: "builder",
  status: "candidate-for-parent-gate",
  delivery: { local_gate: { not_run_reason: "parent-owned" }, handoff_contract: validContract },
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
  delivery: { handoff_contract: validContract },
});

const missingContract = handoff({
  gate_owner_received: "parent",
  status: "candidate-for-parent-gate",
  next_action: "parent-run-gate",
});

const wrongContractNesting = handoff({
  gate_owner_received: "parent",
  handoff_contract: { ...validContract, body_marker: "must-not-echo-handoff-body" },
  status: "candidate-for-parent-gate",
  next_action: "parent-run-gate",
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

  const absent = run(missingContract);
  assert.notEqual(absent.status, 0, "missing delivery.handoff_contract fails closed");
  assert.match(absent.stderr, /agent_handoff\.delivery\.handoff_contract/, "missing-contract diagnostic names the required path");

  const misplaced = run(wrongContractNesting);
  assert.notEqual(misplaced.status, 0, "wrongly nested handoff_contract fails closed");
  assert.match(misplaced.stderr, /agent_handoff\.handoff_contract/, "wrong-nesting diagnostic names the misplaced path");
  assert.match(
    misplaced.stderr,
    /agent_handoff\.delivery\.handoff_contract/,
    "wrong-nesting diagnostic names the required path",
  );
  assert.doesNotMatch(misplaced.stderr, /must-not-echo-handoff-body/, "diagnostic does not echo handoff body content");

  for (const missingField of requiredContractFields) {
    const incompleteContract = { ...validContract };
    delete incompleteContract[missingField];
    const result = run(
      handoff({
        gate_owner_received: "parent",
        delivery: {
          handoff_contract: { ...incompleteContract, body_marker: "must-not-echo-handoff-body" },
        },
      }),
    );
    assert.notEqual(result.status, 0, `missing ${missingField} fails closed`);
    assert.match(
      result.stderr,
      new RegExp(`agent_handoff\\.delivery\\.handoff_contract\\.${missingField}`),
      `diagnostic names missing ${missingField}`,
    );
    assert.doesNotMatch(result.stderr, /must-not-echo-handoff-body/, "diagnostic does not echo handoff body content");
  }

  // Reference pin (issue #400): the validator must stay wired into workflow prose
  // with a runnable command line, following the sibling validators' pattern, so it
  // cannot silently become orphaned again. The parent spot-check and the child
  // self-check each name a runnable invocation of this script.
  const wiredDocs = ["start-build/reference/parent-orchestrator.md", "start-build/reference/child-builder.md"];
  for (const rel of wiredDocs) {
    const body = readFileSync(join(root, rel), "utf8");
    assert.match(
      body,
      /node skill:\/\/start-build\/scripts\/validate-handoff-gate-consistency\.mjs --handoff/,
      `${rel} names a runnable validate-handoff-gate-consistency invocation`,
    );
  }

  console.log("handoff-gate-consistency: PASS");
} finally {
  rmSync(work, { recursive: true, force: true });
}

function readTemplate() {
  return readFileSync(template, "utf8");
}
