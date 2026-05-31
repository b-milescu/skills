# Template Filling Guide — Start Build

This guide holds instructional prose for builder templates. Read once per session; the templates themselves are bare skeletons.

## General rules for all builder templates

- Paste the template as the MR description (review-packet, compact) or as an MR comment (revision-packet, stuck-packet).
- Keep it in sync with the diff as you push. Keep section headers stable so the Reviewer can scan quickly.

## build-plan-packet.md

- Use before first edit, after the Discovery Budget completes.
- Capture only evidence-backed facts: issue, intended behavior, loaded context sources with why-relevant reasons, affected surfaces, test plan, risk, and non-goals.
- If critical info is still missing, stop and route the issue back to triage instead of filling blanks.

## review-packet.md

The template ships the default sections only. Pre-edit discovery (rulebook read, mutation/credential/state/TDD-applicability checks) belongs in `build-plan-packet.md`, not a packet checklist; the packet records the resulting evidence. Add a conditional section heading only when its trigger fires — leave it out otherwise instead of pasting a blank heading.

### Default sections

- **Reviewer Lift** — Structured handoff so the Reviewer can copy values directly into the Review Report. `reviewer-lift-schema.md` owns field names, order, and required semantics; the table in this template is an approved generated copy. Keep every field current with each push. Fill `Merge authority` as a quoted claim only and fill `Merge authority source` with verifiable provenance; a builder cannot grant approval, merge, or auto-merge authority. If you push commits AFTER marking ready, post a delta comment (old SHA → new SHA, reason, changed files, gate rerun, substantive? yes/no) and update this block.
- **Review gate** — Records whether the MR went through the [Mandatory review gate](../BUILD-FLOW.md#mandatory-review-gate) (`mandatory`) or the human explicitly bypassed it (`bypassed (human override)`). Default: `mandatory`.
- **Merge authority source** — Record where the authority claim came from, such as a parent task prompt, human MR comment URL, rulebook path+section, or project default source. Do not write builder-local interpretation as authority; quote the source and let the reviewer/parent verify it.
- **Summary** — One paragraph: what changed, why, and the observable effect on users/operators. End with the loaded context sources beyond the issue and rulebook index (each with why relevant), or `none beyond issue and rulebook index` instead of listing broad docs that were not loaded.
- **Scope** — `In scope` bullets the intended and actual changes; `Out of scope` names adjacent work not done (open separate issues for follow-ups).
- **Acceptance Criteria Evidence** — Map issue acceptance criteria to proof so the reviewer can validate scope quickly.
- **Safety / State / External Delta** — One line per surface; write `N/A — <reason>` when untouched. **Safety invariants:** every applicable invariant and how it is preserved — approved domain envelope (no new venues, scopes, capabilities, or rules); observe vs enforce / dry-run vs production semantics; protective sequencing (e.g. cancel-before-replace, classify-before-continue); coordination primitives (lease/lock acquired and verified; no force-steal); immutable baselines and monotonic invariants; exact-decimal numeric type for money/quantity/domain math; pure engines remain side-effect free. **State / persistence / migration:** state stores, typed models, DB migrations (with numbers), event/intent stores, CLI stdout contracts, cross-language interop, and smoke-test plan. **External-system / credential:** whether any live product/runtime/operator external mutation was made (default: no), and confirm secret stores were not read/printed/committed. When a surface needs more than one line, promote it to the matching conditional section.
- **Test Evidence** — Expand on the `RED`/`GREEN` fields from the Reviewer Lift schema. Include targeted tests, full check gate output (or CI link), coverage where the project requires it. For behavior-touching refactors, provide regression evidence. If red-first evidence is unavailable, explain why and provide equivalent behavior evidence.
- **Reviewer Focus** — What could go wrong and where the Reviewer should look hardest. Mirror the headline in Reviewer Lift > Reviewer Focus, or write `none`.
- **Open Questions** — If reviewer/human input can change direction, replace "None." with stable OQ-N IDs so the reviewer can answer/escalate each one in their report.
- **Follow-ups** — Linked issues for deferred items, or "None".

### Conditional sections

Add the heading only when its trigger applies; the template lists these in a comment so they do not appear as blank headings in every MR.

- **Architecture / Design Decisions** — When the change makes a non-trivial design choice or requires an ADR. Decision, alternatives considered, why this shape won, trade-offs to review. Link to the ADR if one is required.
- **Diff Summary** — When the diff is large or spread across many files and a per-file map helps the reviewer. High-level diffstat and map by file.
- **External-System and Credential Safety** — When the change touches external integrations and the one-line delta is not enough. Explain adapter use, fake/recorded HTTP tests, redaction, and idempotency keys.
- **State, Persistence, and Migration Impact** — When migrations or persistence changes need more than the one-line delta: migration numbers, smoke-test plan, and rollout notes.
- **Manual / Operational Evidence** — When you ran a dry-run, runbook check, or read-only operator command worth quoting. Never paste secrets.
- **Reviewer Hints** — Suggested files/tests to inspect first. Courtesy, not instruction.

## builder-final-handoff.md

- Emit this machine-readable block in child `mr-builder` final responses when a parent orchestrator owns the review gate.
- Keep Reviewer Lift as the durable MR-description handoff; this block complements it for parent parsing.
- Preserve field names and top-level order. Run `bash tests/agent-handoff-templates.sh` after editing.
- For ready handoffs, set both `head_sha` and `reviewed_sha` to the same MR head commit; `reviewed_sha` is the exact SHA the parent passes to the reviewer.
- Use `status: "ready-for-review"`, `"blocked"`, or `"failed"`. If usage limits or tooling failures stop completion, report `status: "failed"` plus `blockers`; the parent owns retries.
- Preserve both `merge_authority` and `merge_authority_source` from the MR Reviewer Lift. The source is provenance for verification, not a grant minted by the builder.
- Never include secrets, raw private payloads, or unredacted logs. Use synthetic URLs/SHAs in examples.
- Consumers must tolerate absent blocks and fall back to human prose / Reviewer Lift.

## review-packet-compact.md

- Eligible for docs-only, tests-only with no runtime safety impact, typo/lint, or dependency bump with no API/runtime impact.
- Its Reviewer Lift table is an approved generated copy of `reviewer-lift-schema.md`; keep field names/order identical and use explicit `N/A`/`none` values where compact evidence applies.
- **Review gate** — Records whether the MR went through the [Mandatory review gate](../BUILD-FLOW.md#mandatory-review-gate) (`mandatory`) or the human explicitly bypassed it (`bypassed (human override)`). Default: `mandatory`.
- **Summary** — One paragraph: what changed and why. End with loaded context sources beyond the issue and rulebook index (each with why relevant), or `none beyond issue and rulebook index`.
- **Scope** — `In scope` bullets the change; `Out of scope` is usually "no runtime behavior, external paths, state schema, gates, or domain rules changed."
- **Acceptance Criteria Evidence** — Map issue acceptance criteria to proof.
- **Safety Confirmation** — One line confirming none of the following changed: product/runtime/operator external-system mutation path; credential / secret-store handling; domain rule or strategy behavior; state schema, migration, deploy topology, or enforce-mode behavior. If any did change, the work is not compact-eligible — use `review-packet.md` instead.
- **Test Evidence** — Commands run and result, or CI link. State `TDD: N/A — <reason>` for compact-eligible non-behavior changes. For docs-only, a targeted markdown/read check may be enough.
- **Follow-ups** — "None" or linked follow-up issues.

## revision-packet.md

- Submit in response to a Review Report requesting changes, or for any substantive post-ready push after review has started. Post as a single MR comment summarising the response/delta, with the actual fixes pushed as new commits on the MR branch (each commit subject naming the item ID when applicable, e.g. "MF-1: ..."). Update the MR description and Reviewer Lift with the revision summary so reviewers see it first.
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

- Submit when blocked for >2 hours on one issue. Post as an MR comment with `gitlab-local` **Snippet: mr-note-create**, keep the MR in Draft, and apply the project's unblock label when one exists.
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
