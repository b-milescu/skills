#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
TEST_NAME=agent-handoff-templates
source tests/lib/assertions.sh

builder=start-build/templates/builder-final-handoff.md
reviewer=start-review/templates/reviewer-final-handoff.md
for file in "$builder" "$reviewer"; do
  assert_file_contains "$file" 'kind: "change-delivery"' "$file neutral delivery kind"
  assert_file_contains "$file" 'CHANGE-DELIVERY-SCHEMA:BEGIN' "$file generated copy"
  assert_file_contains "$file" handoff_contract "$file routing contract"
  assert_file_contains "$file" expected_next_actor "$file next actor"
  assert_file_contains "$file" expected_next_action "$file next action"
  assert_file_contains "$file" evidence_ready_for_next_actor "$file evidence pointers"
  assert_file_not_contains "$file" gitlab.example.com "$file contains no live locator"
done
for field in status gate_owner_received gate_ownership gate_coverage changed_files safety_surfaces acceptance_surfaces decoupling reviewer_focus open_questions next_action blockers; do
  assert_file_contains "$builder" "  $field:" "builder top-level $field"
done
for field in review_verdict report_locator report_url reviewed_commit ci local_checks findings open_questions approval_authority approval_authority_source approval_action finish_authority finish_authority_source finish_action action_blocker next_action next_actor blockers; do
  assert_file_contains "$reviewer" "  $field:" "reviewer top-level $field"
done
node --input-type=module - "$builder" "$reviewer" <<'NODE'
import fs from "node:fs";
import yaml from "js-yaml";
for (const file of process.argv.slice(2)) {
  const text = fs.readFileSync(file, "utf8");
  const blocks = [...text.matchAll(/```yaml\n([\s\S]*?)\n```/g)];
  if (blocks.length !== 1) throw new Error(`${file}: expected one YAML block`);
  const handoff = yaml.load(blocks[0][1])?.agent_handoff;
  if (!handoff || handoff.delivery?.kind !== "change-delivery") throw new Error(`${file}: invalid neutral handoff`);
  const contract = handoff.delivery.handoff_contract;
  for (const field of ["phase", "expected_next_actor", "expected_next_action", "blocked", "blocker_token", "required_parent_decision", "safe_to_continue_without_parent", "changed_since_last_handoff", "evidence_ready_for_next_actor"]) {
    if (!(field in contract)) throw new Error(`${file}: missing ${field}`);
  }
  if (handoff.next_action && handoff.next_action !== contract.expected_next_action) throw new Error(`${file}: next action mismatch`);
  if (file.endsWith("reviewer-final-handoff.md")) {
    for (const field of ["report_locator", "report_url", "reviewed_commit", "ci", "local_checks", "findings", "open_questions", "approval_authority", "approval_authority_source", "approval_action", "finish_authority", "finish_authority_source", "finish_action", "action_blocker", "next_action", "next_actor"]) {
      if (!(field in handoff)) throw new Error(`${file}: missing top-level ${field}`);
    }
    if (handoff.next_actor !== contract.expected_next_actor) throw new Error(`${file}: next actor mismatch`);
    if (handoff.ci.commit !== handoff.reviewed_commit) throw new Error(`${file}: CI commit is not review-bound`);
    for (const finding of handoff.findings) {
      for (const field of ["id", "report_locator", "reviewed_commit", "locations", "remedy_direction"]) {
        if (!(field in finding)) throw new Error(`${file}: finding missing ${field}`);
      }
      if (finding.report_locator !== handoff.report_locator || finding.reviewed_commit !== handoff.reviewed_commit) {
        throw new Error(`${file}: finding tuple is not report-bound`);
      }
    }
  }
}
NODE
printf '%s\n' "agent-handoff-templates: PASS"
