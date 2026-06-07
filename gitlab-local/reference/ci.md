# GitLab review CI card

Small transport-context card for `/start-review` CI reads and exact-SHA CI waiting. MCP is primary; guarded `glab` fallback and flag/help ownership stay in [`gitlab-local/SKILL.md`](../SKILL.md). Apply the [`help-first` rule](../SKILL.md#guarded-glab-fallback-and-help-first-rule) only when a documented fallback path uses flagged `glab`.

CI reads feed the exact-SHA CI phase of the **GitLab Mutation Guard** in [`mutation-guard.md`](mutation-guard.md); this card stays read-only and never marks a mutation safe by itself.

## Use this card when

- verifying the builder's Reviewer Lift CI row against current MR metadata;
- deciding whether CI is exact-SHA green, pending-auto-merge eligible, red, missing, stale, or waived;
- waiting for CI on the reviewed SHA when the caller/role is allowed to wait;
- recording pipeline URL, ID, status, and SHA in a Review Report or handoff.

## Snippets

| Snippet | Use | Inputs | Outputs | Fail closed |
| --- | --- | --- | --- | --- |
| [`ci-decision-snapshot`](../SKILL.md#snippet-ci-decision-snapshot) | Capture decision-grade MR SHA, pipeline metadata, and merge status; branch CI is fallback/progress evidence. | Bound MR IID/URL, source branch, reviewed SHA, and explicit project/repo target when needed. | MR head SHA, pipeline ID/URL/status/SHA when exposed, detailed merge status, branch CI JSON when used. | Stale, missing, red, canceled, skipped, or SHA-mismatched CI is not approval evidence. |
| [`ci-watch-sha-pinned`](../SKILL.md#snippet-ci-watch-sha-pinned) | Poll until the reviewed SHA has a pass/fail/stale/timeout verdict. | MR IID, source branch, reviewed SHA, timeout, poll interval, output format. | Machine or human CI verdict with observed SHA/status/pipeline URL/result. | Head changes, stale pipeline SHA, red/canceled/skipped status, or timeout never pass. |

## Fallback to full gitlab-local

Fall back to [`gitlab-local/SKILL.md`](../SKILL.md) when:

- MCP pipeline data is unavailable and branch CI shape needs fallback interpretation;
- a human waiver or project-specific protected-merge policy changes CI routing;
- helper output, JSON fields, or pipeline status names differ from the card;
- you need troubleshooting detail for failed/running jobs beyond the CI decision snapshot;
- a card and the full reference conflict. The full reference plus live fallback help wins.
