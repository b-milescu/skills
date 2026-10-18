# Review Packet

Use one packet for every work type. Fill the default sections; include
conditional metadata and evidence only when their triggers apply.

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

Section instructions, conditional-section triggers, publication, closure/readback,
and finding-binding checks are canonical in
[`filling-guide.md`](filling-guide.md#general-rules-for-all-builder-templates).

Add `ADR needed?`, `Blocks`, or `Blocked by` metadata rows only when an ADR/design
decision or delivery dependency needs recording. Simple work omits them.

## Reviewer Lift

Fill every row per `reviewer-lift-schema.md`; parent-owned mode follows `../reference/parent-owned-gate.md`.

Child runs: `gate_owner_received: <literal launch value, or absent>` per
[builder-final-handoff.md](builder-final-handoff.md).

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated-copy from start-build/templates/reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | `<change-request head; refresh after every push>` |
| Finding bindings | `<per reviewer-lift-schema.md: none or validated report/SHA/finding-ID tuples>` |
| Review gate | `<mandatory / bypassed (human override)>` |
| Transport | `<identified opaque target transport evidence; no missing-value default>` |
| Gate owner | `<builder / parent; parent-owned child records parent-owned/not-run and candidate SHA only>` |
| Gate coverage | `<exact-candidate-local>` |
| Gate coverage rationale | `Policy <ref>; command <cmd>; candidate <sha>; coverage exact-candidate-local; result: <not-run — parent-owned \| PASS — Gate Receipt: <opaque locator>>` |
| CI pipeline | `<evidence=opaque locator; status=opaque status; commit=40-hex SHA, or N/A — reason>` |
| Local gate | `<status + exact command per reviewer-lift-schema.md; parent-owned: not-run until Gate Receipt per ../reference/parent-owned-gate.md>` |
| RED | `<behavior-touching implementation: failing native test; or N/A with rationale; do not fake tests; per reviewer-lift-schema.md>` |
| GREEN | `<same native test passing, or N/A with rationale; per reviewer-lift-schema.md>` |
| Changed paths | `git diff --name-only <base>...HEAD` — measured output: `<paths separated with <br>>` |
| Touched safety surfaces | `<none or schema-listed surfaces>` |
| Acceptance surfaces | `<profile surface:evidence entries, or none; per reviewer-lift-schema.md>` |
| Decoupling proof | `<single change request, or co-running changes + contract proof>` |
| Reviewer Focus | `<1-2 areas to read hardest, or "none">` |
| Open Questions | `<count + list IDs (OQ-1, OQ-2, ...) or "none">` |
| Approval authority | `<claim per reviewer-lift-schema.md and ../../start-review/REVIEW-FLOW.md#approval-authority-policy>` |
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

When unchanged impact is established, replace this section with **Safety
Confirmation**: one line confirming no external-system mutation path,
credential/secret-store handling, domain rule, state schema, migration, deploy
topology, or enforce-mode behavior changed.

Otherwise keep this heading and record each surface below, with supporting
evidence or `unknown — <missing proof and affected decision>`. An uninvestigated
surface is unknown, not `none` or an omitted section.

- **Safety invariants:** `<which invariants + how preserved, or established unchanged>`
- **State / persistence / migration:** `<stores, migration numbers, smoke-test plan, or established unchanged>`
- **External-system / credential:** `<mutation/credential delta and evidence, or established unchanged>`

## Test Evidence

Expand on the `RED`/`GREEN` Reviewer Lift fields with targeted results and
regression evidence. Record the exact-candidate local gate outcome or the
parent-owned/not-run contract; CI is advisory, not a replacement. State
`TDD: N/A — <reason>` when applicable and retain any check restriction/not-run
status. For risk-relevant claims, name establishing proof and conditions
requiring unknown per `filling-guide.md`.

## Follow-ups

Linked issues for deferred items, or `None`.

<!--
Conditional sections — add the matching heading below ONLY when its trigger
applies; filling-guide.md (review-packet.md > Conditional sections) owns them.

## Architecture / Design Decisions
## Diff Summary
## External-System and Credential Safety
## State, Persistence, and Migration Impact
## Manual / Operational Evidence
## Reviewer Hints
## Reviewer Focus
## Open Questions
-->
