# GitLab build action card

Small transport-context card for `/start-build` GitLab Draft MR creation, description updates, ready-marking, and note actions. MCP is primary; guarded `glab` fallback and flag/help ownership stay in [`gitlab/SKILL.md`](../SKILL.md). Apply the [`help-first` rule](../SKILL.md#guarded-glab-fallback-and-help-first-rule) only when a documented fallback path uses flagged `glab`.

Before any mutating build action, apply the **GitLab Mutation Guard** in [`mutation-guard.md`](mutation-guard.md) (`skill://gitlab/reference/mutation-guard.md`). This card maps build snippets to the guard; it does not replace the guard order.

## Use this card when

- opening an early Draft MR once the source branch exists remotely;
- refreshing the MR description or Reviewer Lift block without changing draft/ready state;
- marking a Draft MR ready after the local gate passes;
- posting build-flow comments to an MR or an issue.

## Snippets

| Snippet | Use | Inputs | Outputs | Fail closed |
| --- | --- | --- | --- | --- |
| [`draft-mr-create`](../SKILL.md#snippet-draft-mr-create) | Open the early Draft MR with a Review Packet and `Closes #<iid>` once the source branch is pushed. | Source branch (pushed), target branch, title, Review Packet body (content-byte-safe), project path. | Draft MR on the bound project with `Closes #<iid>` and a post-create MCP re-read. | Block on missing source branch remote ref; do not create MR before branch is pushed; description must include plain `Closes #<iid>`. |
| [`mr-description-update`](../SKILL.md#snippet-mr-description-update) | Refresh the MR description and Reviewer Lift without changing draft/ready state. | Bound MR IID, updated Review Packet body (content-byte-safe). | Updated description on the bound MR plus post-update MCP re-read. | Do not combine with ready-marking; verify head SHA unchanged after update; content must pass byte-safe validation before mutation. |
| [`draft-mr-mark-ready`](../SKILL.md#snippet-draft-mr-mark-ready) | Mark the Draft MR ready for review after the local gate passes and the Reviewer Lift names the current head SHA. | Bound MR IID, local gate pass status, current head SHA in Reviewer Lift. | MR transitioned from draft to open/ready, with post-update verification. | Block if local gate has not passed or is not documented N/A; block if Reviewer Lift head SHA does not match current head; do not combine with description update in one step. |
| [`mr-note-create`](../SKILL.md#snippet-mr-note-create) | Post MR comments only: build status notes, revision responses, unblock updates. | Bound MR IID or full MR URL; content-byte-safe comment body. | One non-resolvable MR note/comment on the bound MR plus MCP re-read evidence. | Never pair issue-note in one step; do not post with missing project binding or unreviewed body. |
| [`issue-note-create`](../SKILL.md#snippet-issue-note-create) | Post issue comments only when the issue workflow explicitly calls for an issue note. | Bound issue IID or URL; content-byte-safe issue comment body. | One issue note/comment on the bound issue plus MCP re-read evidence. | Do not use for MR build notes or Review Reports. |

## Fallback to full gitlab

Fall back to [`gitlab/SKILL.md`](../SKILL.md) and the Mutation Guard when:

- an action snippet listed here needs exact fallback syntax, flag verification, or `mcp_gap_state` classification;
- MCP note/MR tooling is unavailable or an API fallback gap is hit;
- authority/source, project policy, or caller identity needs a variant not covered by this card;
- GitLab permission errors, post-mutation re-read, or merge-state drift need troubleshooting;
- you need any approval, merge, auto-merge, sha-bound finish, or CI-gate actions — those are not in scope for a builder; see `gitlab/SKILL.md` and the review cards for that transport.
