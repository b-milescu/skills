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
  status: "ready-for-review | blocked | failed"
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
  pipeline:
    id: "456 | N/A"
    url: "https://gitlab.example/group/project/-/pipelines/456 | N/A"
    status: "success | pending | failed | N/A"
    sha: "1111111111111111111111111111111111111111 | N/A"
  local_gate:
    status: "PASS | FAIL | N/A"
    command: "npm run check"
    summary: "brief result or N/A rationale"
  tdd:
    red: "command plus expected failure, or N/A — docs-only"
    green: "command plus passing result, or N/A — docs-only"
  changed_files:
    - "path/one.md"
  safety_surfaces:
    - "none | credentials | external-system | state | migration | gates | locks | deploy | other"
  decoupling:
    summary: "single MR"
    co_running: []
  reviewer_focus:
    - "path/one.md — boundary to inspect"
  open_questions: []
  merge_authority: "approval-only | reviewer may merge | queue auto-merge | human release | project default: ..."
  next_action: "spawn-reviewer | human-decision | fix-blocker"
  artifacts:
    run_dir: "/tmp/agent-run-issue-57-mr-123"
    review_packet: "/tmp/agent-run-issue-57-mr-123/review-packet.md"
  blockers: []
  extra: {}
```
<!-- AGENT-HANDOFF:BUILDER-FINAL:END -->

## Field guidance

- `kind` and `version` are fixed parser anchors for this template version.
- `status` is `ready-for-review`, `blocked`, or `failed`. If usage limits or
  tooling failures prevent completion, return `status: "failed"` and list the
  blocker(s) instead of inventing missing GitLab state.
- `head_sha` is the pushed MR head SHA that the parent should pass to review as
  the reviewed SHA candidate.
- `pipeline` is the latest known MR pipeline for `head_sha`, or `N/A` with a
  reason when GitLab exposes no pipeline yet.
- `local_gate` names the exact command and concise result. Use `N/A` only with a
  concrete reason.
- `tdd` records RED/GREEN evidence for behavior work, or an explicit N/A reason
  for docs/config/mechanical work.
- `changed_files`, `safety_surfaces`, `decoupling`, and `reviewer_focus` must
  match the MR description's Reviewer Lift values.
- `merge_authority` records what the parent/reviewer may do; it never grants the
  child builder approval or merge authority.
- `next_action` tells the parent whether to spawn review, make a human decision,
  or fix a blocker.
- `artifacts` point to local redacted run files only. Do not commit them.
