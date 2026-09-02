# Triage Labels

This file records the target repo's tracker labels. `/setup-dev-skills` should keep it aligned with the live tracker label set whenever it is run, using `setup-dev-skills/reference/project-profile-facts.json` as the fact source for `label_profile_ref` and Triage Role mapping.

Use this file as the default `project_profile.label_profile_ref`. Project-profile
hooks may specialize label vocabulary by pointing here, but they must not create
live labels, rely on lazy label creation, hardcode a reusable skill's preferred
label string, or weaken exact-candidate local Gate Receipt, reviewed-SHA binding,
explicit authority source, independent review, child-builder boundaries,
verifier read-only boundaries, or MCP-first transport correctness plus
help-first provider fallback correctness.

## Live label inventory

| Label | Category | Meaning / use |
| --- | --- | --- |
| `<tracker-label>` | `<triage role / kind / status>` | `<when agents should apply it>` |

## Triage Role map

| Triage Role | Live label | Notes |
| --- | --- | --- |
| `afk_ready` | `<live tracker label or N/A>` | Fully specified and safe for AFK agent implementation. Do not assume a global label string. |
| `needs_info` | `<live tracker label or N/A>` | Needs more information before AFK work; record in prose when no live label exists. |
| `human_decision` | `<live tracker label or N/A>` | Needs maintainer decision before AFK work; record in prose when no live label exists. |

## Agent rules

- Apply only labels listed in the inventory above.
- Map Triage Role names to live labels through the table above; if a role has `N/A`, describe the state in the issue/MR body or a comment instead of inventing a label.
- Do not rely on lazy label creation. Creating, deleting, or renaming tracker labels is a tracker mutation and needs an explicit user decision.

## Setup notes

When running `/setup-dev-skills`:

1. Read the live labels first (`glab label list`, `gh label list`, or the local tracker's label source).
2. Compare them with any existing `docs/agents/triage-labels.md` or target-specific replacement path from `project-profile-facts.json`. Treat canonical-five tables, `Label in mattpocock/skills`, or lazy-label-creation prose as older setup output that needs reconciliation.
3. Ask whether to document the live labels as-is, create/migrate labels to a chosen role vocabulary, or use a hybrid of Triage Role and kind labels.
4. Write this file from the confirmed decision, preserving any user-added project notes that do not conflict with live labels.

If the tracker has no labels yet and the user wants triage-role labels, discuss role names first (`afk_ready`, `needs_info`, `human_decision`) and then record the exact live label strings the user chooses. Do not seed a concrete label string unless the target repo profile confirms it.
