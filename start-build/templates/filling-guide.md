# Template Filling Guide — Start Build

This guide holds instructional prose for builder templates. Read once per session; the templates themselves are bare skeletons.

## General rules for all builder templates

- Publish the template through `forge publish` as the change-request description (review-packet, compact) or provider-native discussion artifact (revision-packet, stuck-packet).
- Keep it in sync with the diff and require provider-native publication readback after every push.
- Before publication or ready transition, use the selected `/forge` provider to validate the native work-item relationship/closure preview. Provider-specific syntax belongs only in its provider reference.

## build-plan-packet.md

- Use before first edit, after the Discovery Budget completes.
- Capture only evidence-backed facts: work item, intended behavior, loaded context sources with why-relevant reasons, affected surfaces, test plan, risk, and non-goals.
- If critical information is missing, route the work item back to triage instead of filling blanks.

## review-packet.md

The template ships the default sections only. Pre-edit discovery (rulebook read, mutation/credential/state/TDD-applicability checks) belongs in `build-plan-packet.md`, not a packet checklist; the packet records the resulting evidence. Add a conditional section heading only when its trigger fires — leave it out otherwise instead of pasting a blank heading.

### Default sections

- **Reviewer Lift** — Copy every row unchanged; fill it per `reviewer-lift-schema.md`, which owns field order, gate, and Approval/Finish authority claim/source semantics. `../../start-review/REVIEW-FLOW.md` owns CI and authority decisions. Parent-owned mode follows `../reference/parent-owned-gate.md`; the child records only the ownership contract and candidate.
- **Finding bindings** — Use `none` until a Review Report finding is in flight. Otherwise copy each originating `(Report locator, Reviewed commit, Finding ID)` exactly from the report and validate before publication or ready transition.
- **Review gate** — Records whether the change request went through the mandatory review gate (`mandatory`) or a human explicitly bypassed it.
- **Authority sources** — Record where each approval/finish claim came from. Do not write builder-local interpretation as authority; the reviewer/parent verifies provenance through the `/forge` common guard.
- **Summary** — One paragraph: what changed, why, and the observable effect. End with loaded context sources beyond the work item and rulebook index, or `none beyond work item and rulebook index`.
- **Scope** — `In scope` bullets the intended and actual changes; `Out of scope` names adjacent work not done.
- **Acceptance Criteria Evidence** — Map work-item acceptance criteria to proof. For literal byte-for-byte criteria, include targeted comparison evidence against the current change-request head commit; do not add ceremony for ordinary prose.
- **Safety / State / External Delta** — One line per surface; write `N/A — <reason>` when untouched. **Safety invariants:** every applicable invariant and how it is preserved — approved domain envelope (no new venues, scopes, capabilities, or rules); observe vs enforce / dry-run vs production semantics; protective sequencing (e.g. cancel-before-replace, classify-before-continue); coordination primitives (lease/lock acquired and verified; no force-steal); immutable baselines and monotonic invariants; exact-decimal numeric type for money/quantity/domain math; pure engines remain side-effect free. **State / persistence / migration:** state stores, typed models, DB migrations (with numbers), event/intent stores, CLI stdout contracts, cross-language interop, and smoke-test plan. **External-system / credential:** whether any live product/runtime/operator external mutation was made (default: no), and confirm secret stores were not read/printed/committed. When a surface needs more than one line, promote it to the matching conditional section.
- **Test Evidence** — Expand `RED`/`GREEN` with targeted tests and Check Gate or provider-native CI evidence. For behavior-touching refactors, provide regression evidence.
- **Reviewer Focus** — What could go wrong and where the Reviewer should look hardest. Mirror the headline in Reviewer Lift > Reviewer Focus, or write `none`.
- **Open Questions** — If reviewer/human input can change direction, replace "None." with stable OQ-N IDs so the reviewer can answer/escalate each one in their report.
- **Follow-ups** — Linked issues for deferred items, or "None".

### Conditional sections

Add the heading only when its trigger applies; the template lists triggers in a comment so blank headings do not appear in every change request.

- **Architecture / Design Decisions** — When the change makes a non-trivial design choice or requires an ADR. Decision, alternatives considered, why this shape won, trade-offs to review. Link to the ADR if one is required.
- **Diff Summary** — When the diff is large or spread across many files and a per-file map helps the reviewer. High-level diffstat and map by file.
- **External-System and Credential Safety** — When the change touches external integrations and the one-line delta is not enough. Explain adapter use, fake/recorded HTTP tests, redaction, and idempotency keys.
- **State, Persistence, and Migration Impact** — When migrations or persistence changes need more than the one-line delta: migration numbers, smoke-test plan, and rollout notes.
- **Manual / Operational Evidence** — When you ran a dry-run, runbook check, or read-only operator command worth quoting. Never paste secrets.
- **Reviewer Hints** — Suggested files/tests to inspect first. Courtesy, not instruction.

