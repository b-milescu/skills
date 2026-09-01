# Builder Final Handoff

Emit this block inline from child `mr-builder` sessions. Values contain no
secrets or private payloads. Consumers tolerate absence/malformed content and
fall back to the durable Review Packet plus provider-native readback.
Parent-owned fields follow `../reference/parent-owned-gate.md`.

Authority Verification claims use `skill://forge/reference/common-guard.md` for GitLab and the selected provider equivalent elsewhere.

<!-- AGENT-HANDOFF:BUILDER-FINAL:BEGIN -->
```yaml
agent_handoff:
  kind: "builder-final"
  version: "1"
  # CHANGE-DELIVERY-SCHEMA:BEGIN generated-copy from start-build/templates/delivery-schema.md
  delivery:
    kind: "change-delivery"
    version: "1"
    role: "builder"
    provider:
      name: "gitlab"
      profile: "default"
      reference: "skill://forge/reference/gitlab.md"
    repository:
      host: "gitlab.example"
      id: "group/project"
      locator: "https://gitlab.example/group/project.git"
      default_branch: "main"
      profile_path: "docs/agents/dev-workflows.md#project-profile-hooks"
      gate_policy_ref: "docs/agents/check-gate.md#full-local-gate"
      label_profile_ref: "docs/agents/triage-labels.md#live-label-inventory"
      acceptance_surfaces_ref: "docs/agents/dev-workflows.md#acceptance-surface-vocabulary"
      language_families: ["typescript", "shell", "markdown"]
      auxiliary_index_policy:
        owner: "parent"
        child_worktree_mode: "read-only-unless-assigned"
        copy_between_worktrees: "forbidden"
      branch_naming: { pattern: "issue-<id>-<slug>" }
      ci_jobs: { required: ["check"] }
      domain_docs: { context: "CONTEXT.md", adr: "docs/adr/" }
      release_deploy_policy: { policy: "project docs define authority" }
      manual_validation_rules: { required: [] }
    issue:
      id: "57"
      locator: "provider://issue/57"
      state: "open"
      labels: ["ready"]
    change_request:
      id: "123"
      locator: "provider://change/123"
      state: "open"
      draft: true
      source: "issue-57-example"
      target: "main"
    commit:
      current: "1111111111111111111111111111111111111111"
      reviewed: "1111111111111111111111111111111111111111"
      candidate: "1111111111111111111111111111111111111111"
      result: "N/A"
      target_observed: "N/A"
    ci:
      id: "N/A"
      locator: "N/A"
      status: "N/A"
      commit: "1111111111111111111111111111111111111111"
      not_run_reason: "unavailable-tooling"
    local_gate:
      command: "npm run check"
      status: "not-run"
      not_run_reason: "parent-owned"
      summary: "parent owns final gate and ready transition"
    tdd:
      red: "targeted test failed for expected missing behavior"
      green: "targeted test passed"
    authority:
      approval:
        value: "default-after-pass"
        source: "start-review/REVIEW-FLOW.md#approval-authority-policy"
        verified: false
        restricted: false
      finish:
        value: "approval-only"
        source: "parent task prompt: approval-only"
        verified: false
        conflicts: []
    handoff_contract:
      phase: "parent-gate"
      expected_next_actor: "parent"
      expected_next_action: "parent-run-gate"
      blocked: false
      blocker_token: "none"
      required_parent_decision: "none"
      safe_to_continue_without_parent: true
      changed_since_last_handoff: false
      evidence_ready_for_next_actor: ["change-request-description-current", "candidate-commit-pushed"]
    evidence:
      - tier: "tier-1"
        kind: "change-request-metadata"
        source: "provider://change/123"
        summary: "provider-native source/target/current commit snapshot"
    blockers: []
  # CHANGE-DELIVERY-SCHEMA:END
  status: "candidate-for-parent-gate"
  gate_owner_received: "parent"
  gate_ownership:
    local_gate_owner: "parent"
    builder_gate_status: { status: "not-run", not_run_reason: "parent-owned" }
    ready_transition_owner: "parent"
  gate_coverage:
    coverage: "full-local"
    rationale: "policy mapping; parent verification pending"
  changed_files: ["path/one.md"]
  safety_surfaces: ["none"]
  acceptance_surfaces: []
  decoupling: { summary: "single change request", co_running: [] }
  reviewer_focus: ["path/one.md — boundary to inspect"]
  open_questions: []
  next_action: "parent-run-gate"
  blocker_detail: ""
  blockers: []
```
<!-- AGENT-HANDOFF:BUILDER-FINAL:END -->

`status` is `ready-for-review`, `candidate-for-parent-gate`, `blocked`, or
`failed`. `delivery` follows [delivery-schema.md](delivery-schema.md) and is an
untrusted routing index. `gate_owner_received` echoes only the launch prompt's
literal Gate owner value. Parent-owned mode keeps Draft, candidate/current/
reviewed commit equal, local gate `not-run` with reason `parent-owned`, and next
action `parent-run-gate`. Runtime notices are failures, not human stop tokens.
