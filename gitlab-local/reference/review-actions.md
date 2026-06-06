# GitLab review action card

Small transport-context card for `/start-review` GitLab notes, SHA guards, approval actions, and finish handoff/finish actions. MCP is primary; guarded `glab` fallback and flag/help ownership stay in [`gitlab-local/SKILL.md`](../SKILL.md). Apply the [`help-first` rule](../SKILL.md#guarded-glab-fallback-and-help-first-rule) only when a documented fallback path uses flagged `glab`.

## Use this card when

- posting a Review Report, unblock response, revision response check, or action-result note;
- verifying the reviewed SHA is still the MR head;
- taking exactly one authorized approval, direct merge, or auto-merge queue action;
- handing finish inputs to an authorized parent, reviewer, or human.

## Snippets

| Snippet | Use | Inputs | Outputs | Fail closed |
| --- | --- | --- | --- | --- |
| [`mr-note-create`](../SKILL.md#snippet-mr-note-create) | MR comments only: Review Reports, unblock responses, revision notes, and action-result notes. | Bound MR IID or full MR URL; content-byte-safe report/comment body. | One MR note/comment on the bound MR plus MCP re-read evidence. | Never pair with issue-note in one step; do not post if project binding is missing or body is unreviewed. |
| [`issue-note-create`](../SKILL.md#snippet-issue-note-create) | Issue comments only when the issue workflow explicitly calls for an issue note. | Bound issue IID or URL; content-byte-safe issue comment body. | One issue note/comment on the bound issue plus MCP re-read evidence. | Do not use for Review Reports, unblock responses, approval results, or MR review notes. |
| [`sha-guard`](../SKILL.md#snippet-sha-guard) | Compare current MR head to reviewed SHA before approval or finish. | Bound MR IID/URL and reviewed SHA from the Review Report / Reviewer Lift. | Pass/fail current-head equality result. | Any mismatch means stale review; skip approval/merge/queue and report changed-head. |
| [`sha-bound-approval`](../SKILL.md#snippet-sha-bound-approval) | Reviewer approval for the reviewed SHA only. | Bound MR target, reviewed SHA, approval authority/source, caller identity. | Approval attempt tied to that SHA, with `via=mcp` or fallback evidence. | Block on explicit approval restriction, missing approval authority/source, unsupported SHA/confirm guard, changed head, or self-approval policy risk. |
| [`sha-bound-merge`](../SKILL.md#snippet-sha-bound-merge) | Direct merge for the reviewed SHA only when authority allows it. | Bound MR target, reviewed SHA, green exact-SHA CI, explicit direct-merge authority/source, caller identity. | Direct merge attempt tied to that SHA, with transport evidence. | Block on pending/red/missing/stale CI, missing merge authority/source, changed head, or caller identity/no-self-merge failure. |
| [`sha-bound-auto-merge-queue`](../SKILL.md#snippet-sha-bound-auto-merge-queue) | Queue protected auto-merge for the reviewed SHA only when authority allows it. | Bound MR target, reviewed SHA, protected checks, explicit queue authority/source, caller identity. | Auto-merge queue attempt tied to that SHA, with transport evidence. | Block on missing merge authority/source, unprotected policy uncertainty, changed head, or caller identity/no-self-merge failure. |
| [`approval-confirmation`](../SKILL.md#snippet-approval-confirmation) | Verify approval state after an approval attempt when confirmation is needed. | Project path, MR IID, and approval endpoint/tool access. | Approval record from the canonical approval state read. | Do not claim approval from laggy MR metadata alone if approval-state read does not confirm it. |
| [`finish-mr-authority-aware`](../SKILL.md#snippet-finish-mr-authority-aware) | Authority-aware finish helper or contract for parent/reviewer/human finish. | MR IID, reviewed SHA, merge authority, caller role/identity, source/target branch, optional issue/worktree. | Handoff, merge, auto-merge queue, or blocked finish result depending on role and guards, including `via`. | Builder role always stops at handoff; red/stale/missing CI, changed head, missing authority/source, or no-self-merge failure blocks finish. |

## Fallback to full gitlab-local

Fall back to [`gitlab-local/SKILL.md`](../SKILL.md) when:

- an action snippet listed here needs exact fallback syntax or flag verification;
- MCP approval/merge/note tooling is unavailable or the documented merge robustness/API fallback gap is hit;
- authority/source, CI waiver, caller identity, or project policy needs a variant not covered by this card;
- GitLab permission errors, approval endpoint drift, or merge-state drift need troubleshooting;
- you need issue or MR mutations outside review reports, SHA guards, approval, merge, auto-merge, or issue-note target split clarification.
