# Review Packet (compact)

For docs-only, tests-only with no runtime safety impact, typo/lint, or a
dependency bump with no API/runtime impact. `filling-guide.md`
(review-packet-compact.md) owns eligibility and section instructions.

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
| RED | `<failing behavior check, or N/A with rationale; per reviewer-lift-schema.md>` |
| GREEN | `<passing behavior check, or N/A with rationale; per reviewer-lift-schema.md>` |
| Changed paths | `git diff --name-only <base>...HEAD` — measured output: `<paths separated with <br>>` |
| Touched safety surfaces | `<none or schema-listed surfaces>` |
| Acceptance surfaces | `<profile surface:evidence entries, or none; per reviewer-lift-schema.md>` |
| Decoupling proof | `<single change request, or co-running changes + contract proof>` |
| Reviewer Focus | `<none / changed docs/tests / 1 area to read hardest>` |
| Open Questions | `<none / count + OQ IDs>` |
| Approval authority | `<claim per reviewer-lift-schema.md and ../../start-review/REVIEW-FLOW.md#finish-authority-source-precedence>` |
| Approval authority source | `<verifiable source per reviewer-lift-schema.md>` |
| Finish authority | `<quoted claim per reviewer-lift-schema.md; default: none — requires explicit human/parent instruction>` |
| Finish authority source | `<verifiable provenance per reviewer-lift-schema.md and ../../start-review/REVIEW-FLOW.md#finish-authority-source-precedence>` |
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
