# Triage Labels

This repo treats GitHub's live label set as the source of truth. The `setup-dev-skills` skill owns regenerating this file when tracker labels change.

Use this file as `project_profile.label_profile_ref` for this repo. The profile
may point to this label vocabulary, but it must not create live labels, rely on
lazy label creation, or weaken the
[safety-floor litany](../../start-build/SAFETY.md#safety-floors).

Live set for `b-milescu/skills`, read with `gh label list -R b-milescu/skills`:

## Live label inventory

| Label | Category | Meaning / use |
| --- | --- | --- |
| `docs` | kind | Documentation-only or documentation-focused work. |
| `human-decision` | triage role | Issue needs a maintainer decision before AFK work. |
| `needs-info` | triage role | Issue needs more information before AFK work. |
| `ready` | status | Existing generic readiness label. Meaning is not yet specialised; ask before using when `ready-for-agent` would also fit. |
| `ready-for-agent` | triage role | Fully specified and safe for AFK agent implementation without new human decisions; requires an Agent Readiness pass or maintainer waiver. |
| `refactor` | kind | Refactoring or structure-improvement work. |


## Triage Role map

| Triage Role | Live label | Notes |
| --- | --- | --- |
| `afk_ready` | `ready-for-agent` | Apply the live label only after an [Agent Readiness](../../reference/agent-readiness-scorecard.md) pass or a recorded maintainer waiver. |
| `needs_info` | `needs-info` | Issue needs more information before AFK work; apply the live label and state the missing information in issue/PR prose. |
| `human_decision` | `human-decision` | Issue needs a maintainer decision before AFK work; apply the live label and state the decision request in issue/PR prose. |

These values are this repo's project-specific vocabulary; reusable skills must read `project_profile.label_profile_ref` instead of assuming these label strings globally.

## Agent rules

- Apply only labels listed above. Do not rely on GitHub's implicit label creation: the issues API may create a label name that does not exist, so verify each name against the live inventory (`get_label` or `gh label list`) before an issue write.
- Use `ready-for-agent` only for AFK-ready issues with a passing or explicitly waived [Agent Readiness scorecard](../../reference/agent-readiness-scorecard.md).
- Use `docs` or `refactor` as optional kind labels when the slice fits.
- Apply `needs-info` when an issue needs more information before AFK work, and state the missing information in the issue/PR body or a comment.
- Apply `human-decision` when an issue needs a maintainer decision before AFK work, and state the decision request in the issue/PR body or a comment. Keep this distinct from the PR-level `human-decision-needed` Review Report verdict token.
- When the maintainer decision is recorded and the `human-decision` label is removed, reconcile the issue body in that same step: mark the decision acceptance criterion satisfied and point it at the durable decision note that records the decision, so the body cites that record instead of restating the decision. This exit rule is bounded to that label transition; it does not license rewriting issue bodies generally.
- Do not apply `needs-triage`, `ready-for-human`, `needs-revision`, or `needs-unblock`, or any label GitHub seeds into new repositories (`bug`, `documentation`, `duplicate`, `enhancement`, `good first issue`, `help wanted`, `invalid`, `question`, `wontfix`); none of them exists in this repository, because the defaults were deleted at repository setup.
- If work needs revision or unblock, state that in the issue/PR body or comment and ask a maintainer whether the live vocabulary should expand.

## Agent Readiness

[Agent Readiness scorecard](../../reference/agent-readiness-scorecard.md) owns the readiness fields and the pass/waiver rule gating `ready-for-agent`. That contract changes no label names; use only the live labels above.
