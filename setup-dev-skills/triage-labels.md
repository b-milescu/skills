# Triage Labels

This file records the target repo's tracker labels and is the default
`project_profile.label_profile_ref`. `/setup-dev-skills` keeps it aligned with the
live tracker label set on every run, using
`setup-dev-skills/reference/project-profile-facts.json` as the fact source for
`label_profile_ref` and Triage Role mapping. Project-profile hooks may specialize
label vocabulary by pointing here, but must not create live labels, rely on lazy
label creation, hardcode a reusable skill's preferred label string, or weaken the
[safety-floor litany](skill://setup-dev-skills/docs/effort-scaling.md#hard-floors-never-scaled-away).

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
- Do not seed a concrete label string unless the target repo profile confirms it. If the tracker has no labels yet and the user wants triage-role labels, agree role names first (`afk_ready`, `needs_info`, `human_decision`), then record the exact live label strings the user chooses.
