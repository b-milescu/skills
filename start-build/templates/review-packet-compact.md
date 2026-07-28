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

The issue-closing reference must be a plain, unbolded `Closes #N` on its own line
(e.g. `Closes #123`). Do not bold or wrap the keyword (`**Closes:** #N` and
`` `Closes #N` `` are not matched by GitLab's auto-close regex and leave the issue
open after merge).

Closes #N

## Reviewer Lift

Field names, order, and required semantics are canonical in `reviewer-lift-schema.md`; parent-owned Gate Receipt / Check Gate ownership is canonical in `../reference/parent-owned-gate.md`.

Before a parent-owned ready transition, validate the canonical receipt and this
current Reviewer Lift with `skill://start-build/scripts/validate-gate-receipt.mjs`,
supplying `--gate-receipt-note-id "<current Gate Receipt note ID>"`.

Before publication or a ready transition, validate every non-`none` `Finding bindings` tuple against the originating Review Report files with `node start-review/scripts/validate-finding-bindings.mjs --report <report.md> ... --lift <this-review-packet.md>` per `../../start-review/reference/finding-identities.md`.

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | `<head SHA at ready-marking; update on every post-ready push>` |
| Finding bindings | `<none, or report=<stable report locator>; sha=<originating reviewed SHA>; id=<MF-N/SF-N/C-N>; separate multiple tuples with <br>; validate against originating reports before publication/ready>` |
| Review gate | `<mandatory / bypassed (human override)>` |
| Gate owner | `<builder / parent; parent-owned child records parent-owned/not-run and candidate SHA only>` |
| Gate coverage | `<full-local / hybrid / ci-only; never parent-owned>` |
| Gate coverage rationale | `<policy source + required CI mapping; unmapped CI-only jobs or none; stale/wrong-SHA evidence invalid after push>` |
| CI pipeline | `<pipeline URL + ID + status + commit SHA when available, or N/A — why>` |
| Local gate | `<PASS / FAIL while draft / N/A — why / not-run — parent-owned per ../reference/parent-owned-gate.md with Gate Receipt pending; completed local gate or parent Gate Receipt permits review launch for every coverage class; hybrid/ci-only may launch with exact-SHA CI pending, but failed/canceled/skipped/missing/stale/wrong-SHA CI blocks pass and finish unless waived> — <exact command>` |
| RED | `<behavior-touching implementation: exact failing test/check command + expected failure reason, or N/A with rationale — why; do not fake tests>` |
| GREEN | `<behavior-touching implementation: exact passing test/check command + brief result, or N/A with rationale — why; do not fake tests>` |
| Changed paths | `<high-level path list / diffstat>` |
| Touched safety surfaces | `<none / external-system / credentials / state / migration / gates / locks / deploy / wire-protocol / other>` |
| Acceptance surfaces | `<none, or per-surface evidence; allowed surfaces come from project_profile.acceptance_surfaces_ref (no ref ⇒ none); evidence enum: test/smoke/docs-read/ci/N/A; compact syntax: surface:evidence — e.g. docs:docs-read, prompt:test; each declared surface must have test/smoke/docs-read/ci/N/A evidence before ready/pass>` |
| Decoupling proof | `<single MR, or co-running MR IIDs/branches + Decoupling Contract proof summary>` |
| Reviewer Focus | `<none / changed docs/tests / 1 area to read hardest>` |
| Open Questions | `<none / count + OQ IDs>` |
| Approval authority | `<default-after-pass / restricted: source-or-reason>` |
| Approval authority source | `<stable repo policy ref, e.g. start-review/REVIEW-FLOW.md#approval-authority-policy / parent task prompt / human or MR comment URL / project rulebook path+section>` |
| Merge authority | `<quoted claim; defaults to none — requires explicit human/parent instruction; a granting value (reviewer may merge / queue auto-merge / project default: ...) needs an affirmative quoted grant in the source: approval-only / reviewer may merge / queue auto-merge / human release / project default: ...>` |
| Merge authority source | `<parent task prompt / human MR comment URL / rulebook path+section / project default source; for any non-none value must quote an affirmative merge/auto-merge grant — a disclaiming/silent source forces the none default>` |
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
| AC-N literal string: `<quoted target text>` | `<exact-string comparison evidence against current head SHA; only when this criterion is byte-for-byte wording-sensitive>` |

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
