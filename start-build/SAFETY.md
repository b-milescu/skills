# Start Build Safety Rules

These rules protect safety boundaries while implementing work items in the invoked target's confirmed integration. Stricter project rulebooks override generic policy. Map domain examples to the target's real safety surfaces. Authorized tracker/change-request publication prescribed by the workflow is distinct from unauthorized product/runtime/operator mutation.

## Safety floors

This is the canonical safety-floor enumeration. Consuming docs reference this
set rather than redefining it; project hooks and ceremony choices preserve every
floor. The detailed non-negotiables below remain applicable.

- **Mandatory independent review** applies to every behavior-touching change.
  Discovery, packet detail, design exploration and verification depth may vary;
  the review gate does not.
- **Applicable TDD, safety non-negotiables, exact-candidate local Check Gate and
  Gate Receipt, reviewed-commit binding and authority guards** remain mandatory.
  Provider CI is advisory evidence, never a quality or finish gate.
- **Role and Context Firewall boundaries** remain intact: builders do not
  self-approve or self-finish; child builders respect parent-owned gate/finish
  boundaries; reviewers derive independent evidence; verifiers remain read-only.
- **Native/MCP-first transport correctness, complete reviewed-diff coverage,
  provider-native mutation readback and help-first documented fallback
  correctness** remain required. Publication includes safe-body validation and
  authored-source equality; extraction or a digest alone is not that proof.

## Non-negotiables

