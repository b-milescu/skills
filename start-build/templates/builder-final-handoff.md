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
    issue:
      iid: "57"
      url: "https://gitlab.example/group/project/-/issues/57"
      state: "opened"
      labels:
        - "ready-for-agent"
    mr:
      iid: "123"
      url: "https://gitlab.example/group/project/-/merge_requests/123"
      state: "opened"
      draft: false
      source_branch: "issue-57-example"
      target_branch: "main"
    sha:
      head: "1111111111111111111111111111111111111111"
      reviewed: "1111111111111111111111111111111111111111"
      candidate: "1111111111111111111111111111111111111111"
      merge_commit: "N/A"
      target_observed: "N/A"
    pipeline:
      id: "456"
      url: "https://gitlab.example/group/project/-/pipelines/456"
      status: "success"
      sha: "1111111111111111111111111111111111111111"
      not_run_reason: "N/A"
    local_gate:
      command: "npm run check"
      status: "PASS"
      not_run_reason: "N/A"
      summary: "completed successfully"
    authority:
      value: "approval-only"
      source: "parent task prompt: approval-only"
      verified: false
      conflicts: []
    actions:
      approval: "N/A"
      finish: "none"
      next: "spawn-reviewer"
      blockers: []
    evidence:
      - tier: "tier-1"
        kind: "mr-metadata"
        source: "https://gitlab.example/group/project/-/merge_requests/123"
        summary: "MR metadata read for source/target/head"
    blockers: []
    extra: {}
  # GITLAB-DELIVERY-SCHEMA:END
  status: "ready-for-review"
  issue:
    iid: "57"
    url: "https://gitlab.example/group/project/-/issues/57"
    title: "Short issue title"
  mr:
    iid: "123"
    url: "https://gitlab.example/group/project/-/merge_requests/123"
    draft: false
    source_branch: "issue-57-example"
    target_branch: "main"
  head_sha: "1111111111111111111111111111111111111111"
  reviewed_sha: "1111111111111111111111111111111111111111"
  pipeline:
    id: "456"
    url: "https://gitlab.example/group/project/-/pipelines/456"
    status: "success"
    sha: "1111111111111111111111111111111111111111"
  local_gate:
    status: "PASS"
    command: "npm run check"
    summary: "completed successfully"
  tdd:
    red: "bash tests/example-behavior.sh failed before fix: expected behavior missing"
    green: "bash tests/example-behavior.sh passed after fix"
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
  merge_authority: "approval-only"
  merge_authority_source: "parent task prompt: approval-only"
  next_action: "spawn-reviewer"
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
- The YAML block above is a concrete synthetic example, not a schema literal:
  replace every value with verified values for the current MR before sending a
  final handoff. Do not leave placeholder alternatives in copied output.
- `status` is one of `ready-for-review`, `blocked`, or `failed`. If usage limits
  or tooling failures prevent completion, return `status: "failed"` and list the
  blocker(s) instead of inventing missing GitLab state.
- `head_sha` is the pushed MR head SHA when this handoff is emitted.
- `reviewed_sha` is the same commit as `head_sha` for `ready-for-review` handoffs;
  it is the exact SHA the parent should pass to the reviewer and must match the
  MR description's Reviewer Lift `Reviewed SHA`. If no reviewable head exists
  because status is `blocked` or `failed`, use `N/A — <why>` and list the blocker.
- `pipeline` is the latest known MR pipeline for `reviewed_sha`, or `N/A` with a
  reason when GitLab exposes no pipeline yet. `pipeline.status` should use the
  GitLab status when available, commonly `success`, `pending`, `running`,
  `failed`, `canceled`, `skipped`, or `N/A` with a reason.
- `local_gate` names the exact command and concise result. `local_gate.status` is
  `PASS`, `FAIL`, or `N/A`; use `N/A` only with a concrete reason.
- `tdd` records RED/GREEN evidence for behavior-touching implementation, or
  explicit N/A rationale for docs/config/mechanical work or impossible TDD.
- `changed_files`, `safety_surfaces`, `decoupling`, and `reviewer_focus` must
  match the MR description's Reviewer Lift values. `safety_surfaces` entries are
  `none`, `credentials`, `external-system`, `state`, `migration`, `gates`,
  `locks`, `deploy`, or `other`.
- `merge_authority` records the quoted authority claim; it never grants the
  child builder approval or merge authority. Valid claims are `approval-only`,
  `reviewer may merge`, `queue auto-merge`, `human release`, or
  `project default: <policy>`.
- `merge_authority_source` records the verifiable provenance for that claim,
  such as parent task prompt, human MR comment URL, rulebook path and section,
  or project default source; missing, unverifiable, or conflicting source
  information is a blocker for reviewer approval/finish actions.
- `next_action` tells the parent whether to spawn review, make a human decision,
  or fix a blocker. Use `spawn-reviewer`, `human-decision`, or `fix-blocker`.
- `artifacts` point to local redacted run files only. Do not commit them.
