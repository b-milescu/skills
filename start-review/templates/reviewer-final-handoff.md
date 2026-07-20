# Reviewer Final Handoff

Machine-readable final output block for `mr-reviewer` sessions. Emit this block
in the reviewer's final response and, when useful, in a local run artifact after
posting the Review Report. Keep the GitLab Review Report comment as the durable
review record; this block complements it for parent-orchestrator parsing.

Consumers must tolerate this block being absent or malformed. Fall back to the
Review Report comment, MR metadata, and human prose before asking the reviewer
to retry. Values must not contain secrets, raw private payloads, or unredacted
logs.

<!-- AGENT-HANDOFF:REVIEWER-FINAL:BEGIN -->
```yaml
agent_handoff:
  kind: "reviewer-final"
  version: "1"
  # GITLAB-DELIVERY-SCHEMA:BEGIN generated-copy from start-build/templates/gitlab-delivery-schema.md
  delivery:
    kind: "gitlab-delivery"
    version: "1"
    role: "reviewer"
    project_profile:
      host: "gitlab.example"
      project_path: "group/project"
      repo_url: "https://gitlab.example/group/project.git"
      default_branch: "main"
      profile_id: "default"
      profile_path: "docs/agents/dev-workflows.md#project-profile-hooks"
      gate_policy_ref: "docs/agents/check-gate.md#full-local-gate"
      label_profile_ref: "docs/agents/triage-labels.md#live-label-inventory"
      language_families:
        - "typescript"
        - "shell"
        - "markdown"
      auxiliary_index_policy:
        ref: "docs/agents/dev-workflows.md#auxiliary-project-index-policy"
        owner: "parent"
        child_worktree_mode: "read-only-unless-assigned"
        copy_between_worktrees: "forbidden"
      branch_naming:
        ref: "docs/agents/dev-workflows.md#branch-naming"
        pattern: "issue-<iid>-<slug>"
      ci_jobs:
        ref: "docs/agents/check-gate.md#ci-parity"
        required:
          - "check"
      domain_docs:
        ref: "docs/agents/domain.md"
        context: "CONTEXT.md"
        adr: "docs/adr/"
      release_deploy_policy:
        ref: "docs/agents/dev-workflows.md#release-deploy-policy"
        policy: "project docs define release/deploy authority"
      manual_validation_rules:
        ref: "docs/agents/check-gate.md#manual-validation-rules"
        required: []
    issue:
      iid: "57"
      url: "https://gitlab.example/group/project/-/issues/57"
      state: "opened"
      labels:
        - "target-afk-ready-label"
    mr:
      iid: "123"
      url: "https://gitlab.example/group/project/-/merge_requests/123"
      state: "opened"
      draft: false
      source_branch: "issue-123-example"
      target_branch: "main"
    sha:
      head: "2222222222222222222222222222222222222222"
      reviewed: "2222222222222222222222222222222222222222"
      candidate: "2222222222222222222222222222222222222222"
      merge_commit: "N/A"
      target_observed: "N/A"
    pipeline:
      id: "456"
      url: "https://gitlab.example/group/project/-/pipelines/456"
      status: "success"
      sha: "2222222222222222222222222222222222222222"
      not_run_reason: "N/A"
    local_gate:
      command: "npm run check"
      status: "PASS"
      not_run_reason: "N/A"
      summary: "accepted builder gate evidence"
    acceptance_surfaces: []
    authority:
      finish_owner: "parent"
      approval:
        value: "default-after-pass"
        source: "start-review/REVIEW-FLOW.md#approval-authority-policy"
        verified: true
        restricted: false
      merge:
        value: "approval-only"
        source: "parent task prompt: approval-only"
        verified: true
        conflicts: []
    actions:
      finish_owner: "parent"
      approval: "not-approved"
      finish: "none"
      next: "finish-by-authorized-actor"
      blockers: []
    handoff_contract:
      phase: "finish"
      expected_next_actor: "parent"
      expected_next_action: "finish-by-authorized-actor"
      blocked: false
      blocker_token: "none"
      required_parent_decision: "none"
      safe_to_continue_without_parent: true
      changed_since_last_handoff: false
      evidence_ready_for_next_actor:
        - "review-report-posted"
        - "parent-finish-owner-recorded"
    evidence:
      - tier: "tier-1"
        kind: "review-report"
        source: "https://gitlab.example/group/project/-/merge_requests/123#note_789"
        summary: "posted Review Report for reviewed SHA"
    blockers: []
    extra: {}
  # GITLAB-DELIVERY-SCHEMA:END
  review_verdict: "pass | request-changes | reject | blocked"
  mr:
    iid: "123"
    url: "https://gitlab.example/group/project/-/merge_requests/123"
    bound_url: "https://gitlab.example/group/project/-/merge_requests/123"
    bound_host: "gitlab.example"
    project_path: "group/project"
    repo_url: "https://gitlab.example/group/project.git"
    source_branch: "issue-123-example"
    target_branch: "main"
    current_sha: "2222222222222222222222222222222222222222"
  report_locator: "review-report:group/project!123:1"
  reviewed_sha: "2222222222222222222222222222222222222222"
  pipeline:
    id: "456 | N/A"
    status: "success | pending | failed | N/A"
    sha: "2222222222222222222222222222222222222222 | N/A"
  local_checks:
    - command: "npm run check"
      status: "PASS | FAIL | not-run"
      summary: "brief evidence or reason not run"
  findings:
    must_fix:
      - id: "MF-1"
        report_locator: "review-report:group/project!123:1"
        reviewed_sha: "2222222222222222222222222222222222222222"
        path: "path/file.ext"
        line: "12"
        problem: "specific problem"
        direction: "specific fix direction"
    should_fix: []
    consider: []
  open_questions_addressed: []
  approval_authority: "default-after-pass | restricted: reason/source"
  approval_authority_source: "stable repo policy ref | parent task prompt | human/MR comment URL | rulebook path+section"
  merge_authority: "approval-only | reviewer may merge | queue auto-merge | human release | project default: ..."
  merge_authority_source: "parent task prompt | human MR comment URL | rulebook path+section | project default source"
  finish_owner: "parent | reviewer | authorized-parent | human | N/A"
  approval_action: "approved | not-approved | blocked | N/A"
  finish_action: "merged | auto-merge queued | approval-only stop | human-release stop | none | blocked | N/A"
  action_blocker: "none | missing-authority | stale-or-missing-ci | changed-head-sha | merge-conflict | sha-bound-action-unsupported | preflight-failure | permission-failure | human-decision-needed | partial-review | secret-exposure-suspected | other"
  next_action: "finish-by-authorized-actor | revise | human-escalation | wait-ci | rerun-review | fix-blocker"
  report_url: "https://gitlab.example/group/project/-/merge_requests/123#note_789 | N/A"
  extra: {}
```
<!-- AGENT-HANDOFF:REVIEWER-FINAL:END -->

