# Template Filling Guide — Start Build

This guide holds instructional prose for builder templates. Read once per session; the templates themselves are bare skeletons.

## General rules for all builder templates

- Publish the template through `forge publish` as the change-request description (review-packet, compact) or provider-native discussion artifact (revision-packet, stuck-packet).
- Keep it in sync with the diff and require provider-native publication readback after every push.
- Before publication or ready transition, use the selected `forge` provider to validate the native work-item relationship/closure preview. Provider-specific syntax belongs only in its provider reference.

## build-plan-packet.md

- Use before first edit, after the Discovery Budget completes.
- Capture only evidence-backed facts: work item, intended behavior, loaded context sources with why-relevant reasons, affected surfaces, test plan, risk, and non-goals.
- If critical information is missing, route the work item back to triage instead of filling blanks.

## review-packet.md

The template ships the default sections only. Pre-edit discovery (rulebook read, mutation/credential/state/TDD-applicability checks) belongs in `build-plan-packet.md`, not a packet checklist; the packet records the resulting evidence. Add a conditional section heading only when its trigger fires — leave it out otherwise instead of pasting a blank heading.

### Default sections

- **Reviewer Lift** — Copy every row unchanged; fill it per `reviewer-lift-schema.md`, which owns field order, gate, and Approval/Finish authority claim/source semantics. `../../start-review/REVIEW-FLOW.md` owns CI and authority decisions. Parent-owned mode follows `../reference/parent-owned-gate.md`; the child records only the ownership contract and candidate.
- **Finding bindings** — Use `none` until a Review Report finding is in flight. Otherwise copy each originating `(Report locator, Reviewed commit, Finding ID)` exactly from the report and validate before publication or ready transition.
- **Authority sources** — Record where each approval/finish claim came from. Do not write builder-local interpretation as authority; the reviewer/parent verifies provenance through the `forge` common guard.
- **Safety / State / External Delta** — One line per surface; write `N/A — <reason>` when untouched. Name each applicable invariant from [SAFETY.md §Non-negotiables](../SAFETY.md#non-negotiables) and how the change preserves it, the state/persistence/migration surfaces touched (with migration numbers and smoke plan), and the external-system/credential delta.

### Conditional sections

Add the heading only when its trigger applies; the template lists the four most common triggers in a comment so blank headings do not appear in every change request.

- **Architecture / Design Decisions** — a non-trivial design choice or required ADR: decision, alternatives, why this shape won, trade-offs, ADR link.
- **Diff Summary** — a large or spread diff: diffstat and per-file map.
- **External-System and Credential Safety** — external integrations where the one-line delta is not enough: adapter use, fake/recorded HTTP tests, redaction, idempotency keys.
- **State, Persistence, and Migration Impact** — migration numbers, smoke-test plan, rollout notes.
- **Manual / Operational Evidence** — a dry-run, runbook check, or read-only operator command worth quoting. Never paste secrets.
- **Reviewer Hints** — files/tests to inspect first. Courtesy, not instruction.

## builder-final-handoff.md

- Emit exactly the [two-line contract](builder-final-handoff.md), using `not-created` before a receipt exists for this candidate; no extra note is needed.
- Validate canonical Lift presence with `../scripts/validate-gate-receipt.mjs --mode lift-only` (relative to this file, run per the [helper rule](../../forge/SKILL.md#helpers)); verify native locator/artifact bindings independently.
- Never include secrets, raw private payloads, or unredacted logs. Use synthetic URLs/SHAs in examples.
- Recover absent/malformed handoffs from the bound change request and durable Review Packet; prose is a locator hint, not verified evidence.

## review-packet-compact.md

- Eligible for docs-only, tests-only with no runtime safety impact, typo/lint, or dependency bump with no API/runtime impact; anything else uses `review-packet.md`.
- The compact template is a delta: it carries the full Reviewer Lift generated copy plus the sections that differ, and `review-packet.md` owns the rest.
- Its Reviewer Lift table is an approved generated copy of `reviewer-lift-schema.md`; keep every field name/order. Use `N/A`/`none` only where that schema permits them. Docs/config/mechanical work may use RED/GREEN `N/A with rationale — <why>` without erasing real gate evidence.
- Both compact and full packets record `Gate owner: builder` or `parent`, `Gate coverage: exact-candidate-local`, and `Gate coverage rationale` as `Policy <ref>; command <cmd>; candidate <sha>; coverage exact-candidate-local; result: <bound result>` per the [canonical schema](reviewer-lift-schema.md#required-fields).
- Parent pre-publication uses the [ownership contract](../reference/parent-owned-gate.md#ownership-contract), `Local gate: not-run — parent-owned; <cmd>` and rationale `result: not-run — parent-owned`. After publication, rebind `Local gate` to `PASS` plus the exact command and exactly one labelled opaque `Gate Receipt: <locator>` pointer; the rationale ends with `result: PASS — Gate Receipt: <same locator>`.
- Builder `PASS` likewise requires an exact-candidate [builder receipt](../reference/parent-owned-gate.md#builder-owned-gate-receipt), the bound rationale and native artifact/readback verification, not parent-only post-note validation. Receipt-independent `lift-only` checks presence, not those proofs.
- Preserve the schema's `Local gate` forms (`PASS`, `FAIL`, `N/A`, `not-run` plus exact command) and their rationale requirements; `N/A` requires no runnable local gate, not merely TDD nonapplicability. An all-N/A compact gate block is not valid.
- **Safety Confirmation** — replaces the full packet's three-surface delta. Any surface that did change makes the work compact-ineligible.

## revision-packet.md

- Submit with `forge publish` in response to a Review Report or substantive post-ready push. Push fixes as new commits, then refresh the change-request description and Reviewer Lift.
- **Finding bindings** — Repeat every marked `(Report locator, Reviewed commit, Finding ID)` tuple addressed and run the pure-local validator (per the [helper rule](../../forge/SKILL.md#helpers)) before publishing.
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
