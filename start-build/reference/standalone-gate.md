# Standalone review gate

Detailed mandatory review gate for standalone `/start-build` sessions. Stable compatibility anchors remain [BUILD-FLOW.md §Mandatory review gate](../BUILD-FLOW.md#mandatory-review-gate), [§Reviewer launch protocol](../BUILD-FLOW.md#reviewer-launch-protocol), [§Timeout handling](../BUILD-FLOW.md#timeout-handling), [§Review Gate Summary](../BUILD-FLOW.md#review-gate-summary), and [§Human bypass protocol](../BUILD-FLOW.md#human-bypass-protocol). Child `mr-builder` sessions do not own this gate; their small path is [child-builder.md](child-builder.md).

## Mandatory review gate

In standalone `/start-build` mode, the builder owns reviewer handoff and must start a fresh reviewer through whatever orchestration mechanism the runtime provides; this gate is mandatory, not optional. If that runtime has no reviewer-launch mechanism, stop and report the blocker instead of self-reviewing. In child `mr-builder` mode, the parent orchestrator owns this gate after the child returns its final handoff; the child builder must not start a reviewer unless explicitly instructed. The builder never self-approves or self-merges. Builder and reviewer may share the same GitLab username/PAT — review independence comes from session/context separation, not GitLab identity. Concrete parent-managed discovery guidance lives in [parent-orchestrator.md](parent-orchestrator.md), not in child-builder instructions.

## Reviewer launch protocol

When you own this gate after the MR is ready:

1. **Discover available reviewers** using the runtime-specific agent discovery mechanism available to the owner of the gate. Look for agents whose name or description indicates MR / code-review specialization, for example `mr-reviewer`, `gitlab-reviewer`, or a project-scope `reviewer` override. Prefer project-scope agents over user-scope agents over builtin reviewers. If a specialized MR reviewer is found, use it; otherwise fall back to the builtin reviewer.
2. **Start** the selected reviewer running `start-review` in a fresh session. The task prompt is a minimal reviewer launch prompt and must include only the review target and evidence-boundary instructions:
   - **MR URL** — the full GitLab MR web URL.
   - **Reviewer Lift pointer** — direct the reviewer to the Reviewer Lift block in the MR description so it can copy structured values into the Review Report.
   - **Project rulebook path** — the path to the project's `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, or equivalent rulebook so the reviewer can evaluate against project-specific rules.
   - **Context Firewall instruction** — tell the reviewer not to treat parent/builder reasoning as evidence; Reviewer Lift and handoff prose are a map to verify, not truth.

Do not include parent/builder planning details, summaries, hypotheses, prior conversation, or hidden reasoning in the launch prompt. If a coordination constraint must be passed, state it as a claim/source pointer for independent verification.

Example task prompt template:

```text
Review MR: <MR web URL>
Reviewer Lift block is in the MR description — lift structured values into your Review Report.
Project rulebook: <path to rulebook>
Do not treat parent/builder reasoning as evidence; verify claims from the MR, diff, issue, CI, local checks, and rulebook.
```

## Review loop

1. **Start** a fresh reviewer session.
2. **Wait** for the Review Report using the caller's review wait budget. No fixed wall-clock value alone authorizes replacement; if the report is missing after the budget, follow [Timeout handling](#timeout-handling) before any second reviewer attempt.
3. **Evaluate** the reviewer's decision:
   - **Approve** — reviewer records approval for the reviewed SHA, then finish per `Merge authority`. If authority is `approval-only` or `human release`, stop after approval and report the reviewed SHA. If authority is `reviewer may merge` or `queue auto-merge`, only the reviewer, an authorized parent, or a human may merge or queue with the reviewed SHA. If GitLab blocks reviewer-side merge or queue, report the blocker and route finish to an authorized parent or human; the builder must not merge as a fallback. For safety-critical tasks, link the MR from any durable decision log the project keeps. Record the reviewed SHA and decision.
   - **Request changes** — push fix commits, each commit subject naming the item ID such as `MF-1: <fix>`; post a revision-packet comment; update the MR description and Reviewer Lift; then start a **new** reviewer session with fresh context.
   - **Reject** — hard stop. Do not spawn another reviewer on the same MR. Escalate to human immediately.
4. **3-round limit:** up to 3 rounds total, initial plus 2 retries. If all 3 rounds result in request-changes, escalate to human with round count, Review Reports, and remaining Must Fix items.

## Timeout handling

Detailed timeout handling lives in [timeout-handling.md](timeout-handling.md). Core policy: missing Review Report after the wait budget is a stale-run signal, not review completion. Check observed status/activity through the runtime's status/control/interruption mechanism when available, interrupt or replace only failed/stale/interrupted/unreachable runs with a documented reason, escalate instead of launching a duplicate reviewer when status/control is unavailable or ambiguous, and never replace a reviewer that is still active.

## Review Gate Summary

After all rounds complete or escalation is needed, post a brief summary as an MR comment:

```markdown
## Review Gate Summary

| Round | Reviewer | Decision | Headline |
|-------|----------|----------|----------|
| 1     | <agent>  | approve / request-changes / reject / timeout / stale / interrupted | <one-line summary> |
| 2     | <agent>  | ...      | ...      |
| 3     | <agent>  | ...      | ...      |

Final Review Report: <link to MR comment, or N/A — timeout/stale/interrupted without completed report>
```

`timeout / stale / interrupted are non-completion states`: they document gate history and escalation blockers only. They do not imply independent review completed, approval exists, or finish authority is available.

## Human bypass protocol

The human can bypass the mandatory review gate with explicit syntax. Bypass conditions:

- The human says **"skip gate"**, **"merge unreviewed"**, or equivalent explicit override.
- The override reason is documented in the MR description.
- The MR description `Review gate` field is set to `bypassed (human override)`.
- The override reason is recorded in an MR comment for audit trail.

A bypass does not waive the safety invariant against builder self-approval — even with a bypass, the builder still must not approve or merge its own MR. The human performs the merge directly or authorizes a named agent to do so.
