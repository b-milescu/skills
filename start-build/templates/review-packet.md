# Review Packet

Summary-first packet. Fill the default sections below; add a conditional section
only when its trigger applies. `filling-guide.md` (review-packet.md) owns
section-by-section instructions and the conditional-section triggers.

## Metadata

| Field | Value |
|---|---|
| Issue | `<gitlab issue URL>` |
| Title | |
| Builder | `@builder — <exact model id if exposed, e.g. claude-opus-4-7>` |
| Branch | |
| Base commit | |
| Commit(s) under review | |
| Status | `<draft / ready-for-review / stuck>` |
| ADR needed? | `<yes/no; planned ADR slug if yes>` |
| Blocks | |
| Blocked by | |

## Reviewer Lift

Field names, order, and required semantics are canonical in `reviewer-lift-schema.md`.

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | `<head SHA at ready-marking; update on every post-ready push>` |
| Review gate | `<mandatory / bypassed (human override)>` |
| CI pipeline | `<pipeline URL + ID + status + commit SHA when available, or N/A — why>` |
| Local gate | `<PASS before ready/review / FAIL while draft / N/A — why / not-run — parent-owned with Gate Receipt pending> — <exact command, e.g. make check>` |
| RED | `<behavior-touching implementation: exact failing test/check command + expected failure reason, or N/A with rationale — why; do not fake tests>` |
| GREEN | `<behavior-touching implementation: exact passing test/check command + brief result, or N/A with rationale — why; do not fake tests>` |
| Changed paths | `<high-level path list / diffstat>` |
| Touched safety surfaces | `<none / external-system / credentials / state / migration / gates / locks / deploy / other>` |
| Decoupling proof | `<single MR, or co-running MR IIDs/branches + Decoupling Contract proof summary>` |
| Reviewer Focus | `<1-2 areas to read hardest, or "none">` |
| Open Questions | `<count + list IDs (OQ-1, OQ-2, ...) or "none">` |
| Approval authority | `<default-after-pass / restricted: source-or-reason>` |
| Approval authority source | `<stable repo policy ref, e.g. start-review/REVIEW-FLOW.md#approval-authority-policy / parent task prompt / human or MR comment URL / project rulebook path+section>` |
| Merge authority | `<quoted claim: approval-only / reviewer may merge / queue auto-merge / human release / project default: ...>` |
| Merge authority source | `<parent task prompt / human MR comment URL / rulebook path+section / project default source>` |
| Delta since last ready push | `<N/A before ready; after ready: old SHA -> new SHA, reason, changed files, gate rerun, substantive? yes/no>` |
<!-- REVIEWER-LIFT-SCHEMA:END -->

## Summary

One paragraph: what changed, why, and the observable effect on users/operators.
Name loaded context sources beyond the issue and rulebook index (each with why
relevant), or write `none beyond issue and rulebook index`.

## Scope

- **In scope:**
- **Out of scope:**

## Acceptance Criteria Evidence

| Acceptance criterion | Evidence |
|---|---|
| AC-1: `<criterion>` | `<test/command/link/manual evidence>` |

## Safety / State / External Delta

One line per surface; write `N/A — <reason>` when a surface is untouched.

- **Safety invariants:** `<none changed / which invariants + how preserved>`
- **State / persistence / migration:** `<none / which stores, migration numbers, smoke-test plan>`
- **External-system / credential:** `<no live external mutation; no secret read/printed/committed / details>`

## Test Evidence

Expand on the `RED`/`GREEN` Reviewer Lift fields: targeted tests, full check
gate output (or CI link), and regression evidence for behavior-touching
refactors. State `TDD: N/A — <reason>` for non-behavior changes.

## Reviewer Focus

What could go wrong and where to read hardest. Mirror the Reviewer Lift >
Reviewer Focus headline, or write `none`.

## Open Questions

`None.` or stable OQ-N IDs the reviewer can answer/escalate.

## Follow-ups

Linked issues for deferred items, or `None`.

<!--
Conditional sections — add the matching heading below ONLY when its trigger
applies. Triggers and filling instructions live in filling-guide.md
(review-packet.md > Conditional sections).

## Architecture / Design Decisions   (a non-trivial design choice or required ADR)
## Diff Summary                       (large/spread diff needing a per-file map)
## Manual / Operational Evidence      (dry-run / runbook / read-only operator output)
## Reviewer Hints                     (files/tests to inspect first)
-->
