# GitLab build read card

Small transport-context card for `/start-build` read-only GitLab work. MCP is primary; guarded `glab` fallback and flag/help ownership stay in [`gitlab/SKILL.md`](../SKILL.md). Apply the [`help-first` rule](../SKILL.md#guarded-glab-fallback-and-help-first-rule) only when a documented fallback path uses flagged `glab`.

## Use this card when

- running the local-repo preflight to verify MCP project binding and worktree safety before any GitLab work;
- reading issue metadata, labels, assignees, comments, and linked URLs before implementation;
- reading MR metadata for SHA guards, draft/state checks, and project binding after opening or updating a Draft MR.

## Snippets

| Snippet | Use | Inputs | Outputs | Fail closed |
| --- | --- | --- | --- | --- |
| [`local-repo-preflight`](../SKILL.md#snippet-local-repo-preflight) | Confirm MCP project binding plus local git worktree/default-branch safety before any build action. | Current worktree, remote-derived project path, selected branch. | Verified project path, repo URL, default branch, and local repo root. | Stop on auth failure, non-repo cwd, repo mismatch, or stale/missing default branch. |
| [`issue-pickup`](../SKILL.md#snippet-issue-pickup) | Read issue description, labels, assignees, URL, and comments for implementation planning. | Issue IID or full issue URL; explicit project path when binding needs it. | Issue title/state/labels/assignees/URL plus comments when requested. | Do not infer issue state from MR text if issue read fails; list data is candidate-only when pagination is uncertain. |

## Fallback to full gitlab

Fall back to [`gitlab/SKILL.md`](../SKILL.md) when:

- the needed build read is not listed here;
- MCP is unavailable or list pagination limits block safe candidate selection;
- project binding is ambiguous or cross-repo work was explicitly chosen;
- you need issue or MR workflow operations beyond read-only pickup;
- a card and the full reference conflict. The full reference plus live fallback help wins.
