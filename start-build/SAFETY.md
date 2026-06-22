# Start Build Safety Rules

These rules protect safety boundaries while implementing GitLab issues. Project-specific rulebooks override this file when stricter. Domain-specific terms here (venues, sizing, breakers, post-fill, etc.) are examples; map them to the host project's equivalent safety surfaces. Product/runtime/operator systems exclude the GitLab issue/MR actions explicitly prescribed by the build/review workflow.

## Non-negotiables

Violations must be fixed or explicitly accepted/waived in the MR before approval. SKILL.md's Essential safety summary owns the entry-level rules (external mutations, credentials, adapters, scope, behavior-change tests, TDD); the bullets below add detail not in SKILL.md.

- **Credential operational detail.** Beyond "never touch credentials": don't read, print, edit, commit, or summarize secret stores; don't log API keys, auth headers, or sensitive payloads; never paste secrets into MR descriptions, comments, CI logs, or screenshots. Never `cat`, `echo`, or otherwise print token-bearing config such as `.env`, `glab` config files, PAT stores, token env vars, or any value that may contain a secret. When an explicitly approved command must consume a credential, read it into a shell variable inside the command that consumes it without printing it, pass it directly to the consuming tool, and redact diagnostics as `[REDACTED]`.
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
- **Project's full check gate green before marking ready/requesting review, with exact-SHA Gate coverage classified.** Safe early Draft branch/MR pushes and pre-ready implementation pushes are allowed so the MR handoff can exist. Do not mark ready or request review until **one** of the following is true:
  1. **Full-local.** The full local gate is `PASS` on the candidate SHA and Gate coverage is `full-local`.
  2. **Hybrid / CI-only.** All uncovered required CI jobs have exact-SHA success / an authorized CI waiver for `hybrid` or `ci-only` coverage.
  3. **N/A.** The gate is explicitly `N/A` with the reason recorded in Reviewer Lift.
  4. **Parent-owned.** In parent-owned gate mode, the child records the ownership contract from [reference/parent-owned-gate.md](reference/parent-owned-gate.md#ownership-contract), leaves the MR Draft, and the parent posts the Gate Receipt / owns the ready transition.

  See [reference/implementation-flow.md §Procedure](reference/implementation-flow.md#procedure) step 9 for the full CI-ready policy.
- **No builder self-approval or self-merge.** Apply each clause discretely:
  - The builder must not approve, merge, queue auto-merge, or take fallback finish actions for its own MRs.
  - All MRs must pass through the [Mandatory review gate](reference/standalone-gate.md#mandatory-review-gate) before merge unless a human bypasses the gate under the strict, non-inferable [Human bypass protocol](reference/standalone-gate.md#human-bypass-protocol); a bypass still does not grant the builder approval or merge authority.
  - In standalone `/start-build` mode, the builder spawns the fresh reviewer session and reports any finish blocker; in child `mr-builder` mode, the parent orchestrator owns the gate after the child returns its final handoff.
  - After independent approval, finish actions belong only to the reviewer, an authorized parent, or a human with explicit authority.

## Behavior-touching refactors

A refactor is **behavior-touching** if it modifies external mutation paths, protective sequencing, lock TTL/ownership, gates/breakers, immutable baselines, schemas/migrations/persistence, daemon poll/health/heartbeat, slow-path scripts that produce mutations or intents, CLI stdout consumed by other code, or deploy/credential topology.

Ambiguous = behavior-touching. Behavior-touching refactors need regression evidence and reviewer attention.

Valid regression evidence includes:

- targeted automated tests;
- explanation of existing coverage naming tests and what surface they cover;
- manual dry-run only when automation is infeasible, with exact commands and no secrets.

## Quality rules

- No broad catch-alls without a recovery comment and an observable signal (metric, alert, return value, finding).
- No assertions for runtime validation outside tests; use explicit errors or schema validation.
- Prefer typed/domain-specific errors at library boundaries; CLIs translate to exit codes/messages.
- Keep stdout contracts stable when other code parses CLI output.
- Public modules/classes/functions get docstrings; safety invariants get why-comments at the seam.
- Avoid mutable globals for runtime state; inject dependencies (clocks, sleeps, clients) explicitly.
- Use UTC-aware timestamps; don't bypass timezone lints without a documented invariant.
- Logs help operators without exposing secrets.
- Health/heartbeat changes need fake-clock stale-state tests.
- **Simplest version of your own change.** Write the most direct form of the code this issue adds or changes — not merely one that passes. During the green-refactor step, collapse needless branches, pass-through wrappers, speculative abstraction, or `any`/cast-heavy boundaries **within the lines your diff introduces or touches**, before marking ready. This is a within-diff bar, never a license to straighten adjacent code or push an untouched file past its current size; when in doubt whether a cleanup is your diff or the surrounding code, treat it as surrounding code and open a follow-up (see SKILL.md "Keep scope tight; file follow-up GitLab issues instead of drive-by refactors").

## Anti-patterns

- "Just one raw external call." Use adapters.
- "Observe-only initializes the executor, so it's fine." Verify no mutating methods are called.
- "This is only a refactor." Safety surfaces still need regression evidence.
- "Float is simpler." Not for money/domain math.
- "I'll broaden scope while here." Open a separate issue.
- "The test exercises the code." Tests need meaningful assertions.
- "Local fallback files can be committed for audit." No; local-only advisory.
- "I'll paste the failing log into the MR." Strip secrets first; redact tokens, headers, env values.

## Escalation

Stop and escalate by assigning/commenting/applying the project's human-decision label when one exists; otherwise comment clearly. Escalate on external-system safety uncertainty, rule ambiguity, credential exposure, review disagreement after two rounds, or legal/ethical concern.

## Done criteria

"Done" is mode-tiered, not single-mode: the role that owns the current step decides which tier applies. A child `mr-builder` is done at **builder-ready** and must not wait on, claim, or perform the later tiers. The later tiers belong to the review gate, the authorized finisher, and the verifier respectively, and each tier points to the reference flow that owns its detail instead of restating it. Across every tier: no secrets are exposed, no live unintended product/runtime/operator side effects occur, and docs/runbooks affected by the change are updated.

- **builder-ready** — the implementation is complete and the Draft MR / Reviewer Lift are current. When the builder owns ready-marking, the local check gate is `PASS` (or `N/A` with a recorded reason), the Draft MR is marked ready, the Reviewer Lift `Reviewed SHA` equals the MR head, and the builder returned its final handoff. In parent-owned gate mode, builder-ready instead means the candidate head is pushed, the MR remains Draft, `local_gate_owner: parent` / `builder_gate_status.status: not-run` / `not_run_reason: parent-owned` / `ready_transition_owner: parent` are recorded, and the parent still owns the Gate Receipt plus ready transition. The builder stops here; this tier never includes builder self-approval or self-merge. See [reference/child-builder.md](reference/child-builder.md) §Authority boundary and child-checklist step 11.
- **review-gate-complete** — an independent reviewer has read the reviewed SHA, posted the Review Report, and the Review Gate Summary records the verdict. Standalone `/start-build` owns this gate directly; child mode hands it to the parent orchestrator. See [reference/standalone-gate.md](reference/standalone-gate.md) §Review Gate Summary. The **default deliverable is an MR**, and the review gate above is MR-centric for any code or docs-in-repo change. For an **analysis-only `kind:meta` issue whose deliverable is a tracker note rather than a repo change**, the artifact is the note instead of an MR; the gate is then the **note-deliverable review path** — a fresh independent reviewer verifies the note against the issue acceptance criteria plus a Review Gate Summary recorded on the issue. The note path does not relax any floor: mandatory independent review, no builder self-approval, and the Context Firewall are preserved exactly as on the MR path. See [reference/standalone-gate.md §Note-deliverable review path](reference/standalone-gate.md#note-deliverable-review-path) for when it applies and the preserved invariants.
- **finish-merge** — after approval, an authorized reviewer/parent/human takes the one authority-scoped finish action (`approval-only` stop, merge, or queued auto-merge) with the reviewed SHA, CI is green/pending-under-protected-auto-merge or explicitly waived in writing, the MR is merged only when merge authority allows, and the linked issue is closed by `Closes #<id>` or project workflow. See [reference/parent-orchestrator.md](reference/parent-orchestrator.md) finish-by-authority step.
- **post-merge-verified** — read-only confirmation that the default branch contains the merged change, the linked issue is closed or reported `issue_closure_pending`, source-branch cleanup is as expected, and any required durable summary is recorded. This is a verifier role, not another reviewer or finisher. See [reference/post-merge-verifier.md](reference/post-merge-verifier.md).
