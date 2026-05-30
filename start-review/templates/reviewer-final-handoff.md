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
        path: "path/file.ext"
        line: "12"
        problem: "specific problem"
        direction: "specific fix direction"
    should_fix: []
    consider: []
  open_questions_addressed: []
  merge_authority: "approval-only | reviewer may merge | queue auto-merge | human release | project default: ..."
  merge_authority_source: "parent task prompt | human MR comment URL | rulebook path+section | project default source"
  approval_action: "approved | not-approved | blocked | N/A"
  finish_action: "merged | auto-merge queued | approval-only stop | human-release stop | none | blocked | N/A"
  action_blocker: "none | missing-authority | stale-or-missing-ci | changed-head-sha | sha-bound-action-unsupported | preflight-failure | permission-failure | human-decision-needed | partial-review | secret-exposure-suspected | other"
  next_action: "finish-by-authorized-actor | revise | human-escalation | wait-ci | rerun-review | fix-blocker"
  report_url: "https://gitlab.example/group/project/-/merge_requests/123#note_789 | N/A"
  extra: {}
```
<!-- AGENT-HANDOFF:REVIEWER-FINAL:END -->

## Field guidance

- `kind` and `version` are fixed parser anchors for this template version.
- `review_verdict` is the review judgment: `pass`, `request-changes`, `reject`,
  or `blocked`, matching the Review Report. `pass` means the review judgment
  passed; it does not imply a GitLab approval, merge, or auto-merge action was
  taken.
- `mr.bound_url`, `mr.bound_host`, `mr.project_path`, `mr.repo_url`,
  `mr.source_branch`, `mr.target_branch`, and `mr.current_sha` record the
  project-bound MR target used for Review Report comments, approval, merge,
  auto-merge, or close-equivalent actions. The bound project must match the
  preflight repo unless the user explicitly chose a cross-repo review target.
- `reviewed_sha` is the exact MR head SHA the reviewer read. Never approve a SHA
  that was not reviewed.
- `pipeline` records the decision-grade pipeline. Green CI counts only when its
  SHA matches `reviewed_sha`.
- `local_checks` lists commands run by the reviewer, or `not-run` with rationale
  when local execution was unnecessary or impossible.
- `findings` mirrors the Review Report's `MF-N`, `SF-N`, and `C-N` IDs so the
  parent can route revisions.
- `open_questions_addressed` lists every `OQ-N` answered, escalated, or
  downgraded in the Review Report.
- `merge_authority` is copied as the quoted authority claim from the Review
  Packet, project rulebook, parent, or human instruction.
- `merge_authority_source` records the source the reviewer verified before any
  approval/finish action. Missing or unverifiable source maps to
  `action_blocker: missing-authority`; conflicting sources use the most
  restrictive/no-action result unless a parent/human resolves them.
- `approval_action` records only the GitLab approval side effect: `approved`,
  `not-approved`, `blocked`, or `N/A`. It must be `blocked` when review cannot
  safely take approval due to missing authority, SHA/CI/tool/preflight/permission
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
  `stale-or-missing-ci`, `changed-head-sha`,
  `sha-bound-action-unsupported`, `preflight-failure`, `permission-failure`,
  `human-decision-needed`, `partial-review`, `secret-exposure-suspected`, or
  `other`. For `secret-exposure-suspected`, report the blocker and safe
  path/artifact locator without secret values.
- `next_action` tells the parent whether an authorized actor should finish,
  the builder should revise, a human must decide, CI should be waited on, the
  reviewer should rerun after a changed head, or a blocker needs fixing.
- `report_url` points at the posted GitLab Review Report comment when available.
