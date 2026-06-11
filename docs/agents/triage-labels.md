# Triage Labels

This repo treats GitLab's live label set as the source of truth. `/setup-dev-skills` owns regenerating this file when tracker labels change.

Use this file as `project_profile.label_profile_ref` for this repo. The profile
may point to this label vocabulary, but it must not create live labels, rely on
lazy label creation, or weaken reviewed-SHA binding, exact-SHA CI, explicit
authority source, independent review, child-builder boundaries, verifier
read-only boundaries, or MCP-first transport correctness plus help-first `glab`
fallback correctness.

Verified on 2026-06-11 with `glab label list`:

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
| `afk_ready` | `ready-for-agent` | Fully specified and safe for AFK agent implementation without new human decisions; requires an Agent Readiness pass or maintainer waiver. |
| `needs_info` | `needs-info` | Issue needs more information before AFK work; apply the live label and state the missing information in issue/MR prose. |
| `human_decision` | `human-decision` | Issue needs a maintainer decision before AFK work; apply the live label and state the decision request in issue/MR prose. |

These values are this repo's project-specific vocabulary and match `setup-dev-skills/reference/project-profile-facts.json`; reusable skills must read `project_profile.label_profile_ref` instead of assuming these label strings globally.

## Agent rules

- Apply only labels listed above. Do not rely on GitLab lazy label creation.
- Use `ready-for-agent` only for AFK-ready issues with a passing or explicitly waived [Agent Readiness scorecard](agent-readiness-scorecard.md).
- Use `docs` or `refactor` as optional kind labels when the slice fits.
- Apply `needs-info` when an issue needs more information before AFK work, and state the missing information in the issue/MR body or a comment.
- Apply `human-decision` when an issue needs a maintainer decision before AFK work, and state the decision request in the issue/MR body or a comment. Keep this distinct from the MR-level `human-decision-needed` Review Report verdict token.
- Do not apply `needs-triage`, `ready-for-human`, `wontfix`, `needs-revision`, or `needs-unblock`; those labels do not exist in this project.
- If work needs revision or unblock, state that in the issue/MR body or comment and ask a maintainer whether the live vocabulary should expand.

## Agent Readiness

Before applying `ready-for-agent`, record the visible readiness contract using [Agent Readiness scorecard](agent-readiness-scorecard.md). The scorecard covers acceptance criteria, current-state/repro evidence, test strategy, risk surface, dependencies, unknowns, AFK safety, and reviewer focus.

Do not apply `ready-for-agent` unless the scorecard passes or a maintainer explicitly waives the missing field(s) in the issue body or a durable issue comment. A waiver records the missing field(s), who accepted the gap, and why the issue remains safe for AFK implementation. This rule changes no label names; use only the live labels listed above.
