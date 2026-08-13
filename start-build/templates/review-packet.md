# Review Packet

Summary-first packet. Fill the default sections below; add a conditional section
only when its trigger applies. `filling-guide.md` (review-packet.md) owns
section-by-section instructions and the conditional-section triggers.

## Metadata

| Field | Value |
|---|---|
| Work item | `<provider-native identifier and locator>` |
| Change request | `<provider-native identifier and locator>` |
| Title | |
| Builder | `@builder — <exact model id if exposed>` |
| Branch | |
| Base commit | |
| Current/reviewed commit(s) | |
| ADR needed? | `<yes/no; planned ADR slug if yes>` |
| Blocks | |
| Blocked by | |

Before publication or a ready transition, use the selected `/forge` provider to
validate the native work-item relationship/closure preview and require
provider-native publication readback. Missing, incomplete, stale, or mismatched
evidence fails closed.

## Reviewer Lift

Field names, order, and required semantics are canonical in `reviewer-lift-schema.md`; parent-owned Gate Receipt / Check Gate ownership is canonical in `../reference/parent-owned-gate.md`.

Before a parent-owned ready transition, validate the canonical receipt and this
current Reviewer Lift with `skill://start-build/scripts/validate-gate-receipt.mjs`,
supplying `--gate-receipt-locator "<opaque current Gate Receipt locator>"`.

Before publication or a ready transition, validate every non-`none` `Finding bindings` tuple against the originating Review Report files with `node start-review/scripts/validate-finding-bindings.mjs --report <report.md> ... --lift <this-review-packet.md>` per `../../start-review/reference/finding-identities.md`.

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | `<change-request head commit at ready-marking; update on every post-ready push>` |
| Finding bindings | `<none, or report=<stable report locator>; sha=<originating reviewed commit>; id=<MF-N/SF-N/C-N>; separate multiple tuples with <br>; validate against originating reports before publication/ready>` |
| Review gate | `<mandatory / bypassed (human override)>` |
| Gate owner | `<builder / parent; parent-owned child records parent-owned/not-run and candidate SHA only>` |
| Gate coverage | `<full-local / hybrid / ci-only; never parent-owned>` |
| Gate coverage rationale | `<policy source + required CI mapping; unmapped CI-only jobs or none; stale/wrong-SHA evidence invalid after push>` |
| CI pipeline | `<provider-native CI locator + ID + status + commit when available, or N/A — why>` |
| Local gate | `<PASS / FAIL while draft / N/A — why / not-run — parent-owned per ../reference/parent-owned-gate.md with Gate Receipt pending; completed local gate or parent Gate Receipt permits review launch for every coverage class; hybrid/ci-only may launch with exact-commit CI pending, but failed/canceled/skipped/missing/stale/wrong-commit CI blocks pass and finish unless waived> — <exact command, e.g. make check>` |
| RED | `<behavior-touching implementation: exact failing test/check command + expected failure reason, or N/A with rationale — why; do not fake tests>` |
| GREEN | `<behavior-touching implementation: exact passing test/check command + brief result, or N/A with rationale — why; do not fake tests>` |
| Changed paths | `git diff --name-only <base>...HEAD` — measured output: `<one path per line, separated with <br>>` |
| Touched safety surfaces | `<none / external-system / credentials / state / migration / gates / locks / deploy / wire-protocol / other>` |
| Acceptance surfaces | `<none, or per-surface evidence; allowed surfaces come from project_profile.acceptance_surfaces_ref (no ref ⇒ none); evidence enum: test/smoke/docs-read/ci/N/A; compact syntax: surface:evidence — e.g. docs:docs-read, prompt:test; each declared surface must have test/smoke/docs-read/ci/N/A evidence before ready/pass>` |
| Decoupling proof | `<single change request, or co-running change-request identifiers/branches + Decoupling Contract proof summary>` |
| Reviewer Focus | `<1-2 areas to read hardest, or "none">` |
| Open Questions | `<count + list IDs (OQ-1, OQ-2, ...) or "none">` |
| Approval authority | `<default-after-pass / restricted: source-or-reason>` |
| Approval authority source | `<stable repo policy ref / parent task prompt / human or provider discussion locator / project rulebook path+section>` |
| Finish authority | `<quoted claim; defaults to none — requires explicit human/parent instruction; a granting value needs an affirmative quoted grant in the source>` |
| Finish authority source | `<parent task prompt / human discussion locator / rulebook path+section / project default source; a disclaiming or silent source forces the none default>` |
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
| AC-N literal string: `<quoted target text>` | `<exact-string comparison evidence against current head SHA; only when this criterion is byte-for-byte wording-sensitive>` |

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
