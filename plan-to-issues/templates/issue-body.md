## Type

AFK / HITL / Needs info

## Parent

Reference to the parent issue, PRD, or source material. Omit if none.

## What to build

Concise description of the vertical slice and the user/operator-visible behavior it delivers. Describe the end-to-end outcome, not a layer-by-layer task list.

Avoid specific file paths or code snippets unless they encode a reviewed decision that prose would lose. Keep snippets small and decision-focused.

## User stories covered

- As a ..., I can ..., so that ...

## Acceptance criteria

<!-- Command-based ACs (grep, test, script) must be executed against the target repo at authoring time, with the observed output or count pasted here. See ../shared-reference/agent-readiness-scorecard.md#scorecard. Authoring rules: (1) scope acceptance greps to owned paths, excluding vendored/third-party dirs (e.g. Libs/, vendor/, node_modules/); (2) always state the baseline commit for any measured baseline (counts, line numbers); (3) prefer content anchors (function/heading names) over bare line numbers, which go stale as batches merge. -->

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Agent Readiness

Fill this before applying the target repo's AFK-ready label from its triage-labels doc. If a field is intentionally missing, name the maintainer waiver and reason; otherwise set Type to HITL or Needs info instead of AFK.

| Field | Value |
| --- | --- |
| Acceptance criteria quality | Criteria are concrete, independently verifiable, and tied to the slice outcome. |
| Current-state / repro evidence | Current behavior, reproduction evidence, baseline docs gap, or N/A with reason. |
| Test strategy | Targeted checks plus full local Check Gate expected for review evidence. |
| Risk surface | docs / CLI / Dev Workflow / state / migration / external integration / credentials / deploy / other. |
| Dependencies | Blockers, ordering constraints, related issues/change requests, or None. |
| Unknowns | Open questions/human decisions, or None. |
| AFK safety | Why an agent can proceed without new human decisions or live product/runtime/operator mutations. |
| Reviewer focus | Area the reviewer should inspect hardest. |

## Out of scope

- Explicit adjacent work not included in this slice.

## Safety / evidence notes

- Affected surfaces: docs / CLI / Dev Workflow / state / migration / external integration / credentials / deploy / other.
- Expected evidence: tests, docs read/grep, dry-run, review packet notes, or other checks.
- No live product/runtime/operator external mutations unless explicitly approved.

## Blocked by

None — can start immediately.

Or:

- #123 — reason this must land first.