## Field guidance

- `kind` and `version` are fixed parser anchors for this template version.
- `delivery` follows `../../start-build/templates/gitlab-delivery-schema.md`.
  It is a compact routing index, not proof; parents/verifiers must verify its
  claims from Tier 1/Tier 2 evidence before relying on them for finish,
  post-merge, or blocker routing. Authority claims are verified through
  `../../gitlab/reference/authority-verification.md`.
- `delivery.project_profile` is a project-specific routing index for gate,
  labels, branches, CI jobs, domain docs, auxiliary indexes, release/deploy
  policy, and manual validation. Reviewers still enforce reviewed-SHA binding,
  exact-SHA CI, explicit authority source, independent review, child-builder
  boundaries, verifier read-only boundaries, and MCP-first transport correctness
  plus help-first `glab` fallback correctness.
- `review_verdict` is the review judgment: `pass`, `request-changes`, `reject`,
  or `blocked`, matching the Review Report. `pass` means the review judgment
  passed; it does not imply a GitLab approval, merge, or auto-merge action was
  taken.
- `mr.bound_url`, `mr.bound_host`, `mr.project_path`, `mr.repo_url`,
  `mr.source_branch`, `mr.target_branch`, and `mr.current_sha` record the
  project-bound MR target used for Review Report comments, approval, merge,
  auto-merge, or close-equivalent actions. The bound project must match the
  preflight repo unless the user explicitly chose a cross-repo review target.
