# Builder Final Handoff

Machine-readable final output block for child `mr-builder` sessions. Emit this
block in the builder's final response and, when useful, in a local run artifact.
Keep the MR description's Reviewer Lift block as the durable reviewer handoff;
this block complements it for parent-orchestrator parsing.

Consumers must tolerate this block being absent or malformed. Fall back to the
human prose handoff, the MR description, and the Reviewer Lift block before
asking the builder to retry. Values must not contain secrets, raw private
payloads, or unredacted logs.

<!-- AGENT-HANDOFF:BUILDER-FINAL:BEGIN -->
```yaml
agent_handoff:
  kind: "builder-final"
  version: "1"
  # GITLAB-DELIVERY-SCHEMA:BEGIN generated-copy from start-build/templates/gitlab-delivery-schema.md
  delivery:
    kind: "gitlab-delivery"
    version: "1"
    role: "builder"
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
      draft: true
      source_branch: "issue-57-example"
      target_branch: "main"
    sha:
      head: "1111111111111111111111111111111111111111"
      reviewed: "1111111111111111111111111111111111111111"
      candidate: "1111111111111111111111111111111111111111"
      merge_commit: "N/A"
      target_observed: "N/A"
    pipeline:
      id: "N/A"
      url: "N/A"
      status: "N/A"
      sha: "N/A"
      not_run_reason: "unavailable-tooling"
    local_gate:
      command: "npm run check"
      status: "not-run"
      not_run_reason: "parent-owned"
      summary: "parent owns final local gate and ready transition"
    acceptance_surfaces: []
    authority:
      approval:
        value: "default-after-pass"
        source: "start-review/REVIEW-FLOW.md#approval-authority-policy"
        verified: false
        restricted: false
      merge:
        value: "approval-only"
        source: "parent task prompt: approval-only"
        verified: false
        conflicts: []
    actions:
      approval: "N/A"
      finish: "none"
      next: "parent-run-gate"
      blockers: []
    handoff_contract:
      phase: "parent-gate"
      expected_next_actor: "parent"
      expected_next_action: "parent-run-gate"
      blocked: false
      blocker_token: "none"
      required_parent_decision: "none"
      safe_to_continue_without_parent: true
      changed_since_last_handoff: false
      evidence_ready_for_next_actor:
        - "mr-description-reviewer-lift-current"
        - "candidate-sha-pushed"
    evidence:
      - tier: "tier-1"
        kind: "mr-metadata"
        source: "https://gitlab.example/group/project/-/merge_requests/123"
        summary: "MR metadata read for source/target/head"
      - tier: "tier-1"
        kind: "git-ref"
        source: "git ls-remote origin issue-57-example"
        summary: "remote source branch points at candidate SHA"
    blockers: []
    extra:
      gate_ownership:
        local_gate_owner: "parent"
        builder_gate_status:
          status: "not-run"
          not_run_reason: "parent-owned"
        ready_transition_owner: "parent"
      gate_coverage:
        owner: "parent"
        coverage: "full-local"
        rationale: "docs/agents/check-gate.md#gate-coverage-for-ready-handoff; required CI check covered by npm run check; unmapped CI-only jobs none"
  # GITLAB-DELIVERY-SCHEMA:END
  status: "candidate-for-parent-gate"
  issue:
    iid: "57"
    url: "https://gitlab.example/group/project/-/issues/57"
    title: "Short issue title"
  mr:
    iid: "123"
    url: "https://gitlab.example/group/project/-/merge_requests/123"
    draft: true
    source_branch: "issue-57-example"
    target_branch: "main"
  head_sha: "1111111111111111111111111111111111111111"
  reviewed_sha: "1111111111111111111111111111111111111111"
  candidate_sha: "1111111111111111111111111111111111111111"
  pipeline:
    id: "N/A"
    url: "N/A"
    status: "N/A"
    sha: "N/A"
    not_run_reason: "unavailable-tooling"
  local_gate:
    status: "not-run"
    command: "npm run check"
    not_run_reason: "parent-owned"
    summary: "parent owns final local gate and ready transition"
  gate_ownership:
    local_gate_owner: "parent"
    builder_gate_status:
      status: "not-run"
      not_run_reason: "parent-owned"
    ready_transition_owner: "parent"
  gate_coverage:
    owner: "parent"
    coverage: "full-local"
    rationale: "docs/agents/check-gate.md#gate-coverage-for-ready-handoff; required CI check covered by npm run check; unmapped CI-only jobs none"
  tdd:
    red: "N/A with rationale — docs/config/mechanical work"
    green: "N/A with rationale — targeted invariant checks only"
  changed_files:
    - "path/one.md"
  safety_surfaces:
    - "none"
  decoupling:
    summary: "single MR"
    co_running: []
  reviewer_focus:
    - "path/one.md — boundary to inspect"
  open_questions: []
  approval_authority: "default-after-pass"
  approval_authority_source: "start-review/REVIEW-FLOW.md#approval-authority-policy"
  merge_authority: "approval-only"
  merge_authority_source: "parent task prompt: approval-only"
  next_action: "parent-run-gate"
  artifacts:
    run_dir: "/tmp/agent-run-issue-57-mr-123"
    review_packet: "/tmp/agent-run-issue-57-mr-123/review-packet.md"
  blockers: []
  extra: {}
```
<!-- AGENT-HANDOFF:BUILDER-FINAL:END -->

## Field guidance

