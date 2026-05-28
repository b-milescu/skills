# Triage Labels

This repo treats GitLab's live label set as the source of truth. `/setup-dev-skills` owns regenerating this file when tracker labels change.

Verified on 2026-05-27 with `glab label list`:

| Label | Category | Meaning / use |
| --- | --- | --- |
| `docs` | kind | Documentation-only or documentation-focused work. |
| `ready` | status | Existing generic readiness label. Meaning is not yet specialised; ask before using when `ready-for-agent` would also fit. |
| `ready-for-agent` | triage role | Fully specified and safe for AFK agent implementation without new human decisions; requires an Agent Readiness pass or maintainer waiver. |
| `refactor` | kind | Refactoring or structure-improvement work. |

## Agent rules

- Apply only labels listed above. Do not rely on GitLab lazy label creation.
- Use `ready-for-agent` only for AFK-ready issues with a passing or explicitly waived [Agent Readiness scorecard](agent-readiness-scorecard.md).
- Use `docs` or `refactor` as optional kind labels when the slice fits.
- Do not apply `needs-triage`, `needs-info`, `ready-for-human`, `wontfix`, `needs-revision`, or `needs-unblock`; those labels do not exist in this project.
- If work needs more information, a human decision, revision, or unblock, state that in the issue/MR body or comment and ask a maintainer whether the live vocabulary should expand.

## Agent Readiness

Before applying `ready-for-agent`, record the visible readiness contract using [Agent Readiness scorecard](agent-readiness-scorecard.md). The scorecard covers acceptance criteria, current-state/repro evidence, test strategy, risk surface, dependencies, unknowns, AFK safety, and reviewer focus.

Do not apply `ready-for-agent` unless the scorecard passes or a maintainer explicitly waives the missing field(s) in the issue body or a durable issue comment. A waiver records the missing field(s), who accepted the gap, and why the issue remains safe for AFK implementation. This rule changes no label names; use only the live labels listed above.
