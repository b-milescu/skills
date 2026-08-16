# Agent Readiness Scorecard

Agent Readiness is the visible contract for an issue carrying `ready-for-agent`.
It records why an AFK builder can start without broad rediscovery and gives the
reviewer a stable checklist for spotting gaps.

This doc owns the readiness criteria. [Triage Labels](triage-labels.md) owns the
live label vocabulary. The [`plan-to-issues` issue body template](../../plan-to-issues/templates/issue-body.md#agent-readiness)
owns the compatible issue body section for newly published tracker issues. Keep
those files pointer-first; do not copy this full contract into each workflow doc.

## Pass rule

Before applying `ready-for-agent`, fill the scorecard in the issue body or in a
durable issue comment. The issue is ready only when every row is present and
specific enough for an AFK builder, or a maintainer explicitly waives the missing
field(s).

A waiver must name the missing field(s), the maintainer decision, and why the
issue is still safe for AFK work. If a row is unknown and not waived, do not apply
`ready-for-agent`; keep the issue as Needs info or HITL in the issue body until
the missing context is resolved.

## Scorecard

| Field | Readiness check |
| --- | --- |
| Acceptance criteria | Criteria are concrete, independently verifiable, and tied to user/operator-visible behavior or docs outcomes. Any command-based AC (grep, test, script) must be executed against the target repo at authoring time, with the observed output or count pasted into the brief. |
| Current-state / repro evidence | Bugs name reproduction evidence; enhancements/docs name the current baseline or gap; non-applicable cases say why. |
| Test strategy | Expected targeted checks and the full local Check Gate are named, including docs/link/read/grep evidence when no executable behavior changes. |
| Risk surface | Affected surfaces are explicit: docs, CLI, Dev Workflow, state, migration, external integration, credentials, deploy, or other. |
| Dependencies | Blockers, sequencing constraints, and related issues/MRs are listed, or `None` is stated. |
| Unknowns | Open questions and human decisions are listed; AFK issues have `None` or an explicit maintainer waiver. |
| AFK safety | The issue explains why an agent can proceed without new human decisions or live product/runtime/operator mutations. |
| Reviewer focus | The expected hardest review area is named so the reviewer can compare the MR against the readiness contract. |

## Use in `/plan-to-issues` publishing

New AFK issues published through `/plan-to-issues` use the compatible
`## Agent Readiness` section from the issue body template. Preserve that section
when posting generated issues. If the scorecard cannot pass and no maintainer
waiver exists, publish the issue as HITL or Needs info instead of applying the
AFK-ready label.
