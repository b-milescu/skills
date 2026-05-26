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
  decision: "approve | request-changes | reject"
  mr:
    iid: "123"
    url: "https://gitlab.example/group/project/-/merge_requests/123"
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
  merge:
    authority: "approval-only | reviewer may merge | queue auto-merge | human release | project default: ..."
    action_taken: "approved | merged | queued-auto-merge | none"
    blocker: "none | reason"
  next_action: "merge | revise | human-escalation | wait-ci"
  report_url: "https://gitlab.example/group/project/-/merge_requests/123#note_789 | N/A"
  extra: {}
```
<!-- AGENT-HANDOFF:REVIEWER-FINAL:END -->

## Field guidance

- `kind` and `version` are fixed parser anchors for this template version.
- `decision` is `approve`, `request-changes`, or `reject`, matching the Review
  Report decision.
- `reviewed_sha` is the exact MR head SHA the reviewer read and approved,
  requested changes for, or rejected. Never approve a SHA that was not reviewed.
- `pipeline` records the decision-grade pipeline. Green CI counts only when its
  SHA matches `reviewed_sha`.
- `local_checks` lists commands run by the reviewer, or `not-run` with rationale
  when local execution was unnecessary or impossible.
- `findings` mirrors the Review Report's `MF-N`, `SF-N`, and `C-N` IDs so the
  parent can route revisions.
- `open_questions_addressed` lists every `OQ-N` answered, escalated, or
  downgraded in the Review Report.
- `merge.authority` is copied from the Review Packet or project rulebook.
  `merge.action_taken` reports what the reviewer actually did; it must remain
  `none` when the reviewer lacks explicit approval or merge authority.
- `next_action` tells the parent whether to merge, revise, escalate, or wait for
  CI.
- `report_url` points at the posted GitLab Review Report comment when available.
