# GitLab review CI card

Small command-context card for `/start-review` CI reads and exact-SHA CI waiting. Full command ownership stays in [`gitlab-local/SKILL.md`](../SKILL.md); this card is a pointer map, not a command copy. Apply the [`help-first` rule](../SKILL.md#help-first-rule) before running any flagged CLI command.

## Use this card when

- verifying the builder's Reviewer Lift CI row against current MR metadata;
- deciding whether CI is exact-SHA green, pending-auto-merge eligible, red, missing, stale, or waived;
- waiting for CI on the reviewed SHA when the caller/role is allowed to wait;
- recording pipeline URL, ID, status, and SHA in a Review Report or handoff.

## Snippets

| Snippet | Use | Inputs | Outputs | Fail closed |
| --- | --- | --- | --- | --- |
| [`ci-decision-snapshot`](../SKILL.md#snippet-ci-decision-snapshot) | Capture decision-grade MR SHA, pipeline metadata, and merge status; branch CI is fallback/progress evidence. | Bound MR IID/URL, source branch, and explicit repo target when needed. | MR head SHA, pipeline ID/URL/status/SHA when exposed, detailed merge status, branch CI JSON when used. | Stale, missing, red, canceled, skipped, or SHA-mismatched CI is not approval evidence. |
| [`ci-watch-sha-pinned`](../SKILL.md#snippet-ci-watch-sha-pinned) | Poll until the reviewed SHA has a pass/fail/stale/timeout verdict. | MR IID, source branch, reviewed SHA, timeout, poll interval, output format. | Machine or human CI verdict with observed SHA/status/pipeline URL/result. | Head changes, stale pipeline SHA, red/canceled/skipped status, or timeout never pass. |

## Fallback to full gitlab-local

Fall back to [`gitlab-local/SKILL.md`](../SKILL.md) when:

- the MR has no pipeline object and branch CI shape needs interpretation;
- a human waiver or project-specific protected-merge policy changes CI routing;
- helper output, JSON fields, or pipeline status names differ from the card;
- you need troubleshooting detail for failed/running jobs beyond the CI decision snapshot;
- a card and the full reference conflict. The full reference plus live help wins.
