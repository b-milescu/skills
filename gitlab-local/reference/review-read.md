# GitLab review read card

Small command-context card for `/start-review` read-only GitLab work. Full command ownership stays in [`gitlab-local/SKILL.md`](../SKILL.md); this card is a pointer map, not a command copy. Apply the [`help-first` rule](../SKILL.md#help-first-rule) before running any flagged CLI command.

## Use this card when

- binding a supplied MR URL, IID, or branch to the current project;
- reading linked issue metadata and comments before reviewing a diff;
- reading MR metadata, comments, pipeline summary, and detailed merge status;
- capturing review artifacts for a focused diff walk.

## Snippets

| Snippet | Use | Inputs | Outputs | Fail closed |
| --- | --- | --- | --- | --- |
| [`local-repo-preflight`](../SKILL.md#snippet-local-repo-preflight) | Confirm tooling, auth, repo root, repo URL, and default branch before MR binding. | Current worktree and selected branch. | Verified repo URL and default branch for later bound reads. | Stop on missing tools, auth failure, non-repo cwd, or repo mismatch. |
| [`issue-pickup`](../SKILL.md#snippet-issue-pickup) | Read linked issue description, labels, assignees, URL, and comments. | Issue IID or full issue URL; explicit repo target when project binding needs it. | Issue title/state/labels/assignees/URL plus comments when requested. | Do not infer issue state from MR text if issue read fails; report evidence gap. |
| [`mr-pickup`](../SKILL.md#snippet-mr-pickup) | Read decision-grade MR metadata before review, final snapshot, and SHA guards. | Bound MR IID, full MR URL, or current branch; explicit repo target when needed. | MR IID, draft/state, source/target branches, head SHA, pipeline, merge status, URL. | Do not approve or finish from list-only/candidate data; re-read one bound MR record. |
| [`artifact-capture`](../SKILL.md#snippet-artifact-capture) | Save MR comments, JSON, patch, and numstat for diff-first review. | Bound MR IID plus temp run directory. | Redacted local artifacts outside tracked paths. | Do not continue from missing or stale diff artifacts when they are needed for findings. |

## Fallback to full gitlab-local

Fall back to [`gitlab-local/SKILL.md`](../SKILL.md) when:

- the needed review read is not listed here;
- CLI help, flag shape, or JSON shape differs from this card's assumptions;
- project binding is ambiguous or cross-repo review was explicitly chosen;
- you need issue or MR workflow operations beyond read-only pickup and artifact capture;
- a card and the full reference conflict. The full reference plus live help wins.
