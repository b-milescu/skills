# Reviewer Final Handoff

Emit after publishing and reading back the durable Review Report. Values are
claims/indexes until the next actor verifies provider-native evidence.

Authority Verification claims use `skill://forge/reference/common-guard.md` for GitLab and the selected provider equivalent elsewhere.

<!-- AGENT-HANDOFF:REVIEWER-FINAL:BEGIN -->
```yaml
agent_handoff:
  kind: "reviewer-final"
  version: "1"
  # CHANGE-DELIVERY-SCHEMA:BEGIN generated-copy from start-build/templates/delivery-schema.md
  delivery:
    kind: "change-delivery"
    version: "1"
    role: "reviewer"
    provider:
      name: "github"
      profile: "default"
      reference: "skill://forge/reference/github.md"
    repository:
      host: "github.com"
      id: "owner/repository"
      locator: "https://github.com/owner/repository.git"
      default_branch: "main"
      profile_path: "docs/agents/dev-workflows.md#project-profile-hooks"
      gate_policy_ref: "docs/agents/check-gate.md"
      label_profile_ref: "docs/agents/triage-labels.md"
      acceptance_surfaces_ref: "docs/agents/dev-workflows.md#acceptance-surface-vocabulary"
      language_families: ["typescript"]
      auxiliary_index_policy:
        owner: "parent"
        child_worktree_mode: "read-only-unless-assigned"
        copy_between_worktrees: "forbidden"
      branch_naming: { pattern: "issue-<id>-<slug>" }
      ci_jobs: { required: ["check"] }
      domain_docs: { context: "CONTEXT.md", adr: "docs/adr/" }
      release_deploy_policy: { policy: "project docs define authority" }
      manual_validation_rules: { required: [] }
    issue: { id: "57", locator: "provider://issue/57", state: "open", labels: ["ready"] }
    change_request:
      id: "123"
      locator: "provider://change/123"
      state: "open"
      draft: false
      source: "issue-57-example"
      target: "main"
    commit:
      current: "1111111111111111111111111111111111111111"
      reviewed: "1111111111111111111111111111111111111111"
      candidate: "1111111111111111111111111111111111111111"
      result: "N/A"
      target_observed: "N/A"
    ci:
      id: "check"
      locator: "provider://ci/check"
      status: "success"
      commit: "1111111111111111111111111111111111111111"
      not_run_reason: "N/A"
    local_gate: { command: "npm run check", status: "PASS", not_run_reason: "N/A", summary: "verified" }
    tdd: { red: "verified builder trace", green: "targeted checks pass" }
    authority:
      approval: { value: "default-after-pass", source: "repo policy", verified: true, restricted: false }
      finish: { value: "approval-only", source: "parent prompt", verified: true, conflicts: [] }
    handoff_contract:
      phase: "finish"
      expected_next_actor: "parent"
      expected_next_action: "finish-by-authorized-actor"
      blocked: false
      blocker_token: "none"
      required_parent_decision: "none"
      safe_to_continue_without_parent: true
      changed_since_last_handoff: false
      evidence_ready_for_next_actor: ["review-report-readback", "reviewed-commit-current"]
    evidence:
      - { tier: "tier-1", kind: "review-report", source: "provider://change/123/report/9", summary: "byte-for-byte readback" }
    blockers: []
  # CHANGE-DELIVERY-SCHEMA:END
  review_verdict: "pass | request-changes | reject | blocked"
  report_locator: "review-report:owner/repository!123:1"
  report_url: "provider://change/123/report/9"
  reviewed_commit: "1111111111111111111111111111111111111111"
  ci: { status: "success", commit: "1111111111111111111111111111111111111111" }
  local_checks: { status: "PASS", commands: ["npm run check"] }
  findings:
    - id: "MF-1"
      report_locator: "review-report:owner/repository!123:1"
      reviewed_commit: "1111111111111111111111111111111111111111"
      locations: ["path/to/file:10-20"]
      remedy_direction: "bounded correction"
  open_questions: { disposition: "none" }
  approval_authority: "default-after-pass"
  approval_authority_source: "repo policy"
  approval_action: "not-approved"
  finish_authority: "approval-only"
  finish_authority_source: "parent prompt"
  finish_action: "none"
  action_blocker: "none / missing-authority / stale-or-missing-ci / changed-head-sha / merge-conflict / sha-bound-action-unsupported / preflight-failure / permission-failure / human-decision-needed / partial-review / secret-exposure-suspected / other"
  next_action: "finish-by-authorized-actor"
  next_actor: "parent"
  blockers: []
```
<!-- AGENT-HANDOFF:REVIEWER-FINAL:END -->


When the launch prompt says `Finish owner: parent`, the reviewer publishes only
the verdict/evidence and returns approval `not-approved`, finish `none`, next
actor `parent`; it never approves or finishes.
The internal route remains `mr-reviewer-final`; the public record is a bound
change request and reviewed commit. Never combine verdict, approval, and finish.
For `secret-exposure-suspected`, describe the blocker without secret values and
use `[REDACTED]`; never copy the sensitive payload into the handoff.