- `report_locator` is the stable identifier chosen in the Review Report before
  publication. It remains the canonical locator even when `report_url` becomes
  available after posting.
- `reviewed_sha` is the exact MR head SHA the reviewer read. Never approve a SHA
  that was not reviewed.
- `pipeline` records the decision-grade pipeline. Green CI counts only when its
  SHA matches `reviewed_sha`.
- `local_checks` lists commands run by the reviewer, or `not-run` with rationale
  when local execution was unnecessary or impossible.
- Every `findings` item repeats the Review Report's `report_locator`,
  `reviewed_sha`, and human-readable `MF-N`, `SF-N`, or `C-N` ID. That tuple,
  defined in `../reference/finding-identities.md`, is the canonical identity the
  parent uses to route revisions; a bare short ID is ambiguous across reports.
- `open_questions_addressed` lists every `OQ-N` answered, escalated, or
  downgraded in the Review Report.
- `approval_authority` records the approval policy result. `default-after-pass`
  means reviewer approval is allowed after a passing review unless explicitly
  restricted; `restricted: ...` names the source/reason that blocks or limits
  approval. Authority Verification (`../../gitlab/reference/authority-verification.md`)
  owns the restricted result and source precedence.
- `approval_authority_source` records the stable repo/rulebook policy source or
  explicit restriction source verified before approval. It is separate from
  merge authority and does not grant merge, auto-merge, release, close, or
  cleanup authority.
- `merge_authority` is copied as the quoted finish-authority claim from the
  Review Packet, project rulebook, parent, or human instruction.
- `merge_authority_source` records the source the reviewer verified before any
  merge/auto-merge/release/close/cleanup or other finish action. Missing or
  unverifiable merge source maps to a finish `action_blocker:
  missing-authority`; conflicting sources use the most restrictive/no-action
  finish result unless a parent/human resolves them. Authority Verification owns
  this conflict/restriction/missing-source classification and the no-self
  approval/merge context check.
- `finish_owner` records launch-supplied finish owner. Parent-managed pass uses literal `Finish owner: parent`; reviewer records verdict/evidence only and leaves approval, direct merge, and auto-merge queue actions to the parent or authorized finisher.
- `approval_action` records only the GitLab approval side effect: `approved`,
  `not-approved`, `blocked`, or `N/A`. It must be `blocked` when review cannot
  safely take approval due to restricted/missing approval authority, SHA/CI/tool/preflight/permission
  failures, partial-review, suspected secret exposure, or a required human
  decision. When the Review Report used intended
  action wording before a post-report approval attempt, this field records the
  completed approval result or blocker after the fresh SHA guard.
- `finish_action` records only the GitLab finish side effect: `merged`,
  `auto-merge queued`, `approval-only stop`, `human-release stop`, `none`,
  `blocked`, or `N/A`. When the Review Report used intended action wording
  before a post-report direct merge or auto-merge queue attempt, this field
  records the completed finish result or blocker after the fresh SHA guard for
  that specific action.
- `action_blocker` is `none` or one stable blocker token: `missing-authority`,
  `stale-or-missing-ci`, `changed-head-sha`, `merge-conflict`,
  `sha-bound-action-unsupported`, `preflight-failure`, `permission-failure`,
  `human-decision-needed`, `partial-review`, `secret-exposure-suspected`, or
  `other`. `merge-conflict` marks an MR that is conflicted or whose target went
  stale after a sibling MR merged. For `secret-exposure-suspected`, report the
  blocker and safe path/artifact locator without secret values.
- `delivery.handoff_contract` is the shared routing contract. Keep it aligned
  with `review_verdict`, `approval_action`, `finish_action`, `action_blocker`,
  and `next_action`. When a human/product/security choice blocks progress, set
  `blocked: true`, use `blocker_token: "human-decision-needed"`, fill
  `required_parent_decision`, and include a specific actionable
  `blocking_question` instead of routing the blocker as builder revision work.
- `next_action` tells the parent whether an authorized actor should finish,
  the builder should revise, a human must decide, CI should be waited on, the
  reviewer should rerun after a changed head, or a blocker needs fixing. Keep it
  equal to `delivery.handoff_contract.expected_next_action`.
- `report_url` points at the posted GitLab Review Report comment when available.
