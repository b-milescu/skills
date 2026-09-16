# Review Packet (compact)

A run uses exactly one packet: this compact variant for docs-only, tests-only
with no runtime safety impact, typo/lint, or a dependency bump with no
API/runtime impact; otherwise [review-packet.md](review-packet.md), which owns
every section, metadata field, and filling rule not restated below. Section
instructions, publication, closure/readback, and finding-binding checks are
canonical in [`filling-guide.md`](filling-guide.md#general-rules-for-all-builder-templates).

## Metadata

Full-packet fields minus `ADR needed?`, `Blocks`, and `Blocked by`.

## Reviewer Lift

Every row is required; `reviewer-lift-schema.md` owns their semantics and
`../reference/parent-owned-gate.md` owns parent-owned mode. Child runs add
`gate_owner_received` per [builder-final-handoff.md](builder-final-handoff.md).

<!-- REVIEWER-LIFT-SCHEMA:BEGIN generated copy; schema reviewer-lift-schema.md -->
| Field | Value |
|---|---|
| Reviewed SHA | |
| Finding bindings | |
| Review gate | |
| Change tier | `<trivial / moderate / high-risk + one-clause rationale>` |
| Transport | `<mcp / glab-fallback (gap: <named gap>) / n/a>` |
| Gate owner | |
| Gate coverage | |
| Gate coverage rationale | `Policy <ref>; command <cmd>; candidate <sha>; coverage exact-candidate-local; result: <not-run — parent-owned \| PASS — Gate Receipt <locator>>` |
| CI pipeline | |
| Local gate | `<status + exact command; parent-owned: not-run until the Gate Receipt>` |
| RED | `<behavior-touching implementation: failing check; else N/A with rationale; do not fake tests>` |
| GREEN | |
| Changed paths | `git diff --name-only <base>...HEAD` measured output: `<paths>` |
| Touched safety surfaces | |
| Acceptance surfaces | |
| Decoupling proof | |
| Reviewer Focus | `<none / changed docs or tests / 1 area>` |
| Open Questions | `<none / count + OQ IDs>` |
| Approval authority | |
| Approval authority source | |
| Finish authority | |
| Finish authority source | |
| Delta since last ready push | |
<!-- REVIEWER-LIFT-SCHEMA:END -->

## Sections

`Summary`, `Scope`, `Acceptance Criteria Evidence`, `Test Evidence`, and
`Follow-ups` as in the full packet. `Safety Confirmation` replaces the full
packet's three-surface delta: one line confirming that no external-system
mutation path, credential/secret-store handling, domain rule, state schema,
migration, deploy topology, or enforce-mode behavior changed. Any surface that
did change makes the work compact-ineligible.
