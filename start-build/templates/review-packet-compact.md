# Review Packet (compact)

For docs-only, tests-only with no runtime safety impact, typo/lint, or a
dependency bump with no API/runtime impact. `filling-guide.md`
(review-packet-compact.md) owns eligibility and section instructions.

## Metadata

| Field | Value |
|---|---|
| Issue | `<gitlab issue URL>` |
| Title | |
| Builder | `@builder — <exact model id if exposed, e.g. claude-opus-4-7>` |
| Branch | |
| Base commit | |
| Commit(s) under review | |
| Status | `<draft / ready-for-review>` |

## Reviewer Lift

Field names, order, and required semantics are canonical in `reviewer-lift-schema.md`; parent-owned Gate Receipt / Check Gate ownership is canonical in `../reference/parent-owned-gate.md`.

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | `<head SHA at ready-marking; update on every post-ready push>` |
| Review gate | `<mandatory / bypassed (human override)>` |
| CI pipeline | `<pipeline URL + ID + status + commit SHA when available, or N/A — why>` |
| Local gate | `<PASS before ready/review / FAIL while draft / N/A — why / not-run — parent-owned per ../reference/parent-owned-gate.md with Gate Receipt pending> — <exact command>` |
| RED | `<behavior-touching implementation: exact failing test/check command + expected failure reason, or N/A with rationale — why; do not fake tests>` |
| GREEN | `<behavior-touching implementation: exact passing test/check command + brief result, or N/A with rationale — why; do not fake tests>` |
| Changed paths | `<high-level path list / diffstat>` |
| Touched safety surfaces | `<none / external-system / credentials / state / migration / gates / locks / deploy / other>` |
| Decoupling proof | `<single MR, or co-running MR IIDs/branches + Decoupling Contract proof summary>` |
| Reviewer Focus | `<none / changed docs/tests / 1 area to read hardest>` |
| Open Questions | `<none / count + OQ IDs>` |
| Approval authority | `<default-after-pass / restricted: source-or-reason>` |
| Approval authority source | `<stable repo policy ref, e.g. start-review/REVIEW-FLOW.md#approval-authority-policy / parent task prompt / human or MR comment URL / project rulebook path+section>` |
| Merge authority | `<quoted claim: approval-only / reviewer may merge / queue auto-merge / human release / project default: ...>` |
| Merge authority source | `<parent task prompt / human MR comment URL / rulebook path+section / project default source>` |
| Delta since last ready push | `<N/A before ready; after ready: old SHA -> new SHA, reason, changed files, gate rerun, substantive? yes/no>` |
<!-- REVIEWER-LIFT-SCHEMA:END -->

## Summary

One paragraph: what changed and why. Name loaded context sources beyond the
issue and rulebook index, or write `none beyond issue and rulebook index`.

## Scope

- **In scope:**
- **Out of scope:** `<usually: no runtime behavior, external paths, state schema, gates, or domain rules changed>`

## Acceptance Criteria Evidence

| Acceptance criterion | Evidence |
|---|---|
| AC-1: `<criterion>` | `<test/command/link/manual evidence>` |

## Safety Confirmation

`<Confirm none changed: product/runtime/operator external-system mutation path;
credential / secret-store handling; domain rule or strategy behavior; state
schema, migration, deploy topology, or enforce-mode behavior. Note any exception.>`

## Test Evidence

Commands run and result, or CI link. State `TDD: N/A — <reason>` for
compact-eligible non-behavior changes. A targeted markdown/read check may be
enough for docs-only work.

## Follow-ups

`None` or linked follow-up issues.