- `kind` and `version` are fixed parser anchors for this template version.
- `delivery` follows `gitlab-delivery-schema.md`. It is a compact routing index,
  not proof; parents/reviewers must verify its claims from Tier 1/Tier 2
  evidence before relying on them for review, CI, authority, or finish routing.
  Authority claims are verified through
  `../../gitlab/reference/authority-verification.md`.
- `delivery.project_profile` records bounded project-specific hooks such as
  gate, labels, branches, CI jobs, domain docs, auxiliary indexes, release/deploy
  policy, and manual validation. These hooks specialize project policy only; they
  do not weaken reviewed-SHA binding, exact-SHA CI, explicit authority source,
  independent review, child-builder boundaries, verifier read-only boundaries, or
  MCP-first transport correctness plus help-first `glab` fallback correctness.
- The YAML block above is a concrete synthetic example, not a schema literal:
  replace every value with verified values for the current MR before sending a
  final handoff. Do not leave placeholder alternatives in copied output.
- `status` is one of `ready-for-review`, `candidate-for-parent-gate`,
  `blocked`, or `failed`. Use `candidate-for-parent-gate` when parent-owned gate
  mode leaves the MR Draft for the parent Gate Receipt / ready transition. If
  usage limits or tooling failures prevent completion, return `status: "failed"`
  and list the blocker(s) instead of inventing missing GitLab state.
- `head_sha` is the pushed MR head SHA when this handoff is emitted.
- `reviewed_sha` is the same commit as `head_sha` for `ready-for-review` and
  `candidate-for-parent-gate` handoffs; in parent-owned gate mode it is the
  candidate SHA the parent must gate before review. It must match the MR
  description's Reviewer Lift `Reviewed SHA` unless no reviewable head exists
  because status is `blocked` or `failed`; then use `N/A — <why>` and list the
  blocker.
- `candidate_sha` repeats the exact head SHA that the parent should check out
  for the Gate Receipt when `status: "candidate-for-parent-gate"`.
- `pipeline` is the latest known MR pipeline for `reviewed_sha`, or `N/A` with a
  reason when GitLab exposes no pipeline yet. `pipeline.status` should use the
  GitLab status when available, commonly `success`, `pending`, `running`,
  `failed`, `canceled`, `skipped`, or `N/A` with a reason.
- `local_gate` names the exact command and concise result. `local_gate.status` is
  `PASS`, `FAIL`, `N/A`, or `not-run`; parent-owned mode uses `not-run` with
  `not_run_reason: "parent-owned"` per
  `start-build/reference/parent-owned-gate.md`.
  `N/A` still needs a concrete reason.
- `gate_ownership` records the parent-owned ownership contract from
  `start-build/reference/parent-owned-gate.md`: `local_gate_owner`,
  `builder_gate_status`, and `ready_transition_owner`.
- `gate_coverage` records the Reviewer Lift Gate owner/coverage/rationale values.
  `coverage` is `full-local`, `hybrid`, or `ci-only`; never `parent-owned`.
  Parent-owned mode may include policy/routing coverage, but the child still does
  not claim local gate pass/fail or Gate Receipt success.
- `delivery.handoff_contract` is the shared routing contract. Keep it aligned
  with `status`, `next_action`, blockers, and the parent-owned gate contract.
  Use `required_parent_decision: "none"` when no extra parent choice is still
  needed, and omit `blocking_question` unless a specific actionable question is
  what stops progress.
- `tdd` records RED/GREEN evidence for behavior-touching implementation, or
  explicit N/A rationale for docs/config/mechanical work or impossible TDD.
- `changed_files`, `safety_surfaces`, `decoupling`, and `reviewer_focus` must
  match the MR description's Reviewer Lift values. `safety_surfaces` entries are
  `none`, `credentials`, `external-system`, `state`, `migration`, `gates`,
  `locks`, `deploy`, `wire-protocol`, or `other`.
- `approval_authority` records the quoted approval policy claim. Use
  `default-after-pass` when repo policy allows reviewer approval after a passing
  review unless explicitly restricted; use `restricted: <reason/source>` when an
  explicit source limits approval. Approval still requires exact reviewed SHA,
  pass-eligible CI/local-gate/OQ state, SHA-bound approval, and the canonical
  Authority Verification seam (`../../gitlab/reference/authority-verification.md`).
- `approval_authority_source` records the stable repo/rulebook policy source or
  explicit restriction source. It is separate from merge authority and does not
  grant merge, auto-merge, release, deploy, close, or cleanup authority.
- `merge_authority` records the quoted finish-authority claim; it never grants
  the child builder approval or merge authority. Valid claims are
  `approval-only`, `reviewer may merge`, `queue auto-merge`, `human release`,
  or `project default: <policy>`.
- `merge_authority_source` records the verifiable provenance for that finish
  authority claim, such as parent task prompt, human MR comment URL, rulebook
  path and section, or project default source. Authority Verification owns source
  precedence, conflict handling, restricted/missing-source results, and no-self
  routing; missing, unverifiable, or conflicting source information is a blocker
  for finish actions, not for default approval by itself.
- `next_action` tells the parent whether to run the parent-owned gate, spawn
  review, make a human decision, or fix a blocker. Use `parent-run-gate`,
  `spawn-reviewer`, `human-decision`, or `fix-blocker`, and keep it equal to
  `delivery.handoff_contract.expected_next_action`.
- `artifacts` point to local redacted run files only. Do not commit them.
