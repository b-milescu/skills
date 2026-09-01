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

Publication, closure/readback, and finding-binding checks are canonical in
[`filling-guide.md`](filling-guide.md#general-rules-for-all-builder-templates).

## Reviewer Lift

Fill every row per `reviewer-lift-schema.md`; parent-owned mode follows `../reference/parent-owned-gate.md`.

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | `<MR head; refresh after every push>` |
| Finding bindings | `<per reviewer-lift-schema.md: none or validated report/SHA/finding-ID tuples>` |
| Review gate | `<mandatory / bypassed (human override)>` |
| Transport | `<mcp / eligible glab-fallback gap / n/a; per reviewer-lift-schema.md>` |
| Gate owner | `<builder / parent; parent-owned child records parent-owned/not-run and candidate SHA only>` |
| Gate coverage | `<full-local / hybrid / ci-only; never parent-owned>` |
| Gate coverage rationale | `<policy + required/local/unmapped CI mapping; refresh after push>` |
| CI pipeline | `<provider-native CI locator + ID + status + commit when available, or N/A — why>` |
| Local gate | `<status + exact command per reviewer-lift-schema.md and ../../start-review/REVIEW-FLOW.md#ci-decision-table; parent-owned: not-run per ../reference/parent-owned-gate.md>` |
| RED | `<behavior-touching implementation: failing check; or N/A with rationale; per reviewer-lift-schema.md>` |
| GREEN | `<passing behavior check, or N/A with rationale; per reviewer-lift-schema.md>` |
| Changed paths | `git diff --name-only <base>...HEAD` — measured output: `<paths separated with <br>>` |
| Touched safety surfaces | `<none or schema-listed surfaces>` |
| Acceptance surfaces | `<profile surface:evidence entries, or none; per reviewer-lift-schema.md>` |
| Decoupling proof | `<single change request, or co-running changes + contract proof>` |
| Reviewer Focus | `<1-2 areas to read hardest, or "none">` |
| Open Questions | `<count + list IDs (OQ-1, OQ-2, ...) or "none">` |
| Approval authority | `<claim per reviewer-lift-schema.md and ../../start-review/REVIEW-FLOW.md#finish-authority-source-precedence>` |
| Approval authority source | `<verifiable source per reviewer-lift-schema.md>` |
| Finish authority | `<quoted claim per reviewer-lift-schema.md; default: none — requires explicit human/parent instruction>` |
| Finish authority source | `<verifiable provenance per reviewer-lift-schema.md and ../../start-review/REVIEW-FLOW.md#finish-authority-source-precedence>` |
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
