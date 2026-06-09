# GitLab review read card

Small transport-context card for `/start-review` read-only GitLab work. MCP is primary; guarded `glab` fallback and flag/help ownership stay in [`gitlab/SKILL.md`](../SKILL.md). Apply the [`help-first` rule](../SKILL.md#guarded-glab-fallback-and-help-first-rule) only when a documented fallback path uses flagged `glab`.

## Use this card when

- binding a supplied MR URL, IID, or branch to the current project;
- reading linked issue metadata and comments before reviewing a diff;
- reading MR metadata, comments, pipeline summary, and detailed merge status;
- capturing review artifacts for a focused diff walk.

## Snippets

| Snippet | Use | Inputs | Outputs | Fail closed |
| --- | --- | --- | --- | --- |
| [`local-repo-preflight`](../SKILL.md#snippet-local-repo-preflight) | Confirm MCP project binding plus local git worktree/default-branch safety before MR binding. | Current worktree, remote-derived project path, selected branch. | Verified project path, repo URL, default branch, and local repo root. | Stop on auth failure, non-repo cwd, repo mismatch, or stale/missing default branch. |
| [`issue-pickup`](../SKILL.md#snippet-issue-pickup) | Read linked issue description, labels, assignees, URL, and comments. | Issue IID or full issue URL; explicit project path when binding needs it. | Issue title/state/labels/assignees/URL plus comments when requested. | Do not infer issue state from MR text if issue read fails; list data is candidate-only when pagination is uncertain. |
| [`mr-pickup`](../SKILL.md#snippet-mr-pickup) | Read decision-grade MR metadata before review, final snapshot, and SHA guards. | Bound MR IID, full MR URL, or current branch; explicit project path/repo target when needed. | MR IID, draft/state, source/target branches, head SHA, pipeline, merge status, URL. | Do not approve or finish from list-only/candidate data; re-read one bound MR record. |
| [`artifact-capture`](../SKILL.md#snippet-artifact-capture) | Save MR comments, JSON, patch, and numstat for diff-first review. | Bound MR IID plus temp run directory. | Redacted local artifacts outside tracked paths. | Do not continue from missing/stale diff artifacts when they are needed for findings. |

## Fallback to full gitlab

Fall back to [`gitlab/SKILL.md`](../SKILL.md) when:

- the needed review read is not listed here;
- MCP is unavailable, the diff endpoint is unavailable, or list pagination limits block safe candidate selection;
- project binding is ambiguous or cross-repo review was explicitly chosen;
- you need issue or MR workflow operations beyond read-only pickup and artifact capture;
- a card and the full reference conflict. The full reference plus live fallback help wins.
