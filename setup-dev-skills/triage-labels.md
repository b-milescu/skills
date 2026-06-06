# Triage Labels

This file records the target repo's tracker labels. `/setup-dev-skills` should keep it aligned with the live tracker label set whenever it is run.

Use this file as the default `project_profile.label_profile_ref`. Project-profile
hooks may specialize label vocabulary by pointing here, but they must not create
live labels, rely on lazy label creation, or weaken reviewed-SHA binding,
exact-SHA CI, explicit authority source, independent review, child-builder
boundaries, verifier read-only boundaries, or MCP-first transport correctness
plus help-first `glab` fallback correctness.

## Live label inventory

| Label | Category | Meaning / use |
| --- | --- | --- |
| `<tracker-label>` | `<triage role / kind / status>` | `<when agents should apply it>` |

## Agent rules

- Apply only labels listed in the inventory above.
- Do not rely on lazy label creation. Creating, deleting, or renaming tracker labels is a tracker mutation and needs an explicit user decision.
- If a workflow needs a state that has no live label, describe the state in the issue/MR body or a comment instead of inventing a label.

## Setup notes

When running `/setup-dev-skills`:

1. Read the live labels first (`glab label list`, `gh label list`, or the local tracker's label source).
2. Compare them with any existing `docs/agents/triage-labels.md`. Treat canonical-five tables, `Label in mattpocock/skills`, or lazy-label-creation prose as older setup output that needs reconciliation.
3. Ask whether to document the live labels as-is, create/migrate labels to a canonical role vocabulary, or use a hybrid of triage-role and kind labels.
4. Write this file from the confirmed decision, preserving any user-added project notes that do not conflict with live labels.

If the tracker has no labels yet and the user wants triage-role labels, common starting roles are: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`.
