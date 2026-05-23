# Template Filling Guide — Start Build

This guide holds instructional prose for builder templates. Read once per session; the templates themselves are bare skeletons.

## General rules for all builder templates

- Paste the template as the MR description (review-packet, compact) or as an MR comment (revision-packet, stuck-packet).
- Keep it in sync with the diff as you push. Keep section headers stable so the Reviewer can scan quickly.

## review-packet.md

- **Reviewer Lift** — Structured handoff so the Reviewer can copy values directly into the Review Report. `reviewer-lift-schema.md` owns field names, order, and required semantics; the table in this template is an approved generated copy. Keep every field current with each push. If you push commits AFTER marking ready, post a delta comment (old SHA → new SHA, reason, changed files, gate rerun, substantive? yes/no) and update this block.
- **Review gate** — Records whether the MR went through the [Mandatory review gate](../BUILD-FLOW.md#mandatory-review-gate) (`mandatory`) or the human explicitly bypassed it (`bypassed (human override)`). Default: `mandatory`.
- **Summary** — One paragraph: what changed, why, and the observable effect on users/operators.
- **In scope** — Bullet list of intended and actual changes.
- **Out of scope** — Explicitly name adjacent work not done. Open separate issues for follow-ups.
- **Acceptance Criteria Evidence** — Map issue acceptance criteria to proof so the reviewer can validate scope quickly.
- **Safety Impact** — Address every applicable invariant; write N/A with reason for non-applicable items: approved domain envelope (no new venues, scopes, capabilities, or rules); observe vs enforce / dry-run vs production semantics; protective sequencing (e.g. cancel-before-replace, classify-before-continue); coordination primitives (lease/lock acquired and verified; no force-steal); immutable baselines and monotonic invariants; exact-decimal numeric type for money/quantity/domain math; pure engines remain side-effect free.
- **Architecture / Design Decisions** — Decision, alternatives considered, why this shape won, trade-offs to review. Link to ADR if one is required.
- **State, Persistence, and Migration Impact** — State stores, typed models, DB migrations, event/intent stores, CLI stdout contracts, cross-language interop. Include migration numbers and smoke-test plan. Write N/A if none.
- **External-System and Credential Safety** — State whether any live PRO external mutations were made (default: no). For changes touching external integrations, explain adapter use, fake/recorded HTTP tests, redaction, and idempotency keys. Confirm secret stores were not read/printed/committed.
- **Diff Summary** — High-level diffstat and map by file.
- **Test Evidence** — Expand on the `RED`/`GREEN` fields from the Reviewer Lift schema. Include targeted tests, full check gate output (or CI link), coverage where the project requires it. For behavior-touching refactors, provide regression evidence. If red-first evidence is unavailable, explain why and provide equivalent behavior evidence.
- **Manual / Operational Evidence** — Optional. Dry-run output, runbook check, read-only operator command. Never paste secrets.
- **Concerns / Reviewer Focus** — What could go wrong and where the Reviewer should look hardest. Mirror the headline in Reviewer Lift > Reviewer Focus.
- **Open Questions** — If reviewer/human input can change direction, replace "None." with stable OQ-N IDs so the reviewer can answer/escalate each one in their report.
- **Follow-ups** — Linked issues for deferred items, or "None".
- **Reviewer Hints** — Suggested files/tests to inspect first. Courtesy, not instruction.

## review-packet-compact.md

- Eligible for docs-only, tests-only with no runtime safety impact, typo/lint, or dependency bump with no API/runtime impact.
- Its Reviewer Lift table is an approved generated copy of `reviewer-lift-schema.md`; keep field names/order identical and use explicit `N/A`/`none` values where compact evidence applies.
- **Review gate** — Records whether the MR went through the [Mandatory review gate](../BUILD-FLOW.md#mandatory-review-gate) (`mandatory`) or the human explicitly bypassed it (`bypassed (human override)`). Default: `mandatory`.
- **Summary** — One paragraph: what changed and why.
- **In scope** — Bullet list.
- **Out of scope** — Usually: "No runtime behavior, external paths, state schema, gates, or domain rules changed."
- **Test Evidence** — Commands run and result, or CI link. State TDD: N/A for compact-eligible non-behavior changes. For docs-only, a targeted markdown/read check may be enough.
- **Follow-ups** — "None" or linked follow-up issues.

## revision-packet.md

- Submit in response to a Review Report requesting changes, or for any substantive post-ready push after review has started. Post as a single MR comment summarising the response/delta, with the actual fixes pushed as new commits on the MR branch (each commit subject naming the item ID when applicable, e.g. "MF-1: ..."). Update the MR description and Reviewer Lift with the revision summary so reviewers see it first.
- **Summary** — One paragraph: what changed in response to review/post-ready delta and what stayed the same.
- **Response to Must Fix** — One subsection per MF item. Quote the headline/snippet, then response and commit SHA.
- **Response to Should Fix** — Same shape; use SF IDs.
- **Response to Consider** — Same shape; valid to decline with reasoning.
- **What I did not change** — Reviewer comments not acted on, and why.
- **Updated Safety Impact** — New/changed safety evidence since prior packet, or "No change."
- **Updated State / Migration / External-System Evidence** — If applicable. Confirm no live PRO external mutation and no credential exposure.
- **Updated Test Evidence** — Re-run gates and targeted tests; CI link or concise output.
- **Diff Since Previous Review** — High-level diffstat for revision-only changes.
- **Open Questions (Unresolved)** — Anything still needing reviewer/human decision.
- **Reviewer Hints for This Round** — Where to inspect first.

## stuck-packet.md

- Submit when blocked for >2 hours on one issue. Post as an MR comment, keep the MR in Draft, and apply the project's unblock label when one exists.
- **What I'm trying to do** — One paragraph.
- **What I've tried** — Chronological list with files, tests, errors, logs, or traces. No secrets.
- **What's in front of me** — Hypotheses, most likely first.
- **What would unblock me** — Hint, design decision, pair session, source pointer, or escalation.
- **Safety status** — Confirm no live PRO external mutation, no credential exposure, and whether the branch is safe to park.
- **Artifacts** — Failing tests, branch HEAD, fixture names, logs with secrets redacted.
- **What I'm doing while stuck** — Park / switch plan.
- **Escalation** — Who/what asked and when.

## adr.md

See the [shared ADR filling guide](../../templates/filling-guide.md) for ADR template filling instructions.