## builder-final-handoff.md

- Emit exactly the [two-line contract](builder-final-handoff.md), using `not-created` before a receipt exists for this candidate; no extra note is needed.
- Keep Reviewer Lift and `gate_owner_received` in the durable Review Packet. Parents verify native evidence at the [applicable stage](../reference/parent-owned-gate.md#stage-correct-handoff-verification), not a final YAML block.
- Run `bash tests/agent-handoff-templates.sh` after editing.
- Never include secrets, raw private payloads, or unredacted logs. Use synthetic URLs/SHAs in examples.
- Recover absent/malformed handoffs from the bound change request and durable Review Packet; prose is a locator hint, not verified evidence.

## review-packet-compact.md

- Eligible for docs-only, tests-only with no runtime safety impact, typo/lint, or dependency bump with no API/runtime impact.
- Its Reviewer Lift table is an approved generated copy of `reviewer-lift-schema.md`; keep field names/order identical and use explicit `N/A`/`none` values where compact evidence applies, including Gate owner/coverage/rationale.
- **Review gate** — `mandatory` unless a human explicitly bypassed it.
- **Summary** — One paragraph: what changed and why. End with loaded context sources beyond the work item and rulebook index, or `none beyond work item and rulebook index`.
- **Scope** — `In scope` bullets the change; `Out of scope` is usually "no runtime behavior, external paths, state schema, gates, or domain rules changed."
- **Acceptance Criteria Evidence** — Map work-item acceptance criteria to proof. Use exact-string evidence only for literal wording criteria.
- **Safety Confirmation** — One line confirming none of the following changed: product/runtime/operator external-system mutation path; credential / secret-store handling; domain rule or strategy behavior; state schema, migration, deploy topology, or enforce-mode behavior. If any did change, the work is not compact-eligible — use `review-packet.md` instead.
- **Test Evidence** — Commands/results or provider-native CI locator. State `TDD: N/A — <reason>` for non-behavior changes.
- **Follow-ups** — "None" or linked follow-up work items.

## revision-packet.md

- Submit with `forge publish` in response to a Review Report or substantive post-ready push. Push fixes as new commits, then refresh the change-request description and Reviewer Lift.
- **Finding bindings** — Repeat every marked `(Report locator, Reviewed commit, Finding ID)` tuple addressed and run the pure-local validator before publishing.
- **Summary** — One paragraph: what changed in response to review/post-ready delta and what stayed the same.
- **Response to Must Fix** — One subsection per MF item. Quote the headline/snippet, then response and commit SHA.
- **Response to Should Fix** — Same shape; use SF IDs.
- **Response to Consider** — Same shape; valid to decline with reasoning.
- **What I did not change** — Reviewer comments not acted on, and why.
- **Updated Safety Impact** — New/changed safety evidence since prior packet, or "No change."
- **Updated State / Migration / External-System Evidence** — If applicable. Confirm no live product/runtime/operator external mutation and no credential exposure.
- **Updated Test Evidence** — Re-run gates and targeted tests; CI link or concise output.
- **Diff Since Previous Review** — High-level diffstat for revision-only changes.
- **Open Questions (Unresolved)** — Anything still needing reviewer/human decision.
- **Reviewer Hints for This Round** — Where to inspect first.

## stuck-packet.md

- Submit through `forge publish` when blocked for more than 2 hours on one work item. Keep the change request Draft and apply a documented unblock label when one exists.
- **What I'm trying to do** — One paragraph.
- **What I've tried** — Chronological list with files, tests, errors, logs, or traces. No secrets.
- **What's in front of me** — Hypotheses, most likely first.
- **What would unblock me** — Hint, design decision, pair session, source pointer, or escalation.
- **Safety status** — Confirm no live product/runtime/operator external mutation, no credential exposure, and whether the branch is safe to park.
- **Artifacts** — Failing tests, branch HEAD, fixture names, logs with secrets redacted.
- **What I'm doing while stuck** — Park / switch plan.
- **Escalation** — Who/what asked and when.

## adr.md

See the [shared ADR filling guide](../shared-templates/filling-guide.md) for ADR template filling instructions.