Violations must be fixed or explicitly accepted/waived in the MR before approval. [SKILL.md §Safety floors](SKILL.md#safety-floors) routes here; this file owns the detail behind every floor.

- **Credential operational detail.** Beyond "never touch credentials": don't read, print, edit, commit, or summarize secret stores; don't log API keys, auth headers, or sensitive payloads; never paste secrets into MR descriptions, comments, CI logs, or screenshots. Never `cat`, `echo`, or otherwise print token-bearing config such as `.env`, provider CLI config files, PAT stores, token env vars, or any value that may contain a secret. When an explicitly approved command must consume a credential, read it into a shell variable inside the command that consumes it without printing it, pass it directly to the consuming tool, and redact diagnostics as `[REDACTED]`.
- **Stay inside the approved domain envelope.** No new venues, scopes, capabilities, or rule changes unless a human approved it and the rulebook/docs changed.
- **Don't relax safety gates casually.** Removing guard errors, weakening dry-run/observe semantics, or enabling enforce/production paths must be explicit in the issue/MR with tests and reviewer-accepted rationale.
- **Preserve protective sequencing.** Multi-step flows that protect invariants keep their full sequence and never leave the system unprotected without escalation.
- **Mutations require the project's coordination primitive.** Any path that mutates shared/external state must acquire and verify the lease/lock; never force-steal an active one.
- **Immutable baselines stay immutable.** Fields set at entry that downstream math depends on are never overwritten; monotonic invariants only move in the safe direction.
- **Use the right numeric type for the domain.** Money/quantity/domain math uses exact decimal types; floats only at I/O boundaries before conversion.
- **Pure engines stay pure.** Deterministic rule modules don't read files, call APIs/DB, or use wall-clock time internally.
- **State changes go through typed/atomic paths.** Use the project's repository/transaction abstractions, not ad-hoc writes. Required state fields fail loud; never coerce missing critical values to defaults.
- **Migrations are append-only.** Never edit a migration that may have run outside a throwaway DB. Add a new numbered migration and test it.
- **Behavior-touching refactors require regression evidence.** See below.
- **The exact-candidate local Check Gate is the quality gate before ready/review.** Safe early Draft branch/MR pushes and pre-ready implementation pushes are allowed. Before marking ready or requesting review, the full local gate must be `PASS` on the candidate SHA, or explicitly `N/A` with rationale when the project has no runnable local gate. In parent-owned mode, the child records the ownership contract from [reference/parent-owned-gate.md](reference/parent-owned-gate.md#ownership-contract), leaves the MR Draft, and the parent publishes the exact-candidate Gate Receipt and owns the ready transition.

  Provider CI is bounded advisory evidence only. Record its locator, status, and commit when available, and attribute a status only when it binds the candidate or provider-proven integration commit. Pending, failed, canceled, skipped, missing, stale, wrong-commit, or unavailable CI never changes ready, review, approval, or finish eligibility. Native provider protection may still refuse a mutation; report that refusal without bypassing it.

  See [reference/implementation-flow.md §Procedure](reference/implementation-flow.md#procedure) step 9 for the ready policy.
- **No builder self-approval or self-merge.** Apply each clause discretely:
  - The builder must not approve, merge, queue auto-merge, or take fallback finish actions for its own MRs.
  - All MRs must pass through the [Mandatory review gate](reference/standalone-gate.md#mandatory-review-gate) before merge unless a human bypasses the gate under the strict, non-inferable [Human bypass protocol](reference/standalone-gate.md#human-bypass-protocol); a bypass still does not grant the builder approval or merge authority.
  - In standalone `/start-build` mode, the builder spawns the fresh reviewer session and reports any finish blocker; in child `mr-builder` mode, the parent orchestrator owns the gate after the child returns its final handoff.
  - After independent approval, finish actions belong only to the reviewer, an authorized parent, or a human with explicit authority.

## Behavior-touching refactors

A refactor is **behavior-touching** if it modifies external mutation paths, protective sequencing, lock TTL/ownership, gates/breakers, immutable baselines, schemas/migrations/persistence, daemon poll/health/heartbeat, slow-path scripts that produce mutations or intents, CLI stdout consumed by other code, or deploy/credential topology.

Ambiguous = behavior-touching. Behavior-touching refactors need regression evidence and reviewer attention.

For behavior-touching work, each headline claim in the MR body must name the mutation that kills its defending assertion. This is scoped to headline claims, not every assertion; do not run a full mutation battery per MR. An assertion whose subject cannot be changed by any mutation of the code under test—for example, when no mock can move the observed state—is structurally incapable of failing and is not regression evidence.

A named killing mutation counts as evidence only when the harness proves the substitution applied by asserting its anchor matched exactly once before checking the result. The observed failure message must match the guard under test; a non-zero exit alone cannot distinguish a fired guard from a parse or setup error.

Valid regression evidence includes:

- targeted automated tests;
- explanation of existing coverage naming tests and what surface they cover;
- manual dry-run only when automation is infeasible, with exact commands and no secrets.

## Quality rules

- No broad catch-alls without a recovery comment and an observable signal (metric, alert, return value, finding).
- Keep local-only advisory output and run artifacts out of the commit; they stay untracked.
- Prefer typed/domain-specific errors at library boundaries; CLIs translate to exit codes/messages.
- Keep stdout contracts stable when other code parses CLI output.
- Public modules/classes/functions get docstrings; safety invariants get why-comments at the seam.
- **Simplest version of your own change.** Write the most direct form of the code this issue adds or changes — not merely one that passes. During the green-refactor step, collapse needless branches, pass-through wrappers, speculative abstraction, or `any`/cast-heavy boundaries **within the lines your diff introduces or touches**, before marking ready. This is a within-diff bar, never a license to straighten adjacent code or push an untouched file past its current size; when in doubt whether a cleanup is your diff or the surrounding code, treat it as surrounding code and open a follow-up (see SKILL.md "Keep scope tight and prefer the smallest direct change").

## Anti-patterns

- "I'll broaden scope while here." Open a separate issue.

## Escalation

Stop and escalate by assigning/commenting/applying the project's human-decision label when one exists; otherwise comment clearly. Escalate on external-system safety uncertainty, rule ambiguity, credential exposure, review disagreement after two rounds, or legal/ethical concern.

## Done criteria

"Done" is mode-tiered, not single-mode: the role that owns the current step decides which tier applies. A child `mr-builder` is done at **builder-ready** and must not wait on, claim, or perform the later tiers. The later tiers belong to the review gate, the authorized finisher, and the verifier respectively, and each tier points to the reference flow that owns its detail instead of restating it. Across every tier: no secrets are exposed, no live unintended product/runtime/operator side effects occur, and docs/runbooks affected by the change are updated.

- **builder-ready** — the implementation is complete and the Draft MR / Reviewer Lift are current. When the builder owns ready-marking, the local check gate is `PASS` (or `N/A` with a recorded reason), the Draft MR is marked ready, the Reviewer Lift `Reviewed SHA` equals the MR head, and the builder returned its final handoff. In parent-owned gate mode, the candidate head is pushed, the MR stays Draft, and the child records the ownership contract from [reference/parent-owned-gate.md](reference/parent-owned-gate.md#ownership-contract) while the parent keeps the Gate Receipt and ready transition. The builder stops here; this tier never includes builder self-approval or self-merge. See [reference/child-builder.md](reference/child-builder.md) §Authority boundary and child-checklist step 11.
- **review-gate-complete** — an independent reviewer has read the reviewed SHA, posted the Review Report, and the Review Gate Summary records the verdict. Standalone `/start-build` owns this gate directly; child mode hands it to the parent orchestrator. See [reference/standalone-gate.md](reference/standalone-gate.md) §Review Gate Summary. The **default deliverable is an MR**; an analysis-only `kind:meta` issue whose deliverable is a tracker note instead uses the [note-deliverable review path](reference/standalone-gate.md#note-deliverable-review-path), which relaxes no floor — mandatory independent review, no builder self-approval, and the Context Firewall hold exactly as on the MR path.
- **finish-merge** — after approval, an authorized reviewer/parent/human takes the one authority-scoped finish action (`approval-only` stop, merge, or queued auto-merge) against the reviewed SHA, under the mandatory exact-candidate Gate Receipt, independent review, authority/caller, and provider-native mutation/readback guards. Provider CI is advisory, and a native provider protection refusal is reported, never bypassed. The MR is merged only when merge authority and provider policy allow, and the linked issue is closed by `Closes #<id>` or project workflow. See [reference/parent-orchestrator.md](reference/parent-orchestrator.md) finish-by-authority step.
- **post-merge-verified** — read-only confirmation that the default branch contains the merged change, the linked issue is closed or reported `issue_closure_pending`, source-branch cleanup is as expected, and any required durable summary is recorded. This is a verifier role, not another reviewer or finisher. See [reference/post-merge-verifier.md](reference/post-merge-verifier.md).
