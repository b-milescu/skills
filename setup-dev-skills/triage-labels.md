# Triage Labels

Neutral seed: record only the invoked target's confirmed live vocabulary and
`project_profile.label_profile_ref` at its chosen path. Shared field guidance at
`skill://setup-dev-skills/reference/project-profile-facts.json` supplies neither
labels nor paths. Preserve custom choices/additions; no live label mutation,
lazy creation or global label-string assumption. Keep the
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
