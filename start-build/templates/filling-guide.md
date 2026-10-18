# Template Filling Guide — Start Build

This guide holds instructional prose for builder templates. Read once per session; the templates themselves are bare skeletons.

## General rules for all builder templates

- Publish the template through `forge publish`: review-packet at the [packet home](../../forge/SKILL.md#packet-home), satisfying applicable known bounds or the [native-validation recipe](../../forge/reference/common-guard.md#native-validation) established for that publication's undocumented capacity; revision-packet and stuck-packet as provider-native discussion artifacts. Publication verification and evidence reuse follow that contract.
- Keep it in sync with the diff and candidate after every push; refresh the publication through the same contract.
- Before publication or ready transition, use the selected `forge` provider to validate the native work-item relationship/closure preview. Provider-specific syntax belongs only in its provider reference.

## build-plan-packet.md

- Use before first edit, after the Discovery Budget completes.
- Capture only evidence-backed facts: work item, intended behavior, loaded context sources with why-relevant reasons, affected surfaces, test plan, risk, and non-goals.
- **Proof / unknowns** — Fill only when [Proof and unknowns](../reference/context-and-planning.md#proof-and-unknowns) applies; mechanical work without that risk omits it.
- If critical information is missing, route the work item back to triage instead of filling blanks.

## review-packet.md

Use the same template for every work type. Pre-edit discovery (rulebook read, mutation/credential/state/TDD-applicability checks) stays in the distinct `build-plan-packet.md` stage; the Review Packet records its resulting evidence. Omit conditional headings and metadata when their triggers do not apply, rather than leaving blanks. This changes neither source reuse/revision nor Draft publication timing.

### Default sections

- **Metadata** — The default rows apply to every packet. Add `ADR needed?` for a non-trivial design choice or required ADR assessment; add `Blocks` / `Blocked by` for delivery dependencies. Docs-only, tests-only with no runtime safety impact, typo/lint, and dependency-only work with no API/runtime impact need none of these three rows when no such decision/dependency applies.
- **Reviewer Lift** — Copy every row unchanged; fill it per `reviewer-lift-schema.md`, which owns field order, gate, and Approval/Finish authority claim/source semantics. `../../start-review/REVIEW-FLOW.md` owns CI and authority decisions. Parent-owned mode follows `../reference/parent-owned-gate.md`; the child records only the ownership contract and candidate.
- **Finding bindings** — Use `none` until a Review Report finding is in flight. Otherwise copy each originating `(Report locator, Reviewed commit, Finding ID)` exactly from the report and validate before publication or ready transition.
- **Authority sources** — Record where each approval/finish claim came from. Do not write builder-local interpretation as authority; the reviewer/parent verifies provenance through the `forge` common guard.
- **Acceptance Criteria Evidence / Test Evidence** — Bind each claim to sufficient evidence, not just an example. For source-proof or other risk-relevant claims, name the invariant, establishing proof, and missing/ambiguous/stale/incomplete evidence that requires unknown, plus affected consumers/checks. Behavior-touching work retains native RED/GREEN or honest N/A/restriction evidence and regression evidence per [SAFETY.md](../SAFETY.md#behavior-touching-refactors). A not-run check is not a passing slice.
- **Safety Confirmation or Safety / State / External Delta** — Use a one-line **Safety Confirmation** only when evidence establishes no change to any listed mutation/credential/domain/state/migration/deploy/enforce surface. Otherwise retain the three-surface delta: applicable safety invariants and preservation evidence, state/persistence/migration impact (migration numbers and smoke plan), and external-system/credential impact. Mark an uninvestigated or unproven surface `unknown — <missing proof and affected decision>`; omission never establishes `none`. Expand the triggered detail sections below when one line cannot carry the evidence.
- **Reviewer Focus / Open Questions** — Their Lift rows are always required. Add separate sections only for detail that does not fit those rows; simple work does not repeat them.

Early Draft pending values are stage-local and cannot satisfy before-ready proof.
Every packet retains the schema's `Gate owner`, `exact-candidate-local` coverage,
bound rationale, exact command and applicable result. Parent pre-publication uses
the [ownership contract](../reference/parent-owned-gate.md#ownership-contract),
`Local gate: not-run — parent-owned; <cmd>` and rationale
`result: not-run — parent-owned`. After publication, bind `Local gate` to `PASS`,
the command and exactly one labelled `Gate Receipt: <locator>` pointer; the
rationale ends `result: PASS — Gate Receipt: <same locator>`. Builder `PASS`
likewise needs an exact-candidate
[builder receipt](../reference/gate-receipt.md#builder-owned-gate-receipt) and
native binding/readback, not parent-only post-note validation. Receipt-independent
`lift-only` checks presence, not these proofs. Preserve `PASS`, `FAIL`, `N/A` or
`not-run` plus exact command per the schema; gate `N/A` requires no runnable gate,
not merely TDD nonapplicability. Docs/config/mechanical RED/GREEN may be
`N/A with rationale — <why>` without erasing gate or check-restriction evidence.

### Conditional sections

Add the heading only when its trigger applies; the template lists these headings in a comment so blank sections do not appear in every change request.

- **Architecture / Design Decisions** — a non-trivial design choice or required ADR: decision, alternatives, why this shape won, trade-offs, ADR link.
- **Diff Summary** — a large or spread diff: diffstat and per-file map.
- **External-System and Credential Safety** — external integrations where the one-line delta is not enough: adapter use, fake/recorded HTTP tests, redaction, idempotency keys.
- **State, Persistence, and Migration Impact** — migration numbers, smoke-test plan, rollout notes.
- **Manual / Operational Evidence** — a dry-run, runbook check, or read-only operator command worth quoting. Never paste secrets.
- **Reviewer Hints** — files/tests to inspect first. Courtesy, not instruction.
- **Reviewer Focus / Open Questions** — supporting detail beyond the required Lift rows; keep stable OQ-N identities.

## builder-final-handoff.md

- Emit exactly the [two-line contract](builder-final-handoff.md), using `not-created` before a receipt exists for this candidate; no extra note is needed.
- Validate canonical Lift presence with `../scripts/validate-gate-receipt.mjs --mode lift-only` (relative to this file, run per the [helper rule](../../forge/SKILL.md#helpers)); verify native locator/artifact bindings independently.
- Never include secrets, raw private payloads, or unredacted logs. Use synthetic URLs/SHAs in examples.
- Recover absent/malformed handoffs from the bound change request and durable Review Packet; prose is a locator hint, not verified evidence.

## revision-packet.md

- Submit with `forge publish` in response to a Review Report or substantive post-ready push. Push fixes as new commits, then refresh the Review Packet and Reviewer Lift at the packet home.
- **Finding bindings** — Retain every original `(Report locator, Reviewed commit, Finding ID)` tuple across revisions, including unchanged/unresolved findings, and run the pure-local validator (per the [helper rule](../../forge/SKILL.md#helpers)) before publishing.
- **Invariant closure / Accepted capability coverage** — Follow [Class-level revision closure](../reference/implementation-flow.md#class-level-revision-closure) from the first blocker; record same-invariant recurrence controls before another candidate while retaining complete accepted capabilities.
- **Response to Must Fix** — One subsection per MF item. Quote the headline/snippet, then response and commit SHA.
- **What I did not change** — Reviewer comments not acted on, and why.
- **Updated Safety Impact** — New/changed safety evidence since prior packet, or "No change."
- **Updated State / Migration / External-System Evidence** — If applicable. Confirm no live product/runtime/operator external mutation and no credential exposure.

## stuck-packet.md

- Submit through `forge publish` when blocked for more than 2 hours on one work item. Keep the change request Draft and apply a documented unblock label when one exists.
- **What I've tried** — Chronological list with files, tests, errors, logs, or traces. No secrets.
- **Safety status** — Confirm no live product/runtime/operator external mutation, no credential exposure, and whether the branch is safe to park.
- **Artifacts** — Failing tests, branch HEAD, fixture names, logs with secrets redacted.

## adr.md

The ADR template is the shared [`adr.md`](../../templates/adr.md); see its [filling guide](../../templates/filling-guide.md) for ADR template filling instructions.
